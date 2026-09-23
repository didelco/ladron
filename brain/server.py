"""Laya brain: turns a guard's perception into a typed decision.

One forward pass per guard, per tick. No token streaming, no chat template:
Laya scores the options in parallel and returns calibrated probabilities.
"""

import os
import threading
import time
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Union

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

MODEL_ID = os.environ.get("LAYA_MODEL", "convaiinnovations/laya")
SUBFOLDER = os.environ.get("LAYA_SUBFOLDER") or None
DEVICE = os.environ.get("LAYA_DEVICE") or None

# The questions are not fixed here. Each guard's menu is built by the game
# from the situation it is in — the actual places it could go, described in
# words — so the service only runs Laya: one forward pass per guard answers
# every question (choice, score and yes/no) in parallel, with calibrated
# probabilities the game uses as behaviour, not just as an argmax.

# Loading the checkpoint takes ~30s. As a background service there is nobody
# around to call /warmup, so do it on startup without blocking the socket.
PRELOAD = os.environ.get("LAYA_PRELOAD") == "1"


@asynccontextmanager
async def lifespan(_: FastAPI):
    if PRELOAD:
        def run():
            try:
                decide_one(Perception(id="preload", state="The museum is quiet.", questions=WARM_QUESTIONS))
                print("[brain] preloaded and warm", flush=True)
            except Exception as e:  # cold cache with no network, say
                print(f"[brain] preload failed: {e}", flush=True)

        threading.Thread(target=run, daemon=True).start()
    yield


app = FastAPI(title="laya-hide brain", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)

_agent = None
# Metal (MPS) blows up if two forward passes encode at the same time, so every
# prediction goes through one lock. Two guards per tick is cheap enough.
_lock = threading.Lock()


_load_lock = threading.Lock()


def agent():
    global _agent
    if _agent is not None:
        return _agent
    # One load, however many requests arrive while it is happening: the
    # preload thread and the first request used to load a copy each.
    with _load_lock:
        if _agent is not None:
            return _agent
        import laya

        t0 = time.time()
        _agent = laya.load(MODEL_ID, device=DEVICE, subfolder=SUBFOLDER)
        print(f"[brain] laya ready on {_agent.device} in {time.time() - t0:.1f}s", flush=True)
    return _agent


class Perception(BaseModel):
    id: str
    # Plain text, or a JSON object whose fields the questions refer to by name.
    state: Union[str, Dict[str, Any]]
    # question id -> Laya question definition (choice / score / noul).
    questions: Dict[str, Dict[str, Any]]


class DecideRequest(BaseModel):
    guards: List[Perception]


class Decision(BaseModel):
    id: str
    answers: Dict[str, Any]
    ms: int


def decide_one(p: Perception) -> Decision:
    return decide_all([p])[0]


def decide_all(guards: List[Perception]) -> List[Decision]:
    """Every guard's every question in ONE forward pass.

    Laya scores each (state, question) pair as its own row of a batch, so a
    call about one guard is already a batch of its questions — nothing stops
    the rows coming from several guards. `Agent.predict` only builds rows for
    a single state, so this builds them for all the guards, runs the model
    once, and reads each row back exactly as `predict` does (same temperature
    buckets, same calibrated confidence). With a handful of guards this costs
    about as much as one did: the encoder is the price, and it runs once.
    """
    import numpy as np
    import torch
    from laya.common import (QTYPES, build_sequence, collate_items,
                             confidence_from_probs, temp_bucket)

    a = agent()
    max_len = a.cfg.get("max_len", 512)
    head_max_len = a.cfg.get("head_max_len", 192)
    rows = []  # (guard index, question id, internal question, marker count)
    items = []
    for gi, g in enumerate(guards):
        for qid, qdef in g.questions.items():
            q = a._to_internal(qdef)
            # A question may name the state fields it is about: every row
            # carries its own copy of the state, so a yes/no about the clue
            # need not drag the whole paragraph through the encoder.
            state = g.state
            fields = qdef.get("fields")
            if fields and isinstance(state, dict):
                state = {k: state[k] for k in fields if k in state}
            seq, markers = build_sequence(a.tok, state, q, max_len, head_max_len)
            items.append({"ids": seq, "markers": markers, "qtype": QTYPES[q["t"]]})
            rows.append((gi, qid, q, len(markers)))

    # Rows are padded to the longest in their batch, so a batch mixing a long
    # row (the plan, which reads the whole state) with short ones pays for
    # the long one everywhere. Rows of similar length go through together.
    order = sorted(range(len(items)), key=lambda i: len(items[i]["ids"]))
    groups: List[List[int]] = []
    for i in order:
        if groups and len(items[i]["ids"]) <= 1.25 * len(items[groups[-1][0]]["ids"]):
            groups[-1].append(i)
        else:
            groups.append([i])

    t0 = time.time()
    kmax = max(len(it["markers"]) for it in items)
    logits = np.full((len(items), kmax), -1e4, dtype=np.float32)
    act = np.zeros((len(items), 2), dtype=np.float32)
    # Everything that touches the device stays under the lock, reading the
    # results back included: Metal aborts the process outright if a second
    # request starts encoding while the first is still copying its answers.
    with _lock, torch.no_grad():
        for group in groups:
            b = collate_items([[items[i] for i in group]], a.tok.pad_token_id)
            lg, ac = a.model(
                b["input_ids"].to(a.device),
                b["attention_mask"].to(a.device),
                b["marker_pos"].to(a.device),
                b["marker_mask"].to(a.device),
                b["qtype"].to(a.device),
            )
            lg = lg.float().cpu().numpy()
            ac = torch.softmax(ac.float(), -1).cpu().numpy()
            for j, i in enumerate(group):
                logits[i, : lg.shape[1]] = lg[j]
                act[i, : ac.shape[1]] = ac[j]
    ms = int((time.time() - t0) * 1000)

    answers: List[Dict[str, Any]] = [{} for _ in guards]
    for r, (gi, qid, q, k) in enumerate(rows):
        qt = QTYPES[q["t"]]
        t_scale = a.temperature_by_options.get(temp_bucket(qt, k), a.temperature[qt])
        z = logits[r, :k] / t_scale
        p = np.exp(z - z.max())
        p = p / p.sum()
        conf = round(confidence_from_probs(p, k), 4)
        ext = {"act_probability": round(float(act[r, 0]), 4)}
        if q["t"] == "choice":
            keys = list(q["crit"].keys())
            answers[gi][qid] = {
                "type": "choice",
                "choice": keys[int(p.argmax())],
                "probabilities": {kk: round(float(v), 4) for kk, v in zip(keys, p)},
                "confidence": conf,
                "action": ext,
            }
        elif q["t"] == "score":
            answers[gi][qid] = {
                "type": "score",
                "score": round(float((np.arange(k) * p).sum()), 4),
                "probabilities": {str(i): round(float(v), 4) for i, v in enumerate(p)},
                "confidence": conf,
                "action": ext,
            }
        else:
            answers[gi][qid] = {
                "type": "noul",
                "noul": round(float(p[1]), 4),
                "confidence": round(max(float(p[1]), 1.0 - float(p[1])), 4),
                "action": ext,
            }
    return [Decision(id=g.id, answers=answers[gi], ms=ms) for gi, g in enumerate(guards)]


WARM_QUESTIONS = {
    "plan": {
        "type": "choice",
        "instructions": "What should the attendant do?",
        "criteria": {"patrol": "keep walking the round", "watch": "stand and watch"},
    }
}


@app.get("/health")
def health():
    a = _agent
    return {"loaded": a is not None, "device": str(a.device) if a else None, "model": MODEL_ID}


@app.post("/warmup")
def warmup():
    t0 = time.time()
    decide_one(Perception(id="warmup", state="Nothing has happened yet. The museum is quiet.", questions=WARM_QUESTIONS))
    return {"ok": True, "device": str(agent().device), "ms": int((time.time() - t0) * 1000)}


@app.post("/decide")
def decide(req: DecideRequest):
    t0 = time.time()
    decisions = decide_all(req.guards) if req.guards else []
    return {
        "decisions": decisions,
        "ms": int((time.time() - t0) * 1000),
        "device": str(agent().device),
    }

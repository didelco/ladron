// Navegación de la documentación: barra lateral por grupos, buscador global, migas de pan,
// índice «en esta página», volver arriba y anterior/siguiente. Va aparte de index.html para
// que otros cambios en ese fichero (páginas nuevas, datos) no choquen con esto.
//
// Se carga ANTES del script principal de index.html y solo usa sus globales (P, NODOS, ORDEN,
// J, TX, RF, AL, PR, elementos(), prGrupos()…) cuando se le llama, así que no depende del
// orden. Todo cuelga de window.NAV; index.html solo llama a:
//   NAV.nav(pag, sel)   pinta la barra lateral            (en lugar de la antigua nav())
//   NAV.portada()       pinta la portada (#p-inicio)      (desde pintar())
//   NAV.despues()       tras cada cambio de página        (al final de ir())
//
// Para añadir una página nueva: una entrada en GRUPOS (su id es el del hash y el de #p-<id>).
(function () {
"use strict";

// --- Mapa de la documentación: los grupos, por lo que busca cada persona ----------------------
// n(): la cifra que sale junto a la página en la portada. kw: palabras extra para el buscador.
const num = (n, uno, varios) => `${n} ${n === 1 ? uno : varios}`;
const GRUPOS = [
  { id: "empezar", titulo: "Empezar", paginas: [
    { id: "inicio", titulo: "Resumen", desc: "El mapa de toda la documentación: qué hay y dónde encontrarlo." },
    { id: "capturas", titulo: "Capturas", desc: "Todas las capturas del juego, ordenadas por sección.", n: () => num((J.capturas || []).length, "captura", "capturas"), kw: "imagenes fotos screenshots" },
  ] },
  { id: "juego", titulo: "Jugar y diseño", paginas: [
    { id: "pantallas", titulo: "Pantallas", desc: "Cada pantalla del juego con sus capturas, sus opciones y a dónde lleva.", n: () => num(Object.keys(NODOS).length, "pantalla", "pantallas"), arbol: true, kw: "menu portada titulo dojo mandos ajustes editor" },
    { id: "historia", titulo: "Historia", desc: "El prólogo, los cinco museos y los 25 robos, con todo su texto.", n: () => num(((J.historia || {}).nights || []).length, "robo", "robos"), kw: "noches cuento prologo final estrellas progreso" },
    { id: "ciudad", titulo: "Ciudad y museos", desc: "La ciudad entera y una ficha por museo.", n: () => num((((J.ciudad || {}).museums) || []).length, "museo", "museos"), kw: "mapa museos" },
    { id: "previa", titulo: "Antes de un robo", desc: "El plano, el cuento y las reglas del plan de cada robo.", kw: "briefing plan tour" },
    { id: "minijuegos", titulo: "Minijuegos", desc: "Los trabajos con las manos: ganzúa, cables, pulso…, con sus niveles.", kw: "ganzua cables pulso vitrina alarma" },
    { id: "escondites", titulo: "Escondites", desc: "Dónde se esconde el ladrón: piezas grandes, muebles y armaduras.", kw: "armadura mueble esconderse" },
    { id: "coleccion", titulo: "Colección", desc: "Qué piezas salen en cada museo, las únicas y la recreativa.", kw: "piezas unicas recreativa arcade" },
    { id: "objetos", titulo: "Objetos y piezas", desc: "Todo lo que se puede poner en un museo y las piezas a robar, con su ficha.", n: () => num(elementos().length, "cosa", "cosas"), kw: "editor catalogo loot vitrina peana" },
    { id: "personajes", titulo: "Personajes", desc: "El ladrón y el guardia: modelo, textos y procedencia.", kw: "ladron guardia ninja" },
  ] },
  { id: "editable", titulo: "Contenido editable", paginas: [
    { id: "textos", titulo: "Textos", desc: "Todos los textos del juego (locale/texts.csv) y dónde se usan; se editan aquí con «serve».", n: () => num(TX.length, "texto", "textos"), kw: "traduccion locale csv claves editar" },
    { id: "megafonia", titulo: "Megafonía", desc: "Las frases de la megafonía por tipo de aviso, con y sin voz.", n: () => num(TX.filter(x => x.group === "Megafonía").length, "frase", "frases"), kw: "voz avisos mega" },
  ] },
  { id: "arte", titulo: "Arte y sonido", paginas: [
    { id: "estilo", titulo: "Estilo", desc: "La guía de estilo: cómo debe verse y sentirse el juego.", kw: "guia arte fuente" },
    { id: "paleta", titulo: "Paleta", desc: "Cada constante de color del código, con su comentario.", n: () => num((J.paleta || []).length, "color", "colores"), kw: "colores hex" },
    { id: "propuesta", titulo: "Paleta propuesta", desc: "La propuesta pendiente de paleta común, con daltonismo y maqueta.", kw: "daltonismo colores propuesta" },
    { id: "sonidos", titulo: "Sonidos", desc: "Los efectos de sonido generados en código, para oírlos.", n: () => num((J.sonidos || []).length, "sonido", "sonidos"), kw: "sfx audio wav efectos" },
  ] },
  { id: "origen", titulo: "Origen y licencias", paginas: [
    { id: "procedencia", titulo: "Procedencia y alternativas", desc: "De dónde sale cada asset, con qué licencia y con qué se podría sustituir.", n: () => num(prGrupos().length, "colección", "colecciones"), kw: "licencia autor cc0 atribucion creditos alternativas terceros" },
    { id: "referencias", titulo: "Referencias", desc: "Enlaces de inspiración y recursos guardados, ligados a Procedencia.", n: () => num(RF.length, "enlace", "enlaces"), kw: "enlaces inspiracion recursos" },
  ] },
  { id: "tecnico", titulo: "Técnico", paginas: [
    { id: "versiones", titulo: "Versiones", desc: "Los hitos de las imágenes importantes, para compararlos antes y después.", n: () => num((window.VERSIONES || {}).asuntos ? window.VERSIONES.asuntos.length : 0, "asunto", "asuntos"), kw: "hitos historial comparar cambios" },
  ] },
];
const PAG = {}, LINEAL = [];
for (const g of GRUPOS) for (const p of g.paginas) { p.grupo = g; PAG[p.id] = p; LINEAL.push(p); }
// Las páginas que solo tienen un índice si se pide con un selector distinto de «h2».
const TOC_SEL = { procedencia: ".pr-col > h3", megafonia: "h2, h3" };
// Sin índice lateral (ya tienen su propia rejilla o son cortas).
const SIN_TOC = new Set(["inicio", "objetos", "referencias", "sonidos", "personajes", "textos"]);

// --- Utilidades ---------------------------------------------------------------------------
const norm = s => String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
const slug = s => norm(s).replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 48) || "apartado";
const html = s => String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const q1 = (s, el = document) => el.querySelector(s);
const reducido = () => window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
const suave = () => (reducido() ? "auto" : "smooth");
const hashActual = () => {
  let s = location.hash.slice(1);
  try { s = decodeURIComponent(s); } catch (e) {}
  const i = s.indexOf("/");
  return i < 0 ? [s || "inicio", ""] : [s.slice(0, i), s.slice(i + 1)];
};
const paginaDeHash = pag => (pag === "pantalla" ? "pantallas" : PAG[pag] ? pag : pag);

// --- Montaje: los elementos fijos que no están en el HTML --------------------------------------
let montado = false;
function montar() {
  if (montado) return;
  montado = true;
  const main = q1("#main");
  main.id = "main";
  main.setAttribute("tabindex", "-1");
  document.body.insertAdjacentHTML("afterbegin", `<a class="salto" href="#main" data-salto>Saltar al contenido</a>`);
  main.insertAdjacentHTML("afterbegin", `<div id="barra" class="barra">
      <button id="b-menu" class="b-menu" type="button" aria-label="Abrir el menú de navegación" aria-expanded="false" aria-controls="nav">☰</button>
      <ol id="migas" class="migas" aria-label="Dónde estás"></ol>
      <button id="b-buscar" class="b-buscar" type="button" data-buscar aria-label="Buscar en toda la documentación" aria-keyshortcuts="/ Control+K">Buscar <kbd>/</kbd></button>
    </div>
    <details id="toc-movil" class="toc-movil" hidden><summary>En esta página</summary><div class="toc-lista"></div></details>`);
  main.insertAdjacentHTML("beforeend", `<footer id="pie-pag" class="pie-pag" aria-label="Seguir leyendo"></footer>`);
  q1(".layout").insertAdjacentHTML("beforeend", `<aside id="toc" class="toc" aria-label="En esta página" hidden><div class="toc-tit">En esta página</div><div class="toc-lista"></div></aside>`);
  document.body.insertAdjacentHTML("beforeend", `<div id="velo" class="velo" data-menu-cerrar></div>
    <button id="arriba" class="arriba" type="button" aria-label="Volver arriba" hidden>↑</button>
    <div id="buscador" class="buscador" hidden role="dialog" aria-modal="true" aria-label="Buscar en la documentación">
      <div class="bus-caja">
        <div class="bus-cab"><input id="bus-q" type="search" role="combobox" aria-expanded="true" aria-controls="bus-res" aria-autocomplete="list" autocomplete="off" spellcheck="false" aria-label="Buscar" placeholder="Buscar páginas, textos del juego, objetos, sonidos, referencias…"><button id="bus-x" class="btn" type="button" aria-label="Cerrar la búsqueda">Esc</button></div>
        <div id="bus-cats" class="bus-cats" role="group" aria-label="Filtrar por tipo"></div>
        <div id="bus-res" class="bus-res" role="listbox" aria-label="Resultados"></div>
        <div class="bus-pie"><span><kbd>↑</kbd> <kbd>↓</kbd> moverse</span><span><kbd>Intro</kbd> abrir</span><span><kbd>Esc</kbd> cerrar</span></div>
      </div>
    </div>`);
  const caja = q1("#caja");
  if (caja) { caja.setAttribute("role", "dialog"); caja.setAttribute("aria-label", "Imagen ampliada"); }
  window.addEventListener("scroll", alDesplazar, { passive: true });
  window.addEventListener("resize", alDesplazar, { passive: true });
}

// --- Barra lateral --------------------------------------------------------------------------
function nav(pag, sel) {
  montar();
  const g = J.generado || {};
  const navEl = q1("#nav");
  navEl.setAttribute("aria-label", "Documentación");
  const foco = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.plegar : null;
  const paginaActiva = pag === "pantalla" ? "pantallas" : pag;
  const enlace = p => `<a href="#${p.id}" ${paginaActiva === p.id && !(p.arbol && pag === "pantalla") ? 'class="on" aria-current="page"' : ""}>${html(p.titulo)}</a>`;
  const pagina = p => enlace(p) + (p.arbol ? `<div class="arbol" role="group" aria-label="Árbol de pantallas">${arbol(P, sel)}</div>` : "");
  const grupo = g => {
    const ab = PLIEGUES["g:" + g.id] ?? true;
    return `<div class="grupo ${ab ? "" : "cerrado"}"><button class="cab" type="button" data-plegar="g:${g.id}" aria-expanded="${ab}" aria-controls="grupo-${g.id}"><span class="flecha ${ab ? "ab" : ""}" aria-hidden="true">›</span>${html(g.titulo)}${ab ? "" : `<span class="cuenta">${g.paginas.length}</span>`}</button><div class="dentro" id="grupo-${g.id}">${g.paginas.map(pagina).join("")}</div></div>`;
  };
  navEl.innerHTML = `<div class="marca"><a href="#inicio"><img src="logo.webp" alt="Ninja Karma, inicio" width="640" height="428"></a><small>Documentación del juego</small></div>
    <button class="nav-buscar" type="button" data-buscar aria-keyshortcuts="/ Control+K"><span>Buscar en todo</span><kbd>/</kbd></button>
    ${GRUPOS.map(grupo).join("")}
    <div class="meta">${html(g.fecha || "—")} · ${html(g.commit || "—")}${EDITABLE ? " · edición activa" : ""}</div>`;
  if (foco) { const b = navEl.querySelector(`[data-plegar="${foco.replace(/"/g, '\\"')}"]`); if (b) b.focus({ preventScroll: true }); }
  // Deja a la vista, dentro de la barra, la página en que estás.
  const on = navEl.querySelector("a.on");
  if (on && !navEl.classList.contains("abierto")) {
    const r = on.getBoundingClientRect(), n = navEl.getBoundingClientRect();
    if (r.bottom > n.bottom - 20 || r.top < n.top + 20) navEl.scrollTop += r.top - n.top - n.height / 3;
  }
}

// --- Portada: un mapa de todo, por lo que se quiere hacer ---------------------------------------
const INTENCIONES = [
  ["Ver cómo es el juego y cómo se recorre", ["pantallas", "capturas", "ciudad"]],
  ["Entender la historia y las reglas", ["historia", "previa", "minijuegos", "escondites", "coleccion"]],
  ["Encontrar un objeto, una pieza o un personaje", ["objetos", "personajes"]],
  ["Cambiar un texto del juego o una frase de la megafonía", ["textos", "megafonia"]],
  ["Consultar colores, estilo y sonidos", ["estilo", "paleta", "propuesta", "sonidos"]],
  ["Saber de dónde sale un asset y con qué licencia", ["procedencia", "referencias"]],
  ["Ver cómo ha cambiado el juego", ["versiones"]],
];
function portada() {
  const g = J.generado || {};
  const el = q1("#p-inicio");
  if (!el) return;
  const linea = p => `<li><a href="#${p.id}"><b>${html(p.titulo)}</b></a>${p.n ? ` <span class="estado">· ${html(p.n())}</span>` : ""}<br><span class="estado">${html(p.desc)}</span></li>`;
  el.innerHTML = `<div class="cabeza"><div><h1>Ninja Karma</h1><div class="sub">Documentación del juego, sacada del propio juego · ${html(g.fecha || "—")}</div></div></div>
    <button class="portada-buscar" type="button" data-buscar><span>Buscar en toda la documentación: un texto, un objeto, un sonido, una licencia…</span><kbd>/</kbd></button>
    <h2 id="inicio-que-quieres">¿Qué quieres hacer?</h2>
    <div class="intenciones">${INTENCIONES.map(([tit, ids]) => `<section class="intencion"><h3>${html(tit)}</h3><ul>${ids.map(i => linea(PAG[i])).join("")}</ul></section>`).join("")}</div>
    <h2 id="inicio-mapa">El mapa, por grupos</h2>
    <p class="estado">La barra de la izquierda (o el botón ☰ en el móvil) sigue este mismo orden.</p>
    <div class="mapa-grupos">${GRUPOS.filter(x => x.id !== "empezar").map(x => `<section class="mg"><h3>${html(x.titulo)}</h3><div>${x.paginas.map(p => `<a class="tag" href="#${p.id}">${html(p.titulo)}</a>`).join("")}</div></section>`).join("")}</div>
    <h2 id="inicio-pantallas">Por dónde empezar con las pantallas</h2>
    <div class="tarjetas">${P.map(tarjeta).join("")}</div>
    <details class="mas"><summary>Sobre esta documentación</summary>
      <p class="estado">Generada el ${html(g.fecha || "—")} desde <code>${html(g.rama || "")}</code> @ <code>${html(g.commit || "")}</code>.
      <code>python3 tools/docs.py build</code> lo regenera todo (abre el juego unos minutos); <code>build --fast</code>, solo datos y textos;
      <code>serve</code> la sirve en <code>http://localhost:8765</code> con los textos editables. A mano solo están <code>docs/ESTILO.md</code> y <code>docs/pantallas.js</code>.
      Atajos: <kbd>/</kbd> o <kbd>Ctrl</kbd>+<kbd>K</kbd> buscan; en una pantalla, <kbd>←</kbd> y <kbd>→</kbd> pasan a la anterior y la siguiente.</p>
    </details>`;
}

// --- Migas de pan, título, índice de la página --------------------------------------------------
let secciones = [];        // [{ id, el, li, hash }] de la página que se ve
let ultimaPagina = "";
function migas(pag, sub) {
  const inicio = `<li><a href="#inicio">Ninja Karma</a></li>`;
  let lis = [];
  if (pag === "inicio") lis = [`<li aria-current="page">Resumen</li>`];
  else {
    const p = PAG[paginaDeHash(pag)];
    if (p) lis.push(`<li class="grupo-m">${html(p.grupo.titulo)}</li>`);
    if (pag === "pantalla") {
      const id = paginaDe(sub) || sub, r = NODOS[id] ? ruta(id) : [];
      lis.push(`<li><a href="#pantallas">Pantallas</a></li>`);
      r.forEach((x, i) => lis.push(i < r.length - 1 ? `<li><a href="#pantalla/${x}">${html(nombre(NODOS[x]))}</a></li>` : `<li aria-current="page">${html(nombre(NODOS[x]))}</li>`));
    } else if (p) lis.push(`<li aria-current="page">${html(p.titulo)}</li>`);
    else lis.push(`<li aria-current="page">${html(pag)}</li>`);
  }
  q1("#migas").innerHTML = inicio + lis.join("") + `<li class="miga-sec" id="miga-sec" hidden></li>`;
  const p = PAG[paginaDeHash(pag)];
  let tit = p ? p.titulo : pag;
  if (pag === "pantalla") { const id = paginaDe(sub) || sub; if (NODOS[id]) tit = nombre(NODOS[id]); }
  document.title = (pag === "inicio" ? "" : tit + " · ") + "Ninja Karma · Documentación";
}
// El texto de un título sin el «#» del enlace ni las notas pequeñas que lleve dentro.
function tituloDe(h) {
  const c = h.cloneNode(true);
  c.querySelectorAll(".ancla, .estado, .nota").forEach(x => x.remove());
  return c.textContent.replace(/\s+/g, " ").trim();
}
function asegurarId(h, pag) {
  if (h.id) return h.id;
  const previo = h.closest("[id]");
  if (previo && previo.closest(".pagina") && previo.id.startsWith(pag + "-")) return previo.id;
  const base = pag + "-" + slug(h.textContent);
  let id = base, i = 2;
  while (document.getElementById(id)) id = base + "-" + i++;
  h.id = id;
  return id;
}
// El hash de una sección: #pagina/seccion, salvo en pantallas, donde el trozo es la subpantalla.
function hashDe(pag, id) {
  if (pag === "pantalla") { const c = id.replace(/^pantalla-/, ""); return NODOS[c] && !PAGINA(NODOS[c]) ? "#pantalla/" + c : null; }
  return id.startsWith(pag + "-") ? "#" + pag + "/" + encodeURIComponent(id.slice(pag.length + 1)) : null;
}
function indicePagina(pag) {
  const cont = q1("#p-" + pag);
  secciones = [];
  if (cont) {
    const sel = TOC_SEL[pag] || "h2";
    for (const h of cont.querySelectorAll(sel)) {
      if (!tituloDe(h)) continue;
      const id = asegurarId(h, pag);
      const nivel = h.tagName === "H3" ? 3 : 2;
      secciones.push({ id, el: document.getElementById(id) || h, hash: hashDe(pag, id), nivel, texto: tituloDe(h) || h.textContent.trim() });
      if (!h.querySelector(".ancla") && hashDe(pag, id)) h.insertAdjacentHTML("beforeend", ` <a class="ancla" href="${hashDe(pag, id)}" aria-label="Enlace a este apartado: ${html(tituloDe(h))}">#</a>`);
    }
  }
  const util = secciones.length >= 3 && !SIN_TOC.has(pag);
  const lista = util ? secciones.map(s => `<a href="${s.hash || "#" + pag}" ${s.hash ? `data-hash="${html(s.hash)}"` : ""} data-toc="${html(s.id)}" class="n${s.nivel}">${html(s.texto)}</a>`).join("") : "";
  for (const c of document.querySelectorAll("#toc .toc-lista, #toc-movil .toc-lista")) c.innerHTML = lista;
  q1("#toc").hidden = !util;
  q1("#toc-movil").hidden = !util;
  q1("#toc-movil").open = false;
  document.body.classList.toggle("con-toc", util);
  alDesplazar();
}
let ticking = false;
function alDesplazar() { if (!ticking) { ticking = true; requestAnimationFrame(() => { ticking = false; espiar(); }); } }
function espiar() {
  const y = window.scrollY;
  q1("#arriba").hidden = y < 700;
  const tope = (q1("#barra") ? q1("#barra").offsetHeight : 46) + 40;
  let act = null;
  for (const s of secciones) { if (s.el.getBoundingClientRect().top <= tope) act = s; else break; }
  for (const a of document.querySelectorAll(".toc-lista a")) {
    const on = act && a.dataset.toc === act.id;
    a.classList.toggle("on", !!on);
    if (on) a.setAttribute("aria-current", "location"); else a.removeAttribute("aria-current");
  }
  const m = q1("#miga-sec");
  if (m) { m.hidden = !act; if (act) m.textContent = act.texto.replace(/^\d+\.\s*/, ""); }
  // El índice lateral sigue el apartado actual sin salirse de su caja.
  const on = q1("#toc a.on");
  if (on && !q1("#toc").hidden) { const t = q1("#toc"), r = on.getBoundingClientRect(), tr = t.getBoundingClientRect(); if (r.bottom > tr.bottom || r.top < tr.top) t.scrollTop += r.top - tr.top - 40; }
}

// --- Anterior / siguiente al pie -----------------------------------------------------------------
function pie(pag, sub) {
  const el = q1("#pie-pag");
  const lado = (cls, etq, href, txt) => `<a class="${cls}" href="${href}"><small>${etq}</small><span>${html(txt)}</span></a>`;
  const vacio = cls => `<span class="${cls} vacio-pie"></span>`;
  let a = "", s = "";
  if (pag === "pantalla") {
    const id = paginaDe(sub) || sub, i = ORDEN.indexOf(id);
    const ant = ORDEN[i - 1], sig = ORDEN[i + 1];
    a = ant ? lado("ant", "← Pantalla anterior", "#pantalla/" + ant, nombre(NODOS[ant])) : lado("ant", "← Volver", "#pantallas", "Todas las pantallas");
    s = sig ? lado("sig", "Pantalla siguiente →", "#pantalla/" + sig, nombre(NODOS[sig])) : lado("sig", "Ver →", "#pantallas", "Todas las pantallas");
  } else {
    const i = LINEAL.findIndex(p => p.id === paginaDeHash(pag));
    if (i < 0) { el.innerHTML = ""; return; }
    a = LINEAL[i - 1] ? lado("ant", "← Anterior", "#" + LINEAL[i - 1].id, LINEAL[i - 1].titulo) : vacio("ant");
    s = LINEAL[i + 1] ? lado("sig", "Siguiente →", "#" + LINEAL[i + 1].id, LINEAL[i + 1].titulo) : vacio("sig");
  }
  el.innerHTML = a + `<a class="sube" href="#main" data-arriba>Volver arriba ↑</a>` + s;
}

// --- Llegar a un sitio concreto (desde un enlace, el buscador o la barra) -----------------------
let venimosDeBuscar = null;  // { textos: bool, alt: bool }
function despues() {
  montar();
  const [pag, sub] = hashActual();
  const cambio = ultimaPagina !== pag + (pag === "pantalla" ? "/" + (paginaDe(sub) || sub) : "");
  ultimaPagina = pag + (pag === "pantalla" ? "/" + (paginaDe(sub) || sub) : "");
  let destino = null;
  // Filtros que esconderían lo que se busca: se quitan para que el enlace llegue siempre.
  if (pag === "textos") {
    if (sub && sub in TEXT) { filtro.q = sub; filtro.grupo = "Todos"; textos(); venimosDeBuscar = { textos: true }; destino = document.querySelector(`#filas [data-key="${CSS.escape(sub)}"]`); }
    else if (venimosDeBuscar && venimosDeBuscar.textos) { filtro.q = ""; textos(); venimosDeBuscar = null; }
  } else if (pag === "procedencia" && sub) {
    if (!document.getElementById("procedencia-" + sub)) { prFiltro.lic = ""; prFiltro.tipo = ""; prFiltro.q = ""; prFiltro.alt = false; procedencia(); }
    destino = document.getElementById("procedencia-" + sub);
    if (destino && venimosDeBuscar && venimosDeBuscar.alt) { const d = destino.querySelector("details.alt"); if (d) d.open = true; }
    venimosDeBuscar = null;
  } else if (pag === "referencias" && sub) {
    if (!document.getElementById("referencias-" + sub)) { rfFiltro.q = ""; rfFiltro.tipo = ""; rfFiltro.etq = ""; rfFiltro.estado = ""; referencias(); }
    destino = document.getElementById("referencias-" + sub);
  }
  migas(pag, sub);
  const actual = paginaDeHash(pag);
  // Al entrar en una página, su grupo se abre.
  const grupo = PAG[actual] && PAG[actual].grupo;
  if (cambio && grupo && PLIEGUES["g:" + grupo.id] === false) { PLIEGUES["g:" + grupo.id] = true; guardarPliegues(); nav(...ACTUAL); }
  document.body.classList.remove("menu-abierto");
  q1("#b-menu").setAttribute("aria-expanded", "false");
  indicePagina(pag);
  pie(pag, sub);
  // Con ids nuevos (los que se ponen aquí) ir() no pudo llegar: se llega ahora.
  let el = destino;
  if (!el && sub && pag !== "pantalla" && pag !== "objetos") el = document.getElementById(pag + "-" + sub) || document.getElementById(sub);
  if (el) { el.scrollIntoView(); destello(el); }
  else if (cambio && !(pag === "objetos" && sub)) window.scrollTo(0, 0);
  if (cambio) q1("#main").focus({ preventScroll: true });
  accesibilidad();
  alDesplazar();
}
function destello(el) {
  if (reducido()) return;
  el.classList.remove("destello"); void el.offsetWidth; el.classList.add("destello");
  setTimeout(() => el.classList.remove("destello"), 2200);
}

// --- Accesibilidad básica: lo que las páginas pintan sin ello -----------------------------------
function accesibilidad() {
  for (const b of document.querySelectorAll(".filtros .btn[data-pr-lic], .filtros .btn[data-pr-tipo], .filtros .btn[data-pr-alt], .filtros .btn[data-rf-tipo], .filtros .btn[data-rf-estado], .filtros .btn[data-rf-etq], .filtros .btn[data-tipo]")) b.setAttribute("aria-pressed", b.classList.contains("si") ? "true" : "false");
  for (const i of document.querySelectorAll("input:not([aria-label]):not([type=radio]):not([type=hidden]), textarea:not([aria-label])")) {
    if (!i.closest("label") && !i.id.startsWith("bus-")) i.setAttribute("aria-label", i.placeholder || i.name || "Campo");
  }
  for (const s of document.querySelectorAll("select:not([aria-label])")) if (!s.closest("label")) s.setAttribute("aria-label", s.id === "grupo" ? "Grupo de textos" : "Elegir");
  for (const im of document.querySelectorAll("img[data-img]:not([tabindex])")) { im.tabIndex = 0; im.setAttribute("role", "button"); if (!im.alt) im.alt = im.dataset.cap || "Imagen"; im.setAttribute("aria-label", "Ampliar: " + (im.dataset.cap || im.alt)); }
  for (const b of document.querySelectorAll(".oc:not([aria-label])")) b.setAttribute("aria-label", (b.querySelector(".n") || b).textContent.trim());
}

// --- Buscador global ---------------------------------------------------------------------------
const CATS = ["Páginas", "Apartados", "Pantallas", "Objetos y piezas", "Personajes", "Historia", "Ciudad", "Sonidos", "Textos del juego", "Megafonía", "Referencias", "Procedencia", "Alternativas", "Paleta"];
let IDX = null, IDX_KEY = null;
const corta = (s, n = 120) => { s = String(s ?? "").replace(/\s+/g, " ").trim(); return s.length > n ? s.slice(0, n - 1) + "…" : s; };
function construirIndice() {
  const clave = [TX, RF, AL.grupos.length, Object.keys(PR.archivos || {}).length];
  if (IDX && IDX_KEY && clave.every((c, i) => c === IDX_KEY[i])) return IDX;
  const it = [];
  const add = (cat, titulo, sub, href, extra = "", peso = 0, flags = null) => it.push({ cat, titulo, sub, href, extra, peso, flags, t: norm(titulo), h: norm(titulo + " " + sub + " " + extra) });
  const h = "#";
  // Páginas
  for (const p of LINEAL) add("Páginas", p.titulo, p.desc, h + p.id, p.grupo.titulo + " " + (p.kw || ""), 30);
  // Apartados de las páginas de texto largo (los títulos que ya tienen)
  for (const p of LINEAL) {
    if (["textos", "megafonia", "procedencia", "referencias", "pantallas", "paleta", "objetos", "sonidos", "inicio"].includes(p.id)) continue;
    const cont = q1("#p-" + p.id);
    if (!cont) continue;
    for (const hd of cont.querySelectorAll("h2, h3")) {
      const txt = tituloDe(hd);
      if (!txt) continue;
      const id = asegurarId(hd, p.id), hs = hashDe(p.id, id);
      if (hs) add("Apartados", txt.replace(/^\d+\.\s*/, ""), p.titulo, hs, "", 8);
    }
  }
  // Pantallas
  for (const n of Object.values(NODOS)) add("Pantallas", nombre(n), corta(n.text || "", 100), h + "pantalla/" + n.id, (n.fn || "") + " " + (n.phase || "") + " " + (n.options || []).map(o => (o.key ? tx(o.key) : o.label || "") + " " + (o.text || "")).join(" "), 12);
  // Objetos y piezas
  for (const e of elementos()) add("Objetos y piezas", e.nombre, e.cat === "loot" ? "Pieza a robar" : "Objeto · " + frase(tx((TIPOS.find(x => x[0] === e.cat) || [0, ""])[1])), h + "objetos/" + e.id, (e.ctx || "") + " " + e.id, 10);
  // Personajes
  add("Personajes", "Ladrón", "ninja.glb", h + "personajes", "ninja banda", 10);
  add("Personajes", "Guardia", "guardia.glb", h + "personajes", "vigilante linterna", 10);
  // Historia
  const hi = J.historia || {};
  const pl = (hi.nights || []);
  for (const n of pl) {
    const l = n.loot, m = museoDe(n.n);
    add("Historia", `Robo ${String(n.n).padStart(2, "0")} · ${tx(l.name)}`, m ? tx(m.name) : "", h + "historia/robo-" + n.n, [tx(l.blurb), tx(l.verb), tx(l.story), n.boss ? tx(n.tip) : ""].join(" "), 6);
  }
  for (const m of hi.museums || []) add("Historia", tx(m.name), "Museo " + m.n, h + "historia/museo" + m.n, tx(m.text), 8);
  add("Historia", "Prólogo", "La historia", h + "historia/prologo", tx(hi.prologue), 4);
  add("Historia", "Final", "La historia", h + "historia/final", tx(hi.ending), 4);
  // Ciudad
  for (const m of ((J.ciudad || {}).museums) || []) add("Ciudad", tx(m.name), "Ficha del museo " + m.n, h + "ciudad/museo" + m.n, m.theme || "", 6);
  // Sonidos
  for (const s of J.sonidos || []) add("Sonidos", s.name, `${s.seconds} s`, h + "sonidos/" + encodeURIComponent(s.name), "efecto sfx", 6);
  // Textos y megafonía
  for (const x of TX) {
    if (x.group === "Megafonía") add("Megafonía", corta(x.es), x.key + (x.audio ? " · con voz" : " · sin voz"), h + "megafonia" + (x.pool ? "/" + encodeURIComponent(x.pool) : ""), x.key + " " + x.es, 0);
    else add("Textos del juego", corta(x.es), x.key + " · " + x.group, h + "textos/" + encodeURIComponent(x.key), x.key + " " + x.es, 0);
  }
  // Referencias
  for (const r of RF) add("Referencias", r.titulo, `${r.dominio} · ${r.estado}`, h + "referencias/" + encodeURIComponent(r.id), `${r.url} ${r.nota || ""} ${r.licencia || ""} ${(r.etiquetas || []).join(" ")} ${r.tipo}`, 6);
  // Procedencia y alternativas
  const claveDe = {};
  for (const { r, rutas } of prGrupos()) {
    claveDe[r.id] = claveDe[r.id] || r.clave;
    add("Procedencia", r.nombre, `${(PR.licencias[r.licencia] || { corta: r.licencia }).corta} · ${r.tipo === "externo" ? "de terceros" : "propio"} · ${rutas.length} fichero${rutas.length === 1 ? "" : "s"}`, h + "procedencia/" + encodeURIComponent(r.clave), `${r.metodo || ""} ${r.autor || ""} ${r.notas || ""} ${r.licencia} ${rutas.join(" ")}`, 6);
  }
  for (const g of AL.grupos) for (const a of g.alternativas) {
    const c = claveDe[g.coleccion];
    if (c) add("Alternativas", a.nombre, `alternativa para ${((PR.colecciones || {})[g.coleccion] || {}).nombre || g.coleccion} · ${g.que_es}`, h + "procedencia/" + encodeURIComponent(c), `${a.autor || ""} ${a.notas || ""} ${a.licencia} ${a.cubre || ""} ${a.url}`, 6, { alt: true });
  }
  // Paleta
  const idf = f => f.replace(/\W/g, "_");
  for (const e of J.paleta || []) add("Paleta", e.name, e.file, h + "paleta/" + idf(e.file), `${e.note || ""} ${e.colours.map(c => c.hex + " " + (c.key || "")).join(" ")}`, 0);
  IDX = it; IDX_KEY = clave;
  return it;
}
function puntuar(it, toks) {
  let s = it.peso;
  for (const tk of toks) {
    const i = it.t.indexOf(tk);
    if (i === 0) s += 30; else if (i > 0 && /[^a-z0-9]/.test(it.t[i - 1])) s += 20; else if (i > 0) s += 12;
    else if (it.h.indexOf(tk) >= 0) s += 3; else return -1;
  }
  return s - Math.min(it.titulo.length, 80) / 100;
}
function buscar(q) {
  const toks = norm(q).split(/\s+/).filter(Boolean);
  if (!toks.length) return [];
  const out = [];
  for (const it of construirIndice()) { const s = puntuar(it, toks); if (s >= 0) out.push({ it, s }); }
  out.sort((a, b) => b.s - a.s);
  return out;
}
// Resalta en el texto original los trozos que casan (la normalización conserva la longitud).
function resaltar(txt, toks) {
  const n = norm(txt);
  if (n.length !== txt.length || !toks.length) return html(txt);
  const marca = new Array(txt.length).fill(false);
  for (const tk of toks) { let i = n.indexOf(tk); while (i >= 0) { for (let k = i; k < i + tk.length; k++) marca[k] = true; i = n.indexOf(tk, i + tk.length); } }
  let out = "", abierto = false;
  for (let k = 0; k < txt.length; k++) {
    if (marca[k] !== abierto) { out += abierto ? "</mark>" : "<mark>"; abierto = marca[k]; }
    out += html(txt[k]);
  }
  return out + (abierto ? "</mark>" : "");
}
const BUS = { q: "", cat: "", activo: 0, abiertas: new Set(), previo: null };
function busAbierto() { return !q1("#buscador").hidden; }
function abrirBuscar(q) {
  montar();
  BUS.previo = document.activeElement;
  document.body.classList.remove("menu-abierto");
  q1("#buscador").hidden = false;
  document.body.classList.add("buscando");
  const inp = q1("#bus-q");
  if (typeof q === "string") inp.value = q;
  BUS.q = inp.value; BUS.cat = ""; BUS.abiertas = new Set();
  pintarBusqueda();
  inp.focus(); inp.select();
}
function cerrarBuscar() {
  if (!busAbierto()) return;
  q1("#buscador").hidden = true;
  document.body.classList.remove("buscando");
  if (BUS.previo && BUS.previo.focus && document.contains(BUS.previo)) BUS.previo.focus({ preventScroll: true });
}
function pintarBusqueda() {
  const res = q1("#bus-res"), cats = q1("#bus-cats"), toks = norm(BUS.q).split(/\s+/).filter(Boolean);
  BUS.activo = 0;
  if (!toks.length) {
    cats.innerHTML = "";
    res.innerHTML = `<div class="bus-cat" role="presentation">Todas las páginas</div>` + GRUPOS.map(g => g.paginas.map(p => item({ titulo: p.titulo, sub: g.titulo + " · " + p.desc, href: "#" + p.id }, [])).join("")).join("")
      + `<p class="bus-ayuda">Prueba con «guardia», «cc0», «MEGA_ALARM», «ganzúa», «#b32424» o el nombre de una pieza. Varias palabras: tienen que estar todas.</p>`;
    marcarActivo(0);
    return;
  }
  const todos = buscar(BUS.q);
  const por = {};
  for (const r of todos) (por[r.it.cat] = por[r.it.cat] || []).push(r);
  cats.innerHTML = todos.length ? `<button type="button" class="btn ${BUS.cat ? "" : "si"}" data-bus-cat="" aria-pressed="${!BUS.cat}">Todo <span>${todos.length}</span></button>` + CATS.filter(c => por[c]).map(c => `<button type="button" class="btn ${BUS.cat === c ? "si" : ""}" data-bus-cat="${html(c)}" aria-pressed="${BUS.cat === c}">${html(c)} <span>${por[c].length}</span></button>`).join("") : "";
  if (!todos.length) {
    res.innerHTML = `<div class="bus-vacio"><b>Nada para «${html(BUS.q.trim())}».</b><p>Prueba con menos palabras o sin tildes, o busca por la clave de un texto (<code>MENU_STORY</code>), una licencia (<code>CC0</code>) o un color (<code>#b32424</code>).</p>
      <p>O mira el <a href="#inicio" data-cerrar-bus>mapa de la documentación</a>.</p></div>`;
    return;
  }
  let salida = "";
  for (const c of CATS) {
    const l = por[c];
    if (!l || (BUS.cat && BUS.cat !== c)) continue;
    const limite = BUS.cat ? 100 : BUS.abiertas.has(c) ? 40 : l.length <= 7 ? l.length : 5;
    salida += `<div class="bus-cat" role="presentation">${html(c)} <span>${l.length}</span></div>` + l.slice(0, limite).map(r => item(r.it, toks)).join("");
    if (!BUS.cat && l.length > limite) salida += `<button type="button" class="bus-mas" data-bus-mas="${html(c)}">${BUS.abiertas.has(c) ? `Filtrar solo «${html(c)}»` : `Ver ${Math.min(35, l.length - limite)} más de ${html(c)}`}</button>`;
    if (BUS.cat && l.length > limite) salida += `<p class="bus-ayuda">Se enseñan los ${limite} primeros de ${l.length}: afina la búsqueda.</p>`;
  }
  res.innerHTML = salida;
  marcarActivo(0);
}
let itemN = 0;
function item(it, toks) {
  return `<a class="bus-item" role="option" id="bus-i${itemN++}" href="${html(it.href)}" ${it.flags && it.flags.alt ? 'data-alt="1"' : ""} aria-selected="false"><span class="bus-t">${resaltar(it.titulo, toks)}</span><span class="bus-s">${resaltar(it.sub || "", toks)}</span></a>`;
}
function marcarActivo(n) {
  const items = [...document.querySelectorAll("#bus-res .bus-item")];
  if (!items.length) { q1("#bus-q").removeAttribute("aria-activedescendant"); return; }
  BUS.activo = (n + items.length) % items.length;
  items.forEach((a, i) => a.setAttribute("aria-selected", i === BUS.activo ? "true" : "false"));
  const a = items[BUS.activo];
  q1("#bus-q").setAttribute("aria-activedescendant", a.id);
  a.scrollIntoView({ block: "nearest" });
}
function irA(a) {
  if (!a) return;
  const href = a.getAttribute("href");
  if (a.dataset.alt) venimosDeBuscar = { alt: true };
  cerrarBuscar();
  const igual = decodeURIComponent(location.hash) === decodeURIComponent(href);
  location.hash = href;
  if (igual) ir();
}

// --- Eventos ---------------------------------------------------------------------------------
document.addEventListener("keydown", e => {
  const enCampo = e.target.closest && e.target.closest("input, textarea, select, [contenteditable]");
  if ((e.key === "k" || e.key === "K") && (e.ctrlKey || e.metaKey)) { e.preventDefault(); busAbierto() ? cerrarBuscar() : abrirBuscar(); return; }
  if (e.key === "/" && !enCampo && !e.ctrlKey && !e.metaKey && !e.altKey && !busAbierto()) { e.preventDefault(); abrirBuscar(); return; }
  if (busAbierto()) {
    e.stopPropagation();
    if (e.key === "Escape") { e.preventDefault(); cerrarBuscar(); }
    else if (e.key === "ArrowDown") { e.preventDefault(); marcarActivo(BUS.activo + 1); }
    else if (e.key === "ArrowUp") { e.preventDefault(); marcarActivo(BUS.activo - 1); }
    else if (e.key === "Enter" && e.target.id === "bus-q") { e.preventDefault(); irA(document.querySelectorAll("#bus-res .bus-item")[BUS.activo]); }
    else if (e.key === "Tab") {
      // El foco no sale del buscador.
      const f = [...document.querySelectorAll("#buscador input, #buscador button, #buscador a")].filter(x => x.offsetParent);
      const i = f.indexOf(document.activeElement);
      if (e.shiftKey && i <= 0) { e.preventDefault(); f[f.length - 1].focus(); } else if (!e.shiftKey && i === f.length - 1) { e.preventDefault(); f[0].focus(); }
    }
    return;
  }
  if (e.key === "Escape" && document.body.classList.contains("menu-abierto")) { document.body.classList.remove("menu-abierto"); q1("#b-menu").setAttribute("aria-expanded", "false"); q1("#b-menu").focus(); return; }
  if (e.key === "Enter" && e.target.matches && e.target.matches("img[data-img][role=button]")) e.target.click();
}, true);
document.addEventListener("input", e => {
  if (e.target.id !== "bus-q") return;
  BUS.q = e.target.value; BUS.cat = ""; BUS.abiertas = new Set();
  pintarBusqueda();
});
document.addEventListener("click", e => {
  const c = e.target;
  if (c.closest("[data-buscar]")) { e.preventDefault(); abrirBuscar(); return; }
  if (c.closest("#bus-x")) { cerrarBuscar(); return; }
  if (busAbierto()) {
    if (c.id === "buscador") { cerrarBuscar(); return; }
    const cat = c.closest("[data-bus-cat]");
    if (cat) { BUS.cat = cat.dataset.busCat; pintarBusqueda(); q1("#bus-q").focus(); return; }
    const mas = c.closest("[data-bus-mas]");
    if (mas) { if (BUS.abiertas.has(mas.dataset.busMas)) BUS.cat = mas.dataset.busMas; else BUS.abiertas.add(mas.dataset.busMas); pintarBusqueda(); return; }
    const a = c.closest("a.bus-item");
    if (a) { e.preventDefault(); irA(a); return; }
    if (c.closest("[data-cerrar-bus]")) { cerrarBuscar(); return; }
    return;
  }
  if (c.closest("#b-menu")) {
    const ab = document.body.classList.toggle("menu-abierto");
    q1("#b-menu").setAttribute("aria-expanded", String(ab));
    if (ab) { const p = q1("#nav a.on") || q1("#nav a"); p && p.focus({ preventScroll: true }); }
    return;
  }
  if (c.closest("[data-menu-cerrar]")) { document.body.classList.remove("menu-abierto"); q1("#b-menu").setAttribute("aria-expanded", "false"); return; }
  if (c.closest("#nav a") && document.body.classList.contains("menu-abierto")) { document.body.classList.remove("menu-abierto"); q1("#b-menu").setAttribute("aria-expanded", "false"); }
  if (c.closest("#arriba") || c.closest("[data-arriba]")) { e.preventDefault(); window.scrollTo({ top: 0, behavior: suave() }); q1("#main").focus({ preventScroll: true }); return; }
  if (c.closest("[data-salto]")) { e.preventDefault(); q1("#main").focus(); return; }
  // Un enlace del índice: desplazamiento suave, y el hash queda como enlace profundo.
  const t = c.closest("a[data-toc]");
  if (t) {
    e.preventDefault();
    const el = document.getElementById(t.dataset.toc);
    if (!el) return;
    if (t.dataset.hash && decodeURIComponent(t.dataset.hash) !== decodeURIComponent(location.hash)) history.pushState(null, "", t.dataset.hash);
    el.scrollIntoView({ behavior: suave() });
    destello(el);
    const d = c.closest("#toc-movil"); if (d) d.open = false;
    return;
  }
  // El «#» junto a un título copia (y fija en la barra de direcciones) su enlace.
  const an = c.closest("a.ancla");
  if (an) {
    e.preventDefault();
    const url = location.href.split("#")[0] + an.getAttribute("href");
    history.pushState(null, "", an.getAttribute("href"));
    navigator.clipboard && navigator.clipboard.writeText(url).catch(() => {});
    an.classList.add("copiado"); setTimeout(() => an.classList.remove("copiado"), 1200);
    return;
  }
  // Un clic en filtros o en la lista repinta trozos de página: se rehacen las etiquetas.
  setTimeout(accesibilidad, 0);
});
document.addEventListener("input", () => setTimeout(accesibilidad, 0));

window.NAV = { nav, portada, despues, abrirBuscar, GRUPOS, PAG, LINEAL, buscar, construirIndice, norm };
})();

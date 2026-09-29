window.CODIGO = {
 "logic/minigame.gd": {
  "doc": "A job done with the hands, in a little box by the thief (MinigameBox), as in Among Us: the world goes on meanwhile, so the longer it takes, the longer you stand there to be seen.  This is what they all share: the keys (only presses count, and what was already held when it opened is not a press), the time, the level, how much the hands shake, being held off by someone else's part, and letting go with the roll key (B) — only that one, so a brush of the stick never throws a job away. Each kind is a script of its own in logic/minigames/, named as the kind, with its look in scenes/minigame_views/ (MinigameView):  of the action kind, which cannot be failed, only done slowly: \"lockpick\" (LockpickGame), \"wires\" (WiresGame), \"steady\" (SteadyGame), \"squeeze\" (SqueezeGame: wriggling into a hideout); of the enduring kind, which can be failed: \"balance\" (BalanceGame: posing as a statue on one foot), \"sneeze\" (SneezeGame: holding in a sneeze while hiding, which never ends while you stay in); and one just for fun, which never ends: \"arcade\" (ArcadeGame: pong on the arcade machine, Arcades).  A new one: logic/minigames/<kind>.gd extending this (its _setup and _play, and progress if it is not counted in steps), scenes/minigame_views/<kind>.gd extending MinigameView, a line GAME_HOW_<KIND> in locale/texts.csv, and whoever starts it calls Minigame.make(\"<kind>\", …). Nothing else needs to know it exists.  Each comes in three levels (level: 0 easy .. 2 hard, level_now()), and frightened hands shake (tremble, 0..1, from how alarmed the guards are).",
  "consts": {
   "SCRIPTS": {
    "value": "\"res://logic/minigames/%s.gd\"",
    "note": "",
    "line": 33
   },
   "DIRS": {
    "value": "[\"up\", \"right\", \"down\", \"left\"]",
    "note": "Directions, as the games name them: up, right, down, left.",
    "line": 35
   }
  }
 },
 "logic/minigames/arcade.gd": {
  "doc": "The modern gallery's arcade machine (Arcades): a game of pong against the machine, up and down to move your paddle. It is a joke: there is nothing to win, it never ends, and you only leave it by letting go — meanwhile you stand there playing, in plain sight, while the guards walk their rounds. The score is only for pride.  The court: x from -HALF_W (your side) to HALF_W (the machine's), y from -HALF_H to HALF_H, up positive.",
  "consts": {
   "HALF_W": {
    "value": "0.8",
    "note": "",
    "line": 12
   },
   "HALF_H": {
    "value": "0.5",
    "note": "",
    "line": 13
   },
   "PADDLE_X": {
    "value": "0.7",
    "note": "Where the paddles stand, and half their height.",
    "line": 15
   },
   "PADDLE_H": {
    "value": "0.13",
    "note": "Where the paddles stand, and half their height.",
    "line": 16
   },
   "BALL": {
    "value": "0.03",
    "note": "The ball's half size.",
    "line": 18
   },
   "MY_SPEED": {
    "value": "1.7",
    "note": "Speeds, in court units a second: yours, the machine's (slower, so it can be beaten), and the ball's, from its serve up to its fastest.",
    "line": 21
   },
   "CPU_SPEED": {
    "value": "0.8",
    "note": "Speeds, in court units a second: yours, the machine's (slower, so it can be beaten), and the ball's, from its serve up to its fastest.",
    "line": 22
   },
   "SERVE": {
    "value": "0.8",
    "note": "Speeds, in court units a second: yours, the machine's (slower, so it can be beaten), and the ball's, from its serve up to its fastest.",
    "line": 23
   },
   "FASTEST": {
    "value": "1.8",
    "note": "Speeds, in court units a second: yours, the machine's (slower, so it can be beaten), and the ball's, from its serve up to its fastest.",
    "line": 24
   },
   "SPEED_UP": {
    "value": "1.07",
    "note": "Each hit off a paddle, this much faster.",
    "line": 26
   },
   "STEEPEST": {
    "value": "1.0",
    "note": "The steepest the ball leaves a paddle, off its very edge, in radians.",
    "line": 28
   },
   "SLOPPY": {
    "value": "1.4",
    "note": "Where on its paddle the machine means to take the ball, anywhere up to this many half paddles from its middle: past one and a bit it misses, now and then.",
    "line": 32
   },
   "PAUSE_S": {
    "value": "0.7",
    "note": "After a point, the ball waits this long in the middle.",
    "line": 34
   }
  }
 },
 "logic/minigames/balance.gd": {
  "doc": "Posing as a statue on a pedestal (Plinths): on one foot, the thief sways and tips; left and right keep it up. Over it goes past the point of no return: it falls off, and that is a noise (\"fail\"). It never ends by itself: it lasts while the pose does, a little harder by the second (very slowly: nobody stands on one foot for ever), and on top of that harder the closer the guards come (and a little with the lights on: pressure, 0..1). Short taps steady it: held down, a key pushes harder and harder, and over it goes the other way. Leaning far (WOBBLE), it sweats and wobbles, and a guard looking sees it is no statue. Harder levels tip sooner and tire a little faster.",
  "consts": {
   "TOPPLE": {
    "value": "2.2",
    "note": "How fast a lean grows by itself (more under pressure), how quickly the sway slows, and the nudges that come from nowhere.",
    "line": 16
   },
   "LEAN_DAMP": {
    "value": "1.6",
    "note": "How fast a lean grows by itself (more under pressure), how quickly the sway slows, and the nudges that come from nowhere.",
    "line": 17
   },
   "TAP_KICK": {
    "value": "0.35",
    "note": "Left and right: a tap gives a little kick; held, the push grows exponentially with how long (doubling every HOLD_DOUBLE seconds, up to PUSH_MAX), so a long press throws it over the other way.",
    "line": 21
   },
   "PUSH_BASE": {
    "value": "2.0",
    "note": "Left and right: a tap gives a little kick; held, the push grows exponentially with how long (doubling every HOLD_DOUBLE seconds, up to PUSH_MAX), so a long press throws it over the other way.",
    "line": 22
   },
   "HOLD_DOUBLE": {
    "value": "0.18",
    "note": "Left and right: a tap gives a little kick; held, the push grows exponentially with how long (doubling every HOLD_DOUBLE seconds, up to PUSH_MAX), so a long press throws it over the other way.",
    "line": 23
   },
   "PUSH_MAX": {
    "value": "30.0",
    "note": "Left and right: a tap gives a little kick; held, the push grows exponentially with how long (doubling every HOLD_DOUBLE seconds, up to PUSH_MAX), so a long press throws it over the other way.",
    "line": 24
   },
   "NUDGE": {
    "value": "0.9",
    "note": "Left and right: a tap gives a little kick; held, the push grows exponentially with how long (doubling every HOLD_DOUBLE seconds, up to PUSH_MAX), so a long press throws it over the other way.",
    "line": 25
   },
   "NUDGE_S": {
    "value": "0.7",
    "note": "Left and right: a tap gives a little kick; held, the push grows exponentially with how long (doubling every HOLD_DOUBLE seconds, up to PUSH_MAX), so a long press throws it over the other way.",
    "line": 26
   },
   "TOPPLE_LEVEL": {
    "value": "[0.8, 1.0, 1.2]",
    "note": "By level: how quickly it tips over, and how much harder it gets with every second on one foot (a share of what it was at the start: 0.015 is 1.9 times as hard after a minute).",
    "line": 30
   },
   "TIRE_LEVEL": {
    "value": "[0.01, 0.015, 0.02]",
    "note": "By level: how quickly it tips over, and how much harder it gets with every second on one foot (a share of what it was at the start: 0.015 is 1.9 times as hard after a minute).",
    "line": 31
   },
   "PRESSURE_TOPPLE": {
    "value": "1.2",
    "note": "At full pressure (the guards on top of it), how much harder it tips and how much harder the nudges come, as a share of what they are when calm.",
    "line": 34
   },
   "PRESSURE_NUDGE": {
    "value": "1.5",
    "note": "At full pressure (the guards on top of it), how much harder it tips and how much harder the nudges come, as a share of what they are when calm.",
    "line": 35
   },
   "FALL": {
    "value": "1.6",
    "note": "Leaning this far it falls off (the lean is in the figure's units: 1 is Figure.MAX_LEAN radians over).",
    "line": 38
   },
   "WOBBLE": {
    "value": "0.6",
    "note": "Leaning this far, the statue wobbles for all to see: a big drop of sweat, and to a guard looking it is no statue (wobbling()).",
    "line": 41
   }
  }
 },
 "logic/minigames/lockpick.gd": {
  "doc": "The case: a dial on the lock, a needle going round it and a green sector on its rim; press the action key as the needle crosses the green to set a pin, one pin after another, the green somewhere else each time. A miss slips the pick, and it settles again. Shaking hands make the needle jitter and the green narrower.",
  "consts": {
   "PIN_PERIOD": {
    "value": "1.0",
    "note": "Seconds for the needle to go once round the dial.",
    "line": 10
   },
   "PIN_BAND": {
    "value": "0.1",
    "note": "Half the width of the green sector, as a share of the way round, steady; at full tremble it is SHAKE_NARROW narrower.",
    "line": 13
   },
   "SHAKE_NARROW": {
    "value": "0.4",
    "note": "Half the width of the green sector, as a share of the way round, steady; at full tremble it is SHAKE_NARROW narrower.",
    "line": 14
   },
   "SHAKE_JITTER": {
    "value": "0.04",
    "note": "How far the needle jitters at full tremble, as a share of the way round.",
    "line": 16
   },
   "SLIP_S": {
    "value": "0.45",
    "note": "A miss: the pick slips off, and the hands answer again after this long.",
    "line": 18
   },
   "GIVE": {
    "value": "0.45",
    "note": "Each near miss on the same pin loosens it: its sweet spot this much wider (a share of PIN_BAND), so whoever keeps at it always gets there.",
    "line": 21
   }
  }
 },
 "logic/minigames/sneeze.gd": {
  "doc": "Hiding (Hideouts): after a while in there, dust tickles the nose. Tickles come along a lane, left to right, on a steady beat, towards the nose; press the action key as each one crosses the bar to hold the sneeze in. Let one through, or miss too often (MISSES), and out it comes: ACHOO! — out of the hideout, and every guard near hears it. It never ends while you stay in: the longer you stay and the more alarmed the guards, the narrower the bar and the quicker the beat. Easier than the pick: the bar starts wide. You leave it by leaving the hideout (any direction), not by letting go: that would be hiding for ever.  The lane: x from -1 (where the tickles come from) to 1 (the nose).",
  "consts": {
   "CALM_S": {
    "value": "5.0",
    "note": "Seconds in the hideout, calm, before the tickling starts, and how long the sneeze leaves the thief stunned on the floor.",
    "line": 17
   },
   "STUN_S": {
    "value": "0.8",
    "note": "Seconds in the hideout, calm, before the tickling starts, and how long the sneeze leaves the thief stunned on the floor.",
    "line": 18
   },
   "BAR_X": {
    "value": "0.45",
    "note": "Where the bar is along the lane, and half its width: at first, at its narrowest (after SHRINK_S in there), and at full tremble this much less.",
    "line": 21
   },
   "BAR": {
    "value": "0.2",
    "note": "Where the bar is along the lane, and half its width: at first, at its narrowest (after SHRINK_S in there), and at full tremble this much less.",
    "line": 22
   },
   "NARROWEST": {
    "value": "0.07",
    "note": "Where the bar is along the lane, and half its width: at first, at its narrowest (after SHRINK_S in there), and at full tremble this much less.",
    "line": 23
   },
   "SHRINK_S": {
    "value": "60.0",
    "note": "Where the bar is along the lane, and half its width: at first, at its narrowest (after SHRINK_S in there), and at full tremble this much less.",
    "line": 24
   },
   "SHAKE_NARROW": {
    "value": "0.35",
    "note": "Where the bar is along the lane, and half its width: at first, at its narrowest (after SHRINK_S in there), and at full tremble this much less.",
    "line": 25
   },
   "BAR_LEVEL": {
    "value": "[1.15, 1.0, 0.85]",
    "note": "How far the bar is by level (0 easy .. 2 hard), as a share of BAR.",
    "line": 27
   },
   "BEAT": {
    "value": "1.3",
    "note": "Seconds between tickles, at first and at the quickest (after SHRINK_S).",
    "line": 29
   },
   "QUICKEST": {
    "value": "0.75",
    "note": "Seconds between tickles, at first and at the quickest (after SHRINK_S).",
    "line": 30
   },
   "SPEED": {
    "value": "1.1",
    "note": "How fast a tickle comes along, in lanes a second (one lane is 2).",
    "line": 32
   },
   "MISSES": {
    "value": "3",
    "note": "Too many presses out of time: a sneeze. Each run of CALM_HITS held in a row forgives one.",
    "line": 35
   },
   "CALM_HITS": {
    "value": "5",
    "note": "Too many presses out of time: a sneeze. Each run of CALM_HITS held in a row forgives one.",
    "line": 36
   },
   "SLIP_S": {
    "value": "0.25",
    "note": "A miss: the hands answer again after this long.",
    "line": 38
   }
  }
 },
 "logic/minigames/squeeze.gd": {
  "doc": "Getting into a hideout (Hideouts): the thief wriggles in, left, right, left, right, sinking a little deeper with each wriggle. Each one counts only once the body has settled from the last (SETTLE_S): mashing gets you nowhere faster, and a wriggle too soon, or to the same side twice, gets you stuck a moment. It cannot be failed, only done slowly: from about two seconds calm and loose to about five in a tight fit with the guards alarmed — and all that time you are out there to be seen.  steps_ is how tight the fit is: 1 for one more wriggle (Hideouts.TIGHT).",
  "consts": {
   "WRIGGLES_LEVEL": {
    "value": "[7, 8, 9]",
    "note": "Wriggles it takes to get in, by level, before the fit.",
    "line": 14
   },
   "SETTLE_S": {
    "value": "0.32",
    "note": "After a wriggle, the body settles this long before the next one counts, and at full tremble this much longer.",
    "line": 17
   },
   "SHAKE_SETTLE": {
    "value": "0.06",
    "note": "After a wriggle, the body settles this long before the next one counts, and at full tremble this much longer.",
    "line": 18
   },
   "STUCK_S": {
    "value": "0.35",
    "note": "Too soon, or the same side twice: stuck this long.",
    "line": 20
   },
   "LEFT": {
    "value": "3",
    "note": "Left and right, as DIRS has them.",
    "line": 22
   },
   "RIGHT": {
    "value": "1",
    "note": "Left and right, as DIRS has them.",
    "line": 23
   }
  }
 },
 "logic/minigames/steady.gd": {
  "doc": "The alarm panel's glass (or the case's, on some nights instead of the pick): a suction cup on it drifts about on its own; the directions push it back. Kept inside the ring for `need` seconds in a row, the glass is cut; out of the ring, the count starts again. Harder levels have a smaller ring and a stronger drift; shaking hands make the drift wilder.",
  "consts": {
   "CUP": {
    "value": "0.26",
    "note": "The cup's radius (the easy ring's is 1), how hard it drifts, how hard the keys push it and how quickly it slows.",
    "line": 11
   },
   "DRIFT": {
    "value": "2.4",
    "note": "The cup's radius (the easy ring's is 1), how hard it drifts, how hard the keys push it and how quickly it slows.",
    "line": 12
   },
   "RING_LEVEL": {
    "value": "[1.0, 0.84, 0.7]",
    "note": "By level (easy, medium, hard): the ring's size and the drift's strength.",
    "line": 14
   },
   "DRIFT_LEVEL": {
    "value": "[0.8, 1.0, 1.15]",
    "note": "By level (easy, medium, hard): the ring's size and the drift's strength.",
    "line": 15
   },
   "PUSH": {
    "value": "4.2",
    "note": "By level (easy, medium, hard): the ring's size and the drift's strength.",
    "line": 16
   },
   "DAMP": {
    "value": "2.6",
    "note": "By level (easy, medium, hard): the ring's size and the drift's strength.",
    "line": 17
   },
   "GUST_S": {
    "value": "0.45",
    "note": "How often the drift changes its mind, in seconds.",
    "line": 19
   }
  }
 },
 "logic/minigames/wires.gd": {
  "doc": "The alarm panel: a row of wires, three to six by the level; over the next one to cut, an arrow shows which way to pull the cutters: press that direction. The wrong way sparks, and the hands jump off it a moment. Shaking hands take longer to steady on the next wire.",
  "consts": {
   "SPARK_S": {
    "value": "0.6",
    "note": "The wrong way on a wire: a spark, and the hands off it this long.",
    "line": 9
   },
   "STEADY_S": {
    "value": "0.3",
    "note": "At full tremble, how long the cutters take to steady on the next wire.",
    "line": 11
   },
   "WIRES_LEVEL": {
    "value": "[3, 4, 6]",
    "note": "How many wires a panel has, by level.",
    "line": 13
   }
  }
 },
 "logic/hideouts.gd": {
  "doc": "Places to hide in. Next to one, the action key gets you in; any direction gets you out, onto the free floor that way.  the big pieces (Museum.big_pieces) you fit inside: the sarcophagus, the Trojan horse, the mammoth (under its coat), the hollow log and the little car on its stand; pieces of furniture on a case tile of their own (pieces), one theme each: a retro fridge and a cardboard box (modern), a legionary's armour (ancient), a confessional and a chest (middle ages), a giant dinosaur egg (prehistory), a giant tortoise shell (nature); a suit of armour still standing (Props): you step inside it.  Whatever looks like a place to hide is one: every big piece and every suit of armour standing in the museum, and every piece of furniture. What keeps it from being too easy is how few of them there are, far apart from one another: the generator stands only so many big pieces to hide in (MapGen), the props only so many suits of armour (Props.place), and each night adds furniture, and empty pedestals to pose on (Plinths), up to the museum's share (places, spread). A saved map keeps what it stood by hand. Getting in takes a moment of wriggling (Minigame \"squeeze\", start), two to five seconds out in the open — once the nights have minigames (Heist.minigames); before that, the action key gets you in at once.  Inside, you make no sound and no guard sees you. Same deal as the statue (Plinths): it only works unseen. Get in in front of a guard and it remembers (Guard.knows) and comes straight for you, and once beside it pulls you out; a guard that did not see you walks right past. A suit of armour knocked over with you inside it tips you out onto the floor.",
  "consts": {
   "REACH": {
    "value": "1.0",
    "note": "Closer than this to one (to its edge) to get in.",
    "line": 33
   },
   "GRAB": {
    "value": "1.2",
    "note": "A guard this close to a blown hideout pulls you out.",
    "line": 35
   },
   "BIG": {
    "value": "[\"sarcophagus\", \"trojan_horse\", \"mammoth\", \"log\", \"car\"]",
    "note": "The big pieces you fit inside (keys of MapGen.BIG).",
    "line": 37
   },
   "PIECES": {
    "value": "{ \"fridge\": {\"model\": \"temas/moderna/nevera\", \"theme\": \"moderna\"}, \"box\": {\"model\": \"temas/moderna/caja\", \"theme\": \"moderna\"}, \"legionary\": {\"model\": \"temas/antiguo/legionario\", \"theme\": \"antiguo\"}, \"confessional\": {\"model\": \"temas/edad_media/confesionario\", \"theme\": \"edad_media\"}, \"chest\": {\"model\": \"temas/edad_media/baul\", \"theme\": \"edad_media\"}, \"egg\": {\"model\": \"temas/prehistoria/huevo\", \"them…",
    "note": "The pieces of furniture you hide in: their model (MuseumView.asset) and the theme whose galleries they stand in (Themes).",
    "line": 40
   },
   "PER_TILES": {
    "value": "120",
    "note": "How many places to hide in and pedestals to pose on a museum has between them: one for this many open tiles, and never fewer than MIN (if there is room); every PLINTH_EVERY-th of them a pedestal.",
    "line": 52
   },
   "MIN": {
    "value": "3",
    "note": "How many places to hide in and pedestals to pose on a museum has between them: one for this many open tiles, and never fewer than MIN (if there is room); every PLINTH_EVERY-th of them a pedestal.",
    "line": 53
   },
   "PLINTH_EVERY": {
    "value": "3",
    "note": "How many places to hide in and pedestals to pose on a museum has between them: one for this many open tiles, and never fewer than MIN (if there is room); every PLINTH_EVERY-th of them a pedestal.",
    "line": 54
   },
   "BIG_SHARE": {
    "value": "0.4",
    "note": "Of the places to hide in, about this share are big pieces (MapGen); of the rest, up to half are suits of armour (Props.place), and furniture fills what is left (spread).",
    "line": 58
   },
   "APART": {
    "value": "9.0",
    "note": "None closer than this to another, in tiles, middle to middle: running from one to the next is a risk of its own.",
    "line": 61
   },
   "TIGHT": {
    "value": "{\"box\": 1, \"egg\": 1, \"chest\": 1, \"shell\": 1, \"armour\": 1, \"legionary\": 1}",
    "note": "How tight a squeeze each is: that many more wriggles to get in (SqueezeGame); the roomy ones take none.",
    "line": 64
   }
  }
 },
 "logic/plinths.gd": {
  "doc": "Low empty pedestals, knee-high, waiting for a sculpture that never came: climb on one (the action key, next to it) and strike a ninja pose, and to a guard you are just another piece of the collection. Any direction steps you down again, onto the free floor that way.  Each stands on a case tile (Tiles.COVER), so it blocks the way like any other piece of furniture; a guard never walks into the statue. The trick only works unseen: climb up in front of a guard and it remembers what it saw (Guard.knows) and comes straight for you — and a guard right beside a statue it knows is you takes you down off it.",
  "consts": {
   "REACH": {
    "value": "1.2",
    "note": "Closer than this to one's middle to climb up.",
    "line": 15
   },
   "HEIGHT": {
    "value": "0.3",
    "note": "How high the top is (m): the thief stands this much off the floor.",
    "line": 17
   },
   "GRAB": {
    "value": "1.3",
    "note": "A guard this close to a blown statue gets hold of it.",
    "line": 19
   },
   "FALL_DOWN_S": {
    "value": "1.2",
    "note": "Seconds on the floor after falling off one (Minigame \"balance\").",
    "line": 21
   },
   "GUARD_NEAR": {
    "value": "10.0",
    "note": "How hard it is to keep the pose on one foot (Minigame \"balance\"), 0..1: mostly the guards, harder the closer they come (from GUARD_NEAR tiles away, full with one right by it), and a little the gallery's lights on.",
    "line": 90
   },
   "LIT_PRESSURE": {
    "value": "0.15",
    "note": "How hard it is to keep the pose on one foot (Minigame \"balance\"), 0..1: mostly the guards, harder the closer they come (from GUARD_NEAR tiles away, full with one right by it), and a little the gallery's lights on.",
    "line": 91
   }
  }
 },
 "logic/collection.gd": {
  "doc": "What stands on each case of the museum tonight, decided once for the whole museum: the view draws it (MuseumView._exhibits) and the arcade machines are found in it (Arcades), so the two never disagree.  A tile's piece comes from its gallery's theme and a hash of its coordinates (Themes.pick), so the same museum always looks the same; and the museum keeps count of what it has put, tile by tile in order, so that an icon (Themes.UNIQUE) stands once at most, a piece with variants (Themes.VARIANTS, the arcade machine) is a different one each time, and with none left the place gets another, a piece with a front (Themes.FRONTED) only goes where there is floor for it to face. What a saved map stood by hand (MuseumView.exhibits) is kept as it is, and counted first: the rest only adds to it.  Not here: the empty pedestals (Plinths), the furniture to hide in (Hideouts), the big pieces, and the job's case, which stands empty.",
  "consts": {
   "TRIES": {
    "value": "8",
    "note": "How many picks a tile gets before it settles for a case of colours.",
    "line": 22
   }
  }
 },
 "logic/themes.gd": {
  "doc": "The collection by themes. Each gallery of a museum takes one theme (or a whole museum just one, only), and what stands and hangs in it comes from that theme: what goes in the glass cases, what stands on a plinth, what stands on the floor, which paintings, and the big piece it would rather have. Corridors show a little of everything.  The glass cases show nothing detailed: bright, simple things in the theme's colours (\"@colours\": MuseumView._colours), that read from the camera as spots of colour; the detailed pieces stand out in the open, on plinths and on the floor, so the two never look alike.  A piece is a model under assets/models/ (\"temas/antiguo/escarabajo\", modelled by art/temas/*.py) or, with an @, one of the pieces MuseumView builds itself (\"@butterflies\": MuseumView.EXHIBITS). Paintings are kinds of canvas (Canvases).  Five themes, and no more: the ancient world (Egypt, Greece and Rome), the middle ages (with the gothic, the Renaissance and Leonardo), prehistory (dinosaurs and early people), nature (animals, plants and trees, life under water) and the modern age — contemporary art and everyday things of today shown as museum pieces: a telly, a toaster.",
  "consts": {
   "ALL": {
    "value": "{ \"antiguo\": { \"gallery\": [\"the ancient world gallery\", \"GALLERY_ANCIENT\"], \"case\": [\"@colours\"], \"plinth\": [\"temas/antiguo/busto_faraon\", \"temas/antiguo/gato_bastet\", \"temas/antiguo/obelisco\", \"@amphora\", \"@statue\", \"temas/antiguo/escarabajo\", \"temas/antiguo/canopos\", \"temas/antiguo/amuletos\", \"temas/antiguo/papiro\"], # Gold, turquoise, lapis lazuli, terracotta; linen under them. \"colours\": [\"#e8…",
    "note": "",
    "line": 24
   },
   "CASE_SHARE": {
    "value": "0.45",
    "note": "Of what stands on a case in a themed gallery, this much is in a glass case, this much on a plinth; the rest on the floor.",
    "line": 88
   },
   "PLINTH_SHARE": {
    "value": "0.35",
    "note": "Of what stands on a case in a themed gallery, this much is in a glass case, this much on a plinth; the rest on the floor.",
    "line": 89
   },
   "UNIQUE": {
    "value": "[\"dinosaur\", \"trojan_horse\", \"temas/edad_media/espada_piedra\", \"temas/edad_media/trono\", \"temas/edad_media/maquina_voladora\"]",
    "note": "The icons: a museum has one at most, as a second would be a copy. Big pieces by their kind (BigPieces.SIZES), the rest by their model. Every piece not here nor in VARIANTS may stand any number of times.",
    "line": 142
   },
   "VARIANTS": {
    "value": "{\"temas/moderna/recreativa\": [\"tenis\", \"invasores\", \"comecocos\", \"bloques\", \"serpiente\", \"carreras\"]}",
    "note": "The pieces where every copy is really something different: several may stand in one museum, each a different variant, never the same one twice; once they are all out, the place gets another piece. The arcade machine, one game each (MuseumView.ARCADE_GAMES has how each looks; you play pong on all of them, Arcades).",
    "line": 149
   },
   "PROP_THEMES": {
    "value": "{\"bust\": \"antiguo\", \"armour\": \"edad_media\", \"bin\": \"\", \"panel\": \"\"}",
    "note": "What the thieves knock over, and the big pieces, by theme (\"\" for none).",
    "line": 175
   },
   "TYPES": {
    "value": "[\"case\", \"small\", \"big\", \"prop\", \"hide\"]",
    "note": "The kinds of piece, as the editor filters them: in a glass case, small (on a plinth), big (on the floor, or on a block of cases), what the thieves knock over, and what they hide in (Hideouts.PIECES).",
    "line": 181
   },
   "FRONTED": {
    "value": "[\"temas/moderna/recreativa\", \"temas/edad_media/trono\", \"temas/antiguo/anubis\"]",
    "note": "Where a theme's model stands: \"case\", \"plinth\" or \"floor\". The floor pieces with a front that must not face a wall: a screen, a seat, a face. MuseumView turns them to the free floor beside them, and a place with none gets another piece.",
    "line": 231
   }
  }
 },
 "logic/arcades.gd": {
  "doc": "The arcade machines standing tonight (the modern gallery's \"temas/moderna/recreativa\", where MuseumView puts one). In front of one, the action key starts a game of pong on it (Minigame \"arcade\", ArcadeGame): a joke, with nothing to win, that keeps you standing there playing while the guards go by. Any number of thieves can play, one machine each; like every minigame, not before the nights have them.",
  "consts": {
   "REACH": {
    "value": "0.9",
    "note": "Closer than this to one (to its edge) to play.",
    "line": 11
   },
   "MODEL": {
    "value": "\"temas/moderna/recreativa\"",
    "note": "Closer than this to one (to its edge) to play.",
    "line": 12
   }
  }
 },
 "logic/briefing.gd": {
  "doc": "The rules on the plan screen before a heist, worked out from the night itself — how many guards and what they are like (Sim.tuning), what is switched on (Sim.feature), the job (Heist) and what lies about to knock over (Props) — so the same rules serve a story night, a generated museum and a saved map.  The rules for the rules: - At most MOST lines, aiming at AIM: the lines that must be said (MUST) always go, up to MOST; the rest (NICE) only fill up to AIM. - A short line each (at most WORDS words): what is so, then what to do. - What is normal is not said: a case without an alarm, guards as the game has them. - The guards in a single line: how many, what stands out about them (two traits at most) and what to do about the first. - A mechanic (MECHANICS) is told in the story twice: on the night that teaches it, on the \"what's new\" page (Story.news), and the night after, here; after that it is known and goes unsaid. Out of the story (no night to go by) it is said whenever the museum has it. A gang's shared job counts as one, taught on the first night. - A museum's big job (Story's \"boss\") says what makes it one, in its own line (\"tip\"), right under the guards. - In this order: the guards, the big job, the job, the museum.",
  "consts": {
   "FAST": {
    "value": "1.05",
    "note": "Past these the guards' senses and pace are worth a word (Sim.tuning, gang ease included): medium is the game as designed, and says nothing.",
    "line": 28
   },
   "SLOW": {
    "value": "0.75",
    "note": "Past these the guards' senses and pace are worth a word (Sim.tuning, gang ease included): medium is the game as designed, and says nothing.",
    "line": 29
   },
   "SHARP_EARS": {
    "value": "1.1",
    "note": "Past these the guards' senses and pace are worth a word (Sim.tuning, gang ease included): medium is the game as designed, and says nothing.",
    "line": 30
   },
   "DULL_EARS": {
    "value": "0.6",
    "note": "Past these the guards' senses and pace are worth a word (Sim.tuning, gang ease included): medium is the game as designed, and says nothing.",
    "line": 31
   },
   "FAR_EYES": {
    "value": "1.1",
    "note": "Past these the guards' senses and pace are worth a word (Sim.tuning, gang ease included): medium is the game as designed, and says nothing.",
    "line": 32
   },
   "SHORT_EYES": {
    "value": "0.6",
    "note": "Past these the guards' senses and pace are worth a word (Sim.tuning, gang ease included): medium is the game as designed, and says nothing.",
    "line": 33
   },
   "GRUDGE": {
    "value": "12.0",
    "note": "calm_after, in seconds: slow to calm down from here up.",
    "line": 35
   },
   "MOST": {
    "value": "5",
    "note": "The most lines on screen, and how many to aim at.",
    "line": 37
   },
   "AIM": {
    "value": "3",
    "note": "The most lines on screen, and how many to aim at.",
    "line": 38
   },
   "WORDS": {
    "value": "14",
    "note": "The longest a line may be, in words (the tests hold every night to it).",
    "line": 40
   },
   "MECHANICS": {
    "value": "{ \"case_alarm\": \"case_alarm\", \"lights\": \"lights\", \"two\": \"two\", \"props\": \"props\", \"games\": \"games\", \"noise\": \"noise\", \"torch\": \"torch\", \"map\": \"big\", }",
    "note": "The mechanics and the story lesson (Story.LESSONS) that teaches each, most urgent first: key -> lesson.",
    "line": 44
   }
  }
 },
 "logic/story.gd": {
  "doc": "The story mode: five museums to rob, five heists in each, twenty-five in all. Each museum keeps to one theme (Themes) and its own look: every gallery shows that theme's pieces, and every piece taken fits it. The first four heists of a museum are its rooms, each a little harder than the last; the fifth is its big job (a boss): the museum's star piece, with a twist of its own made of what the game already has. Take all five and the next museum opens.  Now and then a heist teaches one new thing, and is built around it; the ones in between practise it. The big jobs teach nothing: they test.  The tale, for kids: the Banda del Calcetín only steals what was stolen first. The Barón Von Bostezo made the directors of the town's five museums yawn with his diamond until they signed them over to him; now he keeps them, and fills their cases with things nicked from the town (the grandad's dentures, the ketchup in Jake's fridge), labelled as treasures. Kids' humour: everyday things, a neighbour with a name, an absurd upshot in town; a piece fits its museum by the joke, not the history lesson. One a night, the gang takes them back, until the museums are everybody's again.",
  "consts": {
   "PROLOGUE": {
    "value": "\"STORY_PROLOGUE\"",
    "note": "",
    "line": 24
   },
   "ENDING": {
    "value": "\"STORY_ENDING\"",
    "note": "",
    "line": 26
   },
   "ROOMS": {
    "value": "5",
    "note": "Heists in a museum: four rooms and the big job, always the last.",
    "line": 29
   },
   "LEVELS": {
    "value": "[ # --- El Museo de la Prehistoria: prehistory. Small museums, one guard at most. {\"size\": \"small\", \"shape\": \"rect\", \"guards\": 0, \"view\": 0.45, \"hearing\": 0.2, \"speed\": 0.4, \"calm_after\": 5.0, \"alarms\": 3, \"props\": false, \"lights\": false, \"case_alarm\": false, \"teach\": \"heist\", \"par\": 30, \"loot\": {\"name\": \"NIGHT_01_NAME\", \"blurb\": \"NIGHT_01_BLURB\", \"verb\": \"NIGHT_01_VERB\", \"seconds\": 1.5, \"colour\":…",
    "note": "Each heist: museum size and shape, how many guards, their senses and pace (Sim.tuning keys), what is switched on yet (props, lights, the case's alarm: Sim.feature), a guard's post if the lesson or the big job needs one, the one thing it teaches (LESSONS), and the piece. A big job says so (\"boss\") and has a line of its own for the plan (\"tip\"). Easy to hard, one new thing at a time; each museum's pieces fit its theme. \"reseed\" (optional) builds the night's museum from that many seeds on (seed_for), for a museum that suits it better than the first. \"par\": the time for the fast star (stars), in seconds.",
    "line": 40
   },
   "SEED_BASE": {
    "value": "424242",
    "note": "Each night's museum is always the same one — one for a thief on their own and another for two, with the same piece to take back.",
    "line": 151
   },
   "SEED_TEAM": {
    "value": "104729",
    "note": "Each night's museum is always the same one — one for a thief on their own and another for two, with the same piece to take back.",
    "line": 152
   },
   "LESSON_TRIES": {
    "value": "60",
    "note": "How many museums a lesson night may look through for one that forces its lesson (Sim.assign_posts); each is SEED_STEP on from the last.",
    "line": 155
   },
   "SEED_STEP": {
    "value": "7777",
    "note": "How many museums a lesson night may look through for one that forces its lesson (Sim.assign_posts); each is SEED_STEP on from the last.",
    "line": 156
   },
   "LESSONS": {
    "value": "{ \"heist\": {\"title\": \"LESSON_HEIST_TITLE\", \"stage\": \"lesson:heist\", \"text\": \"LESSON_HEIST_TEXT\"}, # The same first lesson for a gang, with the gang's own jobs. \"heist2\": {\"title\": \"LESSON_HEIST2_TITLE\", \"stage\": \"lesson:heist2\", \"text\": \"LESSON_HEIST2_TEXT\"}, \"heist3\": {\"title\": \"LESSON_HEIST2_TITLE\", \"stage\": \"lesson:heist3\", \"text\": \"LESSON_HEIST3_TEXT\"}, \"heist4\": {\"title\": \"LESSON_HEIST2_TITLE…",
    "note": "What each night teaches, one thing a night, the night built around it: a title, a line on how it works and its own little scene acting it out (LessonStage). The words here, like the pieces' and the tale's, are keys into Text.",
    "line": 162
   },
   "LOCKPICK_NIGHT": {
    "value": "6",
    "note": "From this night on, the first in the second museum, there are minigames (Minigame, Heist.minigames): the case is picked, the alarm panel's glass cut with the suction cup, the pose on a pedestal held on one foot, the way into a hideout wriggled and the sneeze in there held in, and the arcade machine plays pong. Before it, in the whole first museum, none of them: you stand still at the case and hold the panel, and are up on a pedestal or in a hideout at once. Its lesson (\"games\") is the one new thing of its night.",
    "line": 203
   },
   "GAME_LEVEL": {
    "value": "[[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]]",
    "note": "The minigames' level (Minigame.level_now) in each museum, in its rooms and on its big job: none in the first (LOCKPICK_NIGHT), then easy, and a step harder every museum or so, the big jobs a step ahead of their rooms.",
    "line": 208
   },
   "SAVE": {
    "value": "\"user://progress.cfg\"",
    "note": "The minigames' level (Minigame.level_now) in each museum, in its rooms and on its big job: none in the first (LOCKPICK_NIGHT), then easy, and a step harder every museum or so, the big jobs a step ahead of their rooms.",
    "line": 210
   },
   "MUSEUMS": {
    "value": "[ # El Museo de la Prehistoria: rough ochre stone underfoot, clay walls, dark rock below. {\"name\": \"MUSEUM_1_NAME\", \"text\": \"MUSEUM_1_TEXT\", \"theme\": \"prehistoria\", \"colour\": \"#d08a3a\", \"palette\": {\"floor\": 0, \"stone\": Color(\"#4a3624\"), \"stone2\": Color(\"#56402a\"), \"joint\": Color(\"#1e140c\"), \"gloss\": 0.55, \"paper\": Color(\"#6b3f1f\"), \"paper2\": Color(\"#7a4a25\"), \"wallpaper\": 0, \"wainscot\": Color(\"#3a…",
    "note": "The town's museums, each a stop on the city map with ROOMS heists inside, in order, the last its big job. Each shows one theme (Themes): its galleries, its corridors and its pieces. Each has its own floor and walls (MuseumView.THEMES keys) to match, and a colour for its stop on the map. In the order of time, from the dinosaurs to today: prehistory, nature (the living world, still in the old natural-history style), the ancient world, the middle ages, and the modern age, the Barón's own tower.",
    "line": 221
   },
   "STAR_TAKEN": {
    "value": "1",
    "note": "Each heist of the story gives up to three stars, Overcooked style, each its own goal, as bits of a mask: STAR_TAKEN   out of the door with the piece: the heist done; STAR_UNSEEN  no guard saw anyone of the gang, the whole night through (HeistStats \"seen\" at 0: heard is fine, seen is not); STAR_FAST    out under the heist's par (par): its \"par\" in LEVELS, a gang's a little longer (GANG_PAR). A star once won stays won: the best is kept for each heist and each size of gang, as a mask, so a worse go never takes one away, and two goes can win two different stars (keep_stars). Only the story has them; nothing waits on them: the next museum opens with the big job, as ever.  For the screens: Story.stars(7)          -> 2      the best of heist 7, alone, as a count Story.star_mask(7)      -> 0b011  and which (STAR_TAKEN | STAR_UNSEEN) Story.stars_in(1, 2)    -> 11     museum 2 (0-based m = 1), for two Story.STARS_EACH * Story.ROOMS    the most a museum gives (15) Story.par(7)            -> 25.0   seconds for the fast star, alone Story.goals(7)          -> [\"Roba la pieza\", \"Sin que te vean\", \"En menos de 0:25\"]   (STARS order) And after a go, what it won and what was new: HeistStats.rate (the paper's stars, EndPages.newspaper).",
    "line": 371
   },
   "STAR_UNSEEN": {
    "value": "2",
    "note": "Each heist of the story gives up to three stars, Overcooked style, each its own goal, as bits of a mask: STAR_TAKEN   out of the door with the piece: the heist done; STAR_UNSEEN  no guard saw anyone of the gang, the whole night through (HeistStats \"seen\" at 0: heard is fine, seen is not); STAR_FAST    out under the heist's par (par): its \"par\" in LEVELS, a gang's a little longer (GANG_PAR). A star once won stays won: the best is kept for each heist and each size of gang, as a mask, so a worse go never takes one away, and two goes can win two different stars (keep_stars). Only the story has them; nothing waits on them: the next museum opens with the big job, as ever.  For the screens: Story.stars(7)          -> 2      the best of heist 7, alone, as a count Story.star_mask(7)      -> 0b011  and which (STAR_TAKEN | STAR_UNSEEN) Story.stars_in(1, 2)    -> 11     museum 2 (0-based m = 1), for two Story.STARS_EACH * Story.ROOMS    the most a museum gives (15) Story.par(7)            -> 25.0   seconds for the fast star, alone Story.goals(7)          -> [\"Roba la pieza\", \"Sin que te vean\", \"En menos de 0:25\"]   (STARS order) And after a go, what it won and what was new: HeistStats.rate (the paper's stars, EndPages.newspaper).",
    "line": 372
   },
   "STAR_FAST": {
    "value": "4",
    "note": "Each heist of the story gives up to three stars, Overcooked style, each its own goal, as bits of a mask: STAR_TAKEN   out of the door with the piece: the heist done; STAR_UNSEEN  no guard saw anyone of the gang, the whole night through (HeistStats \"seen\" at 0: heard is fine, seen is not); STAR_FAST    out under the heist's par (par): its \"par\" in LEVELS, a gang's a little longer (GANG_PAR). A star once won stays won: the best is kept for each heist and each size of gang, as a mask, so a worse go never takes one away, and two goes can win two different stars (keep_stars). Only the story has them; nothing waits on them: the next museum opens with the big job, as ever.  For the screens: Story.stars(7)          -> 2      the best of heist 7, alone, as a count Story.star_mask(7)      -> 0b011  and which (STAR_TAKEN | STAR_UNSEEN) Story.stars_in(1, 2)    -> 11     museum 2 (0-based m = 1), for two Story.STARS_EACH * Story.ROOMS    the most a museum gives (15) Story.par(7)            -> 25.0   seconds for the fast star, alone Story.goals(7)          -> [\"Roba la pieza\", \"Sin que te vean\", \"En menos de 0:25\"]   (STARS order) And after a go, what it won and what was new: HeistStats.rate (the paper's stars, EndPages.newspaper).",
    "line": 373
   },
   "STARS": {
    "value": "[STAR_TAKEN, STAR_UNSEEN, STAR_FAST]",
    "note": "The three, in the order they are shown.",
    "line": 375
   },
   "STARS_EACH": {
    "value": "3",
    "note": "The three, in the order they are shown.",
    "line": 376
   },
   "GANG_PAR": {
    "value": "{1: 1.0, 2: 1.2, 3: 1.35, 4: 1.5}",
    "note": "How much longer a gang has for the fast star: everyone has to get out, and a gang shares out the job (the alarm panel).",
    "line": 379
   }
  }
 }
};

#!/usr/bin/env python3
"""Generator for the Now Walking / Full map artboards (.dc.html).
Shared pieces (tokens, icons, map layer JS) live here so all 7 artboards stay consistent."""
import json, math, os

BASE = "/private/tmp/claude-501/-Users-svetoslaviliev-Documents-Obsidian-HackYeachResearch/06c8f11f-7325-4ef9-aa81-cbfc92262a6a/scratchpad/design/canvas"
OUT = BASE + "/project"
META = json.load(open(BASE + "/map-meta.json"))

FONT = "'HarmonyOS Sans', 'HarmonyOS Sans SC', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Noto Sans SC', sans-serif"

TH = {
    "light": dict(
        canvas="#F4F5F3", surface="#FFFFFF", sunken="#EEEFEC", t1="#16181A", t2="#5A6066", t3="#6B7176",
        divider="#E1E3DF", accent="#1D6B5B", onAccent="#FFFFFF", accentSub="#E3F0EC", user="#2F6FDE",
        simfg="#7A4F00", simbg="#FFF1D6", land="#EEEEEA", blob="/_blob/47c1f630f4c212aa493463e6caf6c0c2",
        scrim="rgba(244,245,243,0.72)", visited="rgba(107,113,118,0.85)", walked="#6B7176",
        shadow1="0 1px 2px rgba(22,24,26,0.10), 0 2px 8px rgba(22,24,26,0.08)",
        shadow2="0 -1px 3px rgba(22,24,26,0.04), 0 -10px 30px rgba(22,24,26,0.10)",
        accentRGB="29,107,91", hover="#155446", halo="#EEEEEA", userRing="#FFFFFF"),
    "dark": dict(
        canvas="#0F1112", surface="#1A1D1F", sunken="#24292C", t1="#ECEEEF", t2="#A7ADB2", t3="#858C91",
        divider="#2E3336", accent="#6CC3AE", onAccent="#062A23", accentSub="#17332D", user="#5C93F0",
        simfg="#F2C46B", simbg="#3A2C0D", land="#151819", blob="/_blob/4bce0ac3b1ef1c22600176981754eaa5",
        scrim="rgba(15,17,18,0.72)", visited="rgba(133,140,145,0.85)", walked="#858C91",
        shadow1="0 1px 2px rgba(0,0,0,0.40), 0 2px 8px rgba(0,0,0,0.32)",
        shadow2="0 -1px 0 rgba(255,255,255,0.04), 0 -10px 30px rgba(0,0,0,0.50)",
        accentRGB="108,195,174", hover="#8FD6C4", halo="#151819", userRing="#FFFFFF"),
}

# ---------------------------------------------------------------- icons (24 box, SF/HarmonyOS-symbol style)
ICONS = {
    "chevron_down": ('s', '<path d="M6 9.5l6 6 6-6"></path>'),
    "chevron_backward": ('s', '<path d="M14.5 5.5 8 12l6.5 6.5"></path>'),
    "chevron_right": ('s', '<path d="M9.5 5.5 16 12l-6.5 6.5"></path>'),
    "ellipsis": ('f', '<circle cx="5.5" cy="12" r="1.8"></circle><circle cx="12" cy="12" r="1.8"></circle><circle cx="18.5" cy="12" r="1.8"></circle>'),
    "layers": ('s', '<path d="M12 3.5 3.5 8 12 12.5 20.5 8 12 3.5z"></path><path d="M3.5 12 12 16.5 20.5 12"></path><path d="M3.5 16 12 20.5 20.5 16"></path>'),
    "map": ('s', '<path d="M9 4.5 3.5 6.5v13l5.5-2 6 2 5.5-2v-13l-5.5 2-6-2z"></path><path d="M9 4.5v13"></path><path d="M15 6.5v13"></path>'),
    "location": ('s', '<path d="M12 3.5 18.5 19.5 12 16.2 5.5 19.5 12 3.5z"></path>'),
    "info": ('s', '<circle cx="12" cy="12" r="8.5"></circle><path d="M12 11v5"></path><circle cx="12" cy="7.9" r="1.1" fill="currentColor" stroke="none"></circle>'),
    "replay": ('s', '<path d="M4.5 12.5a7.5 7.5 0 1 0 2.2-5.3"></path><path d="M10.6 6.5 6.7 7.2 7.4 3.3"></path>'),
    "play_fill": ('f', '<path d="M8 5.7v12.6c0 .8.9 1.3 1.6.9l10-6.3c.6-.4.6-1.4 0-1.8l-10-6.3C8.9 4.4 8 4.9 8 5.7z"></path>'),
    "pause_fill": ('f', '<rect x="6.5" y="5" width="4" height="14" rx="1.2"></rect><rect x="13.5" y="5" width="4" height="14" rx="1.2"></rect>'),
    "forward_end_fill": ('f', '<path d="M5 6.3v11.4c0 .8.9 1.3 1.6.8l8.2-5.7c.6-.4.6-1.3 0-1.7L6.6 5.5C5.9 5 5 5.5 5 6.3z"></path><rect x="16.6" y="5.5" width="2.6" height="13" rx="1.1"></rect>'),
    "waveform": ('s', '<path d="M4 10v4M8 7v10M12 4.5v15M16 8v8M20 10.5v3"></path>'),
    "doc_text": ('s', '<path d="M14 3.5H7.5A1.5 1.5 0 0 0 6 5v14a1.5 1.5 0 0 0 1.5 1.5h9A1.5 1.5 0 0 0 18 19V7.5l-4-4z"></path><path d="M14 3.5v4h4"></path><path d="M9 12.5h6M9 16h4"></path>'),
    "list_bullet": ('s', '<path d="M9.5 6.5H20M9.5 12H20M9.5 17.5H20"></path><circle cx="5" cy="6.5" r="1.2" fill="currentColor" stroke="none"></circle><circle cx="5" cy="12" r="1.2" fill="currentColor" stroke="none"></circle><circle cx="5" cy="17.5" r="1.2" fill="currentColor" stroke="none"></circle>'),
    "figure_walk": ('s', '<circle cx="13.6" cy="4.4" r="1.9" fill="currentColor" stroke="none"></circle><path d="M12.9 8.6 11.6 15l2.6 2.6V21"></path><path d="M11.6 15 9.6 21"></path><path d="M7.6 12.4l2.2-3.2 3.1-.6 1.9 2.9 2.5 1"></path>'),
    "xmark": ('s', '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"></path>'),
    "check": ('s', '<path d="M5 12.5l4.5 4.5L19 7.5"></path>'),
    "arrow_up_right": ('s', '<path d="M7 17 17 7M9 7h8v8"></path>'),
    "speaker_slash": ('s', '<path d="M4 9.5h3l4.5-4v13L7 14.5H4z"></path><path d="M15.5 9.5l5 5M20.5 9.5l-5 5"></path>'),
    "quote": ('s', '<path d="M5 5.5h14a1.5 1.5 0 0 1 1.5 1.5v8.5A1.5 1.5 0 0 1 19 17h-7l-4.5 3.5V17H5A1.5 1.5 0 0 1 3.5 15.5V7A1.5 1.5 0 0 1 5 5.5z"></path><path d="M8 10h8M8 13h5"></path>'),
}


def icon(name, size=24, color="currentColor", sw=1.9, extra=""):
    kind, body = ICONS[name]
    if kind == 'f':
        return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{color}" aria-hidden="true" '
                f'style="flex: none; display: block{extra}">{body}</svg>')
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="{sw}" '
            f'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="flex: none; display: block{extra}">{body}</svg>')


# ---------------------------------------------------------------- shared JS (map layer)
POLY = META["route_polyline_px"]
STOPS = [[s["n"], s["name"], s["x"], s["y"]] for s in META["stops"]]
STOPS_PL = ["Barbakan", "Brama Floriańska", "Kościół Mariacki", "Sukiennice", "Pomnik Adama Mickiewicza",
            "Wieża Ratuszowa", "Kościół św. Wojciecha", "Kościół św. Piotra i Pawła", "Kościół św. Andrzeja",
            "Ulica Kanonicza", "Wzgórze Wawelskie"]

POIS = [[798, 420], [423, 241], [742, 482], [332, 437], [349, 688], [353, 386], [465, 885], [246, 595], [548, 832], [384, 102], [304, 467], [584, 245], [395, 701], [497, 263], [466, 363], [491, 815], [432, 392], [265, 1140], [439, 1004], [538, 271], [599, 557], [332, 355], [529, 361], [754, 400], [525, 401], [731, 517], [826, 971], [461, 645], [299, 627], [524, 796], [343, 622], [322, 405], [250, 720], [562, 563], [598, 1223], [590, 591], [880, 174], [784, 489], [251, 455], [570, 631], [237, 941], [461, 241], [857, 396], [797, 302], [449, 320], [575, 417], [719, 447], [322, 494], [663, 618], [177, 596], [618, 1086], [455, 186], [318, 655], [385, 1077], [683, 348], [545, 657], [362, 437], [450, 585], [652, 273], [359, 659], [457, 820], [486, 293], [535, 693], [467, 1245], [154, 875], [256, 780], [564, 290], [292, 379], [573, 379], [385, 467], [447, 853], [758, 1012], [408, 581], [635, 236], [555, 206]]
CLUSTERS = [[395, 330, 14], [610, 330, 9], [300, 560, 7], [660, 560, 6], [400, 820, 11], [600, 760, 5], [250, 1000, 4]]
UNESCO = [[365, 175], [400, 128], [500, 115], [600, 112], [690, 145], [780, 205], [860, 250], [880, 300], [878, 400], [855, 480], [825, 535], [770, 580], [700, 615], [660, 665], [632, 740], [618, 830], [606, 940], [590, 1030], [565, 1100], [520, 1160], [450, 1215], [370, 1245], [290, 1220], [245, 1160], [250, 1090], [300, 1040], [330, 980], [290, 900], [260, 800], [225, 690], [195, 600], [172, 500], [185, 420], [240, 360], [300, 290], [340, 225]]

JS = r"""
class Component extends DCLogic {
  renderVals() {
    // Tokens for this artboard (light or dark) and the view setup.
    const TH = __THEME__;
    const V = __VIEW__;
    // Real Royal Route data from map-meta.json (image px on the 1000 x 1289 base map).
    const POLY = __POLY__;
    const STOPS = __STOPS__;
    const NAMES_PL = __NAMES_PL__;
    const POIS = __POIS__;
    const CLUSTERS = __CLUSTERS__;
    const UNESCO = __UNESCO__;
    const MPP = 1.286;
    const f1 = (n) => String(Math.round(n * 10) / 10);
    const f3 = (n) => String(Math.round(n * 1000) / 1000);

    // Cumulative length along the route polyline.
    const cum = [0];
    for (let i = 1; i < POLY.length; i++) {
      cum.push(cum[i - 1] + Math.hypot(POLY[i][0] - POLY[i - 1][0], POLY[i][1] - POLY[i - 1][1]));
    }
    // Nearest polyline index to each stop, searching forward so legs never run backwards.
    const stopIdx = [];
    let from = 0;
    STOPS.forEach((s) => {
      let best = from;
      let bd = Infinity;
      for (let i = from; i < POLY.length; i++) {
        const d = Math.pow(POLY[i][0] - s[2], 2) + Math.pow(POLY[i][1] - s[3], 2);
        if (d < bd) { bd = d; best = i; }
      }
      stopIdx.push(best);
      from = best;
    });
    const total = cum[cum.length - 1];
    const stopD = (n) => cum[stopIdx[n - 1]];
    const pointAt = (dIn) => {
      const d = Math.max(0, Math.min(total, dIn));
      for (let i = 1; i < POLY.length; i++) {
        if (cum[i] >= d) {
          const seg = (cum[i] - cum[i - 1]) || 1;
          const t = (d - cum[i - 1]) / seg;
          return { i: i, p: [POLY[i - 1][0] + t * (POLY[i][0] - POLY[i - 1][0]), POLY[i - 1][1] + t * (POLY[i][1] - POLY[i - 1][1])] };
        }
      }
      return { i: POLY.length - 1, p: POLY[POLY.length - 1] };
    };
    const slice = (d0, d1) => {
      const a = pointAt(d0);
      const b = pointAt(d1);
      const pts = [a.p];
      for (let i = a.i; i < b.i; i++) pts.push(POLY[i]);
      pts.push(b.p);
      return pts.map((p) => f1(p[0]) + "," + f1(p[1])).join(" ");
    };

    // Where the user is: standing at a stop, or a number of metres before the next stop.
    const dUser = V.atStop ? stopD(V.atStop) : stopD(V.next) - V.remainM / MPP;
    const user = pointAt(dUser).p;
    const ca = pointAt(dUser - 8).p;
    const cb = pointAt(dUser + 30).p;
    let course = Math.atan2(cb[1] - ca[1], cb[0] - ca[0]) * 180 / Math.PI;
    // On the open Main Square people cut across rather than follow the street graph, so when the view
    // names an aim (stop + relative bearing from the Look cue) the walking course is taken from that.
    if (V.aim) {
      const st = STOPS[V.aim[0] - 1];
      const phi = Math.atan2(st[3] - user[1], st[2] - user[0]) * 180 / Math.PI;
      course = phi - V.aim[1];
    }

    // Map transform: heading-up (course points to the top) or north-up.
    const rot = V.headingUp ? -90 - course : 0;
    const S = V.S;
    const rad = rot * Math.PI / 180;
    const cs = Math.cos(rad);
    const sn = Math.sin(rad);
    const focus = V.focus === "user" ? user : V.focus;
    const TX = V.screen[0] - S * (focus[0] * cs - focus[1] * sn);
    const TY = V.screen[1] - S * (focus[0] * sn + focus[1] * cs);
    const toScreen = (x, y) => [TX + S * (x * cs - y * sn), TY + S * (x * sn + y * cs)];

    // Route legs.
    const dNext = stopD(V.next);
    const map = {
      transform: "translate(" + f1(TX) + "px, " + f1(TY) + "px) rotate(" + f1(rot) + "deg) scale(" + S + ")",
      walked: slice(0, dUser),
      next: slice(dUser, dNext),
      later: slice(dNext, total),
      w5: f3(5 / S),
      w6: f3(6 / S),
      w10: f3(10 / S),
      unesco: UNESCO.map((p) => p[0] + "," + p[1]).join(" "),
      unescoW: f3(1.25 / S),
      unescoDash: f3(6 / S) + " " + f3(4 / S)
    };

    // Plaques (HTML, upright, centred on the projected stop).
    const pl = V.lang === "pl";
    const rank = { visited: 0, upcoming: 1, next: 2, arrived: 2 };
    const plaqueCss = (state, q) => {
      let size = 28;
      let css = "";
      if (state === "upcoming") {
        css = "background: " + TH.surface + "; border: 2px solid " + TH.accent + "; color: " + TH.accent + "; font-size: 12px; box-shadow: " + TH.shadow1 + ";";
      } else if (state === "next") {
        size = 40;
        css = "background: " + TH.accent + "; border: 3px solid " + TH.surface + "; color: " + TH.onAccent + "; font-size: 13px; box-shadow: " + TH.shadow1 + ";";
      } else if (state === "arrived") {
        size = 40;
        css = "background: " + TH.accent + "; border: 3px solid " + TH.surface + "; color: " + TH.onAccent + "; font-size: 13px; box-shadow: 0 0 0 8px rgba(" + TH.accentRGB + ", 0.2), " + TH.shadow1 + ";";
      } else {
        size = 24;
        css = "background: " + TH.visited + "; color: " + TH.surface + ";";
      }
      return "position: absolute; left: " + f1(q[0] - size / 2) + "px; top: " + f1(q[1] - size / 2) + "px; width: " + size + "px; height: " + size +
        "px; box-sizing: border-box; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; " + css;
    };
    const plaques = STOPS.map((s) => {
      const n = s[0];
      let state = "upcoming";
      if (n === V.atStop) state = "arrived";
      else if (n < V.next) state = "visited";
      else if (n === V.next && !V.atStop) state = "next";
      const q = toScreen(s[2], s[3]);
      const name = pl ? NAMES_PL[n - 1] : s[1];
      const word = pl
        ? { visited: "odwiedzony", upcoming: "kolejny", next: "następny", arrived: "jesteś tutaj" }[state]
        : { visited: "visited", upcoming: "upcoming", next: "next", arrived: "you're here" }[state];
      return {
        state: state,
        style: plaqueCss(state, q),
        num: String(n),
        isNum: state !== "visited",
        isCheck: state === "visited",
        label: (pl ? "Przystanek " : "Stop ") + n + ", " + name + ", " + word
      };
    }).sort((a, b) => rank[a.state] - rank[b.state]);

    // You: dot (or hollow ring in the demo walk) plus the 60 degree heading cone.
    const u = toScreen(user[0], user[1]);
    const userStyle = V.hollow
      ? "position: absolute; left: " + f1(u[0] - 10) + "px; top: " + f1(u[1] - 10) + "px; width: 20px; height: 20px; box-sizing: border-box; border-radius: 50%; border: 3px solid " + TH.user + "; background: transparent; box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.92), " + TH.shadow1 + ";"
      : "position: absolute; left: " + f1(u[0] - 10) + "px; top: " + f1(u[1] - 10) + "px; width: 20px; height: 20px; box-sizing: border-box; border-radius: 50%; border: 3px solid " + TH.userRing + "; background: " + TH.user + "; box-shadow: " + TH.shadow1 + ";";
    const cone = {
      show: !!V.cone,
      style: "position: absolute; left: " + f1(u[0] - 40) + "px; top: " + f1(u[1] - 40) + "px; width: 80px; height: 80px; transform: rotate(" + f1(course + 90 + rot) + "deg);"
    };

    // Explore layer: neutral place dots, count clusters, UNESCO label.
    const inView = (q, m) => q[0] > -m && q[0] < V.view[0] + m && q[1] > -m && q[1] < V.view[1] + m;
    const pois = V.explore ? POIS.map((p) => toScreen(p[0], p[1])).filter((q) => inView(q, 8)).map((q) => ({
      style: "position: absolute; left: " + f1(q[0] - 5.5) + "px; top: " + f1(q[1] - 5.5) + "px; width: 11px; height: 11px; box-sizing: border-box; border-radius: 50%; background: " + TH.t2 + "; border: 1.5px solid " + TH.surface + ";"
    })) : [];
    const clusters = V.explore ? CLUSTERS.map((c) => ({ q: toScreen(c[0], c[1]), n: c[2] })).filter((c) => inView(c.q, 14)).map((c) => ({
      count: String(c.n),
      label: c.n + " places",
      style: "position: absolute; left: " + f1(c.q[0] - 14) + "px; top: " + f1(c.q[1] - 14) + "px; width: 28px; height: 28px; box-sizing: border-box; border-radius: 50%; background: " + TH.t2 + "; border: 2px solid " + TH.surface + "; color: " + TH.surface + "; font-size: 12px; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; display: flex; align-items: center; justify-content: center; box-shadow: " + TH.shadow1 + ";"
    })) : [];
    const lq = V.unescoLabel ? toScreen(V.unescoLabel[0], V.unescoLabel[1]) : [0, 0];

    return {
      map: map,
      plaques: plaques,
      user: { style: userStyle },
      cone: cone,
      north: { style: "width: 20px; height: 20px; display: block; transform: rotate(" + f1(rot) + "deg);" },
      pois: pois,
      clusters: clusters,
      unescoLabel: { style: "position: absolute; left: " + f1(lq[0]) + "px; top: " + f1(lq[1]) + "px; white-space: nowrap;" },
      debug: { userScreen: [f1(u[0]), f1(u[1])], course: f1(course), rot: f1(rot), remain: f1((dNext - dUser) * MPP) }
    };
  }
}
"""


def js_for(theme, view, lang="en"):
    th = {k: TH[theme][k] for k in ("surface", "accent", "onAccent", "visited", "shadow1", "accentRGB", "user", "userRing", "t2")}
    s = JS
    s = s.replace("__THEME__", json.dumps(th))
    s = s.replace("__VIEW__", json.dumps(view))
    s = s.replace("__POLY__", json.dumps(POLY, separators=(",", ":")))
    s = s.replace("__STOPS__", json.dumps(STOPS, ensure_ascii=False, separators=(",", ":")))
    s = s.replace("__NAMES_PL__", json.dumps(STOPS_PL if lang == "pl" else [], ensure_ascii=False))
    s = s.replace("__POIS__", json.dumps(POIS if view.get("explore") else [], separators=(",", ":")))
    s = s.replace("__CLUSTERS__", json.dumps(CLUSTERS if view.get("explore") else [], separators=(",", ":")))
    s = s.replace("__UNESCO__", json.dumps(UNESCO if view.get("explore") else [], separators=(",", ":")))
    assert "{{" not in s and "}}" not in s, "JS must not contain double braces"
    return s


# ---------------------------------------------------------------- page shell
def page(title, theme, body, script, lang="en", w=390, h=844):
    t = TH[theme]
    return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
body{{margin:0}}
a{{color:{t['accent']}}}a:hover{{color:{t['hover']}}}
</style>
</helmet>
<div style="width: {w}px; height: {h}px; position: relative; overflow: hidden; background: {t['canvas']}; font-family: {FONT}; color: {t['t1']}; -webkit-font-smoothing: antialiased">
{body}
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{w},"height":{h}}}}}'>{script}</script>
</body>
</html>
"""


# ---------------------------------------------------------------- components
def map_layer(theme, height, explore=False, label_text="UNESCO Old Town"):
    """The real base map + route + plaques + user. Absolute, full width, `height` tall."""
    t = TH[theme]
    unesco = ""
    if explore:
        unesco = f"""
      <polygon points="{{{{map.unesco}}}}" fill="none" stroke="{t['t3']}" stroke-width="{{{{map.unescoW}}}}" stroke-dasharray="{{{{map.unescoDash}}}}" stroke-linejoin="round"></polygon>"""
    explore_html = ""
    if explore:
        explore_html = f"""
  <div style="{{{{unescoLabel.style}}}}; font-size: 12px; line-height: 16px; font-weight: 500; letter-spacing: 0.2px; color: {t['t2']}; text-shadow: 0 0 2px {t['halo']}, 0 0 2px {t['halo']}, 0 0 3px {t['halo']}, 0 0 4px {t['halo']}">{label_text}</div>
  <sc-for list="{{{{pois}}}}" as="d" hint-placeholder-count="40">
    <div style="{{{{d.style}}}}" aria-hidden="true"></div>
  </sc-for>
  <sc-for list="{{{{clusters}}}}" as="c" hint-placeholder-count="6">
    <div style="{{{{c.style}}}}" role="img" aria-label="{{{{c.label}}}}">{{{{c.count}}}}</div>
  </sc-for>"""
    return f"""<div style="position: absolute; left: 0; top: 0; width: 390px; height: {height}px; overflow: hidden; background: {t['land']}" role="img" aria-label="__MAPLABEL__">
  <div style="position: absolute; left: 0; top: 0; width: 1000px; height: 1289px; transform-origin: 0 0; transform: {{{{map.transform}}}}">
    <img src="{t['blob']}" alt="" style="position: absolute; left: 0; top: 0; width: 1000px; height: 1289px">
    <svg viewBox="0 0 1000 1289" width="1000" height="1289" style="position: absolute; left: 0; top: 0" aria-hidden="true">{unesco}
      <polyline points="{{{{map.walked}}}}" fill="none" stroke="{t['walked']}" stroke-opacity="0.6" stroke-width="{{{{map.w5}}}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
      <polyline points="{{{{map.later}}}}" fill="none" stroke="{t['accent']}" stroke-opacity="0.45" stroke-width="{{{{map.w5}}}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
      <polyline points="{{{{map.next}}}}" fill="none" stroke="{t['surface']}" stroke-width="{{{{map.w10}}}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
      <polyline points="{{{{map.next}}}}" fill="none" stroke="{t['accent']}" stroke-width="{{{{map.w6}}}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
    </svg>
  </div>{explore_html}
  <sc-if value="{{{{cone.show}}}}" hint-placeholder-val="{{{{ true }}}}">
    <svg style="{{{{cone.style}}}}" viewBox="0 0 80 80" width="80" height="80" aria-hidden="true">
      <defs>
        <radialGradient id="userCone" cx="40" cy="40" r="40" gradientUnits="userSpaceOnUse">
          <stop offset="0" stop-color="{t['user']}" stop-opacity="0.30"></stop>
          <stop offset="1" stop-color="{t['user']}" stop-opacity="0"></stop>
        </radialGradient>
      </defs>
      <path d="M40 40 L20 5.36 A40 40 0 0 1 60 5.36 Z" fill="url(#userCone)"></path>
    </svg>
  </sc-if>
  <sc-for list="{{{{plaques}}}}" as="p" hint-placeholder-count="11">
    <div style="{{{{p.style}}}}" role="img" aria-label="{{{{p.label}}}}">
      <sc-if value="{{{{p.isNum}}}}" hint-placeholder-val="{{{{ true }}}}"><span>{{{{p.num}}}}</span></sc-if>
      <sc-if value="{{{{p.isCheck}}}}" hint-placeholder-val="{{{{ false }}}}">{icon('check', 14, 'currentColor', 2.6)}</sc-if>
    </div>
  </sc-for>
  <div style="{{{{user.style}}}}" role="img" aria-label="__USERLABEL__"></div>
</div>"""


def scrim_css(theme):
    t = TH[theme]
    return f"background: {t['scrim']}; -webkit-backdrop-filter: blur(20px) saturate(1.6); backdrop-filter: blur(20px) saturate(1.6); box-shadow: {t['shadow1']}"


def header(theme, title, count, lang="en"):
    t = TH[theme]
    min_label = "Minimalizuj, trasa trwa dalej" if lang == "pl" else "Minimise, tour keeps running"
    menu_label = "Menu trasy" if lang == "pl" else "Tour menu"
    return f"""<div style="position: absolute; top: 48px; left: 0; width: 390px; display: flex; justify-content: center; pointer-events: none">
  <div style="pointer-events: auto; height: 48px; display: flex; align-items: center; border-radius: 24px; {scrim_css(theme)}">
    <button type="button" aria-label="{min_label}" style="width: 48px; height: 48px; border: 0; padding: 0; margin: 0; background: transparent; color: {t['t1']}; display: flex; align-items: center; justify-content: center; border-radius: 24px; font-family: inherit; cursor: pointer">{icon('chevron_down', 22, 'currentColor', 2.1)}</button>
    <div style="display: flex; align-items: baseline; gap: 8px; padding: 0 2px; white-space: nowrap">
      <span style="font-size: 16px; line-height: 24px; font-weight: 600; color: {t['t1']}">{title}</span>
      <span style="font-size: 14px; line-height: 20px; font-weight: 500; color: {t['t2']}; font-variant-numeric: tabular-nums">{count}</span>
    </div>
    <button type="button" aria-label="{menu_label}" style="width: 48px; height: 48px; border: 0; padding: 0; margin: 0; background: transparent; color: {t['t1']}; display: flex; align-items: center; justify-content: center; border-radius: 24px; font-family: inherit; cursor: pointer">{icon('ellipsis', 22)}</button>
  </div>
</div>"""


def map_buttons_nowwalking(theme, map_bottom, lang="en"):
    """North tick (top right), attribution (bottom left), open full map (bottom right)."""
    t = TH[theme]
    info_label = "Dane mapy: © autorzy OpenStreetMap" if lang == "pl" else "Map data: © OpenStreetMap contributors"
    expand_label = "Otwórz pełną mapę" if lang == "pl" else "Open full map"
    top = map_bottom - 48
    return f"""<div aria-hidden="true" style="position: absolute; right: 20px; top: 108px; width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; {scrim_css(theme)}">
  <svg viewBox="0 0 20 20" style="{{{{north.style}}}}"><path d="M10 2.5 13 10H7z" fill="{t['t1']}"></path><path d="M10 17.5 7 10h6z" fill="{t['t3']}" fill-opacity="0.55"></path></svg>
</div>
<button type="button" aria-label="{info_label}" style="position: absolute; left: 8px; top: {top}px; width: 48px; height: 48px; border: 0; padding: 0; background: transparent; display: flex; align-items: center; justify-content: center; color: {t['t2']}; cursor: pointer">
  <span style="width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; {scrim_css(theme)}">{icon('info', 16, 'currentColor', 1.8)}</span>
</button>
<button type="button" aria-label="{expand_label}" style="position: absolute; right: 12px; top: {top - 4}px; width: 48px; height: 48px; border: 0; padding: 0; border-radius: 50%; color: {t['t1']}; display: flex; align-items: center; justify-content: center; cursor: pointer; {scrim_css(theme)}">{icon('map', 22, 'currentColor', 1.8)}</button>"""


def look_cue(theme, b, caption, up=False, label=""):
    t = TH[theme]
    r = 30
    cx0, cy0 = 40, 44
    br = math.radians(b)
    dx, dy = cx0 + r * math.sin(br), cy0 - r * math.cos(br)
    nx, ny = cx0 + 21 * math.sin(br), cy0 - 21 * math.cos(br)
    upsvg = ""
    if up:
        ax, ay = dx, dy - 12
        upsvg = (f'<path d="M{ax:.1f} {ay + 5:.1f}V{ay - 5:.1f}M{ax - 3.6:.1f} {ay - 1.4:.1f}l3.6-3.6 3.6 3.6" fill="none" stroke="{t["accent"]}" '
                 f'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path>')
    return f"""<div role="img" aria-label="{label}" style="flex: none; width: 136px; display: flex; flex-direction: column; align-items: center; gap: 2px">
  <svg width="80" height="52" viewBox="0 0 80 52" aria-hidden="true" style="display: block">
    <path d="M10 44A30 30 0 0 1 70 44" fill="none" stroke="{t['divider']}" stroke-width="3" stroke-linecap="round"></path>
    <path d="M40 11.5v3.5M11.5 44H15M65 44h3.5" stroke="{t['divider']}" stroke-width="2" stroke-linecap="round"></path>
    <path d="M40 41 L{nx:.1f} {ny:.1f}" stroke="{t['accent']}" stroke-opacity="0.3" stroke-width="2" stroke-linecap="round"></path>
    <path d="M40 38.5l4.6 7h-9.2z" fill="{t['t2']}"></path>
    {upsvg}
    <circle cx="{dx:.2f}" cy="{dy:.2f}" r="6" fill="{t['accent']}" stroke="{t['surface']}" stroke-width="2"></circle>
  </svg>
  <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {t['t2']}; white-space: nowrap">{caption}</span>
</div>"""


def overline(theme, text, color=None):
    t = TH[theme]
    return (f'<div style="font-size: 12px; line-height: 16px; font-weight: 500; letter-spacing: 0.6px; text-transform: uppercase; '
            f'color: {color or t["t2"]}">{text}</div>')


def controls(theme, playing=True):
    t = TH[theme]
    main_icon = icon('pause_fill' if playing else 'play_fill', 32, t['onAccent'])
    main_label = "Pause" if playing else "Play"
    side = f"width: 56px; height: 56px; border: 0; padding: 0; border-radius: 50%; background: transparent; color: {t['t1']}; display: flex; align-items: center; justify-content: center; cursor: pointer; font-family: inherit"
    return f"""<div style="display: flex; align-items: center; justify-content: center; gap: 36px; height: 72px">
    <button type="button" aria-label="Replay last part" style="{side}">{icon('replay', 28, 'currentColor', 2)}</button>
    <button type="button" aria-label="{main_label}" style="width: 72px; height: 72px; border: 0; padding: 0; border-radius: 50%; background: {t['accent']}; display: flex; align-items: center; justify-content: center; cursor: pointer">{main_icon}</button>
    <button type="button" aria-label="Skip this part" style="{side}">{icon('forward_end_fill', 28, 'currentColor')}</button>
  </div>"""


def links(theme):
    t = TH[theme]
    st = f"height: 48px; display: flex; align-items: center; gap: 8px; padding: 0 8px; border: 0; background: transparent; color: {t['t1']}; font-family: inherit; font-size: 16px; line-height: 24px; font-weight: 500; text-decoration: none; cursor: pointer"
    return f"""<div style="display: flex; justify-content: space-between; margin: 0 -8px">
    <a href="#place-detail-transcript" style="{st}"><span style="color: {t['t2']}; display: flex">{icon('doc_text', 20, 'currentColor', 1.8)}</span>Transcript</a>
    <button type="button" aria-haspopup="dialog" style="{st}"><span style="color: {t['t2']}; display: flex">{icon('list_bullet', 20, 'currentColor', 1.8)}</span>Stops <span style="font-variant-numeric: tabular-nums; color: {t['t2']}; font-weight: 400">(11)</span></button>
  </div>"""


def segments(theme, fills):
    t = TH[theme]
    segs = []
    for f in fills:
        segs.append(f'<span style="flex: 1; height: 3px; border-radius: 2px; background: {t["divider"] if theme == "light" else "#3A4044"}; overflow: hidden; display: block">'
                    f'<span style="display: block; height: 3px; width: {int(f * 100)}%; background: {t["accent"]}; border-radius: 2px"></span></span>')
    return "".join(segs)


def panel(theme, top, inner, pad="20px 16px 0"):
    t = TH[theme]
    return f"""<main style="position: absolute; left: 0; top: {top}px; width: 390px; height: {844 - top}px; box-sizing: border-box; background: {t['surface']}; border-radius: 28px 28px 0 0; box-shadow: {t['shadow2']}; padding: {pad}; display: flex; flex-direction: column">
{inner}
</main>"""


def distance_block(theme, num, unit, sub):
    t = TH[theme]
    return f"""<div style="display: flex; flex-direction: column; gap: 2px; min-width: 0">
      <div style="display: flex; align-items: baseline; gap: 5px; font-variant-numeric: tabular-nums; white-space: nowrap">
        <span style="font-size: 46px; line-height: 50px; font-weight: 700; letter-spacing: -1.2px; color: {t['t1']}">{num}</span>
        <span style="font-size: 24px; line-height: 28px; font-weight: 600; color: {t['t1']}">{unit}</span>
      </div>
      <div style="font-size: 14px; line-height: 20px; color: {t['t2']}">{sub}</div>
    </div>"""


# ================================================================= Now Walking (heading to stop)
def now_walking(theme, demo=False):
    t = TH[theme]
    remain = 80 if demo else 120
    num = str(remain)
    sub = "about 1 min" if demo else "about 2 min"
    view = dict(S=1.35, next=4, remainM=remain, headingUp=True, aim=[4, 20], focus="user", screen=[195, 236 if demo else 252], cone=True,
                hollow=demo, view=[390, 340])
    m = map_layer(theme, 340)
    m = m.replace("__MAPLABEL__", f"Map. Next stop Cloth Hall, {remain} metres ahead, slightly right. Double-tap to open full map.")
    m = m.replace("__USERLABEL__", "Your simulated position" if demo else "Your position")

    sim = ""
    if demo:
        sim = f"""<div style="position: absolute; top: 98px; left: 0; width: 390px; display: flex; justify-content: center; pointer-events: none">
  <button type="button" aria-label="Simulated location. Demo walk is on, replaying at 4 times speed. Opens demo controls." style="pointer-events: auto; height: 44px; border: 0; padding: 0 4px; background: transparent; display: flex; align-items: center; cursor: pointer; font-family: inherit">
    <span style="height: 28px; display: flex; align-items: center; gap: 6px; padding: 0 10px 0 8px; border-radius: 14px; background: {t['simbg']}; color: {t['simfg']}; box-shadow: {t['shadow1']}; font-size: 12px; line-height: 16px; font-weight: 500; letter-spacing: 0.6px; white-space: nowrap">
      {icon('figure_walk', 14, 'currentColor', 2)}<span>SIMULATED</span><span aria-hidden="true" style="opacity: 0.55">·</span><span style="font-variant-numeric: tabular-nums; letter-spacing: 0">4×</span>
    </span>
  </button>
</div>"""

    if demo:
        card_head = f"""<div style="display: flex; align-items: center; gap: 8px; height: 24px">
        <span style="color: {t['accent']}; display: flex">{icon('figure_walk', 20, 'currentColor', 1.9)}</span>
        <span style="flex: 1; font-size: 16px; line-height: 24px; font-weight: 500; color: {t['t1']}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">On the way to Cloth Hall</span>
      </div>"""
        card_text = f"""<div style="height: 84px; overflow: hidden; display: flex; flex-direction: column; justify-content: flex-end; -webkit-mask-image: linear-gradient(to bottom, transparent 0, #000 26px); mask-image: linear-gradient(to bottom, transparent 0, #000 26px)">
        <p style="margin: 0; font-size: 18px; line-height: 28px; color: {t['t1']}">Next, the Cloth Hall: the long building in the middle of the square, about two minutes ahead, slightly to your right.</p>
      </div>"""
        card_foot = f"""<div style="display: flex; align-items: center; gap: 8px; height: 16px; font-size: 12px; line-height: 16px; font-weight: 500; color: {t['t2']}">
        <span>Demo walk · recorded route replayed at</span><span style="font-variant-numeric: tabular-nums">4×</span>
      </div>"""
    else:
        card_head = f"""<div style="display: flex; align-items: center; gap: 8px; height: 24px">
        <span style="color: {t['accent']}; display: flex">{icon('waveform', 20, 'currentColor', 2)}</span>
        <span style="flex: 1; font-size: 16px; line-height: 24px; font-weight: 500; color: {t['t1']}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">St Mary's Basilica</span>
        <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {t['t2']}">The Historian</span>
      </div>"""
        card_text = f"""<div style="height: 84px; overflow: hidden; display: flex; flex-direction: column; justify-content: flex-end; -webkit-mask-image: linear-gradient(to bottom, transparent 0, #000 24px); mask-image: linear-gradient(to bottom, transparent 0, #000 24px)">
        <p style="margin: 0; font-size: 18px; line-height: 28px; color: {t['t3']}">Look back at the two towers.</p>
        <p style="margin: 0; font-size: 18px; line-height: 28px; color: {t['t1']}">The taller tower, on your left, is where the trumpeter plays…</p>
      </div>"""
        card_foot = f"""<div style="display: flex; align-items: center; gap: 12px; height: 16px">
        <div role="progressbar" aria-label="Story 2 of 3" aria-valuemin="0" aria-valuemax="100" aria-valuenow="48" style="flex: 1; display: flex; gap: 4px">{segments(theme, [1, 0.45, 0])}</div>
        <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {t['t2']}; font-variant-numeric: tabular-nums; white-space: nowrap">Story 2 of 3</span>
      </div>"""

    inner = f"""  <section aria-label="Next stop 4, Cloth Hall, {remain} metres, {sub}, ahead slightly right" style="display: flex; flex-direction: column">
    <div style="display: flex; flex-direction: column; gap: 4px">
      {overline(theme, 'Next · Stop 4')}
      <h1 style="margin: 0; font-size: 22px; line-height: 28px; font-weight: 700; color: {t['t1']}">Cloth Hall</h1>
    </div>
    <div style="display: flex; align-items: flex-end; justify-content: space-between; margin-top: 14px">
      {distance_block(theme, num, 'm', sub)}
      {look_cue(theme, 20, 'ahead, slightly right', label='Cloth Hall is ahead, slightly right')}
    </div>
  </section>
  <section aria-label="Now playing" style="margin-top: 18px; background: {t['sunken']}; border-radius: 20px; padding: 14px 16px 16px; display: flex; flex-direction: column; gap: 10px">
      {card_head}
      {card_text}
      {card_foot}
  </section>
  <div style="margin-top: 18px">
  {controls(theme, playing=True)}
  </div>
  <div style="margin-top: 6px">
  {links(theme)}
  </div>"""
    body = "\n".join([m, header(theme, "Royal Route", "4/11"), sim, map_buttons_nowwalking(theme, 312),
                      panel(theme, 316, inner)])
    return body, view


# ================================================================= Now Walking (arrived)
def arrived(theme="light"):
    t = TH[theme]
    view = dict(S=1.5, atStop=3, next=4, headingUp=False, focus=[520, 512], screen=[195, 200], cone=False, view=[390, 324])
    m = map_layer(theme, 324)
    m = m.replace("__MAPLABEL__", "Map. You're at stop 3, St Mary's Basilica. Double-tap to open full map.")
    m = m.replace("__USERLABEL__", "Your position")
    tell_more = f"""<button type="button" style="flex: none; height: 48px; border: 0; padding: 0; margin: -6px -4px -6px 0; background: transparent; display: flex; align-items: center; cursor: pointer; font-family: inherit">
          <span style="height: 36px; display: flex; align-items: center; gap: 6px; padding: 0 14px; border-radius: 18px; background: {t['accentSub']}; color: {t['accent']}; font-size: 14px; line-height: 20px; font-weight: 600; white-space: nowrap">Tell me more</span>
        </button>"""
    inner = f"""  <section aria-label="You're here, stop 3, St Mary's Basilica. Look left and up, at the taller tower." style="display: flex; flex-direction: column">
    <div style="display: flex; flex-direction: column; gap: 4px">
      {overline(theme, "You're here · Stop 3", t['accent'])}
      <h1 style="margin: 0; font-size: 22px; line-height: 28px; font-weight: 700; color: {t['t1']}">St Mary's Basilica</h1>
    </div>
    <div style="display: flex; align-items: flex-end; justify-content: space-between; margin-top: 14px">
      <div style="display: flex; flex-direction: column; gap: 4px; min-width: 0; padding-bottom: 2px">
        <div style="font-size: 24px; line-height: 30px; font-weight: 600; color: {t['t1']}">Look left and up</div>
        <div style="font-size: 14px; line-height: 20px; color: {t['t2']}">at the taller of the two towers</div>
      </div>
      {look_cue(theme, -90, 'look up, left', up=True, label="St Mary's Basilica is on your left. Look up.")}
    </div>
  </section>
  <section aria-label="Now playing" style="margin-top: 16px; background: {t['sunken']}; border-radius: 20px; padding: 14px 16px 14px; display: flex; flex-direction: column; gap: 10px">
      <div style="display: flex; align-items: center; gap: 8px; height: 24px">
        <span style="color: {t['accent']}; display: flex">{icon('waveform', 20, 'currentColor', 2)}</span>
        <span style="flex: 1; font-size: 16px; line-height: 24px; font-weight: 500; color: {t['t1']}">St Mary's Basilica</span>
        <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {t['t2']}">The Historian</span>
      </div>
      <div style="height: 84px; overflow: hidden; display: flex; flex-direction: column; justify-content: flex-end; -webkit-mask-image: linear-gradient(to bottom, transparent 0, #000 24px); mask-image: linear-gradient(to bottom, transparent 0, #000 24px)">
        <p style="margin: 0; font-size: 18px; line-height: 28px; color: {t['t3']}">You've arrived.</p>
        <p style="margin: 0; font-size: 18px; line-height: 28px; color: {t['t1']}">Every hour, a trumpeter plays a short call from that tower, the hejnał…</p>
      </div>
      <div style="display: flex; align-items: center; gap: 12px; height: 36px">
        <div style="flex: 1; display: flex; flex-direction: column; gap: 6px; min-width: 0">
          <div role="progressbar" aria-label="Story 1 of 3" aria-valuemin="0" aria-valuemax="100" aria-valuenow="30" style="display: flex; gap: 4px">{segments(theme, [0.3, 0, 0])}</div>
          <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {t['t2']}; font-variant-numeric: tabular-nums">Story 1 of 3</span>
        </div>
        {tell_more}
      </div>
  </section>
  <div style="margin-top: 14px">
  {controls(theme, playing=True)}
  </div>
  <div style="margin-top: 4px">
  {links(theme)}
  </div>"""
    body = "\n".join([m, header(theme, "Royal Route", "3/11"), map_buttons_nowwalking(theme, 296), panel(theme, 300, inner)])
    return body, view


# ================================================================= Reading mode (Polish, text only)
def reading_pl(theme="light"):
    t = TH[theme]
    view = dict(S=1.3, atStop=3, next=4, headingUp=False, focus=[577.6, 515], screen=[214, 138], cone=False, view=[390, 200], lang="pl")
    m = map_layer(theme, 200)
    m = m.replace("__MAPLABEL__", "Mapa. Jesteś przy przystanku 3, Kościół Mariacki. Stuknij dwukrotnie, aby otworzyć pełną mapę.")
    m = m.replace("__USERLABEL__", "Twoja pozycja")
    paras = [
        "Stoisz przed Kościołem Mariackim. Spójrz w lewo i w górę, na wyższą z dwóch wież.",
        "Co godzinę trębacz gra z tej wieży krótki sygnał, hejnał, na cztery strony miasta. Posłuchaj do końca: melodia urywa się w pół nuty.",
        "Legenda mówi, że trębacza trafiła strzała, gdy ostrzegał miasto przed atakiem. Od tamtej pory hejnał zawsze milknie w tym samym miejscu.",
        "Jeśli kościół jest otwarty, wejdź do środka. Czeka tam rzeźbiony, drewniany ołtarz Wita Stwosza, ukończony w 1489 roku. To jeden z największych ołtarzy tego rodzaju w Europie.",
    ]
    ptxt = "\n        ".join(f'<p style="margin: 0; font-size: 20px; line-height: 30px; color: {t["t1"]}">{p}</p>' for p in paras)
    inner = f"""  <section aria-label="Jesteś tutaj, przystanek 3, Kościół Mariacki. Spójrz w lewo i w górę." style="display: flex; align-items: flex-end; justify-content: space-between; gap: 8px">
    <div style="display: flex; flex-direction: column; gap: 4px; min-width: 0; padding-bottom: 18px">
      {overline(theme, 'Jesteś tutaj · Przystanek 3', t['accent'])}
      <h1 style="margin: 0; font-size: 22px; line-height: 28px; font-weight: 700; color: {t['t1']}">Kościół Mariacki</h1>
    </div>
    {look_cue(theme, -90, 'w lewo i w górę', up=True, label='Kościół Mariacki jest po lewej. Spójrz w górę.')}
  </section>
  <section aria-label="Tekst opowieści" style="margin-top: 14px; flex: 1; min-height: 0; background: {t['sunken']}; border-radius: 20px; padding: 14px 16px 0; display: flex; flex-direction: column; gap: 12px">
    <div style="display: flex; align-items: center; gap: 8px; height: 24px">
      <span style="color: {t['t2']}; display: flex">{icon('doc_text', 20, 'currentColor', 1.8)}</span>
      <span style="flex: 1; font-size: 16px; line-height: 24px; font-weight: 500; color: {t['t1']}">Opowieść <span style="font-variant-numeric: tabular-nums">1 z 3</span></span>
      <span style="height: 24px; display: flex; align-items: center; gap: 4px; padding: 0 8px; border-radius: 8px; background: {t['surface']}; color: {t['t2']}; font-size: 12px; line-height: 16px; font-weight: 500; white-space: nowrap">{icon('speaker_slash', 14, 'currentColor', 1.8)}Tylko tekst</span>
    </div>
    <div tabindex="0" style="flex: 1; min-height: 0; overflow: hidden; display: flex; flex-direction: column; gap: 12px; max-width: 600px; -webkit-mask-image: linear-gradient(to bottom, #000 0, #000 calc(100% - 56px), transparent 100%); mask-image: linear-gradient(to bottom, #000 0, #000 calc(100% - 56px), transparent 100%)">
        {ptxt}
    </div>
  </section>
  <div style="margin-top: 12px; display: flex; align-items: center; gap: 6px; color: {t['t2']}; font-size: 13px; line-height: 18px">
    {icon('info', 16, 'currentColor', 1.8)}<span>Polskie opowieści są wyświetlane jako tekst.</span>
  </div>
  <button type="button" style="margin-top: 12px; height: 52px; border: 0; border-radius: 26px; background: {t['accent']}; color: {t['onAccent']}; font-family: inherit; font-size: 16px; line-height: 24px; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 6px; cursor: pointer">Następny przystanek{icon('chevron_right', 18, 'currentColor', 2.2)}</button>"""
    body = "\n".join([m, header(theme, "Droga Królewska", "3/11", lang="pl"), panel(theme, 176, inner, pad="20px 16px 28px")])
    return body, view


# ================================================================= Full map (tour mode)
def round_btn(theme, label, ic, pos, href=None):
    t = TH[theme]
    st = f"position: absolute; {pos}; width: 48px; height: 48px; border: 0; padding: 0; border-radius: 50%; color: {t['t1']}; display: flex; align-items: center; justify-content: center; cursor: pointer; text-decoration: none; {scrim_css(theme)}"
    if href:
        return f'<a href="{href}" aria-label="{label}" style="{st}">{ic}</a>'
    return f'<button type="button" aria-label="{label}" style="{st}">{ic}</button>'


def attribution(theme, top):
    t = TH[theme]
    h = t['halo']
    return (f'<div style="position: absolute; left: 16px; top: {top}px; font-size: 12px; line-height: 16px; color: {t["t2"]}; '
            f'text-shadow: 0 0 2px {h}, 0 0 2px {h}, 0 0 4px {h}">© OpenStreetMap contributors</div>')


def full_map(theme="light"):
    t = TH[theme]
    view = dict(S=1.1, next=4, remainM=120, headingUp=False, focus=[505, 515], screen=[200, 300], cone=True, view=[390, 844])
    m = map_layer(theme, 844)
    m = m.replace("__MAPLABEL__", "Map of the Royal Route. Stops 1 to 3 visited. Next stop 4, Cloth Hall, selected.")
    m = m.replace("__USERLABEL__", "Your position")
    sheet_top = 536
    sheet = f"""<section aria-label="Cloth Hall" style="position: absolute; left: 0; top: {sheet_top}px; width: 390px; height: {844 - sheet_top}px; box-sizing: border-box; background: {t['surface']}; border-radius: 28px 28px 0 0; box-shadow: {t['shadow2']}; padding: 8px 16px 28px; display: flex; flex-direction: column">
  <div aria-hidden="true" style="align-self: center; width: 36px; height: 4px; border-radius: 2px; background: {t['divider']}"></div>
  <div style="margin-top: 12px; display: flex; align-items: flex-start; gap: 12px">
    <div aria-hidden="true" style="flex: none; margin-top: 2px; width: 40px; height: 40px; box-sizing: border-box; border-radius: 50%; background: {t['accent']}; color: {t['onAccent']}; display: flex; align-items: center; justify-content: center; font-size: 15px; font-weight: 700; font-variant-numeric: tabular-nums">4</div>
    <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">
      {overline(theme, 'Next · Stop 4', t['accent'])}
      <h1 style="margin: 0; font-size: 22px; line-height: 28px; font-weight: 700; color: {t['t1']}">Cloth Hall</h1>
      <div style="font-size: 14px; line-height: 20px; color: {t['t2']}">Market hall · 14th c.</div>
    </div>
    <button type="button" aria-label="Close" style="flex: none; width: 48px; height: 48px; margin: -6px -10px 0 0; border: 0; padding: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">
      <span style="width: 30px; height: 30px; border-radius: 50%; background: {t['sunken']}; color: {t['t2']}; display: flex; align-items: center; justify-content: center">{icon('xmark', 16, 'currentColor', 2.2)}</span>
    </button>
  </div>
  <div style="margin-top: 12px; display: flex; align-items: center; gap: 6px; font-size: 14px; line-height: 20px; font-weight: 500; color: {t['t1']}; font-variant-numeric: tabular-nums">
    <span style="color: {t['accent']}; display: flex">{icon('arrow_up_right', 16, 'currentColor', 2.2)}</span>120 m · ahead, slightly right<span style="color: {t['t2']}; font-weight: 400">· about 2 min</span>
  </div>
  <p style="margin: 8px 0 0; font-size: 16px; line-height: 24px; color: {t['t1']}; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden">The long building in the middle of the square, Sukiennice in Polish. A market hall since the 14th century.</p>
  <div style="margin-top: 12px; display: flex">
    <span style="height: 28px; display: flex; align-items: center; gap: 6px; padding: 0 10px; border-radius: 8px; background: {t['sunken']}; color: {t['t2']}; font-size: 12px; line-height: 16px; font-weight: 500">{icon('quote', 14, 'currentColor', 1.8)}Tour story</span>
  </div>
  <div style="margin-top: auto; display: flex; gap: 12px">
    <button type="button" style="flex: 1; height: 48px; border: 0; border-radius: 24px; background: {t['accent']}; color: {t['onAccent']}; font-family: inherit; font-size: 16px; line-height: 24px; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer">{icon('play_fill', 18, 'currentColor')}Listen</button>
    <a href="#place-detail" style="flex: 1; height: 48px; border-radius: 24px; background: {t['sunken']}; color: {t['t1']}; font-size: 16px; line-height: 24px; font-weight: 600; display: flex; align-items: center; justify-content: center; text-decoration: none">Details</a>
  </div>
</section>"""
    body = "\n".join([
        m,
        round_btn(theme, "Back to Now Walking", icon('chevron_backward', 22, 'currentColor', 2.1), "left: 16px; top: 48px", href="#now-walking"),
        round_btn(theme, "Map layers", icon('layers', 22, 'currentColor', 1.8), "right: 16px; top: 48px"),
        round_btn(theme, "Follow my position", icon('location', 20, 'currentColor', 1.9), f"right: 16px; top: {sheet_top - 16 - 48}px"),
        attribution(theme, sheet_top - 28),
        sheet,
    ])
    return body, view


# ================================================================= Full map (explore)
def chip(theme, label, count=None, on=False):
    t = TH[theme]
    cnt = f'<span style="font-variant-numeric: tabular-nums; color: {t["accent"] if on else t["t2"]}; font-weight: 400">{count}</span>' if count else ""
    chk = f'<span style="display: flex">{icon("check", 16, "currentColor", 2.3)}</span>' if on else ""
    face = (f"background: {t['accentSub']}; color: {t['accent']}; border: 1px solid {t['accentSub']}" if on
            else f"background: {t['surface']}; color: {t['t1']}; border: 1px solid {t['divider']}")
    checked = ' checked' if on else ''
    return f"""<label style="flex: none; height: 48px; display: flex; align-items: center; position: relative; cursor: pointer">
        <input type="checkbox"{checked} style="position: absolute; opacity: 0; width: 1px; height: 1px; margin: 0">
        <span style="height: 36px; box-sizing: border-box; display: flex; align-items: center; gap: 6px; padding: 0 {12 if on else 14}px; border-radius: 8px; {face}; font-size: 14px; line-height: 20px; font-weight: 500; white-space: nowrap">{chk}{label}{cnt}</span>
      </label>"""


def explore(theme="light"):
    t = TH[theme]
    view = dict(S=0.56, next=4, remainM=120, headingUp=False, focus=[525, 640], screen=[195, 350], cone=True,
                explore=True, unescoLabel=[430, 140], view=[390, 844])
    m = map_layer(theme, 844, explore=True)
    m = m.replace("__MAPLABEL__", "Map of Kraków's Old Town with all places, the Royal Route stops and the UNESCO Old Town boundary.")
    m = m.replace("__USERLABEL__", "Your position")
    bar_top = 712
    bar = f"""<section aria-label="Filter places" style="position: absolute; left: 0; top: {bar_top}px; width: 390px; height: {844 - bar_top}px; box-sizing: border-box; background: {t['surface']}; border-radius: 28px 28px 0 0; box-shadow: {t['shadow2']}; padding: 18px 0 24px; display: flex; flex-direction: column">
  <div style="padding: 0 16px; display: flex; align-items: baseline; justify-content: space-between; gap: 12px">
    <h1 style="margin: 0; font-size: 18px; line-height: 24px; font-weight: 500; color: {t['t1']}">All places</h1>
    <span style="display: flex; align-items: center; gap: 4px; font-size: 12px; line-height: 16px; font-weight: 500; color: {t['t2']}">{icon('check', 14, t['accent'], 2.3)}Kraków · offline ready</span>
  </div>
  <div role="group" aria-label="Categories" style="margin-top: 8px; display: flex; gap: 8px; overflow: hidden; padding: 0 16px">
      {chip(theme, 'Tour stops', on=True)}
      {chip(theme, 'Monuments', '395', on=True)}
      {chip(theme, 'Plaques', '923')}
      {chip(theme, 'Heritage')}
      {chip(theme, 'Museums')}
  </div>
</section>"""
    body = "\n".join([
        m,
        round_btn(theme, "Back", icon('chevron_backward', 22, 'currentColor', 2.1), "left: 16px; top: 48px", href="#now-walking"),
        round_btn(theme, "Map layers", icon('layers', 22, 'currentColor', 1.8), "right: 16px; top: 48px"),
        round_btn(theme, "Follow my position", icon('location', 20, 'currentColor', 1.9), f"right: 16px; top: {bar_top - 16 - 48}px"),
        attribution(theme, bar_top - 28),
        bar,
    ])
    return body, view


# ================================================================= write
def write(name, title, theme, fn, lang="en"):
    body, view = fn()
    html = page(title, theme, body, js_for(theme, view, lang), lang=lang)
    with open(os.path.join(OUT, name), "w") as fh:
        fh.write(html)
    print("wrote", name, len(html))


if __name__ == "__main__":
    write("Main.dc.html", "Now Walking", "light", lambda: now_walking("light"))
    write("NowWalkingArrived.dc.html", "Now Walking · Arrived", "light", lambda: arrived("light"))
    write("NowWalkingDemo.dc.html", "Now Walking · Demo walk", "light", lambda: now_walking("light", demo=True))
    write("NowWalkingReadingPL.dc.html", "Now Walking · Reading mode (Polish)", "light", lambda: reading_pl("light"), lang="pl")
    write("NowWalkingDark.dc.html", "Now Walking · Dark", "dark", lambda: now_walking("dark"))
    write("FullMap.dc.html", "Full map", "light", lambda: full_map("light"))
    write("FullMapExplore.dc.html", "Full map · Explore", "light", lambda: explore("light"))

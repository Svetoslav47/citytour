#!/usr/bin/env python3
"""Generates the onboarding / home / tour detail / route ready / before-you-go artboards."""
import json, os

BASE = os.path.dirname(os.path.abspath(__file__))
CANVAS = os.path.join(BASE, "canvas")
OUT = os.path.join(CANVAS, "project")
meta = json.load(open(os.path.join(CANVAS, "map-meta.json")))

POLY_JS = "[" + ",".join("[%.1f,%.1f]" % (p[0], p[1]) for p in meta["route_polyline_px"]) + "]"
STOPS_JS = "[" + ",".join("[%.1f,%.1f]" % (s["x"], s["y"]) for s in meta["stops"]) + "]"

LIGHT_MAP = "/_blob/47c1f630f4c212aa493463e6caf6c0c2"
FONT = "'HarmonyOS Sans', 'HarmonyOS Sans SC', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Noto Sans SC', sans-serif"
NOTO = '<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;700&amp;display=swap" rel="stylesheet">'

# ---------- tokens ----------
CANVAS_BG = "#F4F5F3"; SURFACE = "#FFFFFF"; SUNKEN = "#EEEFEC"
T1 = "#16181A"; T2 = "#5A6066"; T3 = "#6B7176"; DIV = "#E1E3DF"
ACC = "#1D6B5B"; SUBTLE = "#E3F0EC"; USER = "#2F6FDE"; ERR = "#B3261E"
SCRIM = "background: rgba(244,245,243,0.76); -webkit-backdrop-filter: blur(20px) saturate(1.6); backdrop-filter: blur(20px) saturate(1.6); box-shadow: 0 1px 2px rgba(0,0,0,0.06), 0 2px 8px rgba(0,0,0,0.08);"
TAB = "font-variant-numeric: tabular-nums;"
OVERLINE = f"font-size: 12px; line-height: 16px; font-weight: 500; letter-spacing: 0.6px; text-transform: uppercase; color: {T2};"
BTN_RESET = "border: 0; margin: 0; padding: 0; background: transparent; font-family: inherit; cursor: pointer;"
PRIMARY = f"{BTN_RESET} display: flex; align-items: center; justify-content: center; width: 100%; height: 48px; border-radius: 24px; background: {ACC}; color: #FFFFFF; font-size: 16px; line-height: 24px; font-weight: 500;"
HIDDEN_INPUT = "position: absolute; opacity: 0; width: 1px; height: 1px; margin: 0; pointer-events: none;"

# ---------- icons (24 box, stroke 1.75, round caps) ----------
ICONS = {
    "chevron_backward": '<path d="M14.5 5.5L8 12l6.5 6.5"></path>',
    "chevron_right": '<path d="M9.5 5.5L16 12l-6.5 6.5"></path>',
    "chevron_down": '<path d="M6 9.5l6 6 6-6"></path>',
    "xmark": '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"></path>',
    "checkmark": '<path d="M5 12.5l4.5 4.5L19 7.5"></path>',
    "gearshape": '<path d="M12.22 2.75h-.44a1.9 1.9 0 0 0-1.9 1.9v.17a1.9 1.9 0 0 1-.95 1.64l-.41.24a1.9 1.9 0 0 1-1.9 0l-.14-.08a1.9 1.9 0 0 0-2.6.7l-.22.37a1.9 1.9 0 0 0 .7 2.6l.14.09a1.9 1.9 0 0 1 .95 1.63v.48a1.9 1.9 0 0 1-.95 1.66l-.14.08a1.9 1.9 0 0 0-.7 2.6l.22.37a1.9 1.9 0 0 0 2.6.7l.14-.08a1.9 1.9 0 0 1 1.9 0l.41.24a1.9 1.9 0 0 1 .95 1.64v.17a1.9 1.9 0 0 0 1.9 1.9h.44a1.9 1.9 0 0 0 1.9-1.9v-.17a1.9 1.9 0 0 1 .95-1.64l.41-.24a1.9 1.9 0 0 1 1.9 0l.14.08a1.9 1.9 0 0 0 2.6-.7l.22-.38a1.9 1.9 0 0 0-.7-2.6l-.14-.07a1.9 1.9 0 0 1-.95-1.66v-.47a1.9 1.9 0 0 1 .95-1.66l.14-.08a1.9 1.9 0 0 0 .7-2.6l-.22-.37a1.9 1.9 0 0 0-2.6-.7l-.14.08a1.9 1.9 0 0 1-1.9 0l-.41-.24a1.9 1.9 0 0 1-.95-1.64v-.17a1.9 1.9 0 0 0-1.9-1.9z"></path><circle cx="12" cy="12" r="3"></circle>',
    "headphones": '<path d="M3.5 14.5h2.75a1.75 1.75 0 0 1 1.75 1.75v2.5a1.75 1.75 0 0 1-1.75 1.75H5.25A1.75 1.75 0 0 1 3.5 18.75V12a8.5 8.5 0 0 1 17 0v6.75a1.75 1.75 0 0 1-1.75 1.75h-1a1.75 1.75 0 0 1-1.75-1.75v-2.5a1.75 1.75 0 0 1 1.75-1.75h2.75"></path>',
    "speaker_wave_2": '<path d="M3.75 9.5h3.5L12 5.25v13.5L7.25 14.5h-3.5z"></path><path d="M15.5 9a4.25 4.25 0 0 1 0 6"></path><path d="M18.25 6.25a8 8 0 0 1 0 11.5"></path>',
    "lock_fill": '<rect x="5" y="10.25" width="14" height="10.25" rx="2.5" fill="currentColor"></rect><path d="M8.25 10.25V7.75a3.75 3.75 0 0 1 7.5 0v2.5"></path>',
    "location": '<path d="M12 21s-6.75-5.9-6.75-11.25a6.75 6.75 0 0 1 13.5 0C18.75 15.1 12 21 12 21z"></path><circle cx="12" cy="9.75" r="2.5"></circle>',
    "bell": '<path d="M6.25 16.75V11a5.75 5.75 0 0 1 11.5 0v5.75l1.5 1.75H4.75z"></path><path d="M10 21a2.1 2.1 0 0 0 4 0"></path>',
    "info_circle": '<circle cx="12" cy="12" r="8.75"></circle><path d="M12 11v5.25"></path><circle cx="12" cy="7.9" r="0.6" fill="currentColor"></circle>',
    "map": '<path d="M9 4.75L3.75 6.75v12.5L9 17.25l6 2 5.25-2V4.75L15 6.75z"></path><path d="M9 4.75v12.5M15 6.75v12.5"></path>',
    "expand": '<path d="M14 4.75h5.25V10M19.25 4.75L13.5 10.5M10 19.25H4.75V14M4.75 19.25l5.75-5.75"></path>',
    "person": '<circle cx="12" cy="8" r="3.75"></circle><path d="M4.75 20a7.25 7.25 0 0 1 14.5 0"></path>',
}

def icon(name, size=24, color="currentColor", sw=1.75, extra=""):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" '
            f'style="flex: none; display: block;{extra}">{ICONS[name]}</svg>')

def check_circle_fill(size=20, color=ACC):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" aria-hidden="true" style="flex: none; display: block">'
            f'<circle cx="12" cy="12" r="10" fill="{color}"></circle>'
            f'<path d="M7.5 12.25l3 3 6-6.25" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path></svg>')

# ---------- shared JS ----------
JS_COMMON = """
    const POLY = %s;
    const ST = %s;
    const IDX = [0, 13, 48, 65, 71, 76, 94, 150, 161, 178, 220];
    const pts = (a) => a.map((p) => p[0].toFixed(1) + ',' + p[1].toFixed(1)).join(' ');
    const plaque = (label, sx, sy, kind) => {
      let size = 28;
      let skin = 'background: #FFFFFF; color: #1D6B5B; box-shadow: inset 0 0 0 2px #1D6B5B, 0 1px 2px rgba(0,0,0,0.12), 0 2px 6px rgba(0,0,0,0.08);';
      let fs = 12;
      if (kind === 'next') {
        size = 34; fs = 13;
        skin = 'background: #1D6B5B; color: #FFFFFF; box-shadow: 0 0 0 3px #FFFFFF, 0 1px 3px rgba(0,0,0,0.20), 0 3px 10px rgba(0,0,0,0.10);';
      } else if (kind === 'start') {
        size = 28; fs = 12;
        skin = 'background: #1D6B5B; color: #FFFFFF; box-shadow: 0 0 0 2.5px #FFFFFF, 0 1px 3px rgba(0,0,0,0.20), 0 2px 8px rgba(0,0,0,0.10);';
      } else if (kind === 'small') {
        size = 24; fs = 12;
      }
      return {
        n: label,
        style: 'position: absolute; left: ' + (sx - size / 2).toFixed(1) + 'px; top: ' + (sy - size / 2).toFixed(1) +
          'px; width: ' + size + 'px; height: ' + size + 'px; border-radius: 50%%; display: flex; align-items: center; justify-content: center; font-size: ' +
          fs + 'px; line-height: 16px; font-weight: 700; font-variant-numeric: tabular-nums; ' + skin
      };
    };
""" % (POLY_JS, STOPS_JS)


def page(title, h, body, js, chinese=False, lang="en"):
    font_link = ("\n" + NOTO) if chinese else ""
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
a{{color:#1D6B5B}}a:hover{{color:#155446}}
</style>{font_link}
</helmet>
<div style="width: 390px; height: {h}px; position: relative; overflow: hidden; background: {CANVAS_BG}; font-family: {FONT}; color: {T1}; -webkit-font-smoothing: antialiased">
{body}
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":390,"height":{h}}}}}'>
class Component extends DCLogic {{
  renderVals() {{{js}
  }}
}}
</script>
</body>
</html>
"""


def write(name, html):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write(html)
    print("wrote", name, len(html))


def map_block(w, h, extra_layers="", overlays="", radius="", bg="#EEEEEA"):
    """Brief-mandated map structure. Route SVG content is injected via extra_layers."""
    rad = f" border-radius: {radius};" if radius else ""
    return f"""<div style="position: absolute; left: 0; top: 0; width: {w}px; height: {h}px; overflow: hidden; background: {bg};{rad}">
    <div style="position: absolute; left: 0; top: 0; width: 1000px; height: 1289px; transform-origin: 0 0; transform: {{{{mapTransform}}}}">
      <img src="{LIGHT_MAP}" alt="" style="position: absolute; left: 0; top: 0; width: 1000px; height: 1289px">
      <svg viewBox="0 0 1000 1289" width="1000" height="1289" style="position: absolute; left: 0; top: 0" aria-hidden="true">
{extra_layers}
      </svg>
    </div>
{overlays}
  </div>"""


def dots(step):
    out = []
    for i in range(1, 4):
        if i == step:
            out.append(f'<span style="width: 18px; height: 6px; border-radius: 3px; background: {ACC}"></span>')
        else:
            out.append('<span style="width: 6px; height: 6px; border-radius: 3px; background: rgba(107,113,118,0.38)"></span>')
    return (f'<div role="img" aria-label="Step {step} of 3" style="display: flex; justify-content: center; align-items: center; gap: 6px; height: 16px">'
            + "".join(out) + "</div>")


def skip_row():
    return f"""<div style="height: 48px; display: flex; justify-content: flex-end; padding: 0 4px">
      <button type="button" aria-label="Skip introduction" style="{BTN_RESET} height: 48px; padding: 0 16px; font-size: 16px; line-height: 24px; font-weight: 500; color: {T2}">Skip</button>
    </div>"""


# =====================================================================
# Onboarding 1
# =====================================================================
def onboarding1():
    layers = """        <polyline points="{{route}}" fill="none" stroke="#FFFFFF" stroke-width="{{casingW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
        <polyline points="{{route}}" fill="none" stroke="#1D6B5B" stroke-width="{{routeW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>"""
    overlays = f"""    <sc-for list="{{{{plaques}}}}" as="p" hint-placeholder-count="3">
      <div style="{{{{p.style}}}}">{{{{p.n}}}}</div>
    </sc-for>
    <div style="position: absolute; left: {{{{phoneLeft}}}}px; top: {{{{phoneTop}}}}px; width: 48px; height: 48px; border-radius: 50%; background: #FFFFFF; color: {T1}; display: flex; align-items: center; justify-content: center; box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 4px 14px rgba(0,0,0,0.10)">
      {icon("headphones", 32, sw=1.6)}
    </div>"""
    m = map_block(200, 240, layers, overlays, radius="20px")
    body = f"""  <div style="position: absolute; left: 0; top: 0; right: 0; bottom: 0; display: flex; flex-direction: column; padding: 44px 0 24px; box-sizing: border-box">
    {skip_row()}
    <div style="display: flex; justify-content: center; margin-top: 20px">
      <div role="img" aria-label="The Royal Route on a map of Kraków, from the Barbican to Wawel Hill" style="position: relative; width: 200px; height: 240px; border-radius: 20px; overflow: hidden; box-shadow: inset 0 0 0 1px rgba(22,24,26,0.06)">
  {m}
      </div>
    </div>
    <div style="display: flex; flex-direction: column; align-items: center; text-align: center; gap: 12px; padding: 40px 28px 0">
      <h1 style="margin: 0; font-size: 28px; line-height: 34px; font-weight: 700; letter-spacing: -0.2px; color: {T1}">Your guide fits in your pocket</h1>
      <p style="margin: 0; font-size: 16px; line-height: 24px; color: {T2}">Put your headphones in, lock your phone and walk. The Historian leads you through Kraków and tells you about each place as you reach it.</p>
    </div>
    <div style="flex: 1"></div>
    <div style="display: flex; flex-direction: column; gap: 24px; padding: 0 16px">
      {dots(1)}
      <button type="button" style="{PRIMARY}">Continue</button>
    </div>
  </div>"""
    js = JS_COMMON + """
    const S = 0.2, TX = 0, TY = -10.2;
    const sc = (i) => [ST[i][0] * S + TX, ST[i][1] * S + TY];
    const a = sc(0), b = sc(4), c = sc(10);
    return {
      mapTransform: 'translate(' + TX + 'px, ' + TY + 'px) scale(' + S + ')',
      route: pts(POLY),
      casingW: (9 / S).toFixed(1),
      routeW: (5 / S).toFixed(1),
      plaques: [plaque('1', a[0], a[1], 'start'), plaque('5', b[0], b[1], 'up'), plaque('11', c[0], c[1], 'up')],
      phoneLeft: (a[0] - 66).toFixed(1),
      phoneTop: (a[1] - 14).toFixed(1)
    };"""
    write("Onboarding1.dc.html", page("Onboarding 1/3", 844, body, js))


# =====================================================================
# Onboarding 2
# =====================================================================
def radio_visual(checked):
    if checked:
        return f'<span aria-hidden="true" style="flex: none; width: 20px; height: 20px; border-radius: 50%; background: {ACC}; display: flex; align-items: center; justify-content: center; margin-top: 2px"><span style="width: 8px; height: 8px; border-radius: 50%; background: #FFFFFF"></span></span>'
    return f'<span aria-hidden="true" style="flex: none; width: 20px; height: 20px; border-radius: 50%; box-sizing: border-box; border: 1.5px solid {T3}; margin-top: 2px"></span>'


def onboarding2():
    row_divider = f'<div style="height: 1px; background: {DIV}; margin-left: 16px"></div>'
    body = f"""  <div style="position: absolute; left: 0; top: 0; right: 0; bottom: 0; display: flex; flex-direction: column; padding: 44px 0 24px; box-sizing: border-box">
    {skip_row()}
    <div style="display: flex; flex-direction: column; gap: 8px; padding: 16px 16px 0">
      <h1 style="margin: 0; font-size: 28px; line-height: 34px; font-weight: 700; letter-spacing: -0.2px">How should the guide speak?</h1>
      <p style="margin: 0; font-size: 16px; line-height: 24px; color: {T2}">You can change this any time.</p>
    </div>
    <div role="radiogroup" aria-label="Narration language" style="margin: 28px 16px 0; background: {SURFACE}; border-radius: 20px; overflow: hidden">
      <label style="position: relative; display: flex; align-items: flex-start; gap: 12px; padding: 14px 16px 16px; cursor: pointer">
        <input type="radio" name="voice" value="en" checked="checked" style="{HIDDEN_INPUT}">
        <span style="flex: 1; display: flex; flex-direction: column; min-width: 0">
          <span style="font-size: 16px; line-height: 24px; font-weight: 500; color: {T1}">English</span>
          <span style="display: flex; align-items: center; gap: 8px; margin-top: 2px">
            <span style="font-size: 14px; line-height: 20px; color: {T2}">Spoken · Laura voice</span>
            <span style="display: inline-flex; align-items: center; height: 22px; padding: 0 8px; border-radius: 8px; background: {SUBTLE}; color: {ACC}; font-size: 12px; line-height: 16px; font-weight: 500">Downloading</span>
          </span>
          <span style="display: flex; align-items: center; gap: 10px; margin-top: 10px">
            <span role="progressbar" aria-label="Downloading English voice" aria-valuenow="40" aria-valuemin="0" aria-valuemax="100" style="flex: 1; height: 4px; border-radius: 2px; background: {DIV}; overflow: hidden"><span style="display: block; width: 40%; height: 4px; border-radius: 2px; background: {ACC}"></span></span>
            <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {T2}; {TAB}">40%</span>
          </span>
        </span>
        {radio_visual(True)}
      </label>
      {row_divider}
      <label style="position: relative; display: flex; align-items: flex-start; gap: 12px; padding: 14px 16px; cursor: pointer">
        <input type="radio" name="voice" value="zh" style="{HIDDEN_INPUT}">
        <span style="flex: 1; display: flex; flex-direction: column; min-width: 0">
          <span lang="zh" style="font-size: 16px; line-height: 24px; font-weight: 500; color: {T1}">中文</span>
          <span style="font-size: 14px; line-height: 20px; color: {T2}; margin-top: 2px">Spoken · <span lang="zh">聆小珊</span></span>
        </span>
        {radio_visual(False)}
      </label>
      {row_divider}
      <label style="position: relative; display: flex; align-items: flex-start; gap: 12px; padding: 14px 16px; cursor: pointer">
        <input type="radio" name="voice" value="pl" style="{HIDDEN_INPUT}">
        <span style="flex: 1; display: flex; flex-direction: column; min-width: 0">
          <span lang="pl" style="font-size: 16px; line-height: 24px; font-weight: 500; color: {T1}">Polski</span>
          <span style="display: flex; align-items: center; gap: 6px; font-size: 14px; line-height: 20px; color: {T2}; margin-top: 2px">Text only {icon("info_circle", 16, T2, 1.75)}</span>
        </span>
        {radio_visual(False)}
      </label>
    </div>
    <p style="display: flex; gap: 8px; margin: 12px 16px 0; padding: 0 4px; font-size: 13px; line-height: 18px; color: {T2}">{icon("info_circle", 16, T2, 1.75, " margin-top: 1px;")}<span>Polish stories are shown as text. On-device speech currently speaks English and Chinese.</span></p>
    <div style="display: flex; padding: 24px 16px 0">
      <button type="button" style="{BTN_RESET} display: inline-flex; align-items: center; gap: 8px; height: 48px; padding: 0 20px 0 16px; border-radius: 24px; background: rgba(22,24,26,0.055); color: {ACC}; font-size: 16px; line-height: 24px; font-weight: 500">{icon("speaker_wave_2", 20)}Play a sample</button>
    </div>
    <div style="flex: 1"></div>
    <div style="display: flex; flex-direction: column; gap: 24px; padding: 0 16px">
      {dots(2)}
      <button type="button" style="{PRIMARY}">Continue</button>
    </div>
  </div>"""
    write("Onboarding2.dc.html", page("Onboarding 2/3", 844, body, "\n    return {};", chinese=True))


# =====================================================================
# Onboarding 3
# =====================================================================
def onboarding3():
    body = f"""  <div style="position: absolute; left: 0; top: 0; right: 0; bottom: 0; display: flex; flex-direction: column; padding: 44px 0 24px; box-sizing: border-box">
    {skip_row()}
    <div style="padding: 16px 16px 0">
      <h1 style="margin: 0; font-size: 28px; line-height: 34px; font-weight: 700; letter-spacing: -0.2px">Two permissions, and why</h1>
    </div>
    <div style="margin: 28px 16px 0; background: {SURFACE}; border-radius: 20px; overflow: hidden">
      <div role="group" aria-label="Location. Finds the next stop and knows when you've arrived. Used only while a tour is running. Allowed." style="display: flex; align-items: flex-start; gap: 14px; padding: 16px">
        <span style="color: {ACC}; padding-top: 2px">{icon("location", 32, sw=1.6)}</span>
        <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">
          <span style="font-size: 16px; line-height: 24px; font-weight: 500">Location</span>
          <span style="font-size: 14px; line-height: 20px; color: {T2}">Finds the next stop and knows when you've arrived. Used only while a tour is running.</span>
        </div>
        <span style="flex: none; display: flex; align-items: center; gap: 6px; height: 28px; color: {ACC}; font-size: 14px; line-height: 20px; font-weight: 500">{check_circle_fill(20)}Allowed</span>
      </div>
      <div style="height: 1px; background: {DIV}; margin-left: 62px"></div>
      <div role="group" aria-label="Notifications. Tells you when you arrive if your screen is off." style="display: flex; align-items: flex-start; gap: 14px; padding: 16px">
        <span style="color: {ACC}; padding-top: 2px">{icon("bell", 32, sw=1.6)}</span>
        <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">
          <span style="font-size: 16px; line-height: 24px; font-weight: 500">Notifications</span>
          <span style="font-size: 14px; line-height: 20px; color: {T2}">Tells you when you arrive if your screen is off.</span>
        </div>
        <button type="button" aria-label="Allow notifications" style="{BTN_RESET} flex: none; height: 48px; margin: -10px -8px -10px 0; padding: 0 8px; display: flex; align-items: center">
          <span style="display: flex; align-items: center; height: 32px; padding: 0 16px; border-radius: 16px; background: rgba(22,24,26,0.055); color: {ACC}; font-size: 14px; line-height: 20px; font-weight: 500">Allow</span>
        </button>
      </div>
    </div>
    <p style="margin: 12px 20px 0; font-size: 13px; line-height: 18px; color: {T2}">Location is used only while a tour is running. Nothing leaves your phone.</p>
    <div style="flex: 1"></div>
    <div style="display: flex; flex-direction: column; gap: 8px; padding: 0 16px">
      {dots(3)}
      <div style="height: 16px"></div>
      <button type="button" style="{PRIMARY}">Done</button>
      <button type="button" style="{BTN_RESET} height: 48px; border-radius: 24px; color: {ACC}; font-size: 16px; line-height: 24px; font-weight: 500">Set up later</button>
    </div>
  </div>"""
    write("Onboarding3.dc.html", page("Onboarding 3/3", 844, body, "\n    return {};"))


# =====================================================================
# Home
# =====================================================================
def home():
    layers = """        <polyline points="{{route}}" fill="none" stroke="#FFFFFF" stroke-width="{{casingW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
        <polyline points="{{route}}" fill="none" stroke="#1D6B5B" stroke-width="{{routeW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>"""
    overlays = """    <sc-for list="{{stopDots}}" as="d" hint-placeholder-count="6">
      <div style="{{d.style}}"></div>
    </sc-for>
    <sc-for list="{{plaques}}" as="p" hint-placeholder-count="1">
      <div style="{{p.style}}">{{p.n}}</div>
    </sc-for>"""
    m = map_block(358, 201, layers, overlays)
    chip = f"display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 10px; box-sizing: border-box; border: 1px solid {DIV}; border-radius: 8px; font-size: 12px; line-height: 16px; font-weight: 500; color: {T2}"
    body = f"""  <div style="position: absolute; left: 0; top: 0; right: 0; bottom: 0; display: flex; flex-direction: column; padding: 44px 16px 24px; box-sizing: border-box">
    <header style="display: flex; flex-direction: column">
      <div style="display: flex; align-items: center; justify-content: space-between; height: 56px">
        <h1 style="margin: 0; font-size: 28px; line-height: 34px; font-weight: 700; letter-spacing: -0.2px">CityTour</h1>
        <button type="button" aria-label="Settings" style="{BTN_RESET} width: 48px; height: 48px; margin-right: -4px; display: flex; align-items: center; justify-content: center; color: {T1}">
          <span style="width: 40px; height: 40px; border-radius: 50%; background: rgba(22,24,26,0.055); display: flex; align-items: center; justify-content: center">{icon("gearshape", 22, sw=1.6)}</span>
        </button>
      </div>
      <p style="display: flex; align-items: center; gap: 4px; margin: 0; font-size: 14px; line-height: 20px; color: {T2}">Kraków · offline ready {icon("checkmark", 16, T2, 2)}</p>
    </header>

    <section aria-label="Now walking" style="margin-top: 20px; background: {SURFACE}; border-radius: 20px; padding: 16px 16px 8px">
      <div style="display: flex; align-items: center; justify-content: space-between">
        <span style="{OVERLINE}">Now walking</span>
        <span style="display: flex; align-items: center; gap: 6px; font-size: 12px; line-height: 16px; font-weight: 500; color: {T2}"><span style="width: 8px; height: 8px; border-radius: 50%; background: {ACC}; box-shadow: 0 0 0 3px rgba(29,107,91,0.18)"></span>Live</span>
      </div>
      <h2 style="margin: 8px 0 0; font-size: 18px; line-height: 24px; font-weight: 500">The Royal Route</h2>
      <p style="margin: 2px 0 0; font-size: 14px; line-height: 20px; color: {T2}; {TAB}">Stop 4 of 11 · Cloth Hall</p>
      <div role="progressbar" aria-label="Tour progress, stop 4 of 11" aria-valuenow="4" aria-valuemin="0" aria-valuemax="11" style="margin-top: 14px; height: 4px; border-radius: 2px; background: {DIV}; overflow: hidden"><div style="width: 36.4%; height: 4px; border-radius: 2px; background: {ACC}"></div></div>
      <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 8px">
        <button type="button" aria-label="Open Now Walking" style="{BTN_RESET} height: 48px; display: flex; align-items: center">
          <span style="display: flex; align-items: center; height: 36px; padding: 0 22px; border-radius: 18px; background: {SUBTLE}; color: {ACC}; font-size: 14px; line-height: 20px; font-weight: 500">Open</span>
        </button>
        <button type="button" style="{BTN_RESET} height: 48px; padding: 0 4px 0 16px; color: {ERR}; font-size: 14px; line-height: 20px; font-weight: 500">End tour</button>
      </div>
    </section>

    <h2 style="{OVERLINE} margin: 28px 0 8px 4px">Guided tours</h2>
    <a href="#tour-detail" aria-label="The Royal Route. From the Barbican to Wawel Hill. 11 stops, 2.5 kilometres, about 1 hour 25 minutes. Guide: The Historian." style="display: block; text-decoration: none; color: {T1}; background: {SURFACE}; border-radius: 20px; overflow: hidden">
      <div style="position: relative; width: 358px; height: 201px">
  {m}
      </div>
      <div style="display: flex; flex-direction: column; padding: 14px 16px 16px">
        <span style="font-size: 18px; line-height: 24px; font-weight: 500">The Royal Route</span>
        <span style="margin-top: 2px; font-size: 14px; line-height: 20px; color: {T2}">From the Barbican to Wawel Hill</span>
        <span style="margin-top: 6px; font-size: 13px; line-height: 18px; color: {T2}; {TAB}">11 stops · 2.5 km · ~1 h 25 min</span>
        <span style="display: flex; gap: 8px; margin-top: 12px">
          <span style="{chip}">{icon("person", 14, T2, 2)}The Historian</span>
          <span style="{chip}">EN <span lang="zh">中文</span> PL</span>
        </span>
      </div>
    </a>

    <h2 style="{OVERLINE} margin: 28px 0 8px 4px">Explore</h2>
    <a href="#explore" style="display: flex; align-items: center; gap: 12px; min-height: 64px; padding: 10px 12px 10px 16px; box-sizing: border-box; text-decoration: none; color: {T1}; background: {SURFACE}; border-radius: 20px">
      <span style="flex: none; width: 36px; height: 36px; border-radius: 10px; background: {SUNKEN}; color: {T1}; display: flex; align-items: center; justify-content: center">{icon("map", 22, sw=1.6)}</span>
      <span style="flex: 1; display: flex; flex-direction: column; min-width: 0">
        <span style="font-size: 16px; line-height: 24px; font-weight: 500">All places in Kraków</span>
        <span style="font-size: 14px; line-height: 20px; color: {T2}; {TAB}">Monuments 395 · Plaques 923 · offline</span>
      </span>
      <span style="color: {T3}">{icon("chevron_right", 20, sw=2)}</span>
    </a>
  </div>"""
    js = JS_COMMON + """
    const S = 0.4, TX = -34, TY = -40;
    const stopDots = [];
    for (let i = 1; i < ST.length; i++) {
      const x = ST[i][0] * S + TX, y = ST[i][1] * S + TY;
      if (y > 210) continue;
      stopDots.push({ style: 'position: absolute; left: ' + (x - 5).toFixed(1) + 'px; top: ' + (y - 5).toFixed(1) + 'px; width: 7px; height: 7px; border-radius: 50%; background: #1D6B5B; border: 1.5px solid #FFFFFF; box-shadow: 0 1px 2px rgba(0,0,0,0.18)' });
    }
    return {
      mapTransform: 'translate(' + TX + 'px, ' + TY + 'px) scale(' + S + ')',
      route: pts(POLY),
      casingW: (7 / S).toFixed(1),
      routeW: (4 / S).toFixed(1),
      stopDots: stopDots,
      plaques: [plaque('1', ST[0][0] * S + TX, ST[0][1] * S + TY, 'start')]
    };"""
    write("Home.dc.html", page("Home", 844, body, js, chinese=True))


# =====================================================================
# Tour detail (390 x 1240)
# =====================================================================
STOP_NAMES = ["Barbican", "St Florian's Gate", "St Mary's Basilica", "Cloth Hall", "Adam Mickiewicz Monument",
              "Town Hall Tower", "St Adalbert's Church", "Sts Peter and Paul", "St Andrew's Church",
              "Kanonicza Street", "Wawel Hill"]
STORY_MIN = [3, 2, 4, 5, 5, 6, 5, 5, 5, 6, 6]  # sums to 52 min -> 33 + 52 = 1 h 25 min


def tour_detail():
    layers = """        <polyline points="{{route}}" fill="none" stroke="#FFFFFF" stroke-width="{{casingW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
        <polyline points="{{route}}" fill="none" stroke="#1D6B5B" stroke-width="{{routeW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>"""
    overlays = f"""    <div style="position: absolute; left: {{{{fadeL}}}}px; top: 0; width: 44px; height: 260px; background: linear-gradient(90deg, #EEEEEA 0%, rgba(238,238,234,0) 100%)"></div>
    <div style="position: absolute; left: {{{{fadeR}}}}px; top: 0; width: 44px; height: 260px; background: linear-gradient(270deg, #EEEEEA 0%, rgba(238,238,234,0) 100%)"></div>
    <div style="position: absolute; left: 0; top: {{{{fadeT}}}}px; width: 390px; height: 30px; background: linear-gradient(180deg, #EEEEEA 0%, rgba(238,238,234,0) 100%)"></div>
    <svg width="390" height="260" viewBox="0 0 390 260" style="position: absolute; left: 0; top: 0" aria-hidden="true">
      <path d="{{{{leaders}}}}" fill="none" stroke="{ACC}" stroke-opacity="0.55" stroke-width="1" stroke-linecap="round"></path>
    </svg>
    <sc-for list="{{{{stopDots}}}}" as="d" hint-placeholder-count="11">
      <div style="{{{{d.style}}}}"></div>
    </sc-for>
    <sc-for list="{{{{plaques}}}}" as="p" hint-placeholder-count="11">
      <div style="{{{{p.style}}}}">{{{{p.n}}}}</div>
    </sc-for>"""
    m = map_block(390, 260, layers, overlays)

    rows = []
    for i, (name, mins) in enumerate(zip(STOP_NAMES, STORY_MIN)):
        n = i + 1
        top = "50%" if i == 0 else "0"
        bottom = "50%" if i == len(STOP_NAMES) - 1 else "0"
        rows.append(f"""        <a href="#place-{n}" aria-label="Stop {n}, {name}. Story {mins} minutes." style="display: flex; align-items: center; gap: 14px; height: 48px; padding: 0 12px 0 14px; text-decoration: none; color: {T1}">
          <span style="position: relative; flex: none; width: 28px; height: 48px; display: flex; align-items: center; justify-content: center">
            <span style="position: absolute; left: 13px; width: 2px; top: {top}; bottom: {bottom}; background: {DIV}"></span>
            <span style="position: relative; width: 28px; height: 28px; border-radius: 50%; box-sizing: border-box; border: 2px solid {ACC}; background: {SURFACE}; color: {ACC}; display: flex; align-items: center; justify-content: center; font-size: 12px; line-height: 16px; font-weight: 700; {TAB}">{n}</span>
          </span>
          <span style="flex: 1; min-width: 0; font-size: 16px; line-height: 24px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{name}</span>
          <span style="flex: none; font-size: 13px; line-height: 18px; color: {T2}; {TAB}">{mins} min</span>
          <span style="flex: none; color: {T3}">{icon("chevron_right", 16, sw=2)}</span>
        </a>""")
    stops_html = "\n".join(rows)

    stat_col = lambda v, l, border: f"""<div style="flex: 1; display: flex; flex-direction: column; gap: 2px; padding-left: {'16px' if border else '0'};{(' border-left: 1px solid ' + DIV + ';') if border else ''}">
          <span style="font-size: 18px; line-height: 24px; font-weight: 500; {TAB}">{v}</span>
          <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {T2}">{l}</span>
        </div>"""

    body = f"""  <div role="img" aria-label="Map of the Royal Route with 11 stops" style="position: absolute; left: 0; top: 0; width: 390px; height: 260px">
  {m}
  </div>
  <button type="button" aria-label="Back" style="{BTN_RESET} position: absolute; left: 8px; top: 48px; width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; color: {T1}">
    <span style="width: 40px; height: 40px; border-radius: 50%; {SCRIM} display: flex; align-items: center; justify-content: center">{icon("chevron_backward", 22, sw=2)}</span>
  </button>
  <button type="button" aria-label="Map attribution" style="{BTN_RESET} position: absolute; left: 8px; top: 208px; width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; color: {T2}">
    <span style="width: 28px; height: 28px; border-radius: 50%; {SCRIM} display: flex; align-items: center; justify-content: center">{icon("info_circle", 18, sw=1.75)}</span>
  </button>
  <button type="button" aria-label="Expand map" style="{BTN_RESET} position: absolute; right: 8px; top: 204px; width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; color: {T1}">
    <span style="width: 40px; height: 40px; border-radius: 50%; {SCRIM} display: flex; align-items: center; justify-content: center">{icon("expand", 20, sw=1.9)}</span>
  </button>

  <main style="position: absolute; left: 0; top: 260px; width: 390px; display: flex; flex-direction: column; padding: 18px 16px 0; box-sizing: border-box">
    <h1 style="margin: 0; font-size: 28px; line-height: 34px; font-weight: 700; letter-spacing: -0.2px">The Royal Route</h1>
    <p style="margin: 4px 0 0; font-size: 16px; line-height: 24px; color: {T2}">The kings' coronation path, from the city gate to the castle.</p>

    <div style="display: flex; margin-top: 18px; padding: 0 4px">
      {stat_col("2.5 km", "walk", False)}
      {stat_col("~1 h 25 min", "with stories", True)}
      {stat_col("11", "stops", True)}
    </div>

    <div role="group" aria-label="Guide: The Historian. English, Laura voice." style="display: flex; align-items: center; gap: 12px; margin-top: 18px; height: 60px; padding: 0 16px; background: {SURFACE}; border-radius: 20px">
      <span style="flex: none; width: 36px; height: 36px; border-radius: 50%; background: {SUBTLE}; color: {ACC}; display: flex; align-items: center; justify-content: center; font-size: 15px; line-height: 20px; font-weight: 700">H</span>
      <span style="flex: 1; display: flex; flex-direction: column; min-width: 0">
        <span style="font-size: 16px; line-height: 22px; font-weight: 500">The Historian</span>
        <span style="font-size: 13px; line-height: 18px; color: {T2}">Your guide · English · Laura voice</span>
      </span>
    </div>

    <h2 style="{OVERLINE} margin: 22px 0 8px 4px">Stops</h2>
    <div style="background: {SURFACE}; border-radius: 20px; overflow: hidden">
{stops_html}
    </div>

    <h2 style="{OVERLINE} margin: 20px 0 6px 4px">About these stories</h2>
    <p style="margin: 0 4px; font-size: 14px; line-height: 20px; color: {T2}">Drafted with AI, reviewed by a person. 23 sources cited. <a href="#sources" style="color: {ACC}; font-weight: 500; text-decoration: none; white-space: nowrap">See sources ›</a></p>
  </main>

  <div style="position: absolute; left: 0; bottom: 0; width: 390px; padding: 12px 16px 24px; box-sizing: border-box; background: {SURFACE}; border-top: 1px solid {DIV}">
    <button type="button" style="{PRIMARY}">Start tour</button>
  </div>"""

    js = JS_COMMON + """
    const S = 0.2, TX = 88.2, TY = 19.8;
    const COLS = { 1: [268, 58], 2: [268, 86], 3: [268, 114], 5: [268, 142], 7: [268, 170], 8: [268, 198], 9: [268, 226],
                   4: [122, 100], 6: [122, 128], 10: [122, 212], 11: [122, 240] };
    const plaques = [], stopDots = [];
    let leaders = '';
    for (let i = 0; i < ST.length; i++) {
      const n = i + 1;
      const sx = ST[i][0] * S + TX, sy = ST[i][1] * S + TY;
      const c = COLS[n];
      const dx = c[0] - sx, dy = c[1] - sy, len = Math.sqrt(dx * dx + dy * dy);
      const ex = c[0] - dx / len * 12, ey = c[1] - dy / len * 12;
      leaders += 'M' + sx.toFixed(1) + ' ' + sy.toFixed(1) + 'L' + ex.toFixed(1) + ' ' + ey.toFixed(1);
      stopDots.push({ style: 'position: absolute; left: ' + (sx - 4).toFixed(1) + 'px; top: ' + (sy - 4).toFixed(1) + 'px; width: 5px; height: 5px; border-radius: 50%; background: #1D6B5B; border: 1.5px solid #FFFFFF' });
      plaques.push(plaque(String(n), c[0], c[1], 'small'));
    }
    return {
      mapTransform: 'translate(' + TX + 'px, ' + TY + 'px) scale(' + S + ')',
      route: pts(POLY),
      casingW: (8 / S).toFixed(1),
      routeW: (4.5 / S).toFixed(1),
      fadeL: TX.toFixed(1),
      fadeR: (TX + 1000 * S - 44).toFixed(1),
      fadeT: TY.toFixed(1),
      leaders: leaders,
      stopDots: stopDots,
      plaques: plaques
    };"""
    write("TourDetail.dc.html", page("Tour detail", 1240, body, js))


# =====================================================================
# Route ready + Before you go (shared)
# =====================================================================
ROUTE_JS = JS_COMMON + """
    const S = 0.6, TX = -130.2, TY = -13.2;
    const USER = [424, 412];
    const seg = (a, b) => { const out = []; if (a <= b) { for (let k = a; k <= b; k++) out.push(POLY[k]); } else { for (let k = a; k >= b; k--) out.push(POLY[k]); } return out; };
    // Optimised order from here: Cloth Hall, Mickiewicz, St Mary's, St Florian's Gate, Barbican, Town Hall Tower, then south to Wawel.
    const ORDER = [3, 4, 2, 1, 0, 5, 6, 7, 8, 9, 10];
    const path = [].concat(
      seg(65, 71),
      seg(58, 48),
      seg(47, 0),
      seg(1, 52),
      [[517.4, 533.4]], seg(73, 76),
      seg(77, 220)
    );
    const plaques = [];
    for (let k = ORDER.length - 1; k >= 0; k--) {
      const s = ST[ORDER[k]];
      plaques.push(plaque(String(k + 1), s[0] * S + TX, s[1] * S + TY, k === 0 ? 'next' : 'up'));
    }
    const ux = USER[0] * S + TX, uy = USER[1] * S + TY;
    const target = POLY[65];
    const heading = Math.atan2(target[0] - USER[0], -(target[1] - USER[1])) * 180 / Math.PI;
    return {
      mapTransform: 'translate(' + TX + 'px, ' + TY + 'px) scale(' + S + ')',
      route: pts(path),
      approach: pts([USER, [440, 452], target]),
      casingW: (9 / S).toFixed(1),
      routeW: (5 / S).toFixed(1),
      dotW: (4 / S).toFixed(1),
      dotDash: '0.01 ' + (9 / S).toFixed(1),
      plaques: plaques,
      userLeft: (ux - 10).toFixed(1),
      userTop: (uy - 10).toFixed(1),
      coneLeft: (ux - 40).toFixed(1),
      coneTop: (uy - 40).toFixed(1),
      coneRot: heading.toFixed(1)
    };"""


def route_map_and_panel(cone_id):
    layers = """        <polyline points="{{route}}" fill="none" stroke="#FFFFFF" stroke-width="{{casingW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
        <polyline points="{{route}}" fill="none" stroke="#1D6B5B" stroke-width="{{routeW}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
        <polyline points="{{approach}}" fill="none" stroke="#1D6B5B" stroke-width="{{dotW}}" stroke-dasharray="{{dotDash}}" stroke-linecap="round" stroke-linejoin="round"></polyline>"""
    overlays = f"""    <svg width="80" height="80" viewBox="0 0 80 80" style="position: absolute; left: {{{{coneLeft}}}}px; top: {{{{coneTop}}}}px; transform: rotate({{{{coneRot}}}}deg); transform-origin: 40px 40px" aria-hidden="true">
      <defs>
        <radialGradient id="{cone_id}" cx="40" cy="40" r="40" gradientUnits="userSpaceOnUse">
          <stop offset="0" stop-color="{USER}" stop-opacity="0.30"></stop>
          <stop offset="1" stop-color="{USER}" stop-opacity="0"></stop>
        </radialGradient>
      </defs>
      <path d="M40 40L20 5.36A40 40 0 0 1 60 5.36Z" fill="url(#{cone_id})"></path>
    </svg>
    <sc-for list="{{{{plaques}}}}" as="p" hint-placeholder-count="11">
      <div style="{{{{p.style}}}}">{{{{p.n}}}}</div>
    </sc-for>
    <div role="img" aria-label="Your location" style="position: absolute; left: {{{{userLeft}}}}px; top: {{{{userTop}}}}px; width: 14px; height: 14px; border-radius: 50%; background: {USER}; border: 3px solid #FFFFFF; box-shadow: 0 1px 3px rgba(0,0,0,0.25), 0 2px 8px rgba(0,0,0,0.12)"></div>"""
    m = map_block(390, 380, layers, overlays)

    def seg_control(name, label, items, selected):
        parts = []
        for i, it in enumerate(items):
            on = i == selected
            pill = (f"background: {ACC}; color: #FFFFFF;" if on else f"background: transparent; color: {T2};")
            checked = ' checked="checked"' if on else ""
            parts.append(f"""<label style="position: relative; flex: 1; height: 48px; display: flex; align-items: center; cursor: pointer">
            <input type="radio" name="{name}"{checked} style="{HIDDEN_INPUT}">
            <span style="flex: 1; height: 40px; border-radius: 20px; display: flex; align-items: center; justify-content: center; font-size: 14px; line-height: 20px; font-weight: 500; {TAB} {pill}">{it}</span>
          </label>""")
        return f"""<div role="radiogroup" aria-label="{label}" style="display: flex; height: 48px; padding: 0 4px; border-radius: 24px; background: {SUNKEN}; margin-top: 8px">
          {''.join(parts)}
        </div>"""

    return f"""  {m}
  <div style="position: absolute; left: 12px; top: 50px; height: 48px; display: flex; align-items: center; border-radius: 24px; {SCRIM}">
    <button type="button" aria-label="Back" style="{BTN_RESET} width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; color: {T1}">{icon("chevron_backward", 22, sw=2)}</button>
    <h1 style="margin: 0 20px 0 0; font-size: 17px; line-height: 22px; font-weight: 500">Your route</h1>
  </div>
  <div style="position: absolute; left: 12px; top: 108px; display: flex; align-items: center; gap: 6px; height: 28px; padding: 0 12px 0 10px; border-radius: 14px; {SCRIM} font-size: 12px; line-height: 16px; font-weight: 500; color: {T1}"><span style="width: 8px; height: 8px; border-radius: 50%; background: {USER}; box-shadow: 0 0 0 2px #FFFFFF"></span>Numbered in walking order from you</div>
  <button type="button" aria-label="Map attribution" style="{BTN_RESET} position: absolute; right: 6px; top: 300px; width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; color: {T2}">
    <span style="width: 28px; height: 28px; border-radius: 50%; {SCRIM} display: flex; align-items: center; justify-content: center">{icon("info_circle", 18)}</span>
  </button>

  <section style="position: absolute; left: 0; top: 352px; width: 390px; height: 492px; background: {SURFACE}; border-radius: 28px 28px 0 0; box-shadow: 0 -1px 0 rgba(22,24,26,0.04), 0 -6px 24px rgba(0,0,0,0.08); display: flex; flex-direction: column; padding: 24px 16px 24px; box-sizing: border-box">
    <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 8px">
      <div style="display: flex; flex-direction: column; gap: 4px">
        <span style="{OVERLINE}">Starting near you</span>
        <h2 style="margin: 0; font-size: 22px; line-height: 28px; font-weight: 700; {TAB}">Cloth Hall, 120 m away</h2>
      </div>
      <button type="button" aria-expanded="false" style="{BTN_RESET} flex: none; height: 48px; margin: -2px -8px 0 0; padding: 0 8px; display: flex; align-items: center; gap: 2px; color: {ACC}; font-size: 14px; line-height: 20px; font-weight: 500">Show order {icon("chevron_down", 18, sw=2)}</button>
    </div>
    <p style="margin: 8px 0 0; font-size: 16px; line-height: 24px; color: {T1}; {TAB}">2.5 km · 33 min walking<br><span style="color: {T2}">~1 h 25 min with stories</span></p>
    <p style="display: flex; align-items: flex-start; gap: 8px; margin: 10px 0 0; font-size: 14px; line-height: 20px; color: {T1}; {TAB}">{check_circle_fill(20)}<span>Optimised order: 640 m shorter than the listed order</span></p>

    <span style="{OVERLINE} margin-top: 22px">Start from</span>
    {seg_control("startFrom", "Start from", ["My location", "First stop"], 0)}

    <span style="{OVERLINE} margin-top: 18px">Time available</span>
    {seg_control("timeAvailable", "Time available", ["All stops", "45 min", "90 min"], 0)}
    <p style="margin: 8px 0 0 4px; font-size: 13px; line-height: 18px; color: {T2}; {TAB}">All 11 stops, renumbered in walking order from you.</p>

    <div style="flex: 1"></div>
    <button type="button" style="{PRIMARY}">Begin</button>
  </section>"""


def route_ready():
    write("RouteReady.dc.html", page("Route ready", 844, route_map_and_panel("coneRR"), ROUTE_JS))


def before_you_go():
    def step(n, title, sub, ic, extra="", first=False, last=False):
        top = "20px" if first else "0"
        bottom = "auto; height: 20px" if last else "0"
        line = "" if (first and last) else f'<span style="position: absolute; left: 13px; width: 2px; top: {top}; bottom: {"0" if not last else "auto"};{" height: 20px;" if last else ""} background: {DIV}"></span>'
        sub_html = f'<span style="font-size: 14px; line-height: 20px; color: {T2}">{sub}</span>' if sub else ""
        return f"""      <li style="display: flex; gap: 14px; padding: 0 0 {'0' if last else '20px'}; position: relative">
        <span style="position: relative; flex: none; width: 28px; display: flex; justify-content: center">
          {line}
          <span style="position: relative; width: 28px; height: 28px; border-radius: 50%; box-sizing: border-box; border: 1.5px solid {T3}; background: {SURFACE}; color: {T1}; display: flex; align-items: center; justify-content: center; font-size: 13px; line-height: 16px; font-weight: 700; {TAB}">{n}</span>
        </span>
        <span style="flex: 1; display: flex; flex-direction: column; gap: 2px; padding-top: 2px; min-width: 0">
          <span style="font-size: 16px; line-height: 24px; font-weight: 500">{title}</span>
          {sub_html}{extra}
        </span>
        <span style="flex: none; color: {T2}; padding-top: 2px">{icon(ic, 24, sw=1.6)}</span>
      </li>"""

    test_btn = f"""
          <button type="button" style="{BTN_RESET} align-self: flex-start; display: inline-flex; align-items: center; gap: 8px; height: 40px; margin-top: 8px; padding: 0 18px 0 14px; border-radius: 20px; background: rgba(22,24,26,0.055); color: {ACC}; font-size: 14px; line-height: 20px; font-weight: 500; box-shadow: 0 0 0 4px transparent">{icon("speaker_wave_2", 18)}Play a test line</button>"""

    sheet = f"""  <div aria-hidden="true" style="position: absolute; left: 0; top: 0; width: 390px; height: 844px; background: rgba(15,17,18,0.34)"></div>
  <section role="dialog" aria-modal="true" aria-labelledby="byg-title" style="position: absolute; left: 0; bottom: 0; width: 390px; background: {SURFACE}; border-radius: 28px 28px 0 0; box-shadow: 0 -8px 32px rgba(0,0,0,0.14); display: flex; flex-direction: column; padding: 0 16px 24px; box-sizing: border-box">
    <div style="display: flex; justify-content: center; padding: 8px 0 4px">
      <span aria-hidden="true" style="width: 36px; height: 4px; border-radius: 2px; background: rgba(22,24,26,0.18)"></span>
    </div>
    <div style="display: flex; align-items: center; justify-content: space-between; height: 56px; margin-bottom: 8px">
      <h2 id="byg-title" style="margin: 0; padding-left: 4px; font-size: 20px; line-height: 26px; font-weight: 700">Before you go</h2>
      <button type="button" aria-label="Close" style="{BTN_RESET} width: 48px; height: 48px; margin-right: -4px; display: flex; align-items: center; justify-content: center; color: {T1}">
        <span style="width: 36px; height: 36px; border-radius: 50%; background: rgba(22,24,26,0.055); display: flex; align-items: center; justify-content: center">{icon("xmark", 18, sw=2)}</span>
      </button>
    </div>
    <ol style="list-style: none; margin: 0; padding: 0 4px; display: flex; flex-direction: column">
{step(1, "Headphones in.", "The guide talks as you walk.", "headphones", first=True)}
{step(2, "Check the volume.", "", "speaker_wave_2", extra=test_btn)}
{step(3, "Lock your phone.", "I'll keep talking and tell you where to look.", "lock_fill", last=True)}
    </ol>
    <p style="display: flex; gap: 8px; margin: 24px 4px 0; font-size: 13px; line-height: 18px; color: {T2}">{icon("info_circle", 16, T2, 1.75, " margin-top: 1px;")}<span>While the tour runs, CityTour uses your location with the screen locked. You'll see a system notification. Stop any time from the app or the notification.</span></p>
    <div style="margin-top: 20px">
      <button type="button" style="{PRIMARY}">Start walking</button>
    </div>
  </section>"""
    body = f"""  <div aria-hidden="true" style="position: absolute; left: 0; top: 0; width: 390px; height: 844px">
{route_map_and_panel("coneBYG")}
  </div>
{sheet}"""
    write("BeforeYouGo.dc.html", page("Before you go", 844, body, ROUTE_JS))


if __name__ == "__main__":
    onboarding1(); onboarding2(); onboarding3(); home(); tour_detail(); route_ready(); before_you_go()

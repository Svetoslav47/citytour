# Generator for PlaceDetail(+Dark), TourSummary, Settings, LockScreen(+Dark), Widgets artboards.
import json, os

BASE = "/private/tmp/claude-501/-Users-svetoslaviliev-Documents-Obsidian-HackYeachResearch/06c8f11f-7325-4ef9-aa81-cbfc92262a6a/scratchpad/design/canvas"
OUT = os.path.join(BASE, "project")
META = json.load(open(os.path.join(BASE, "map-meta.json")))

FONT = "font-family: 'HarmonyOS Sans', 'HarmonyOS Sans SC', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Noto Sans SC', sans-serif"
TNUM = "font-variant-numeric: tabular-nums"

LIGHT = dict(canvas="#F4F5F3", surface="#FFFFFF", sunken="#EEEFEC", primary="#16181A", secondary="#5A6066",
             tertiary="#6B7176", divider="#E1E3DF", accent="#1D6B5B", onAccent="#FFFFFF", subtle="#E3F0EC",
             simFg="#7A4F00", simBg="#FFF1D6", scrim="rgba(244, 245, 243, 0.72)", neutralBtn="rgba(22, 24, 26, 0.06)",
             arc="rgba(29, 107, 91, 0.28)", link="#1D6B5B", linkHover="#155446", knob="#FFFFFF")
DARK = dict(canvas="#0F1112", surface="#1A1D1F", sunken="#24292C", primary="#ECEEEF", secondary="#A7ADB2",
            tertiary="#858C91", divider="#2E3336", accent="#6CC3AE", onAccent="#062A23", subtle="#17332D",
            simFg="#F2C46B", simBg="#3A2C0D", scrim="rgba(15, 17, 18, 0.72)", neutralBtn="rgba(236, 238, 239, 0.08)",
            arc="rgba(108, 195, 174, 0.32)", link="#6CC3AE", linkHover="#8FD6C4", knob="#FFFFFF")


def fill(s, t):
    for k, v in t.items():
        s = s.replace("@@" + k + "@@", v)
    assert "@@" not in s, s[s.index("@@") - 40: s.index("@@") + 40]
    return s


def page(title, w, h, root, t, js_body="return { };", lang="en"):
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
a{{color:{t['link']}}}a:hover{{color:{t['linkHover']}}}
</style>
</helmet>
{root}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{w},"height":{h}}}}}'>
class Component extends DCLogic {{
  renderVals() {{
    {js_body}
  }}
}}
</script>
</body>
</html>
"""

# ---------- icons (24 box, stroke currentColor, round caps) ----------

def svg(size, inner, fill_mode=False, sw=1.9, extra=""):
    if fill_mode:
        return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" style="flex: none; display: block{extra}">{inner}</svg>'
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="flex: none; display: block{extra}">{inner}</svg>'

I = dict(
    chevron_backward='<path d="M14.5 5.5L8 12l6.5 6.5"></path>',
    chevron_right='<path d="M9.5 6l6 6-6 6"></path>',
    picture='<rect x="3" y="5" width="18" height="14" rx="3"></rect><circle cx="8.75" cy="9.75" r="1.6"></circle><path d="M4 17l4.8-4.6a1 1 0 0 1 1.4 0L14 16l2.3-2.2a1 1 0 0 1 1.4 0L20.5 16.5"></path>',
    eye='<path d="M2.75 12S6.25 5.75 12 5.75 21.25 12 21.25 12 17.75 18.25 12 18.25 2.75 12 2.75 12z"></path><circle cx="12" cy="12" r="2.75"></circle>',
    info_circle='<circle cx="12" cy="12" r="8.75"></circle><path d="M12 11v5.25"></path><path d="M12 7.75v.01"></path>',
    figure_walk='<circle cx="13.5" cy="4.5" r="1.75"></circle><path d="M9.5 20.5l2.75-5.75"></path><path d="M14.75 20.5l-1.25-4.25-1.75-2.25.75-4.5"></path><path d="M8 12.75l1.25-3.25 3.25-1.5"></path><path d="M13.25 9.25l1.5 2.5 2.75 1"></path>',
    external='<path d="M8 16L16 8"></path><path d="M9.5 8H16v6.5"></path>',
    headphones='<path d="M4.25 15.5v-3.25a7.75 7.75 0 0 1 15.5 0v3.25"></path><rect x="3.5" y="14" width="4.25" height="6.75" rx="1.75"></rect><rect x="16.25" y="14" width="4.25" height="6.75" rx="1.75"></rect>',
    lock='<rect x="5" y="10.5" width="14" height="10" rx="2.75" fill="currentColor" stroke="none"></rect><path d="M8.25 10.5V8a3.75 3.75 0 0 1 7.5 0v2.5"></path>',
    waveform='<path d="M4 10.5v3"></path><path d="M8 7.5v9"></path><path d="M12 4.5v15"></path><path d="M16 8.5v7"></path><path d="M20 11v2"></path>',
    doc_text='<rect x="5" y="3.25" width="14" height="17.5" rx="2.75"></rect><path d="M8.75 8.25h6.5"></path><path d="M8.75 12h6.5"></path><path d="M8.75 15.75h4"></path>',
    location='<path d="M12 3.5l6.75 16.25L12 16l-6.75 3.75z"></path>',
    check='<path d="M6.5 12.5l3.5 3.5 7.5-8"></path>',
    arrow_ccw='<path d="M5 12a7 7 0 1 0 2.05-4.95"></path><path d="M5 4.5V9h4.5"></path>',
)
F = dict(
    play='<path d="M8 5.6v12.8a1.1 1.1 0 0 0 1.66.94l10.3-6.4a1.1 1.1 0 0 0 0-1.88L9.66 4.66A1.1 1.1 0 0 0 8 5.6z"></path>',
    pause='<rect x="6" y="4.75" width="4.25" height="14.5" rx="1.4"></rect><rect x="13.75" y="4.75" width="4.25" height="14.5" rx="1.4"></rect>',
    next='<path d="M4.75 6.3v11.4a1.1 1.1 0 0 0 1.73.9l8.1-5.7a1.1 1.1 0 0 0 0-1.8l-8.1-5.7a1.1 1.1 0 0 0-1.73.9z"></path><rect x="16.75" y="5.25" width="2.75" height="13.5" rx="1.375"></rect>',
    prev='<path d="M19.25 6.3v11.4a1.1 1.1 0 0 1-1.73.9l-8.1-5.7a1.1 1.1 0 0 1 0-1.8l8.1-5.7a1.1 1.1 0 0 1 1.73.9z"></path><rect x="4.5" y="5.25" width="2.75" height="13.5" rx="1.375"></rect>',
)


def ic(name, size, color, sw=1.9, extra=""):
    return f'<span style="display: flex; color: {color}">{svg(size, I[name], sw=sw, extra=extra)}</span>'


def fic(name, size, color):
    return f'<span style="display: flex; color: {color}">{svg(size, F[name], fill_mode=True)}</span>'


def check_svg(size, color="#FFFFFF", sw=2.6):
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display: block">{I["check"]}</svg>'


OVERLINE = "margin: 0; font-size: 12px; line-height: 16px; font-weight: 500; letter-spacing: 0.6px; color: @@secondary@@"

# =====================================================================
# PLACE DETAIL
# =====================================================================

def place_detail():
    sources = [
        ("https://en.wikipedia.org/wiki/St._Mary%27s_Basilica,_Krak%C3%B3w", "St. Mary’s Basilica, Kraków", "Wikipedia · rev. [1234567] · CC BY-SA 4.0"),
        ("#source-heritage-register", "Kraków heritage register, entry [A-1]", "Kraków city open data licence"),
        ("https://www.openstreetmap.org/copyright", "Map and location data", "© OpenStreetMap contributors · ODbL 1.0"),
    ]
    src_items = []
    for i, (href, title, meta) in enumerate(sources):
        border = "" if i == len(sources) - 1 else "border-bottom: 1px solid @@divider@@; "
        src_items.append(f'''
          <li style="{border}">
            <a href="{href}" style="display: flex; align-items: flex-start; gap: 12px; padding: 12px 0; min-height: 48px; box-sizing: border-box; text-decoration: none; color: @@primary@@">
              <span style="flex: none; width: 24px; height: 24px; border-radius: 8px; background: @@sunken@@; color: @@secondary@@; font-size: 12px; line-height: 24px; font-weight: 700; text-align: center; {TNUM}">{i + 1}</span>
              <span style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">
                <span style="font-size: 15px; line-height: 20px; font-weight: 500">{title}</span>
                <span style="font-size: 13px; line-height: 18px; color: @@secondary@@">{meta}</span>
              </span>
            </a>
          </li>''')

    facts = [("Built", "14th century"), ("Altarpiece", "Veit Stoss, finished 1489"), ("Trumpet call", "Hourly, from the taller tower")]
    fact_rows = []
    for i, (k, v) in enumerate(facts):
        border = "" if i == len(facts) - 1 else "border-bottom: 1px solid @@divider@@; "
        fact_rows.append(f'''
          <div style="{border}display: flex; align-items: baseline; justify-content: space-between; gap: 16px; padding: 13px 0">
            <dt style="font-size: 14px; line-height: 20px; color: @@secondary@@">{k}</dt>
            <dd style="margin: 0; font-size: 16px; line-height: 22px; text-align: right; {TNUM}">{v}</dd>
          </div>''')

    look_dial = '''<svg width="56" height="36" viewBox="0 0 56 36" fill="none" aria-hidden="true" style="flex: none; display: block">
                <path d="M6 31A22 22 0 0 1 50 31" stroke="@@arc@@" stroke-width="2" stroke-linecap="round"></path>
                <path d="M28 6.5v3.5" stroke="@@arc@@" stroke-width="2" stroke-linecap="round"></path>
                <circle cx="28" cy="31" r="2.25" fill="@@tertiary@@"></circle>
                <circle cx="9" cy="20" r="4.5" fill="@@accent@@"></circle>
                <path d="M9 12.5V4.5M6 7.25l3-3 3 3" stroke="@@accent@@" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"></path>
              </svg>'''

    root = f'''<div style="width: 390px; height: 1500px; position: relative; overflow: hidden; background: @@canvas@@; {FONT}; color: @@primary@@; display: flex; flex-direction: column">

  <!-- Photo slot (4:3). No licensed photo yet: labelled placeholder, not a fake photo. -->
  <div role="img" aria-label="Photo placeholder for St Mary's Basilica, image 1 of 3" style="position: relative; flex: none; width: 390px; height: 292px; background: @@sunken@@; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 12px">
    <div style="width: 56px; height: 56px; border-radius: 50%; background: @@surface@@; display: flex; align-items: center; justify-content: center">{ic("picture", 28, "@@tertiary@@", sw=1.75)}</div>
    <div style="display: flex; flex-direction: column; align-items: center; gap: 2px">
      <span style="font-size: 14px; line-height: 20px; font-weight: 500; color: @@secondary@@">Photo of St Mary&#8217;s Basilica</span>
      <span style="font-size: 12px; line-height: 16px; color: @@tertiary@@">Placeholder &#183; 4:3 &#183; from Wikimedia Commons</span>
    </div>
    <div style="position: absolute; left: 16px; right: 16px; bottom: 12px; display: flex; align-items: center; justify-content: space-between">
      <span style="font-size: 12px; line-height: 16px; color: @@secondary@@">&#169; [Author], CC BY-SA 4.0</span>
      <span aria-hidden="true" style="display: flex; gap: 6px">
        <span style="width: 6px; height: 6px; border-radius: 50%; background: @@secondary@@"></span>
        <span style="width: 6px; height: 6px; border-radius: 50%; background: @@divider@@"></span>
        <span style="width: 6px; height: 6px; border-radius: 50%; background: @@divider@@"></span>
      </span>
    </div>
    <button aria-label="Back" style="position: absolute; left: 8px; top: 44px; width: 48px; height: 48px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">
      <span style="width: 40px; height: 40px; border-radius: 50%; background: @@scrim@@; backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); display: flex; align-items: center; justify-content: center">{ic("chevron_backward", 22, "@@primary@@", sw=2)}</span>
    </button>
  </div>

  <div style="display: flex; flex-direction: column; gap: 20px; padding: 20px 16px 0">

    <!-- Title block + actions -->
    <div style="display: flex; flex-direction: column; gap: 16px">
      <div style="display: flex; flex-direction: column">
        <p style="{OVERLINE}">STOP 3 &#183; CHURCH &#183; 14TH C.</p>
        <h1 style="margin: 6px 0 0; font-size: 28px; line-height: 34px; font-weight: 700">St Mary&#8217;s Basilica</h1>
        <p lang="pl" style="margin: 2px 0 0; font-size: 14px; line-height: 20px; color: @@secondary@@">Ko&#347;ci&#243;&#322; Mariacki</p>
        <p style="margin: 8px 0 0; display: flex; align-items: center; gap: 6px; font-size: 14px; line-height: 20px; color: @@secondary@@; {TNUM}">{ic("figure_walk", 16, "@@secondary@@", sw=1.8)}<span>120 m &#183; ahead, slightly left</span></p>
      </div>
      <div style="display: flex; gap: 12px">
        <button style="height: 48px; padding: 0 22px 0 18px; border: 0; border-radius: 24px; background: @@accent@@; color: @@onAccent@@; font-family: inherit; font-size: 16px; line-height: 22px; font-weight: 500; display: flex; align-items: center; gap: 8px; cursor: pointer; {TNUM}">{fic("play", 18, "@@onAccent@@")}<span>Listen &#183; 4 min</span></button>
        <button style="height: 48px; padding: 0 22px; border: 0; border-radius: 24px; background: @@neutralBtn@@; color: @@primary@@; font-family: inherit; font-size: 16px; line-height: 22px; font-weight: 500; cursor: pointer">Tell me more</button>
      </div>
    </div>

    <!-- Where to look -->
    <section aria-label="Where to look" style="background: @@subtle@@; border-radius: 20px; padding: 16px; display: flex; flex-direction: column; gap: 6px">
      <div style="display: flex; align-items: flex-start; justify-content: space-between">
        <p style="margin: 0; display: flex; align-items: center; gap: 6px; font-size: 12px; line-height: 16px; font-weight: 500; letter-spacing: 0.6px; color: @@accent@@">{ic("eye", 16, "@@accent@@", sw=1.9)}<span>LOOK</span></p>
        {look_dial}
      </div>
      <p style="margin: -10px 0 0; font-size: 17px; line-height: 25px; color: @@primary@@">The taller tower, on your left as you face the front. Look up to the top window.</p>
    </section>

    <!-- Transcript -->
    <section aria-label="Transcript" style="display: flex; flex-direction: column; gap: 12px">
      <div style="display: flex; align-items: baseline; justify-content: space-between">
        <h2 style="{OVERLINE}">TRANSCRIPT</h2>
        <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: @@secondary@@; {TNUM}">Story 2 of 3</span>
      </div>
      <p style="margin: 0; font-size: 18px; line-height: 28px; color: @@tertiary@@">Every hour, a trumpeter plays a short call from that tower, the <span lang="pl">hejna&#322;</span>, to all four sides of the city.</p>
      <p aria-current="true" style="margin: 0; padding-left: 13px; border-left: 3px solid @@accent@@; font-size: 18px; line-height: 28px; color: @@primary@@">Listen to the end: the melody stops mid-note.</p>
      <p style="margin: 0; font-size: 18px; line-height: 28px; color: @@primary@@">The legend says a trumpeter was struck by an arrow as he warned the city of an attack, and the call has broken off ever since.</p>
    </section>

    <!-- Facts -->
    <section aria-label="Facts" style="display: flex; flex-direction: column; gap: 8px">
      <h2 style="{OVERLINE}">FACTS</h2>
      <dl style="margin: 0; background: @@surface@@; border-radius: 20px; padding: 0 16px">{"".join(fact_rows)}
      </dl>
    </section>

    <!-- Sources -->
    <section aria-label="Sources" style="display: flex; flex-direction: column; gap: 8px">
      <h2 style="{OVERLINE}">SOURCES</h2>
      <ol style="margin: 0; padding: 0 16px; list-style: none; background: @@surface@@; border-radius: 20px">{"".join(src_items)}
      </ol>
    </section>

    <!-- Provenance footnote -->
    <div style="display: flex; align-items: flex-start; gap: 10px; padding: 0 4px">
      {ic("info_circle", 18, "@@secondary@@", sw=1.8)}
      <p style="margin: 0; font-size: 13px; line-height: 18px; color: @@secondary@@">Drafted with AI from the sources above, reviewed by a person on 3 Oct 2026. <a href="#how-these-stories-are-made" style="font-weight: 500">How these stories are made</a></p>
    </div>
  </div>
</div>'''
    return root

# =====================================================================
# TOUR SUMMARY
# =====================================================================

def tour_summary():
    stops = [[s["x"], s["y"]] for s in META["stops"]]
    route = META["route_polyline_px"]
    js = f'''const S = 0.4, TX = -6, TY = -2, SIZE = 24;
    const STOPS = {json.dumps(stops)};
    const ROUTE = {json.dumps(route, separators=(",", ":"))};
    const pts = ROUTE.map(p => p[0].toFixed(1) + "," + p[1].toFixed(1)).join(" ");
    const plaques = STOPS.map((p, i) => {{
      const left = (p[0] * S + TX - SIZE / 2).toFixed(1);
      const top = (p[1] * S + TY - SIZE / 2).toFixed(1);
      return {{
        n: i + 1,
        style: "position: absolute; left: " + left + "px; top: " + top + "px; width: " + SIZE + "px; height: " + SIZE + "px; border-radius: 50%; background: rgba(107, 113, 118, 0.85); box-shadow: 0 0 0 1.5px #FFFFFF, 0 1px 3px rgba(22, 24, 26, 0.18); display: flex; align-items: center; justify-content: center"
      }};
    }});
    return {{
      mapTransform: "translate(" + TX + "px, " + TY + "px) scale(" + S + ")",
      routeWalked: pts,
      w: (5 / S).toFixed(2),
      plaques: plaques
    }};'''

    heard = ["Barbican", "St Florian’s Gate", "St Mary’s Basilica", "Cloth Hall"]
    rows = []
    for i, name in enumerate(heard):
        rows.append(f'''
          <a href="#place-{i + 1}" style="display: flex; align-items: center; gap: 14px; min-height: 56px; padding: 0 12px 0 16px; text-decoration: none; color: @@primary@@">
            <span aria-hidden="true" style="flex: none; width: 24px; height: 24px; border-radius: 50%; background: rgba(107, 113, 118, 0.85); display: flex; align-items: center; justify-content: center">{check_svg(14)}</span>
            <span style="flex: 1; font-size: 16px; line-height: 22px; font-weight: 500">{name}</span>
            {ic("chevron_right", 18, "@@tertiary@@", sw=2)}
          </a>
          <div style="height: 1px; background: @@divider@@; margin-left: 54px"></div>''')
    rows.append(f'''
          <a href="#all-stories" style="display: flex; align-items: center; gap: 14px; min-height: 56px; padding: 0 12px 0 16px; text-decoration: none; color: @@primary@@">
            <span style="flex: none; width: 24px; display: flex; justify-content: center">{ic("waveform", 20, "@@secondary@@", sw=1.9)}</span>
            <span style="flex: 1; font-size: 16px; line-height: 22px">All 11 stories</span>
            <span style="font-size: 14px; line-height: 20px; color: @@secondary@@; {TNUM}">7 more</span>
            {ic("chevron_right", 18, "@@tertiary@@", sw=2)}
          </a>''')

    def stat(value, label, first=False):
        bl = "" if first else "border-left: 1px solid @@divider@@; "
        return f'''<div style="{bl}flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px">
          <span style="font-size: 22px; line-height: 28px; font-weight: 700; {TNUM}">{value}</span>
          <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: @@secondary@@">{label}</span>
        </div>'''

    root = f'''<div style="width: 390px; height: 1100px; position: relative; overflow: hidden; background: @@canvas@@; {FONT}; color: @@primary@@; display: flex; flex-direction: column">

  <!-- Walked map: whole Royal Route, every plaque visited -->
  <div style="position: relative; flex: none; width: 390px; height: 472px; overflow: hidden; background: #EEEEEA">
    <div role="img" aria-label="Map of the Royal Route, walked from the Barbican to Wawel Hill, all 11 stops visited" style="position: absolute; left: 0; top: 0; width: 390px; height: 472px; overflow: hidden">
      <div style="position: absolute; left: 0; top: 0; width: 1000px; height: 1289px; transform-origin: 0 0; transform: {{{{mapTransform}}}}">
        <img src="/_blob/47c1f630f4c212aa493463e6caf6c0c2" alt="" style="position: absolute; left: 0; top: 0; width: 1000px; height: 1289px">
        <svg viewBox="0 0 1000 1289" width="1000" height="1289" style="position: absolute; left: 0; top: 0" aria-hidden="true">
          <polyline points="{{{{routeWalked}}}}" fill="none" stroke="#6B7176" stroke-opacity="0.6" stroke-width="{{{{w}}}}" stroke-linecap="round" stroke-linejoin="round"></polyline>
        </svg>
      </div>
      <sc-for list="{{{{plaques}}}}" as="item" hint-placeholder-count="11">
        <div style="{{{{ item.style }}}}">{check_svg(14)}</div>
      </sc-for>
    </div>
    <button style="position: absolute; right: 12px; top: 44px; height: 48px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; cursor: pointer; font-family: inherit">
      <span style="height: 40px; padding: 0 20px; border-radius: 20px; background: rgba(244, 245, 243, 0.72); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); box-shadow: 0 1px 4px rgba(22, 24, 26, 0.12); display: flex; align-items: center; font-size: 16px; line-height: 22px; font-weight: 500; color: @@accent@@">Done</span>
    </button>
    <button aria-label="Map attribution" style="position: absolute; right: 4px; bottom: 4px; width: 48px; height: 48px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">
      <span style="width: 28px; height: 28px; border-radius: 50%; background: rgba(244, 245, 243, 0.72); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); box-shadow: 0 1px 4px rgba(22, 24, 26, 0.12); display: flex; align-items: center; justify-content: center">{ic("info_circle", 16, "@@secondary@@", sw=1.9)}</span>
    </button>
  </div>

  <div style="display: flex; flex-direction: column; gap: 20px; padding: 20px 16px 0">
    <header style="display: flex; flex-direction: column">
      <p style="{OVERLINE}">TOUR COMPLETE</p>
      <h1 style="margin: 4px 0 0; font-size: 28px; line-height: 34px; font-weight: 700">The Royal Route</h1>
      <p style="margin: 2px 0 0; font-size: 14px; line-height: 20px; color: @@secondary@@">Saturday, 3 October</p>
    </header>

    <div style="background: @@surface@@; border-radius: 20px; padding: 14px 0; display: flex">
      {stat("11/11", "stops", True)}
      {stat("2.5 km", "walked")}
      {stat("1 h 24 min", "total")}
    </div>

    <section aria-label="You heard" style="display: flex; flex-direction: column; gap: 8px">
      <h2 style="{OVERLINE}">YOU HEARD</h2>
      <div style="background: @@surface@@; border-radius: 20px; overflow: hidden">{"".join(rows)}
      </div>
    </section>

    <a href="#sources-and-credits" style="background: @@surface@@; border-radius: 20px; display: flex; align-items: center; gap: 14px; min-height: 56px; padding: 0 12px 0 16px; text-decoration: none; color: @@primary@@">
      <span style="flex: none; width: 24px; display: flex; justify-content: center">{ic("doc_text", 20, "@@secondary@@", sw=1.8)}</span>
      <span style="flex: 1; font-size: 16px; line-height: 22px">Sources and credits</span>
      <span style="font-size: 14px; line-height: 20px; color: @@secondary@@; {TNUM}">23 sources</span>
      {ic("chevron_right", 18, "@@tertiary@@", sw=2)}
    </a>
  </div>
</div>'''
    return root, js

# =====================================================================
# SETTINGS
# =====================================================================

HIDDEN_INPUT = "position: absolute; width: 1px; height: 1px; margin: 0; opacity: 0; pointer-events: none"


def s_nav(label, value, href, sub=None):
    lab = f'<span style="font-size: 16px; line-height: 22px">{label}</span>'
    if sub:
        lab = f'<span style="display: flex; flex-direction: column; gap: 2px">{lab}<span style="font-size: 14px; line-height: 20px; color: @@secondary@@; {TNUM}">{sub}</span></span>'
    minh = 72 if sub else 56
    val = f'<span style="font-size: 14px; line-height: 20px; color: @@secondary@@; text-align: right">{value}</span>' if value else ""
    return f'''<a href="{href}" style="display: flex; align-items: center; gap: 8px; min-height: {minh}px; padding: 0 12px 0 16px; text-decoration: none; color: @@primary@@">
          <span style="flex: 1; min-width: 0">{lab}</span>
          {val}
          {ic("chevron_right", 18, "@@tertiary@@", sw=2)}
        </a>'''


def s_value(label, value):
    return f'''<div style="display: flex; align-items: center; gap: 8px; min-height: 56px; padding: 0 16px">
          <span style="flex: 1; font-size: 16px; line-height: 22px">{label}</span>
          <span style="font-size: 14px; line-height: 20px; color: @@secondary@@">{value}</span>
        </div>'''


def s_toggle(label, on=True, sub=None):
    lab = f'<span style="font-size: 16px; line-height: 22px">{label}</span>'
    if sub:
        lab = f'<span style="display: flex; flex-direction: column; gap: 2px">{lab}<span style="font-size: 14px; line-height: 20px; color: @@secondary@@">{sub}</span></span>'
    minh = 72 if sub else 56
    track = "@@accent@@" if on else "rgba(22, 24, 26, 0.14)"
    justify = "flex-end" if on else "flex-start"
    checked = " checked" if on else ""
    return f'''<label style="position: relative; display: flex; align-items: center; gap: 12px; min-height: {minh}px; padding: 8px 16px; box-sizing: border-box; cursor: pointer">
          <span style="flex: 1; min-width: 0">{lab}</span>
          <input type="checkbox" role="switch"{checked} style="{HIDDEN_INPUT}">
          <span aria-hidden="true" style="flex: none; width: 40px; height: 24px; border-radius: 12px; background: {track}; padding: 2px; box-sizing: border-box; display: flex; justify-content: {justify}">
            <span style="width: 20px; height: 20px; border-radius: 50%; background: #FFFFFF"></span>
          </span>
        </label>'''


def s_segment(label, name, options, selected):
    segs = []
    for o in options:
        sel = o == selected
        bg = "background: @@subtle@@; color: @@accent@@; font-weight: 500" if sel else "color: @@secondary@@; font-weight: 500"
        checked = " checked" if sel else ""
        segs.append(f'''<label style="position: relative; flex: 1; height: 48px; display: flex; align-items: center; cursor: pointer">
              <input type="radio" name="{name}"{checked} style="{HIDDEN_INPUT}">
              <span style="flex: 1; height: 40px; border-radius: 20px; display: flex; align-items: center; justify-content: center; font-size: 14px; line-height: 20px; {TNUM}; {bg}">{o}</span>
            </label>''')
    return f'''<div role="radiogroup" aria-label="{label}" style="display: flex; flex-direction: column; gap: 10px; padding: 14px 16px 12px">
          <span style="font-size: 16px; line-height: 22px">{label}</span>
          <div style="display: flex; padding: 0 4px; border-radius: 24px; background: @@sunken@@">
            {"".join(segs)}
          </div>
        </div>'''


def s_group(title, rows, foot=None):
    div = '\n        <div style="height: 1px; background: @@divider@@; margin: 0 16px"></div>\n        '
    footer = ""
    if foot:
        footer = f'\n      {foot}' if foot.startswith("<") else f'\n      <p style="margin: 0 16px; font-size: 13px; line-height: 18px; color: @@secondary@@">{foot}</p>'
    return f'''
    <section aria-label="{title.capitalize()}" style="display: flex; flex-direction: column; gap: 8px">
      <h2 style="{OVERLINE}; padding: 0 16px">{title}</h2>
      <div style="background: @@surface@@; border-radius: 20px; overflow: hidden">
        {div.join(rows)}
      </div>{footer}
    </section>'''


def settings():
    amber = '''<p style="margin: 0; padding: 10px 14px; border-radius: 12px; background: @@simBg@@; color: @@simFg@@; font-size: 13px; line-height: 18px">Replays a recorded walk along the Royal Route instead of using GPS. Everything simulated is labelled <span style="font-weight: 700; letter-spacing: 0.6px">SIMULATED</span>.</p>'''
    groups = [
        s_group("NARRATION", [
            s_nav("Story language", "English", "#story-language"),
            s_nav("App language", "System", "#app-language"),
            s_nav("Voice", "Laura &#183; Installed", "#voice"),
            s_nav("Guide", "The Historian", "#guide"),
            s_segment("Detail level", "detail", ["Brief", "Standard", "Deep"], "Standard"),
        ], "Standard: about 3 minutes per stop, with directions."),
        s_group("WALKING", [
            s_toggle("Spoken directions", True, "Short directions at turns between stops."),
            s_toggle("Mention places along the way", True),
            s_segment("Start the story when I&#8217;m within", "radius", ["20 m", "35 m", "50 m"], "35 m"),
        ], "Larger works better in narrow streets where GPS drifts."),
        s_group("SOUND AND HAPTICS", [
            s_toggle("Arrival chime", True),
            s_toggle("Vibrate on arrival", True),
        ]),
        s_group("OFFLINE DATA", [
            s_nav("Krak&#243;w pack", "Included", "#offline-data", sub="Monuments 395 &#183; Plaques 923 &#183; 11 tour stories"),
        ]),
        s_group("DEMO", [
            s_toggle("Demo walk (simulated location)", True),
            s_segment("Replay speed", "speed", ["1&#215;", "2&#215;", "4&#215;", "8&#215;"], "4&#215;"),
        ], amber),
        s_group("PERMISSIONS", [
            s_nav("Location", "Precise &#183; while using", "#location"),
            s_nav("Notifications", "On", "#notifications"),
        ]),
        s_group("ABOUT", [
            s_nav("How these stories are made", "", "#how-these-stories-are-made"),
            s_nav("Sources and licences", "", "#sources-and-licences"),
            s_nav("Show introduction again", "", "#introduction"),
            s_value("Version", "1.0 (HackYeah 2026 build)"),
        ]),
    ]
    root = f'''<div style="width: 390px; height: 1500px; position: relative; overflow: hidden; background: @@canvas@@; {FONT}; color: @@primary@@; display: flex; flex-direction: column">
  <div style="flex: none; height: 44px"></div>
  <div style="flex: none; height: 48px; padding: 0 4px; display: flex; align-items: center">
    <button aria-label="Back" style="width: 48px; height: 48px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">{ic("chevron_backward", 24, "@@primary@@", sw=2)}</button>
  </div>
  <h1 style="flex: none; margin: 4px 16px 20px; font-size: 28px; line-height: 34px; font-weight: 700">Settings</h1>
  <div style="display: flex; flex-direction: column; gap: 24px; padding: 0 16px">{"".join(groups)}
  </div>
</div>'''
    return root

# =====================================================================
# LOCK SCREEN
# =====================================================================

LOCK_LIGHT = dict(LIGHT, wall="linear-gradient(180deg, #E6EAE8 0%, #D4DBD8 100%)", material="rgba(255, 255, 255, 0.66)",
                  clock="#16181A", date="#3A4044", lyric="#2B3034")
LOCK_DARK = dict(DARK, wall="linear-gradient(180deg, #1B1F21 0%, #0C0E0F 100%)", material="rgba(40, 45, 48, 0.72)",
                 clock="#ECEEEF", date="#C2C7CB", lyric="#D3D7DA")


def app_icon(size, radius):
    return f'''<span aria-hidden="true" style="flex: none; width: {size}px; height: {size}px; border-radius: {radius}px; background: #1D6B5B; display: flex; align-items: center; justify-content: center">
            <svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" aria-hidden="true" style="display: block"><path d="M7.5 17.5c1-3.5 4.5-3.25 6-5.5s.75-3.5.75-3.5" stroke="#F4F5F3" stroke-width="2" stroke-linecap="round"></path><circle cx="14.6" cy="7.2" r="1.9" fill="#F4F5F3"></circle></svg>
          </span>'''


def lock():
    root = f'''<div style="width: 390px; height: 844px; position: relative; overflow: hidden; background: @@wall@@; {FONT}; color: @@clock@@; display: flex; flex-direction: column; align-items: center">
  <div style="flex: none; height: 64px"></div>
  <span role="img" aria-label="Locked" style="display: flex">{ic("lock", 18, "@@clock@@", sw=2)}</span>
  <div style="margin-top: 20px; font-size: 92px; line-height: 96px; font-weight: 600; letter-spacing: -2px; {TNUM}">14:32</div>
  <div style="margin-top: 4px; font-size: 17px; line-height: 22px; font-weight: 500; color: @@date@@">Saturday, 3 October</div>

  <!-- System media card (AVSession, 'audio' template; favourite/loop/seek turned off) -->
  <section aria-label="Now playing in CityTour" style="margin-top: 40px; width: 358px; box-sizing: border-box; padding: 16px 16px 10px; border-radius: 24px; background: @@material@@; backdrop-filter: blur(30px); -webkit-backdrop-filter: blur(30px); display: flex; flex-direction: column; gap: 12px">
    <div style="display: flex; align-items: center; gap: 12px">
      <div role="img" aria-label="Artwork: stop 4 plaque" style="flex: none; width: 64px; height: 64px; border-radius: 14px; background: #1D6B5B; display: flex; align-items: center; justify-content: center">
        <span style="width: 38px; height: 38px; border-radius: 50%; box-shadow: inset 0 0 0 2.5px rgba(255, 255, 255, 0.92); display: flex; align-items: center; justify-content: center; color: #FFFFFF; font-size: 19px; line-height: 24px; font-weight: 700; {TNUM}">4</span>
      </div>
      <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px">
        <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: @@secondary@@">CityTour</span>
        <span style="font-size: 17px; line-height: 22px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">Walking to Cloth Hall</span>
        <span style="font-size: 14px; line-height: 20px; color: @@secondary@@; {TNUM}">Next: Cloth Hall &#183; 120 m</span>
      </div>
      <button aria-label="Audio output: headphones" style="flex: none; align-self: flex-start; width: 48px; height: 48px; margin: -12px -12px 0 0; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">{ic("headphones", 20, "@@secondary@@", sw=1.8)}</button>
    </div>
    <p style="margin: 0; font-size: 13px; line-height: 18px; color: @@lyric@@; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">Walk down Floria&#324;ska Street, towards the brick church.</p>
    <div style="display: flex; align-items: center; justify-content: center; gap: 44px">
      <button aria-label="Replay" style="width: 48px; height: 48px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">{fic("prev", 26, "@@clock@@")}</button>
      <button aria-label="Pause" style="width: 56px; height: 56px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">{fic("pause", 34, "@@clock@@")}</button>
      <button aria-label="Skip" style="width: 48px; height: 48px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">{fic("next", 26, "@@clock@@")}</button>
    </div>
  </section>

  <!-- System continuous-task notification -->
  <section aria-label="Notification from CityTour" style="margin-top: 10px; width: 358px; box-sizing: border-box; padding: 14px 16px; border-radius: 20px; background: @@material@@; backdrop-filter: blur(30px); -webkit-backdrop-filter: blur(30px); display: flex; align-items: flex-start; gap: 12px">
    {app_icon(28, 8)}
    <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">
      <div style="display: flex; align-items: baseline; justify-content: space-between; gap: 8px">
        <span style="font-size: 13px; line-height: 18px; font-weight: 500; color: @@secondary@@">CityTour</span>
        <span style="font-size: 12px; line-height: 16px; color: @@secondary@@">now</span>
      </div>
      <span style="font-size: 15px; line-height: 20px">CityTour is using your location</span>
    </div>
  </section>
</div>'''
    return root

# =====================================================================
# WIDGETS
# =====================================================================

def widgets():
    t = LIGHT
    # progress plaques for 2x4
    prog = []
    for n in range(1, 12):
        if n < 4:
            prog.append(f'<span style="flex: none; width: 14px; height: 14px; border-radius: 50%; background: rgba(107, 113, 118, 0.85); display: flex; align-items: center; justify-content: center">{check_svg(10, sw=3)}</span>')
        elif n == 4:
            prog.append(f'<span style="flex: none; width: 22px; height: 22px; border-radius: 50%; background: @@accent@@; box-shadow: 0 0 0 2px #FFFFFF; color: #FFFFFF; font-size: 12px; line-height: 16px; font-weight: 700; display: flex; align-items: center; justify-content: center; {TNUM}">4</span>')
        else:
            prog.append('<span style="flex: none; width: 12px; height: 12px; border-radius: 50%; box-sizing: border-box; border: 1.5px solid #858C91; background: #FFFFFF"></span>')
        if n < 11:
            col = "rgba(107, 113, 118, 0.55)" if n < 4 else "@@divider@@"
            prog.append(f'<span style="flex: 1; height: 2px; border-radius: 1px; background: {col}"></span>')

    def round_btn(label, icon_html, visual=36, bg="@@sunken@@"):
        return f'''<button aria-label="{label}" style="flex: none; width: 48px; height: 48px; padding: 0; border: 0; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">
              <span style="width: {visual}px; height: {visual}px; border-radius: 50%; background: {bg}; display: flex; align-items: center; justify-content: center">{icon_html}</span>
            </button>'''

    W_STYLE = "box-sizing: border-box; border-radius: 20px; background: #FFFFFF; display: flex; flex-direction: column"
    cap = lambda a, b: f'<p style="margin: 0; font-size: 13px; line-height: 18px; color: #2B3034; text-align: center"><span style="font-weight: 600">{a}</span> &#183; {b}</p>'

    w22a = f'''<div style="display: flex; flex-direction: column; align-items: center; gap: 14px">
      <article aria-label="CityTour widget, 2 by 2, tour in progress" style="width: 184px; height: 184px; padding: 14px 16px 16px; {W_STYLE}">
        <div style="display: flex; align-items: flex-start; justify-content: space-between">
          <p style="{OVERLINE}; padding-top: 6px; {TNUM}">NEXT &#183; 4/11</p>
          <div style="margin: -4px -10px 0 0">{round_btn("Pause", fic("pause", 18, "@@primary@@"), 40)}</div>
        </div>
        <div style="margin-top: auto; display: flex; flex-direction: column">
          <span style="font-size: 18px; line-height: 24px; font-weight: 500">Cloth Hall</span>
          <span style="margin-top: 2px; font-size: 28px; line-height: 32px; font-weight: 700; {TNUM}">120 m</span>
          <span style="margin-top: 2px; font-size: 12px; line-height: 16px; font-weight: 500; color: @@secondary@@">ahead, right</span>
        </div>
      </article>
      {cap("2&#215;2", "Active tour")}
    </div>'''

    w24a = f'''<div style="display: flex; flex-direction: column; align-items: center; gap: 14px">
      <article aria-label="CityTour widget, 2 by 4, tour in progress" style="width: 384px; height: 184px; padding: 14px 16px 8px; {W_STYLE}">
        <p style="{OVERLINE}">NEXT &#183; STOP 4 OF 11</p>
        <div style="margin-top: 4px; display: flex; align-items: baseline; justify-content: space-between; gap: 12px">
          <span style="font-size: 18px; line-height: 24px; font-weight: 500">Cloth Hall</span>
          <span style="font-size: 24px; line-height: 28px; font-weight: 700; {TNUM}">120 m</span>
        </div>
        <div style="margin-top: 2px; display: flex; justify-content: space-between; gap: 12px; font-size: 12px; line-height: 16px; font-weight: 500; color: @@secondary@@">
          <span>ahead, slightly right</span><span style="{TNUM}">~2 min</span>
        </div>
        <div role="img" aria-label="Progress: 3 of 11 stops visited, stop 4 next" style="margin-top: 12px; height: 24px; display: flex; align-items: center; gap: 3px">
          {"".join(prog)}
        </div>
        <div style="margin-top: auto; display: flex; align-items: center; gap: 4px">
          {ic("waveform", 16, "@@secondary@@", sw=1.9)}
          <span style="flex: 1; min-width: 0; margin-left: 4px; font-size: 14px; line-height: 20px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">St Mary&#8217;s Basilica</span>
          {round_btn("Replay", ic("arrow_ccw", 20, "@@primary@@", sw=2), 36, "transparent")}
          {round_btn("Pause", fic("pause", 16, "@@primary@@"), 36)}
          {round_btn("Skip", fic("next", 18, "@@primary@@"), 36, "transparent")}
        </div>
      </article>
      {cap("2&#215;4", "Active tour (default size)")}
    </div>'''

    w22i = f'''<div style="display: flex; flex-direction: column; align-items: center; gap: 14px">
      <article aria-label="CityTour widget, 2 by 2, no tour running" style="width: 184px; height: 184px; padding: 14px 16px 16px; {W_STYLE}">
        <div style="display: flex; align-items: center; gap: 6px">
          {app_icon(16, 5)}
          <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: @@secondary@@">CityTour</span>
        </div>
        <span style="margin-top: 12px; font-size: 18px; line-height: 24px; font-weight: 700">The Royal Route</span>
        <span style="margin-top: 2px; font-size: 12px; line-height: 16px; font-weight: 500; color: @@secondary@@; {TNUM}">11 stops &#183; 2.5 km</span>
        <button style="margin-top: auto; height: 48px; border: 0; border-radius: 24px; background: @@accent@@; color: @@onAccent@@; font-family: inherit; font-size: 16px; line-height: 22px; font-weight: 500; cursor: pointer">Start</button>
      </article>
      {cap("2&#215;2", "No tour")}
    </div>'''

    root = f'''<div style="width: 900px; height: 700px; position: relative; overflow: hidden; background: linear-gradient(180deg, #E4E8E6 0%, #CFD6D3 100%); {FONT}; color: @@primary@@; display: flex; align-items: center; justify-content: center; gap: 32px">
    {w22a}
    {w24a}
    {w22i}
</div>'''
    return root


def write(name, html):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(html)
    print("wrote", name, len(html))


pd = place_detail()
write("PlaceDetail.dc.html", page("Place detail · St Mary’s Basilica", 390, 1500, fill(pd, LIGHT), LIGHT))
write("PlaceDetailDark.dc.html", page("Place detail · Dark", 390, 1500, fill(pd, DARK), DARK))
ts, js = tour_summary()
write("TourSummary.dc.html", page("Tour summary", 390, 1100, fill(ts, LIGHT), LIGHT, js))
write("Settings.dc.html", page("Settings", 390, 1500, fill(settings(), LIGHT), LIGHT))
lk = lock()
write("LockScreen.dc.html", page("Lock screen", 390, 844, fill(lk, LOCK_LIGHT), LIGHT))
write("LockScreenDark.dc.html", page("Lock screen · Dark", 390, 844, fill(lk, LOCK_DARK), DARK))
write("Widgets.dc.html", page("Home-screen widgets", 900, 700, fill(widgets(), LIGHT), LIGHT))

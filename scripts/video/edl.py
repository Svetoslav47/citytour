#!/usr/bin/env python3
"""Edit decision list for the CityTour demo video (68 s, 1920x1080, 30 fps).

Maps every output frame to the emulator screenshot shown on the phone (bursts captured at ~7 fps on the device,
named by device epoch ns) and lists the audio cues. Device clock: CST (UTC+8); time-of-day = epoch - DAY0.
Writes plan.json (per-frame phone image + scene) and cues.json (audio), and resizes the used frames into phone/.
"""
import json, os, bisect
from PIL import Image

V = os.path.dirname(os.path.abspath(__file__))
REPO = '/Users/svetoslaviliev/Documents/GitHub/citytour'
FPS = 30
DUR = 68.0
N = int(DUR * FPS)
DAY0 = 1791043200  # 2026-10-04 00:00 CST as epoch seconds (device date at 09:33:43 = 1791077623)
SCREEN_W, SCREEN_H = 663, 1434  # 1.5x the on-canvas phone screen (442x956)

def burst(name):
    fs = sorted(f for f in os.listdir(os.path.join(V, 'shots', name)) if f.endswith('.jpeg'))
    ts = [int(f.split('.')[0]) / 1e9 for f in fs]
    return {'name': name, 'files': fs, 'ts': ts, 't0': ts[0]}

B = {n: burst(n) for n in ['A', 'B', 'C', 'E', 'DL', 'home_scroll', 'HUD', 'LOCK']}

def tod(hms):  # '09:55:02.136' -> seconds since CST midnight
    h, m, s = hms.split(':'); return int(h) * 3600 + int(m) * 60 + float(s)

def at(b, off):
    """Frame of burst b nearest to offset `off` seconds from its first frame."""
    t = b['t0'] + off
    i = bisect.bisect_left(b['ts'], t)
    if i >= len(b['ts']): i = len(b['ts']) - 1
    if i > 0 and abs(b['ts'][i - 1] - t) <= abs(b['ts'][i] - t): i -= 1
    return ('shots/%s/%s' % (b['name'], b['files'][i]))

def at_tod(b, sec_of_day):
    return at(b, (DAY0 + sec_of_day) - b['t0'])

# ---- timeline (video seconds) -------------------------------------------------------------------------------
E_EN_TAIL = tod('09:55:02.136') + 3.0     # E1 offset 3.0 s: "the main building of the Jagiellonian University."
SEG = [
    # (v_start, v_end, kind, params)
    (8.6, 9.3, 'still', {'img': 'shots/home_top.jpeg'}),
    (9.3, 12.0, 'map', {'b': 'home_scroll', 'o0': 1.2, 'o1': 5.2}),
    (12.0, 12.6, 'map', {'b': 'home_scroll', 'o0': 5.2, 'o1': 1.0}),           # fling back to the top
    (12.6, 13.6, 'map', {'b': 'A', 'o0': 0.0, 'o1': 2.1}),                      # tap Demo walk -> Now Walking
    (13.6, 23.2, 'map', {'b': 'A', 'o0': 15.60, 'o1': 15.60 + 9.6}),            # arrival story at the Barbican
    (23.2, 25.9, 'map', {'b': 'B', 'o0': 0.5, 'o1': 24.5}),                     # timelapse, collapsed sheet
    (25.9, 28.3, 'map', {'b': 'C', 'o0': 58.6, 'o1': 61.0}),                    # "In 30 metres, turn right."
    (28.3, 29.6, 'map', {'b': 'C', 'o0': 64.2, 'o1': 65.5}),                    # arrival at the monument
    (29.6, 30.2, 'still', {'img': None, 'from': 'C@65.5'}),                     # screen dims (renderer)
    (30.2, 30.9, 'still', {'img': 'shots/screen_off.jpeg'}),
    (30.9, 32.1, 'still', {'img': 'shots/lock1.jpeg'}),
    (32.1, 36.6, 'still', {'img': 'shots/lock2.jpeg'}),
    (36.6, 39.25, 'tod', {'b': 'E', 's0': E_EN_TAIL, 's1': E_EN_TAIL + 2.65}),
    (39.25, 45.43, 'tod', {'b': 'E', 's0': tod('09:55:08.55'), 's1': tod('09:55:14.73')}),
    (45.43, 50.33, 'tod', {'b': 'E', 's0': tod('09:55:24.10'), 's1': tod('09:55:29.00')}),
    (50.33, 55.4, 'map', {'b': 'HUD', 'o0': 0.0, 'o1': 5.07}),
    (55.4, 57.6, 'map', {'b': 'DL', 'o0': 1.0, 'o1': 9.0}),
    (57.6, 60.2, 'still', {'img': 'docs:widget-active.png'}),
]

def phone_src(v):
    for (a, b, kind, p) in SEG:
        if a <= v < b:
            u = (v - a) / (b - a)
            if kind == 'still':
                if p.get('img') is None: return at(B['C'], 65.5)
                img = p['img']
                return os.path.join(REPO, 'docs/img', img.split(':', 1)[1]) if img.startswith('docs:') else img
            if kind == 'map':
                return at(B[p['b']], p['o0'] + u * (p['o1'] - p['o0']))
            if kind == 'tod':
                return at_tod(B[p['b']], p['s0'] + u * (p['s1'] - p['s0']))
    return None

def vt_of_tod(seg_start, s0, sec):  # video time where a device time-of-day lands in a 'tod' segment (real time)
    return seg_start + (sec - s0)

# ---- audio cues ------------------------------------------------------------------------------------------------
A_T0 = B['A']['t0'] - DAY0
def v_of_A(sec):  # Take A real-time segment 13.6 <-> offset 15.60
    return 13.6 + ((sec - A_T0) - 15.60)

AUD = {
    'A2': REPO + '/data/course/krakow/audio/en/_arrival/c62d3fca6505fe8f.mp3',
    'A3': REPO + '/data/course/krakow/audio/en/poi_wd_Q807309/teaser_0.mp3',
    'C1': REPO + '/data/course/krakow-kazimierz/audio/en/_nav/776cfb0a3735d7ce.mp3',
    'L1': REPO + '/data/course/krakow/audio/en/poi_wd_Q1143171/teaser_0.mp3',
    'E1': REPO + '/data/course/krakow-scholars/audio/en/poi_wd_Q2983000/teaser_0.mp3',
    'E2': REPO + '/data/course/krakow-scholars/audio/pl/poi_wd_Q2983000/teaser_1.mp3',
    'E3': REPO + '/data/course/krakow-scholars/audio/zh/poi_wd_Q2983000/full_1.mp3',
    'VO': V + '/vo_end.mp3',
    'TAP': V + '/sfx_tap.mp3',
    'WHOOSH': V + '/sfx_whoosh.mp3',
}
pl_tap = vt_of_tod(36.6, E_EN_TAIL, tod('09:55:05.926'))
zh_tap = vt_of_tod(39.25, tod('09:55:08.55'), tod('09:55:13.475'))
cues = [
    {'id': 'A2', 'at': round(v_of_A(tod('09:32:56.219')), 3), 'gain': 0.0},
    {'id': 'A3', 'at': round(v_of_A(tod('09:32:59.664')), 3), 'gain': 0.0},
    {'id': 'C1', 'at': 26.0, 'gain': 0.0},
    {'id': 'L1', 'at': 30.5, 'gain': 0.0},
    {'id': 'E1', 'at': 36.6, 'from': 3.0, 'gain': 0.0},
    {'id': 'E2', 'at': round(vt_of_tod(39.25, tod('09:55:08.55'), tod('09:55:08.650')), 3), 'gain': 0.0},
    {'id': 'E3', 'at': round(vt_of_tod(45.43, tod('09:55:24.10'), tod('09:55:24.209')), 3), 'gain': 0.0},
    {'id': 'VO', 'at': 61.0, 'gain': 1.5},
    {'id': 'TAP', 'at': 13.05, 'gain': -6.0},
    {'id': 'TAP', 'at': round(pl_tap, 3), 'gain': -6.0},
    {'id': 'TAP', 'at': round(zh_tap, 3), 'gain': -6.0},
    {'id': 'TAP', 'at': 31.95, 'gain': -6.0},
    {'id': 'WHOOSH', 'at': 4.25, 'gain': -9.0},
    {'id': 'WHOOSH', 'at': 8.25, 'gain': -9.0},
    {'id': 'WHOOSH', 'at': 49.95, 'gain': -10.0},
    {'id': 'WHOOSH', 'at': 59.85, 'gain': -9.0},
]
for c in cues: c['file'] = AUD[c['id']]

# ---- frames -----------------------------------------------------------------------------------------------------
os.makedirs(os.path.join(V, 'phone'), exist_ok=True)
plan, used = [], {}
for f in range(N):
    v = f / FPS
    src = phone_src(v)
    rel = None
    if src:
        absrc = src if os.path.isabs(src) else os.path.join(V, src)
        key = absrc
        if key not in used:
            out = os.path.join(V, 'phone', '%04d.jpg' % len(used))
            used[key] = out
        rel = os.path.relpath(used[key], V)
    plan.append({'f': f, 't': round(v, 4), 'phone': rel})

for absrc, out in used.items():
    if not os.path.exists(out):
        im = Image.open(absrc).convert('RGB').resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
        im.save(out, quality=90)

meta = {
    'fps': FPS, 'dur': DUR, 'n': N,
    'pl_tap': round(pl_tap, 3), 'zh_tap': round(zh_tap, 3),
    'a_tap': 13.05,
    'lang': {'en': [36.6, 39.25], 'pl': [39.25, 45.43], 'zh': [45.43, 50.33]},
    'sub_pl': [cues[5]['at'], cues[5]['at'] + 6.04],
    'sub_zh': [cues[6]['at'], cues[6]['at'] + 4.78],
}
json.dump({'meta': meta, 'frames': plan}, open(os.path.join(V, 'plan.json'), 'w'))
json.dump(cues, open(os.path.join(V, 'cues.json'), 'w'), indent=1)
print('frames', N, 'unique phone images', len(used))
print(json.dumps(meta))
print(json.dumps([(c['id'], c['at']) for c in cues]))

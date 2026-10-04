#!/usr/bin/env python3
"""Audio mix for the demo: music bed (ElevenLabs Music, offset 11 s) ducked under the app's own George clips,
plus a closing VO line and two subtle SFX. Output: audio.wav (68.0 s, 48 kHz stereo), mastered to -14 LUFS."""
import json, os, subprocess

V = os.path.dirname(os.path.abspath(__file__))
DUR = 68.0
MUSIC_OFFSET = 11.0
LOUD = {'A2': -24.4, 'A3': -24.0, 'C1': -23.0, 'L1': -24.2, 'E1': -23.2, 'E2': -24.0, 'E3': -24.5, 'VO': -25.3,
        'TAP': -26.7, 'WHOOSH': -18.9}
VOICE_TARGET = -15.0
SFX_TARGET = {'TAP': -27.0, 'WHOOSH': -28.0}

cues = json.load(open(os.path.join(V, 'cues.json')))
inputs = ['-i', os.path.join(V, 'music.mp3')]
parts, vox, sfx = [], [], []
for i, c in enumerate(cues, start=1):
    inputs += ['-i', c['file']]
    is_sfx = c['id'] in SFX_TARGET
    target = SFX_TARGET[c['id']] if is_sfx else VOICE_TARGET
    gain = target - LOUD[c['id']] + (c.get('gain', 0.0) if not is_sfx else 0.0)
    ms = int(round(c['at'] * 1000))
    chain = f'[{i}:a]aresample=48000,aformat=channel_layouts=stereo'
    if c.get('from'):
        chain += f",atrim=start={c['from']},asetpts=PTS-STARTPTS,afade=t=in:d=0.04"
    chain += f',volume={gain:.2f}dB,adelay={ms}|{ms},apad=whole_dur={DUR}[c{i}]'
    parts.append(chain)
    (sfx if is_sfx else vox).append(f'[c{i}]')

parts.append(f'{"".join(vox)}amix=inputs={len(vox)}:normalize=0:dropout_transition=0[vox]')
parts.append(f'{"".join(sfx)}amix=inputs={len(sfx)}:normalize=0:dropout_transition=0[sfx]')
parts.append('[vox]asplit=2[vox1][vox2]')
parts.append(f'[0:a]aresample=48000,aformat=channel_layouts=stereo,atrim=start={MUSIC_OFFSET}:end={MUSIC_OFFSET + DUR + 0.5},'
             f'asetpts=PTS-STARTPTS,volume=-4dB,afade=t=in:d=1.2,afade=t=out:st={DUR - 0.9}:d=0.9[mus]')
parts.append('[mus][vox1]sidechaincompress=threshold=0.045:ratio=3.5:attack=30:release=550:knee=6[musd]')
parts.append(f'[musd][vox2][sfx]amix=inputs=3:normalize=0:dropout_transition=0,atrim=end={DUR},'
             f'loudnorm=I=-14:TP=-1.5:LRA=11:linear=false[out]')
cmd = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error'] + inputs + ['-filter_complex', ';'.join(parts),
       '-map', '[out]', '-ar', '48000', '-ac', '2', os.path.join(V, 'audio.wav')]
subprocess.run(cmd, check=True)
print('audio.wav written')

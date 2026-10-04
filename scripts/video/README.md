# Demo video pipeline

How `citytour-demo.mp4` (68 s, 1920×1080, attached to the GitHub release) was made. Nothing in it is mocked: every
phone frame is a real emulator screenshot and every spoken line is the app's own ElevenLabs clip.

1. **Capture** (`cap.sh`): on-device screenshot bursts on the Pura 90 emulator (`snapshot_display` in a loop, ~7 fps,
   frames named by device epoch ns) while the app is driven with `uitest`. `take_e.sh` records the mid-story language
   switch, timing the menu taps from the live hilog.
2. **Edit list** (`edl.py`): maps each of the 2,040 output frames to a source screenshot, and places each voice clip at
   the moment the app played it (hilog `UTT_START` times; clips matched by the SHA-256 of their sentence).
3. **Motion design** (`render.html` + `render.js`): one HTML stage (phone mockup, captions, speech cards with
   translations, language chips, tap ripples) rendered frame by frame with headless Chrome (puppeteer-core).
4. **Audio** (`mix.py`): music bed generated with ElevenLabs Music, ducked under the voice with ffmpeg
   `sidechaincompress`, plus a closing line in the same voice and two generated SFX; mastered to −14 LUFS.
5. **Encode**: `ffmpeg -framerate 30 -i frames/%05d.jpg -i audio.wav -c:v libx264 -crf 17 -pix_fmt yuv420p -c:a aac`.

The Demo walk shown is SIMULATED (as labelled in the app); the timelapse segment is marked "sped up". Cover photos:
Wikimedia Commons, CC BY-SA 4.0 (credits in `data/ATTRIBUTION.md`).

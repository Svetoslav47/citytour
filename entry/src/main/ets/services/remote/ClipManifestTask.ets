/*
 * Parses a downloaded course's clip manifest (audio/manifest.json, ~0.5 MB for a full course) on a TaskPool worker,
 * not on the UI thread, and turns its course-relative clip paths into absolute sandbox paths.
 * TaskPool (API 9+): doc API参考/ArkTS/ArkTS_API/@ohos.taskpool (taskpool.execute with a @Concurrent function;
 * a @Concurrent function may use imported functions, its arguments and result are copied between threads).
 * If TaskPool is unavailable the parse falls back to the calling thread (still correct, just not offloaded).
 */
import { taskpool } from '@kit.ArkTS';
import { ClipEntry, parseClipManifest } from 'common';
import { Log } from '../../app/Log';
import { LogEvents } from 'common';

@Concurrent
function parseCourseClips(text: string, root: string): ClipEntry[] {
  const m = parseClipManifest(text);
  const out: ClipEntry[] = [];
  for (const e of m.entries) {
    const c: ClipEntry = {
      lang: e.lang, poiId: e.poiId, personaId: e.personaId, length: e.length, n: e.n, file: `${root}/${e.file}`,
      textSha256: e.textSha256, durationMs: e.durationMs
    };
    out.push(c);
  }
  return out;
}

/** Clip entries with absolute file paths under `root`; [] when the text is not a valid manifest. Never rejects. */
export async function courseClipsOffThread(text: string, root: string): Promise<ClipEntry[]> {
  try {
    const r = await taskpool.execute(parseCourseClips, text, root);
    return r as ClipEntry[];
  } catch (e) {
    Log.w(LogEvents.NARR_AUDIO, `event=course_clips_taskpool_fail ${Log.errKv(e as Object)} fallback=ui_thread`);
    try {
      return parseCourseClips(text, root);
    } catch (e2) {
      return [];
    }
  }
}

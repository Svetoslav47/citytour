/*
 * A downloaded course's pack (docs/SERVER.md §6): a SourcePackRepository (same
 * parsing, same per-file size + SHA-256 checks against the pack's own manifest.json, same lazy narrations and maps),
 * reading from a folder under filesDir/courses/<id>/<version>/. Every file was also verified
 * against the signed course manifest when it was downloaded (CourseStore).
 * The async read (pack load) uses fileIo.open/read Promises; the lazy sync read (narrations, maps) uses
 * openSync/readSync.
 * Docs: API参考/Core_File_Kit_文件基础服务/ArkTS_API/ohos_file_fs_文件管理_/js-apis-file-fs.
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { FileStore } from '../remote/FileStore';
import { PackSource, SourcePackRepository } from './SourcePackRepository';

export class FilePackSource implements PackSource {
  private readonly dir: string;

  /** dir: absolute folder of the pack, ending without '/'. */
  constructor(dir: string) {
    this.dir = dir;
  }

  label(): string {
    return 'file';
  }

  async read(file: string): Promise<Uint8Array> {
    const bytes = await FileStore.readBytes(`${this.dir}/${file}`);
    if (bytes === undefined) {
      throw new Error(`unreadable ${file}`);
    }
    return bytes;
  }

  readSync(file: string): Uint8Array {
    const path = `${this.dir}/${file}`;
    const st = fs.statSync(path);
    const f = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const out = new Uint8Array(st.size);
      let off = 0;
      while (off < st.size) {
        const buf = new ArrayBuffer(Math.min(256 * 1024, st.size - off));
        const n = fs.readSync(f.fd, buf, { offset: off });
        if (n <= 0) {
          break;
        }
        out.set(new Uint8Array(buf, 0, n), off);
        off += n;
      }
      if (off !== st.size) {
        throw new Error(`short read ${file}`);
      }
      return out;
    } finally {
      fs.closeSync(f);
    }
  }
}

export class FilePackRepository extends SourcePackRepository {
  constructor(dir: string) {
    super(new FilePackSource(dir));
  }
}

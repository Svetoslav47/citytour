/*
 * Async file helpers for downloaded courses and the runtime voice cache (docs/SERVER.md §6). Everything here is
 * Promise-based (Core File Kit fileIo async API, Crypto Architecture Kit Md async update/digest), so hashing and IO
 * of course files never block the UI thread (the app was once killed by THREAD_BLOCK_6S for main-thread work).
 * Every function resolves (never rejects): failures are reported as false / undefined / '' and logged by callers.
 * Docs: API参考/Core_File_Kit_文件基础服务/ArkTS_API/ohos_file_fs_文件管理_/js-apis-file-fs (open/read/write/close,
 * mkdir(path, recursion) 11+, rename, rmdir, unlink, access, listFile, stat, readText), js-apis-cryptoframework
 * (createMd SHA256, update/digest Promise), js-apis-util (TextEncoder/TextDecoder).
 */
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';

const CHUNK: number = 64 * 1024;

export function hexOf(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i++) {
    s += (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
  }
  return s;
}

export class FileStore {
  static async exists(path: string): Promise<boolean> {
    try {
      return await fs.access(path);
    } catch (e) {
      return false;
    }
  }

  static async mkdirs(path: string): Promise<boolean> {
    try {
      if (await FileStore.exists(path)) {
        return true;
      }
      await fs.mkdir(path, true);
      return true;
    } catch (e) {
      // Parallel downloads race to create the same folder: "File exists" (13900015) means another worker won.
      if ((e as BusinessError).code === 13900015 || await FileStore.exists(path)) {
        return true;
      }
      Log.w(LogEvents.COURSE, `event=mkdir_fail path=${path} ${Log.errKv(e as Object)}`);
      return false;
    }
  }

  /** rm -rf; true when the path is gone afterwards. */
  static async remove(path: string): Promise<boolean> {
    try {
      if (!(await FileStore.exists(path))) {
        return true;
      }
      const st = await fs.stat(path);
      if (st.isDirectory()) {
        await fs.rmdir(path);
      } else {
        await fs.unlink(path);
      }
      return true;
    } catch (e) {
      Log.w(LogEvents.COURSE, `event=remove_fail path=${path} ${Log.errKv(e as Object)}`);
      return false;
    }
  }

  static async rename(from: string, to: string): Promise<boolean> {
    try {
      await fs.rename(from, to);
      return true;
    } catch (e) {
      Log.w(LogEvents.COURSE, `event=rename_fail from=${from} to=${to} ${Log.errKv(e as Object)}`);
      return false;
    }
  }

  static async list(dir: string): Promise<string[]> {
    try {
      return await fs.listFile(dir);
    } catch (e) {
      return [];
    }
  }

  static async size(path: string): Promise<number> {
    try {
      const st = await fs.stat(path);
      return st.size;
    } catch (e) {
      return -1;
    }
  }

  /** Writes bytes to a new file (truncating), creating its folder. */
  static async writeBytes(path: string, data: ArrayBuffer): Promise<boolean> {
    let file: fs.File | undefined = undefined;
    try {
      const slash = path.lastIndexOf('/');
      if (slash > 0 && !(await FileStore.mkdirs(path.substring(0, slash)))) {
        return false;
      }
      file = await fs.open(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      let off = 0;
      while (off < data.byteLength) {
        const len = Math.min(CHUNK * 4, data.byteLength - off);
        const n = await fs.write(file.fd, data.slice(off, off + len));
        if (n <= 0) {
          return false;
        }
        off += n;
      }
      return true;
    } catch (e) {
      Log.w(LogEvents.COURSE, `event=write_fail path=${path} ${Log.errKv(e as Object)}`);
      return false;
    } finally {
      if (file !== undefined) {
        try {
          await fs.close(file);
        } catch (e) {
          // already closed
        }
      }
    }
  }

  static async writeText(path: string, text: string): Promise<boolean> {
    try {
      const enc = new util.TextEncoder();
      const bytes = enc.encodeInto(text);
      const buf = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
      return await FileStore.writeBytes(path, buf);
    } catch (e) {
      Log.w(LogEvents.COURSE, `event=write_text_fail path=${path} ${Log.errKv(e as Object)}`);
      return false;
    }
  }

  /** UTF-8 text of a file, or undefined. */
  static async readText(path: string): Promise<string | undefined> {
    const bytes = await FileStore.readBytes(path);
    if (bytes === undefined) {
      return undefined;
    }
    try {
      return util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(bytes);
    } catch (e) {
      return undefined;
    }
  }

  /** All bytes of a file (async, chunked), or undefined. */
  static async readBytes(path: string): Promise<Uint8Array | undefined> {
    let file: fs.File | undefined = undefined;
    try {
      const size = await FileStore.size(path);
      if (size < 0) {
        return undefined;
      }
      file = await fs.open(path, fs.OpenMode.READ_ONLY);
      const out = new Uint8Array(size);
      let off = 0;
      while (off < size) {
        const buf = new ArrayBuffer(Math.min(CHUNK * 4, size - off));
        const n = await fs.read(file.fd, buf, { offset: off });
        if (n <= 0) {
          break;
        }
        out.set(new Uint8Array(buf, 0, n), off);
        off += n;
      }
      return off === size ? out : undefined;
    } catch (e) {
      return undefined;
    } finally {
      if (file !== undefined) {
        try {
          await fs.close(file);
        } catch (e) {
          // already closed
        }
      }
    }
  }

  /** Lowercase hex SHA-256 of a file, read in chunks with async digest calls; '' on any error. */
  static async sha256File(path: string): Promise<string> {
    let file: fs.File | undefined = undefined;
    try {
      const md = cryptoFramework.createMd('SHA256');
      file = await fs.open(path, fs.OpenMode.READ_ONLY);
      let off = 0;
      while (true) {
        const buf = new ArrayBuffer(CHUNK);
        const n = await fs.read(file.fd, buf, { offset: off });
        if (n <= 0) {
          break;
        }
        await md.update({ data: new Uint8Array(buf, 0, n) });
        off += n;
      }
      const d = await md.digest();
      return hexOf(d.data);
    } catch (e) {
      Log.w(LogEvents.COURSE, `event=sha_fail path=${path} ${Log.errKv(e as Object)}`);
      return '';
    } finally {
      if (file !== undefined) {
        try {
          await fs.close(file);
        } catch (e) {
          // already closed
        }
      }
    }
  }

  /** Hex SHA-256 of bytes in memory (async digest). '' on error. */
  static async sha256Bytes(data: Uint8Array): Promise<string> {
    try {
      const md = cryptoFramework.createMd('SHA256');
      let off = 0;
      while (off < data.length) {
        const end = Math.min(data.length, off + CHUNK * 4);
        await md.update({ data: data.slice(off, end) });
        off = end;
      }
      const d = await md.digest();
      return hexOf(d.data);
    } catch (e) {
      return '';
    }
  }
}

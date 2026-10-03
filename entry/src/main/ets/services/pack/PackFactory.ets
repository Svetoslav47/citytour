/*
 * Chooses the PackRepository implementation (B3): the bundled offline Kraków pack (RawfilePackRepository) when it
 * is in the HAP, else the developer stub (3 stops) with a PACK_ERR warning. The stub path only exists while the
 * pack build (B2) is not merged; a pack that is present but broken is NOT replaced by the stub: it fails loudly.
 */
import { PackRepository } from '../../contracts/Ports';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { RawfilePackRepository } from './RawfilePackRepository';
import { StubPackRepository } from './StubPackRepository';

export class PackFactory {
  private static chosen: string = '';

  static create(): PackRepository {
    if (RawfilePackRepository.available()) {
      PackFactory.chosen = 'rawfile';
      return new RawfilePackRepository();
    }
    PackFactory.chosen = 'stub';
    Log.w(LogEvents.PACK_ERR, 'reason=no_rawfile_pack fallback=stub blocking=false');
    return new StubPackRepository();
  }

  /** Short name for the APP_START log line (`pack=…`). */
  static kind(): string {
    if (PackFactory.chosen === '') {
      PackFactory.chosen = RawfilePackRepository.available() ? 'rawfile' : 'stub';
    }
    return PackFactory.chosen;
  }
}

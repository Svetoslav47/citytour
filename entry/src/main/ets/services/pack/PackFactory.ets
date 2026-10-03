/*
 * Chooses the PackRepository implementation. T0 returns the inline stub; B3 switches this to
 * RawfilePackRepository (the offline Kraków pack). Owned by B after the T0 merge.
 */
import { PackRepository } from '../../contracts/Ports';
import { StubPackRepository } from './StubPackRepository';

export class PackFactory {
  static create(): PackRepository {
    return new StubPackRepository();
  }

  /** Short name for the APP_START log line (`pack=…`). */
  static kind(): string {
    return 'stub';
  }
}

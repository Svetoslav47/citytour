/*
 * Numbered sources with publisher and licence (DESIGN §3.8, attribution obligations of RISKS T14). Tapping a
 * row opens the link in the system browser (startAbility with the URL; doc uiability-intra-device-interaction /
 * "拉起浏览器"), never an in-app web view; if that fails (e.g. offline or no browser) a toast says so.
 */
import { common, Want } from '@kit.AbilityKit';
import { Log } from '../../app/Log';
import { LogEvents } from '../../app/LogEvents';
import { SourceRow } from '../../viewmodel/PlaceViewModel';
import { Radius, Space, Type } from '../common/Tokens';

@ComponentV2
export struct SourcesList {
  @Param rows: SourceRow[] = [];

  private open(row: SourceRow): void {
    if (row.url === '') {
      return;
    }
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: row.url
      };
      ctx.startAbility(want).then(() => {
        Log.i(LogEvents.APP_PAGE, `page=browser source=${row.id}`);
      }).catch((e: Object) => {
        Log.w(LogEvents.UNCAUGHT, `where=SourcesList.open source=${row.id} ${Log.errKv(e)}`);
        this.toastOffline();
      });
    } catch (e) {
      Log.w(LogEvents.UNCAUGHT, `where=SourcesList.open ${Log.errKv(e as Object)}`);
      this.toastOffline();
    }
  }

  private toastOffline(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.place_offline_link') });
    } catch (e) {
      // a toast is best effort
    }
  }

  build() {
    Column() {
      ForEach(this.rows, (row: SourceRow, idx: number) => {
        Row({ space: Space.S3 }) {
          Text(`${row.n}`)
            .fontSize(Type.CAPTION)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width(24)
            .height(24)
            .borderRadius(8)
            .backgroundColor($r('app.color.bg_surface_sunken'))
          Column({ space: 2 }) {
            Text(row.title)
              .fontSize(15)
              .lineHeight(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text(`${row.publisher} · ${row.license}`)
              .fontSize(Type.FOOTNOTE)
              .lineHeight(Type.FOOTNOTE_LH)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (row.url !== '') {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([$r('app.color.text_tertiary')])
          }
        }
        .id(`rowSource${row.n}`)
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .padding({ top: Space.S3, bottom: Space.S3 })
        .border({ width: { top: idx === 0 ? 0 : 1 }, color: $r('app.color.divider') })
        .accessibilityGroup(true)
        .accessibilityText($r('app.string.place_source_a11y', row.n, row.title, row.license))
        .onClick(() => this.open(row))
      }, (row: SourceRow) => `${row.n}:${row.id}`)
    }
    .width('100%')
    .padding({ left: Space.S4, right: Space.S4 })
    .borderRadius(Radius.LG)
    .backgroundColor($r('app.color.bg_surface'))
  }
}

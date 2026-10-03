/*
 * Settings building blocks (task B9, DESIGN §3.11 and the mockup docs/design/mockups/Settings.dc.html): grouped
 * cards on bg.surface (radius lg), overline section headers, 56 vp single-line / 72 vp two-line rows, a hairline
 * divider inset 16 vp, a pill segmented control (sunken track, accent-subtle selection) and footnotes.
 * Screen-reader state: accessibilitySelected / accessibilityChecked (API 13+, doc API参考/ArkUI_方舟UI框架/ArkTS组件/
 * 通用属性/无障碍属性/ts-universal-attributes-accessibility).
 * Every interactive row is at least 48 vp tall, is one accessibility group and says what it does. Font sizes are fp
 * (Type tokens), so they follow the system font scale; rows grow with their text.
 */
import { Radius, Size, Space, TABULAR, Type } from '../common/Tokens';

/** Back button + the large title (title1), as the other screens draw their own header. */
@ComponentV2
export struct SettingsHeader {
  @Param title: ResourceStr = '';
  @Param backId: string = 'btnSettingsBack';
  @Event onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(24)
            .fontColor([$r('app.color.text_primary')])
        }
        .id(this.backId)
        .width(Size.TOUCH)
        .height(Size.TOUCH)
        .accessibilityText($r('app.string.a11y_back'))
        .onClick(() => this.onBack())
      }
      .width('100%')
      .padding({ left: Space.S1 })

      Text(this.title)
        .fontSize(Type.TITLE1)
        .lineHeight(Type.TITLE1_LH)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .accessibilityLevel('yes')
        .margin({ left: Space.S4, right: Space.S4, top: Space.S1, bottom: 20 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@ComponentV2
export struct SectionHeader {
  @Param label: ResourceStr = '';

  build() {
    Text(this.label)
      .fontSize(Type.CAPTION)
      .lineHeight(Type.CAPTION_LH)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(Type.OVERLINE_SPACING)
      .textCase(TextCase.UpperCase)
      .fontColor($r('app.color.text_secondary'))
      .padding({ left: Space.S4, right: Space.S4 })
      .margin({ bottom: Space.S2 })
      .width('100%')
  }
}

/** A white card that groups rows (radius lg, clipped). */
@ComponentV2
export struct SettingsCard {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .borderRadius(Radius.LG)
    .clip(true)
    .backgroundColor($r('app.color.bg_surface'))
  }
}

@ComponentV2
export struct RowDivider {
  build() {
    Divider()
      .strokeWidth(1)
      .color($r('app.color.divider'))
      .margin({ left: Space.S4, right: Space.S4 })
  }
}

@ComponentV2
export struct Footnote {
  @Param text: ResourceStr = '';

  build() {
    Text(this.text)
      .fontSize(Type.FOOTNOTE)
      .lineHeight(Type.FOOTNOTE_LH)
      .fontColor($r('app.color.text_secondary'))
      .padding({ left: Space.S4, right: Space.S4 })
      .margin({ top: Space.S2 })
      .width('100%')
  }
}

/** Title, optional subtitle, optional value and chevron. Tappable when `tappable`. */
@ComponentV2
export struct NavRow {
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  @Param value: ResourceStr = '';
  @Param rowId: string = '';
  @Param tappable: boolean = true;
  @Param busy: boolean = false;
  @Event onTap: () => void = () => {};

  build() {
    Row({ space: Space.S2 }) {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(Type.BODY)
          .lineHeight(22)
          .fontColor($r('app.color.text_primary'))
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontFeature(TABULAR)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.busy) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.accent'))
      }
      if (this.value !== '') {
        Text(this.value)
          .fontSize(Type.CALLOUT)
          .lineHeight(Type.CALLOUT_LH)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.End)
          .constraintSize({ maxWidth: '55%' })
      }
      if (this.tappable) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('app.color.text_tertiary')])
      }
    }
    .id(this.rowId)
    .width('100%')
    .constraintSize({ minHeight: this.subtitle !== '' ? 72 : 56 })
    .padding({ left: Space.S4, right: this.tappable ? Space.S3 : Space.S4, top: Space.S2, bottom: Space.S2 })
    .accessibilityGroup(true)
    .stateStyles({
      pressed: { .backgroundColor(this.tappable ? $r('sys.color.interactive_pressed') : Color.Transparent) },
      normal: { .backgroundColor(Color.Transparent) }
    })
    .onClick(() => {
      if (this.tappable) {
        this.onTap();
      }
    })
  }
}

/** A switch row. The whole row toggles; disabled rows are greyed and say why in the subtitle. */
@ComponentV2
export struct ToggleRow {
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  @Param isOn: boolean = false;
  @Param rowId: string = '';
  @Param active: boolean = true;
  @Event onToggle: (on: boolean) => void = (on: boolean) => {};

  build() {
    Row({ space: Space.S3 }) {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(Type.BODY)
          .lineHeight(22)
          .fontColor(this.active ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .id(`${this.rowId}Switch`)
        .selectedColor($r('app.color.accent'))
        .enabled(this.active)
        .hitTestBehavior(HitTestMode.None)   // the row handles the tap (one target, no double toggle)
    }
    .id(this.rowId)
    .width('100%')
    .constraintSize({ minHeight: this.subtitle !== '' ? 72 : 56 })
    .padding({ left: Space.S4, right: Space.S4, top: Space.S2, bottom: Space.S2 })
    .accessibilityGroup(true)
    .accessibilityChecked(this.isOn)
    .onClick(() => {
      if (this.active) {
        this.onToggle(!this.isOn);
      }
    })
  }
}

/** One option of a segmented row (key + label). */
export class SegmentOption {
  key: string;
  label: Resource;
  a11y: Resource;

  constructor(key: string, label: Resource, a11y?: Resource) {
    this.key = key;
    this.label = label;
    this.a11y = a11y !== undefined ? a11y : label;
  }
}

/** DESIGN §3.11 SegmentButton look: a sunken pill track, the selected option in accent on accent-subtle. */
@ComponentV2
export struct SegmentRow {
  @Param title: ResourceStr = '';
  @Param options: SegmentOption[] = [];
  @Param selected: string = '';
  @Param idPrefix: string = 'seg';
  @Event onSelect: (key: string) => void = (key: string) => {};

  build() {
    Column({ space: 10 }) {
      if (this.title !== '') {
        Text(this.title)
          .fontSize(Type.BODY)
          .lineHeight(22)
          .fontColor($r('app.color.text_primary'))
      }
      Row() {
        ForEach(this.options, (o: SegmentOption) => {
          Stack() {
            Text(o.label)
              .fontSize(Type.CALLOUT)
              .lineHeight(Type.CALLOUT_LH)
              .fontWeight(FontWeight.Medium)
              .fontFeature(TABULAR)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(o.key === this.selected ? $r('app.color.accent') : $r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .width('100%')
              .constraintSize({ minHeight: 40 })
              .padding({ left: Space.S1, right: Space.S1 })
              .borderRadius(20)
              .backgroundColor(o.key === this.selected ? $r('app.color.accent_subtle') : Color.Transparent)
              .animation({ duration: 150, curve: Curve.Sharp })
          }
          .id(`${this.idPrefix}${o.key}`)
          .layoutWeight(1)
          .constraintSize({ minHeight: Size.TOUCH })
          .accessibilityText(o.a11y)
          .accessibilitySelected(o.key === this.selected)
          .onClick(() => this.onSelect(o.key))
        }, (o: SegmentOption) => o.key)
      }
      .width('100%')
      .padding({ left: Space.S1, right: Space.S1 })
      .borderRadius(24)
      .backgroundColor($r('app.color.bg_surface_sunken'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: Space.S4, right: Space.S4, top: 14, bottom: Space.S3 })
  }
}

/** A radio row for the language and strategy sub-pages. */
@ComponentV2
export struct RadioRow {
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  @Param selected: boolean = false;
  @Param rowId: string = '';
  @Param group: string = 'settings';
  @Event onSelect: () => void = () => {};

  build() {
    Row({ space: Space.S3 }) {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(Type.BODY)
          .lineHeight(22)
          .fontColor($r('app.color.text_primary'))
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize(Type.CALLOUT)
            .lineHeight(Type.CALLOUT_LH)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Radio({ value: this.rowId, group: this.group })
        .checked(this.selected)
        .radioStyle({ checkedBackgroundColor: $r('app.color.accent') })
        .hitTestBehavior(HitTestMode.None)
    }
    .id(this.rowId)
    .width('100%')
    .constraintSize({ minHeight: this.subtitle !== '' ? 72 : 56 })
    .padding({ left: Space.S4, right: Space.S4, top: Space.S2, bottom: Space.S2 })
    .accessibilityGroup(true)
    .accessibilitySelected(this.selected)
    .onClick(() => this.onSelect())
  }
}

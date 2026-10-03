/*
 * Design tokens (docs/DESIGN.md §4). Colours live in resources (base/ + dark/ color.json, so dark mode switches
 * automatically); this file holds the numeric tokens: type scale (fp), spacing and radii (vp).
 */
export class Space {
  static readonly S1: number = 4;
  static readonly S2: number = 8;
  static readonly S3: number = 12;
  static readonly S4: number = 16;   // page margin, card padding
  static readonly S5: number = 24;   // section gap
  static readonly S6: number = 32;
  static readonly S7: number = 48;   // touch target, sticky bar
  static readonly S8: number = 64;
}

export class Radius {
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 20;
  static readonly XL: number = 28;
}

/** Type scale: [size, line height] in fp (DESIGN §4.2). */
export class Type {
  static readonly DISPLAY: number = 34;
  static readonly DISPLAY_LH: number = 40;
  static readonly TITLE1: number = 28;
  static readonly TITLE1_LH: number = 34;
  static readonly TITLE2: number = 22;
  static readonly TITLE2_LH: number = 28;
  static readonly TITLE3: number = 18;
  static readonly TITLE3_LH: number = 24;
  static readonly BODY: number = 16;
  static readonly BODY_LH: number = 24;
  static readonly TRANSCRIPT: number = 18;
  static readonly TRANSCRIPT_LH: number = 28;
  static readonly CALLOUT: number = 14;
  static readonly CALLOUT_LH: number = 20;
  static readonly FOOTNOTE: number = 13;
  static readonly FOOTNOTE_LH: number = 18;
  static readonly CAPTION: number = 12;
  static readonly CAPTION_LH: number = 16;
  static readonly OVERLINE_SPACING: number = 0.6;
}

export class Size {
  static readonly TOUCH: number = 48;
  static readonly BUTTON_H: number = 48;
  static readonly ICON_BUTTON: number = 40;
  static readonly PAGE_MAX_W: number = 600;
}

/** Tabular figures for numbers that change (DESIGN §4.2). */
export const TABULAR: string = '"tnum" 1';

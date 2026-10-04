// Suite: SheetDetents.test - module under test: core/map/SheetDetents (Now Walking half-collapsible sheet, §3.6.3).
// Detent resolution from drag offset and fling velocity, rubber band, peek height with the safe area, map inset.
import { describe, it, expect } from '@ohos/hypium';
import {
  collapseProgress, detentOffset, dragOffset, expandedHeight, FLING_VPS, mapBottomInset, mapBoxHeight, PEEK_CONTENT_H, peekHeight,
  resolveDetent, RUBBER, SHEET_OVERLAP, SheetDetent, sheetTravel, toggleDetent, visibleSheetHeight
} from 'common';

function near(a: number, b: number): boolean {
  return Math.abs(a - b) < 1e-6;
}

export default function sheetDetentsTest() {
  describe('SheetDetents', () => {
    it('peek_height_clears_the_gesture_bar', 0, () => {
      expect(peekHeight(0)).assertEqual(PEEK_CONTENT_H);
      expect(peekHeight(28)).assertEqual(PEEK_CONTENT_H + 28);
      expect(peekHeight(Number.NaN)).assertEqual(PEEK_CONTENT_H);
      expect(peekHeight(-5)).assertEqual(PEEK_CONTENT_H);
    });
    it('travel_and_detent_offsets', 0, () => {
      expect(sheetTravel(500, 190)).assertEqual(310);
      expect(sheetTravel(100, 190)).assertEqual(0);   // never negative
      expect(detentOffset(SheetDetent.EXPANDED, 310)).assertEqual(0);
      expect(detentOffset(SheetDetent.COLLAPSED, 310)).assertEqual(310);
    });
    it('slow_release_picks_the_nearer_detent', 0, () => {
      expect(resolveDetent(100, 0, 300)).assertEqual(SheetDetent.EXPANDED);
      expect(resolveDetent(200, 0, 300)).assertEqual(SheetDetent.COLLAPSED);
      expect(resolveDetent(149, FLING_VPS - 1, 300)).assertEqual(SheetDetent.EXPANDED);
      expect(resolveDetent(151, -(FLING_VPS - 1), 300)).assertEqual(SheetDetent.COLLAPSED);
    });
    it('fling_wins_over_position', 0, () => {
      expect(resolveDetent(10, FLING_VPS, 300)).assertEqual(SheetDetent.COLLAPSED);    // short fast flick down
      expect(resolveDetent(290, -FLING_VPS, 300)).assertEqual(SheetDetent.EXPANDED);   // short fast flick up
      expect(resolveDetent(290, -2000, 300)).assertEqual(SheetDetent.EXPANDED);
    });
    it('no_travel_or_bad_input_stays_expanded', 0, () => {
      expect(resolveDetent(50, 0, 0)).assertEqual(SheetDetent.EXPANDED);
      expect(resolveDetent(Number.NaN, Number.NaN, 300)).assertEqual(SheetDetent.EXPANDED);
    });
    it('drag_follows_finger_with_rubber_band', 0, () => {
      expect(dragOffset(0, 120, 300)).assertEqual(120);
      expect(dragOffset(300, -50, 300)).assertEqual(250);
      expect(near(dragOffset(0, -40, 300), -40 * RUBBER)).assertTrue();
      expect(near(dragOffset(300, 40, 300), 300 + 40 * RUBBER)).assertTrue();
    });
    it('toggle_and_progress', 0, () => {
      expect(toggleDetent(SheetDetent.EXPANDED)).assertEqual(SheetDetent.COLLAPSED);
      expect(toggleDetent(SheetDetent.COLLAPSED)).assertEqual(SheetDetent.EXPANDED);
      expect(collapseProgress(150, 300)).assertEqual(0.5);
      expect(collapseProgress(-20, 300)).assertEqual(0);
      expect(collapseProgress(400, 300)).assertEqual(1);
      expect(collapseProgress(10, 0)).assertEqual(0);
    });
    it('map_inset_follows_the_visible_sheet', 0, () => {
      expect(visibleSheetHeight(500, 0)).assertEqual(500);
      expect(visibleSheetHeight(500, 310)).assertEqual(190);
      expect(visibleSheetHeight(500, -10)).assertEqual(500);   // rubber band above expanded
      // page 844, peek 190: map box 678; collapsed only the peek's rounded top covers the map
      const box = mapBoxHeight(844, 190);
      expect(box).assertEqual(844 - 190 + SHEET_OVERLAP);
      expect(mapBottomInset(visibleSheetHeight(500, 310), 844, box)).assertEqual(SHEET_OVERLAP);
      expect(mapBottomInset(visibleSheetHeight(500, 0), 844, box)).assertEqual(500 - 190 + SHEET_OVERLAP);
      expect(mapBottomInset(Number.NaN, 844, box)).assertEqual(0);
      expect(mapBoxHeight(100, 190)).assertEqual(0);
    });
    it('expanded_height_matches_the_design_map_box', 0, () => {
      expect(expandedHeight(844, 340, 190)).assertEqual(844 - 340 + SHEET_OVERLAP);
      expect(expandedHeight(300, 340, 190)).assertEqual(190);   // never below the peek
    });
  });
}

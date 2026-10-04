/*
 * Pushes the home-screen "Next stop" card (B14, DESIGN §3.13, ARCHITECTURE §2.8) from the running app.
 * Subscribes to TourControl snapshots for the app's lifetime (started in Index, like the summary recorder; it keeps
 * running in the background during a tour thanks to the continuous task). core/widget/CardModel decides what the card
 * shows and when to push (events, >= 50 m distance steps, never per fix). Each push lists this app's cards on the
 * home screen (formProvider.getPublishedRunningFormInfos, API 20) and updates each one (formProvider.updateForm,
 * API 9; doc js-apis-app-form-formprovider), so no form id is stored. Texts are localised here with the app's
 * resources. Logs: WIDGET event=push forms=n mode= stop=k/n src=demo|real, or event=push_fail / list_fail.
 */
import { formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { EngineSnapshot } from 'common';
import { Lang } from 'common';
import { AppContainer } from '../app/AppContainer';
import { Log } from '../app/Log';
import { LogEvents } from 'common';
import { CardMode, CardState, cardStateFor, shouldPushCard } from 'common';
import { localName } from './Format';
import { findTour, poiName } from './PackView';

/** form_config.json card name. */
const CARD_NAME: string = 'NextStop';
const LIST_TIMEOUT_MS: number = 3000;
const WALK_MPS: number = 1.3;

export class WidgetBridge {
  private static unsubscribe: (() => void) | undefined = undefined;
  private static lang: () => Lang = () => Lang.EN;
  private static last: CardState | undefined = undefined;
  private static lastPushMs: number = 0;

  /** Subscribes once (Index.aboutToAppear). `lang` = the text language for tour and place names. Never throws. */
  static start(lang: () => Lang): void {
    WidgetBridge.lang = lang;
    if (WidgetBridge.unsubscribe !== undefined) {
      return;
    }
    try {
      WidgetBridge.unsubscribe =
        AppContainer.tourControl().subscribe((s: EngineSnapshot) => WidgetBridge.onSnapshot(s));
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=WidgetBridge.start ${Log.errKv(e as Object)}`);
    }
  }

  private static onSnapshot(s: EngineSnapshot): void {
    try {
      const next = cardStateFor(s);
      const now = Date.now();
      if (!shouldPushCard(WidgetBridge.last, next, WidgetBridge.lastPushMs, now)) {
        return;
      }
      WidgetBridge.last = next;
      WidgetBridge.lastPushMs = now;
      WidgetBridge.push(next);
    } catch (e) {
      Log.e(LogEvents.UNCAUGHT, `where=WidgetBridge.onSnapshot ${Log.errKv(e as Object)}`);
    }
  }

  private static str(name: string, ...args: (string | number)[]): string {
    const ctx = AppContainer.context();
    if (ctx === undefined) {
      return '';
    }
    try {
      return args.length > 0 ? ctx.resourceManager.getStringByNameSync(name, ...args) :
        ctx.resourceManager.getStringByNameSync(name);
    } catch (e) {
      Log.w(LogEvents.WIDGET, `event=string_fail name=${name} ${Log.errKv(e as Object)}`);
      return '';
    }
  }

  private static distanceText(m: number): string {
    if (!Number.isFinite(m)) {
      return '';
    }
    return m >= 1000 ? WidgetBridge.str('fmt_km', (m / 1000).toFixed(1)) : WidgetBridge.str('fmt_m', Math.round(m));
  }

  /** Card texts for the state (already localised). */
  private static texts(c: CardState): Record<string, string> {
    const pack = AppContainer.packRepository();
    const lang = WidgetBridge.lang();
    const tour = findTour(pack, c.tourId);
    const tourTitle = tour === undefined ? 'CityTour' : localName(tour.titles, lang);
    const o: Record<string, string> = {
      'overline': 'CityTour', 'title': '', 'big': '', 'foot': '', 'demo': c.demo ? '1' : '0', 'mode': c.mode
    };
    switch (c.mode) {
      case CardMode.HEADING:
        o['overline'] = WidgetBridge.str('widget_next', c.stopNumber, c.totalStops);
        o['title'] = poiName(pack, c.poiId, lang);
        o['big'] = WidgetBridge.distanceText(c.distanceM);
        o['foot'] = c.paused ? WidgetBridge.str('walk_paused') : Number.isFinite(c.distanceM) ?
          `~${WidgetBridge.str('fmt_min', Math.max(1, Math.round(c.distanceM / WALK_MPS / 60)))}` : '';
        break;
      case CardMode.AT_STOP:
        o['overline'] = WidgetBridge.str('widget_here', c.stopNumber, c.totalStops);
        o['title'] = poiName(pack, c.poiId, lang);
        o['foot'] = c.paused ? WidgetBridge.str('walk_paused') : WidgetBridge.str('widget_at_stop');
        break;
      case CardMode.COMPLETE:
      case CardMode.ENDED:
        o['overline'] = tourTitle;
        o['title'] = WidgetBridge.str(c.mode === CardMode.COMPLETE ? 'walk_tour_complete' : 'walk_tour_ended');
        o['big'] = `${c.visited}/${c.totalStops}`;
        o['foot'] = WidgetBridge.str('widget_stops_heard');
        break;
      default:
        o['title'] = tour === undefined ? WidgetBridge.str('widget_idle_title') : tourTitle;
        o['foot'] = WidgetBridge.str('widget_idle_foot');
        break;
    }
    return o;
  }

  private static push(c: CardState): void {
    const data = formBindingData.createFormBindingData(WidgetBridge.texts(c));
    const src = c.demo ? 'demo' : 'real';
    const timeout = new Promise<formInfo.RunningFormInfo[]>((resolve) => {
      setTimeout(() => resolve([]), LIST_TIMEOUT_MS);
    });
    Promise.race([formProvider.getPublishedRunningFormInfos(), timeout])
      .then((forms: formInfo.RunningFormInfo[]) => {
        const mine = forms.filter((f: formInfo.RunningFormInfo) => f.formName === CARD_NAME);
        mine.forEach((f: formInfo.RunningFormInfo) => {
          formProvider.updateForm(f.formId, data).catch((e: BusinessError) => {
            Log.w(LogEvents.WIDGET, `event=push_fail id=${f.formId} code=${e.code}`);
          });
        });
        Log.i(LogEvents.WIDGET, `event=push forms=${mine.length} mode=${c.mode} stop=${c.stopNumber}/${c.totalStops} ` +
          `distM=${Number.isFinite(c.distanceM) ? c.distanceM : 'nan'} src=${src}`);
      })
      .catch((e: BusinessError) => {
        Log.w(LogEvents.WIDGET, `event=list_fail code=${e.code} src=${src}`);
      });
  }
}

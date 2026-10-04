/*
 * Form provider for the home-screen "Next stop" card (B14, ARCHITECTURE §2.8; doc arkts-ui-widget-active-refresh).
 * onAddForm returns the idle card; the running app pushes live content itself (services/form/WidgetBridge:
 * formProvider.getPublishedRunningFormInfos + updateForm, API 20), so no form id has to be stored here.
 * Runs in the form extension process: hilog directly with the app's domain/tag (app/Log needs no context either).
 */
import { formBindingData, FormExtensionAbility } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { Log } from '../app/Log';
import { LogEvents } from 'common';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    let title = 'CityTour';
    let foot = '';
    try {
      const rm = this.context.resourceManager;
      title = rm.getStringByNameSync('widget_idle_title');
      foot = rm.getStringByNameSync('widget_idle_foot');
    } catch (e) {
      Log.e(LogEvents.WIDGET, `event=add_strings ${Log.errKv(e as Object)}`);
    }
    Log.i(LogEvents.WIDGET, `event=add src=launcher`);
    const obj: Record<string, string> = {
      'overline': 'CityTour', 'title': title, 'big': '', 'foot': foot, 'demo': '0', 'mode': 'idle'
    };
    return formBindingData.createFormBindingData(obj);
  }

  onUpdateForm(formId: string): void {
    // Periodic refresh is off (form_config updateEnabled=false); the app pushes on tour events.
    Log.i(LogEvents.WIDGET, `event=onUpdateForm id=${formId}`);
  }

  onRemoveForm(formId: string): void {
    Log.i(LogEvents.WIDGET, `event=remove id=${formId}`);
  }
}

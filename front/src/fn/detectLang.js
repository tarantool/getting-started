// @flow
import { STORAGE_TUTORIAL_LANG } from '../constants';

export type TutorialLang = 'en' | 'ru';
export const langs: TutorialLang[] = ['en', 'ru'];

export const detectLang = (): TutorialLang => {
  const browserLang = (localStorage && localStorage.getItem(STORAGE_TUTORIAL_LANG))
    || window.navigator.language.slice(0, 2).toLowerCase();

  return langs.includes(browserLang) ? ((browserLang: any): TutorialLang) : langs[0];
}

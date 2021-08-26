// @flow
import {
  combine,
  createStore,
  createEffect,
  createEvent,
  guard,
  forward
} from 'effector';
import { loadTutorialContent, loadPopupContent } from '../fn/loadContent';
import {
  splitMarkdownSections,
  type ParsedSections
} from '../fn/splitMarkdown';
import { detectLang, type TutorialLang } from '../fn/detectLang';
import { PROJECT_NAME, STORAGE_TUTORIAL_LANG } from '../constants';

export type WelcomeModalState = 'loading' | 'visible' | 'hidden';

const $tutorialSections = createStore<ParsedSections | null>(null);
const $tutorialSectionsLoding = createStore<bool>(false);
const $tutorialSectionsError = createStore<string | null>(null);
const $welcomeModalContent = createStore<string | null>(null);
export const $currentLanguage = createStore<TutorialLang | null>(null);
const $currentSection = createStore<string | null>(null);
const $welcomeModalState = createStore<WelcomeModalState>('loading');

export const sectionChange = createEvent<[TutorialLang, string]>('Changing tutorial lang & section');
export const welcomeModalClose = createEvent<mixed>();
export const sectionsErrorModalClose = createEvent<mixed>();
export const setLanguage = createEvent<TutorialLang>();
export const saveDataToAnalytics = createEvent<void>();

export const $welcomeModal = combine({
  state: $welcomeModalState,
  content: $welcomeModalContent
});

const analyticsFx = createEffect(section => {
  const pageviewEvent = {
    type: 'pageview',
    url: window.location.pathname
  };
  window.tarantool_enterprise_core.analyticModule.sendEvent(pageviewEvent);
});


export const $tutorial = combine({
  currentLanguage: $currentLanguage,
  currentSection: $currentSection,
  tutorialSections: $tutorialSections,
  tutorialSectionsError: $tutorialSectionsError,
  tutorialSectionsLoding: $tutorialSectionsLoding
});

const detectLangFx = createEffect<void, TutorialLang, void>({
  handler: detectLang
});

export const loadTutorialFx = createEffect<
  TutorialLang | null,
  ParsedSections | null,
  Error
>({
  handler: async lang => {
    if (!lang) return null;
    return await loadTutorialContent(lang)
      .then(text => splitMarkdownSections(text, PROJECT_NAME, lang));
  }
});

export const loadPopupFx = createEffect<
  TutorialLang | null,
  string | null,
  Error
>({
  async handler(lang) {
    if (!lang) return null;
    return await loadPopupContent(lang);
  }
});

const storeLanguageFx = createEffect<TutorialLang, void, Error>({
  handler: lang => localStorage
    && localStorage.setItem(STORAGE_TUTORIAL_LANG, lang)
});

// init
$currentLanguage
  .on(detectLangFx.doneData, (_, l) => l)
  .on(setLanguage, (_, l) => l)
  .on(sectionChange, (_, [l]) => l);

$currentSection
  .on(sectionChange, (_, [l, v]) => v);

$welcomeModalContent
  .on(loadPopupFx.doneData, (_, str) => str);

$welcomeModalState
  .on(loadPopupFx.done, () => 'visible')
  .on(loadPopupFx.fail, () => 'hidden')
  .on(welcomeModalClose, () => 'hidden');

$tutorialSections
  .on(loadTutorialFx.doneData, (_, v) => v);

$tutorialSectionsError
  .on(loadTutorialFx.failData, (_, err) => err && err.message)
  .on(sectionsErrorModalClose, () => null);

$tutorialSectionsLoding
  .on(loadTutorialFx.doneData, () => false)
  .on(loadTutorialFx.failData, () => false)
  .on(loadTutorialFx, () => true);

guard<TutorialLang | null>({
  source: $currentLanguage,
  filter: lang => !!lang,
  target: loadTutorialFx
});

guard<TutorialLang | null>({
  source: $currentLanguage,
  filter: lang => !!lang,
  target: loadPopupFx
});

forward({ from: setLanguage, to: storeLanguageFx });

detectLangFx();

forward({
  from: saveDataToAnalytics,
  to: analyticsFx
});

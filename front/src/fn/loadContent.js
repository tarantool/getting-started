// @flow
import { updateImagesPaths } from './splitMarkdown';
import{ type TutorialLang } from './detectLang';

const prefix = process.env.REACT_APP_MD_URL || '';

const loadMDFile = (fileName: string) =>
  fetch(`${prefix}/${fileName}`)
    .then(response => {
      const { status, statusText } = response;

      if(status !== 200) {
        throw new Error(`${status} ${statusText}`);
      }

      return response.text();
    })
    .then(text => updateImagesPaths(text, prefix));

export const loadTutorialContent = (lang: TutorialLang) => loadMDFile(lang + '/index.md');

export const loadPopupContent = (lang: TutorialLang) => loadMDFile(lang + '/popup.md');

// @flow
import * as React from 'react';
import { withRouter } from 'react-router-dom';
import type { History } from 'react-router';
import { DropdownItem } from '@tarantool.io/ui-kit';
import { useStore } from 'effector-react';
import { Select } from './Select';
import { langs } from '../fn/detectLang';
import { $currentLanguage, setLanguage } from '../store';

type Props = {
  className?: string,
  history: History
};

const items = langs.map(lang => (
  <DropdownItem onClick={() => setLanguage(lang)}>{lang.toUpperCase()}</DropdownItem>
));

export const LangSelect = withRouter((props: Props) => {
  const lang = useStore($currentLanguage);

  if (!lang) {
    return null;
  }

  return (
    <Select {...props} items={items} text={lang.toUpperCase()} size='l' />
  );
});

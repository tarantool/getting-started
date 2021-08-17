// @flow
import React from 'react';
import { css, cx } from 'emotion';
import { Button, Markdown, Modal } from '@tarantool.io/ui-kit';
import { useStore } from 'effector-react';
import { LangSelect } from './LangSelect';
import { $welcomeModal, loadPopupFx, welcomeModalClose } from '../store';
import { getMarkdownHeading } from '../fn/splitMarkdown';

const styles = {
  langSwitcher: css`
    margin-left: 30px;
  `
};

export const WelcomePopup = () => {
  const { state, content } = useStore($welcomeModal);
  const heading = getMarkdownHeading(content);

  return (
    <Modal
      footerControls={[
        <Button text='Приступить' size='l' intent='primary' onClick={welcomeModalClose} />
      ]}
      onClose={welcomeModalClose}
      title={[heading, <LangSelect className={styles.langSwitcher} />]}
      visible={state === 'visible'}
      wide
    >
      <Markdown text={content ? content.slice(content.indexOf('\n')) : ''} />
    </Modal>
  );
}

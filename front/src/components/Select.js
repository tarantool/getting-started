// @flow
import * as React from 'react';
import {
  Button,
  DropdownDivider,
  IconChevronDown,
  withDropdown
} from '@tarantool.io/ui-kit';

const DropdownButton = withDropdown(Button);

type Props = {
  title?: string,
  text?: string,
  className?: string,
  children?: React.Node,
  items: React.Node[],
  disabled?: boolean
};

export const Select = (
  props: Props
) => (
  <DropdownButton
    iconRight={IconChevronDown}
    {...props}
  />
);

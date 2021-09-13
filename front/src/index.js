// @flow
import * as React from 'react';
import { matchPath } from 'react-router';
import { SVGImage } from '@tarantool.io/ui-kit';
import { ConnectedApp } from './components/App';
import menuIcon from './menu-icon.svg';
import { PROJECT_NAME } from './constants';
import { sectionChange } from './store';

const projectPath = path => `/${PROJECT_NAME}/${path}`;
const { tarantool_enterprise_core } = window;

tarantool_enterprise_core.history.listen(
  ({ pathname }) => {
    const match = matchPath(pathname, {
      path: `/${PROJECT_NAME}/:langId/:sectionId`,
      exact: true,
      strict: false
    })

    if (match && match.params) {
      sectionChange([match.params.langId, match.params.sectionId])
    }
  }
);

if (tarantool_enterprise_core.history.location.pathname.indexOf(`/${PROJECT_NAME}`) !== 0) {
  tarantool_enterprise_core.history.replace(projectPath(''));
}

tarantool_enterprise_core.register(
  PROJECT_NAME,
  [
    {
      label: 'Tutorial',
      path: `/${PROJECT_NAME}/`,
      icon: <SVGImage glyph={menuIcon} />
    }
  ],
  ConnectedApp,
  'react',
  null
);


(function() {
  var id='3939b3f2jxr6jjtxhvp86csrxyuxz9gucr3';
  var js=document.createElement('script');
  js.setAttribute('type','text/javascript');
  js.setAttribute('src','//deploy.mopinion.com/js/pastease.js');
  js.async=true;document.getElementsByTagName('head')[0].appendChild(js);
  var t=setInterval(
    function(){
      try{
        window.Pastease.load(id);
        clearInterval(t)
      } catch(e) {

      }
    },50
  )
})();

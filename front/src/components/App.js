// @flow
import * as React from 'react';
import { connect } from 'effector-react';
import { Router, Switch, Route, Redirect } from 'react-router-dom';
import type { Location } from 'react-router';
import {
  PageLayoutWithRef,
  SplashError,
  SectionPreloader
} from '@tarantool.io/ui-kit';
import { detectLang, type TutorialLang } from '../fn/detectLang';
import { type ParsedSections } from '../fn/splitMarkdown';
import { getScrollableParent } from '../fn/getScrollableParent';
import { LangSelect } from '../components/LangSelect';
import { TutorialLayout } from '../components/TutorialLayout';
import { WelcomePopup } from '../components/WelcomePopup';
import { PROJECT_NAME } from '../constants';
import { $tutorial } from '../store';

const projectPath = (lang: string, path: string) => `/${PROJECT_NAME}/${lang}/${path}`;
const { components: { AppTitle }, history } = window.tarantool_enterprise_core;

type Props = {
  location: Location,
  tutorialSections?: ParsedSections,
  tutorialSectionsLoding: bool,
  currentLanguage?: TutorialLang,
  currentSection?: string,
  tutorialSectionsError: string | null
};

export class App extends React.Component<Props> {
  pageLayoutRef = React.createRef<HTMLElement>();

  componentDidUpdate(prevProps: Props) {
    if (this.props.location !== prevProps.location) {
      if (this.pageLayoutRef && this.pageLayoutRef.current) {
        const scrollableParent = getScrollableParent(this.pageLayoutRef.current);
        scrollableParent.scrollTo(0, 0);
      }
    }
  }

  render() {
    const {
      currentLanguage,
      currentSection,
      tutorialSections,
      tutorialSectionsError,
      tutorialSectionsLoding
    } = this.props;

    if (tutorialSectionsLoding) {
      return <SectionPreloader />;
    }

    if (tutorialSectionsError) {
      return (
        <SplashError
          title='Ошибка загрузки руководства'
          details={tutorialSectionsError}
          description={<>
            Но вы можете воспользоваться сервисом
          </>}
        />
      );
    }

    return tutorialSections
      ? (
        <Router history={history}>
          <PageLayoutWithRef heading='Tutorial' topRightControls={[<LangSelect />]} ref={this.pageLayoutRef}>
            <AppTitle title='Tutorial' />
            <WelcomePopup />
            <Switch>
              {currentLanguage && (
                <Route
                  path={projectPath(currentLanguage, ':sectionId')}
                  render={({ match: { params: { sectionId } } }) => {
                    const sectionIndex = tutorialSections.findIndex(
                      ({ id }) => id === sectionId
                    );

                    if (sectionIndex === -1) {
                      return (
                        <Redirect
                          to={projectPath(currentLanguage, tutorialSections[0].id)}
                          push={false}
                        />
                      );
                    }

                    return (
                      <TutorialLayout
                        sections={tutorialSections}
                        selectedSection={parseInt(sectionIndex, 10)}
                      />
                    )
                  }}
                />
              )}
              <Route
                render={() => (
                  <Redirect
                    to={projectPath(currentLanguage || detectLang(), currentSection || tutorialSections[0].id)}
                    push={false}
                  />
                )}
              />
            </Switch>
          </PageLayoutWithRef>
        </Router>
      )
      : 'Fail'
  }
}

export const ConnectedApp = connect(App)($tutorial);

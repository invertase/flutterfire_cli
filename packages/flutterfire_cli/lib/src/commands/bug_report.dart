/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'package:issue/issue.dart';

import '../flutter_app.dart';
import 'base.dart';

class BugReportCommand extends FlutterFireCommand {
  BugReportCommand(FlutterApp? flutterApp) : super(flutterApp);

  @override
  final String description = 'Generate a bug report for your project.';

  @override
  final String name = 'bug-report';

  @override
  Future<void> run() async {
    commandRequiresFlutterApp();

    final config = IssueConfig(
      template: FlutterFireIssueTemplate(),
      tracker: GitHubIssueTracker(
        organization: 'firebase',
        repository: 'flutterfire',
        template: '---bug-report.md',
      ),
    );

    try {
      await buildIssueAndOpen(config);
    } on UserInterruptException {
      logger.stdout('Aborting $name.');
    }
  }
}

class FlutterFireIssueTemplate extends IssueTemplate {
  FlutterFireIssueTemplate()
      : super(
          titleTemplate: '🐛 [PLUGIN_NAME_HERE] Your issue title here',
          labels: ['Needs Attention', 'type: bug'],
          heading: '## Bug report',
          sections: [
            const DescriptionIssueSection(),
            CombinedIssueSection(
              prompt: 'Issue Details',
              sections: const [
                StepsToReproduceIssueSection(),
                ExpectedBehaviorIssueSection(),
                SampleProjectIssueSection(),
              ],
            ),
            const DividerIssueSection(),
            const AdditionalContextIssueSection(),
            const DividerIssueSection(),
            FlutterDoctorIssueSection(),
            const DividerIssueSection(),
            FlutterDependenciesIssueSection(),
          ],
        );
}

class SampleProjectIssueSection extends IssueSection {
  const SampleProjectIssueSection()
      : super.userDriven(
          heading: '### Sample project',
          content:
              'Providing a minimal example project which demonstrates the bug '
              'in isolation from your main App _greatly_ enhances the chance '
              'of a timely fix.\n'
              'Please link to the public repository URL.',
        );
}

class FlutterDependenciesIssueSection extends DetailsIssueSection {
  FlutterDependenciesIssueSection()
      : super.commandDriven(
          command: ['flutter', 'pub', 'deps', '--', '--style=compact'],
          heading: '### Flutter dependencies',
          details: '''
```bash
$kPlaceholder
```''',
          placeholder: kPlaceholder,
          summary: 'Click To Expand',
        );

  static const kPlaceholder = 'PASTE FLUTTER DEPENDENCIES OUTPUT HERE';
}

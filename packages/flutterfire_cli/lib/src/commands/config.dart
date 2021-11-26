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

import 'package:ansi_styles/ansi_styles.dart';
import 'package:interact/interact.dart' as interact;

import '../common/exception.dart';
import '../common/platform.dart';
import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../firebase/firebase_project.dart';
import '../flutter_app.dart';

import 'base.dart';

class ConfigCommand extends FlutterFireCommand {
  ConfigCommand(FlutterApp flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
    argParser.addOption(
      'out',
      valueHelp: 'filePath',
      defaultsTo: 'lib${currentPlatform.pathSeparator}firebase_options.dart',
      abbr: 'o',
      help: 'The output file path of the Dart file that will be generated with '
          'your Firebase configuration options.',
    );
    argParser.addOption(
      'ios-bundle-id',
      valueHelp: 'bundleIdentifier',
      abbr: 'i',
      help: 'The bundle identifier of your iOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "ios" folder (if it exists).',
    );
    argParser.addOption(
      'macos-bundle-id',
      valueHelp: 'bundleIdentifier',
      abbr: 'm',
      help: 'The bundle identifier of your macOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "macos" folder (if it exists).',
    );
    argParser.addOption(
      'android-app-id',
      valueHelp: 'applicationId',
      abbr: 'a',
      help: 'The application id of you Android app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists).',
    );
  }

  @override
  final String name = 'configure';

  @override
  List<String> aliases = <String>[
    'c',
    'config',
  ];

  @override
  final String description = 'Configure Firebase for your Flutter app. This '
      'command will fetch Firebase configuration for you and generate a '
      'Dart file with prefilled FirebaseOptions you can use.';

  Future<FirebaseProject> _promptCreateFirebaseProject() async {
    final newProjectId = interact.Input(
      prompt:
          'Enter a project id for your new Firebase project (e.g. ${AnsiStyles.cyan('my-cool-project')})',
      validator: (String x) {
        if (RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(x)) {
          return true;
        } else {
          // ignore: only_throw_errors
          throw interact.ValidationError(
            'Firebase project ids must be lowercase and contain only alphanumeric and dash characters.',
          );
        }
      },
    ).interact();
    final creatingProjectSpinner = interact.Spinner(
      icon: AnsiStyles.green('✔'),
      rightPrompt: (done) {
        if (!done) {
          return 'Creating new Firebase project ${AnsiStyles.cyan(newProjectId)}...';
        }
        return 'New Firebase project ${AnsiStyles.cyan(newProjectId)} created succesfully.';
      },
    ).interact();
    final newProject = await firebase.createProject(
      projectId: newProjectId,
      account: accountEmail,
    );
    creatingProjectSpinner.done();
    return newProject;
  }

  Future<FirebaseProject> _selectFirebaseProject() async {
    var selectedProjectId = projectId;
    selectedProjectId ??= await firebase.getDefaultFirebaseProjectId();
    List<FirebaseProject>? firebaseProjects;
    final fetchingProjectsSpinner = interact.Spinner(
      icon: AnsiStyles.green('✔'),
      rightPrompt: (done) {
        if (!done) {
          return 'Fetching available Firebase projects...';
        }
        final baseMessage =
            'Found ${AnsiStyles.cyan('${firebaseProjects!.length}')} Firebase projects.';
        if (selectedProjectId != null) {
          return '$baseMessage Selecting project ${AnsiStyles.cyan(selectedProjectId)}.';
        }
        return baseMessage;
      },
    ).interact();
    firebaseProjects = await firebase.getProjects(account: accountEmail);
    fetchingProjectsSpinner.done();
    if (selectedProjectId != null) {
      return firebaseProjects.firstWhere(
        (project) => project.projectId == selectedProjectId,
        orElse: () {
          throw FirebaseProjectNotFoundException(selectedProjectId!);
        },
      );
    }

    // We can't prompt to select a Firebase in a CI environmet.
    if (isCI) {
      throw FirebaseProjectRequiredException();
    }

    // No projects to choose from so lets
    // prompt to create straight away.
    if (firebaseProjects.isEmpty) {
      return _promptCreateFirebaseProject();
    }

    final choices = <String>[
      ...firebaseProjects.map(
        (p) => '${p.projectId} (${p.displayName})',
      ),
      AnsiStyles.green('<create a new project>'),
    ];

    final selectedChoiceIndex = interact.Select(
      prompt: 'Select a Firebase project to build your configuration from',
      options: choices,
    ).interact();
    // Last choice is to create a new project.
    if (selectedChoiceIndex == choices.length - 1) {
      return _promptCreateFirebaseProject();
    }

    return firebaseProjects[selectedChoiceIndex];
  }

  Map<String, bool> _selectPlatforms() {
    final selectedPlatforms = <String, bool>{
      kAndroid: flutterApp.android,
      kIos: flutterApp.ios,
      kMacos: flutterApp.macos,
      kWeb: flutterApp.web,
    };
    final answers = interact.MultiSelect(
      prompt:
          'Which platforms should your FirebaseOptions configuration support?',
      options: selectedPlatforms.keys.toList(),
      defaults: selectedPlatforms.values.toList(),
    ).interact();
    var index = 0;
    for (final key in selectedPlatforms.keys) {
      if (answers.contains(index)) {
        selectedPlatforms[key] = true;
      } else {
        selectedPlatforms[key] = false;
      }
      index++;
    }
    return selectedPlatforms;
  }

  @override
  Future<void> run() async {
    final selectedFirebaseProject = await _selectFirebaseProject();
    final selectedPlatforms = _selectPlatforms();
    // print(selectedPlatforms);

    // final firebaseApps =
    // await firebase.getApps(project: 'react-native-firebase-testing');
    // final newApp = await firebase.createAppleApp(
    //   project: project,
    //   displayName: 'ffclitest2ios',
    //   bundleId: 'com.flutterfire.cli.test',
    // );
    // print(newApp);
    // print(newApp.appId);
    // print(newApp.platform);

    // final firebaseProject =
    //     await firebase.createProject(projectId: 'ffclitest2');
    // print(firebaseProject);
  }
}

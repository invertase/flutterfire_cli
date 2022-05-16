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

import 'dart:io';
import 'package:ansi_styles/ansi_styles.dart';
import 'package:path/path.dart' as path;

import '../common/platform.dart';
import '../common/strings.dart';
import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../firebase/firebase_android_gradle_plugins.dart';
import '../firebase/firebase_android_options.dart';
import '../firebase/firebase_app_id_file.dart';
import '../firebase/firebase_apple_options.dart';
import '../firebase/firebase_configuration_file.dart';
import '../firebase/firebase_options.dart';
import '../firebase/firebase_project.dart';
import '../firebase/firebase_web_options.dart';
import '../flutter_app.dart';

import 'base.dart';

class ConfigCommand extends FlutterFireCommand {
  ConfigCommand(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
    argParser.addOption(
      'out',
      valueHelp: 'filePath',
      defaultsTo: 'lib${currentPlatform.pathSeparator}firebase_options.dart',
      abbr: 'o',
      help: 'The output file path of the Dart file that will be generated with '
          'your Firebase configuration options.',
    );
    argParser.addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help:
          'Skip the Y/n confirmation prompts and accept default options (such as detected platforms).',
    );
    argParser.addOption(
      'ios-bundle-id',
      valueHelp: 'bundleIdentifier',
      mandatory: isCI,
      abbr: 'i',
      help: 'The bundle identifier of your iOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "ios" folder (if it exists).',
    );
    argParser.addOption(
      'macos-bundle-id',
      valueHelp: 'bundleIdentifier',
      mandatory: isCI,
      abbr: 'm',
      help: 'The bundle identifier of your macOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "macos" folder (if it exists).',
    );
    argParser.addOption(
      'android-app-id',
      valueHelp: 'applicationId',
      help:
          'DEPRECATED - use "android-package-name" instead. The application id of your Android app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists)',
    );
    argParser.addOption(
      'android-package-name',
      valueHelp: 'packageName',
      abbr: 'a',
      help: 'The package name of your Android app, e.g. "com.example.app". '
          'If no package name is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists).',
    );
    argParser.addFlag(
      'apply-gradle-plugins',
      defaultsTo: true,
      hide: true,
      abbr: 'g',
      help:
          "Whether to add the Firebase related Gradle plugins (such as Crashlytics and Performance) to your Android app's build.gradle files "
          'and create the google-services.json file in your ./android/app folder.',
    );
    argParser.addFlag(
      'app-id-json',
      defaultsTo: true,
      hide: true,
      abbr: 'j',
      help:
          'Whether to generate the firebase_app_id.json files used by native iOS and Android builds.',
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

  bool get yes {
    return argResults!['yes'] as bool || false;
  }

  bool get applyGradlePlugins {
    return argResults!['apply-gradle-plugins'] as bool;
  }

  bool get generateAppIdJson {
    return argResults!['app-id-json'] as bool;
  }

  String? get androidApplicationId {
    final value = argResults!['android-package-name'] as String?;
    final deprecatedValue = argResults!['android-app-id'] as String?;

    // TODO validate packagename is valid if provided.

    if (value != null) {
      return value;
    }
    if (deprecatedValue != null) {
      logger.stdout(
        'Warning - android-app-id (-a) is deprecated. Consider using android-package-name (-p) instead.',
      );
      return deprecatedValue;
    }

    if (isCI) {
      throw FirebaseCommandException(
        'configure',
        'Please provide value for android-package-name.',
      );
    }
    return null;
  }

  String? get iosBundleId {
    final value = argResults!['ios-bundle-id'] as String?;
    // TODO validate bundleId is valid if provided
    return value;
  }

  String? get macosBundleId {
    final value = argResults!['macos-bundle-id'] as String?;
    // TODO validate bundleId is valid if provided
    return value;
  }

  String get outputFilePath {
    return argResults!['out'] as String;
  }

  String get iosAppIDOutputFilePrefix {
    return 'ios';
  }

  String get macosAppIDOutputFilePrefix {
    return 'macos';
  }

  String get androidAppIDOutputFilePrefix {
    return 'android';
  }

  Future<FirebaseProject> _promptCreateFirebaseProject() async {
    final newProjectId = promptInput(
      'Enter a project id for your new Firebase project (e.g. ${AnsiStyles.cyan('my-cool-project')})',
      validator: (String x) {
        if (RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(x)) {
          return true;
        } else {
          return 'Firebase project ids must be lowercase and contain only alphanumeric and dash characters.';
        }
      },
    );
    final creatingProjectSpinner = spinner(
      (done) {
        if (!done) {
          return 'Creating new Firebase project ${AnsiStyles.cyan(newProjectId)}...';
        }
        return 'New Firebase project ${AnsiStyles.cyan(newProjectId)} created successfully.';
      },
    );
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

    if ((isCI || yes) && selectedProjectId == null) {
      throw FirebaseProjectRequiredException();
    }

    List<FirebaseProject>? firebaseProjects;

    final fetchingProjectsSpinner = spinner(
      (done) {
        if (!done) {
          return 'Fetching available Firebase projects...';
        }
        final baseMessage =
            'Found ${AnsiStyles.cyan('${firebaseProjects?.length ?? 0}')} Firebase projects.';
        if (selectedProjectId != null) {
          return '$baseMessage Selecting project ${AnsiStyles.cyan(selectedProjectId)}.';
        }
        return baseMessage;
      },
    );
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

    final selectedChoiceIndex = promptSelect(
      'Select a Firebase project to configure your Flutter application with',
      choices,
    );

    // Last choice is to create a new project.
    if (selectedChoiceIndex == choices.length - 1) {
      return _promptCreateFirebaseProject();
    }

    return firebaseProjects[selectedChoiceIndex];
  }

  Map<String, bool> _selectPlatforms() {
    final selectedPlatforms = <String, bool>{
      kAndroid: flutterApp!.android,
      kIos: flutterApp!.ios,
      kMacos: flutterApp!.macos,
      kWeb: flutterApp!.web,
    };
    if (isCI || yes) {
      return selectedPlatforms;
    }
    final answers = promptMultiSelect(
      'Which platforms should your configuration support (use arrow keys & space to select)?',
      selectedPlatforms.keys.toList(),
      defaultSelection: selectedPlatforms.values.toList(),
    );
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
    commandRequiresFlutterApp();

    final selectedFirebaseProject = await _selectFirebaseProject();
    final selectedPlatforms = _selectPlatforms();

    if (!selectedPlatforms.containsValue(true)) {
      throw NoFlutterPlatformsSelectedException();
    }

    FirebaseOptions? androidOptions;
    if (selectedPlatforms[kAndroid]!) {
      androidOptions = await FirebaseAndroidOptions.forFlutterApp(
        flutterApp!,
        androidApplicationId: androidApplicationId,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
      );
    }

    FirebaseOptions? iosOptions;
    if (selectedPlatforms[kIos]!) {
      iosOptions = await FirebaseAppleOptions.forFlutterApp(
        flutterApp!,
        appleBundleIdentifier: iosBundleId,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
      );
    }

    FirebaseOptions? macosOptions;
    if (selectedPlatforms[kMacos]!) {
      macosOptions = await FirebaseAppleOptions.forFlutterApp(
        flutterApp!,
        appleBundleIdentifier: macosBundleId,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        macos: true,
      );
    }

    FirebaseOptions? webOptions;
    if (selectedPlatforms[kWeb]!) {
      webOptions = await FirebaseWebOptions.forFlutterApp(
        flutterApp!,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
      );
    }

    final futures = <Future>[];

    final configFile = FirebaseConfigurationFile(
      outputFilePath,
      androidOptions: androidOptions,
      iosOptions: iosOptions,
      macosOptions: macosOptions,
      webOptions: webOptions,
      force: isCI || yes,
    );
    futures.add(configFile.write());

    if (generateAppIdJson) {
      if (iosOptions != null) {
        final appIDFile = FirebaseAppIDFile(
          iosAppIDOutputFilePrefix,
          options: iosOptions,
          force: isCI || yes,
        );
        futures.add(appIDFile.write());
      }

      if (macosOptions != null) {
        final appIDFile = FirebaseAppIDFile(
          macosAppIDOutputFilePrefix,
          options: macosOptions,
          force: isCI || yes,
        );
        futures.add(appIDFile.write());
      }
    } else {
      logger.stdout(
        logSkippingAppIdJson,
      );
    }

    if (androidOptions != null && applyGradlePlugins) {
      futures.add(
        FirebaseAndroidGradlePlugins(
          flutterApp!,
          androidOptions,
          logger,
        ).apply(force: isCI || yes),
      );
    }

    if (iosOptions != null) {
      final googleServiceInfoFile = path.join(
        flutterApp!.iosDirectory.path,
        'Runner',
        iosOptions.optionsSourceFileName,
      );

      final file = File(googleServiceInfoFile);

      if (!file.existsSync()) {
        await file.writeAsString(iosOptions.optionsSourceContent);
      }

      final pathToScript = path.split(Platform.script.toFilePath());

      final sourceDirIndex = pathToScript.indexOf('.dart_tool');

      final listToPbxScriptDir = pathToScript.sublist(0, sourceDirIndex);

      final pathToPbxScript = path.joinAll(
        [
          ...listToPbxScriptDir,
          'scripts',
          'set_ios_pbxproj_file.rb',
        ],
      );

      final xcodeProjFilePath =
          path.join(flutterApp!.iosDirectory.path, 'Runner.xcodeproj');

      if (Platform.isMacOS) {
        await Process.run('ruby', [
          pathToPbxScript,
          '--googleFile=$googleServiceInfoFile',
          '--xcodeFile=$xcodeProjFilePath'
        ]);
      }
    }

    await Future.wait<void>(futures);

    logger.stdout('');
    logger.stdout(
      logFirebaseConfigGenerated(outputFilePath),
    );
    logger.stdout('');
    logger.stdout(
      listAsPaddedTable(
        [
          [AnsiStyles.bold('Platform'), AnsiStyles.bold('Firebase App Id')],
          if (webOptions != null) [kWeb, webOptions.appId],
          if (androidOptions != null) [kAndroid, androidOptions.appId],
          if (iosOptions != null) [kIos, iosOptions.appId],
          if (macosOptions != null) [kMacos, macosOptions.appId],
        ],
        paddingSize: 2,
      ),
    );
    logger.stdout('');
    logger.stdout(
      logLearnMoreAboutCli,
    );
  }
}

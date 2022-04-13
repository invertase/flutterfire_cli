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

import '../common/exception.dart';
import '../common/platform.dart';
import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../firebase/firebase_android_options.dart';
import '../firebase/firebase_app_id_file.dart';
import '../firebase/firebase_apple_options.dart';
import '../firebase/firebase_configuration_file.dart';
import '../firebase/firebase_options.dart';
import '../firebase/firebase_project.dart';
import '../firebase/firebase_web_options.dart';
import '../flutter_app.dart';

import 'base.dart';

final _androidBuildGradleRegex = RegExp(
  r'''(?:\s*?dependencies\s?{$\n(?<indentation>[\s\S\w]*?)classpath\s?['"]{1}com.android.tools.build:gradle:.*?['"]{1}\s*?$)''',
  multiLine: true,
);
final _androidAppBuildGradleRegex = RegExp(
  r'''(?:^[\s]+apply[\s]+plugin\:[\s]+['"]{1}com\.android\.application['"]{1})''',
  multiLine: true,
);
const _googleServicesPluginClass = 'com.google.gms:google-services';
const _googleServicesPluginName = 'com.google.gms.google-services';
const _googleServicesPluginVersion = '4.3.10';
const _googleServicesPlugin =
    "classpath '$_googleServicesPluginClass:$_googleServicesPluginVersion'";
const _googleServicesConfigStart = '// START: FlutterFire Configuration';
const _googleServicesConfigEnd = '// END: FlutterFire Configuration';

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
        return 'New Firebase project ${AnsiStyles.cyan(newProjectId)} created succesfully.';
      },
    );
    final newProject = await firebase.createProject(
      projectId: newProjectId,
      account: accountEmail,
    );
    creatingProjectSpinner.done();
    return newProject;
  }

  Future<void> conditionallySetupAndroidGoogleServices({
    required FlutterApp flutterApp,
    required FirebaseOptions firebaseOptions,
    bool force = false,
  }) async {
    if (!flutterApp.android) {
      // Flutter application is not configured to target Android.
      return;
    }

    // <app>/android/app/google-services.json
    var existingProjectId = '';
    var shouldPromptOverwriteGoogleServicesJson = false;
    final androidGoogleServicesJsonFile = File(
      path.join(
        flutterApp.androidDirectory.path,
        'app',
        firebaseOptions.optionsSourceFileName,
      ),
    );
    if (androidGoogleServicesJsonFile.existsSync()) {
      final existingGoogleServicesJsonContents =
          await androidGoogleServicesJsonFile.readAsString();
      existingProjectId = FirebaseAndroidOptions.projectIdFromFileContents(
        existingGoogleServicesJsonContents,
      );
      if (existingProjectId != firebaseOptions.projectId) {
        shouldPromptOverwriteGoogleServicesJson = true;
      }
    }
    if (shouldPromptOverwriteGoogleServicesJson && !force) {
      final overwriteGoogleServicesJson = promptBool(
        'The ${AnsiStyles.cyan(firebaseOptions.optionsSourceFileName)} file already exists but for a different Firebase project (${AnsiStyles.grey(existingProjectId)}). '
        'Do you want to replace it with new Firebase project ${AnsiStyles.green(firebaseOptions.projectId)}?',
      );
      if (!overwriteGoogleServicesJson) {
        logger.stdout(
          'Skipping ${AnsiStyles.cyan(firebaseOptions.optionsSourceFileName)} setup. This may cause issues with some Firebase services on Android in your application.',
        );
        return;
      }
    }
    await androidGoogleServicesJsonFile.writeAsString(
      firebaseOptions.optionsSourceContent,
    );

    // DETECT <app>/android/build.gradle
    var shouldPromptUpdateAndroidBuildGradle = false;
    final androidBuildGradleFile = File(
      path.join(flutterApp.androidDirectory.path, 'build.gradle'),
    );
    final androidBuildGradleFileContents =
        await androidBuildGradleFile.readAsString();
    if (!androidBuildGradleFileContents.contains(_googleServicesPluginClass)) {
      final hasMatch =
          _androidBuildGradleRegex.hasMatch(androidBuildGradleFileContents);
      if (!hasMatch) {
        // TODO some unrecoverable error here
        return;
      }
      shouldPromptUpdateAndroidBuildGradle = true;
      // TODO should we check if has google() repositories configured?
    } else {
      // TODO already contains google services, should we upgrade version?
    }

    // DETECT <app>/android/app/build.gradle
    var shouldPromptUpdateAndroidAppBuildGradle = false;
    final androidAppBuildGradleFile = File(
      path.join(flutterApp.androidDirectory.path, 'app', 'build.gradle'),
    );
    final androidAppBuildGradleFileContents =
        await androidAppBuildGradleFile.readAsString();
    if (!androidAppBuildGradleFileContents
        .contains(_googleServicesPluginClass)) {
      final hasMatch = _androidAppBuildGradleRegex
          .hasMatch(androidAppBuildGradleFileContents);
      if (!hasMatch) {
        // TODO some unrecoverable error here?
        return;
      }
      shouldPromptUpdateAndroidAppBuildGradle = true;
    }

    if ((shouldPromptUpdateAndroidBuildGradle ||
            shouldPromptUpdateAndroidAppBuildGradle) &&
        !force) {
      final updateAndroidGradleFiles = promptBool(
        'The files ${AnsiStyles.cyan('android/build.gradle')} & ${AnsiStyles.cyan('android/app/build.gradle')} will be updated to apply the Firebase configuration. '
        'Do you want to continue?',
      );
      if (!updateAndroidGradleFiles) {
        logger.stdout(
          'Skipping applying Firebase Google Services gradle plugin for Android. This may cause issues with some Firebase services on Android in your application.',
        );
        return;
      }
    }

    // WRITE <app>/android/build.gradle
    if (shouldPromptUpdateAndroidBuildGradle) {
      final updatedAndroidBuildGradleFileContents =
          androidBuildGradleFileContents
              .replaceFirstMapped(_androidBuildGradleRegex, (match) {
        final indentation = match.group(1);
        return '${match.group(0)}\n$indentation$_googleServicesConfigStart\n$indentation$_googleServicesPlugin\n$indentation$_googleServicesConfigEnd';
      });
      await androidBuildGradleFile
          .writeAsString(updatedAndroidBuildGradleFileContents);
    }
    // WRITE <app>/android/app/build.gradle
    if (shouldPromptUpdateAndroidAppBuildGradle) {
      final updatedAndroidAppBuildGradleFileContents =
          androidAppBuildGradleFileContents
              .replaceFirstMapped(_androidAppBuildGradleRegex, (match) {
        return "${match.group(0)}\n$_googleServicesConfigStart\napply plugin: '$_googleServicesPluginName'\n$_googleServicesConfigEnd";
      });
      await androidAppBuildGradleFile
          .writeAsString(updatedAndroidAppBuildGradleFileContents);
    }
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

    if (androidOptions != null) {
      futures.add(
        conditionallySetupAndroidGoogleServices(
          firebaseOptions: androidOptions,
          flutterApp: flutterApp!,
          force: isCI || yes,
        ),
      );
    }

    await Future.wait<void>(futures);

    logger.stdout('');
    logger.stdout(
      'Firebase configuration file ${AnsiStyles.cyan(outputFilePath)} generated successfully with the following Firebase apps:',
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
      'Learn more about using this file in the FlutterFire documentation:\n'
      ' > https://firebase.flutter.dev/docs/cli',
    );
  }
}

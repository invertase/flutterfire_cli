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

import '../common/inputs.dart';
import '../common/platform.dart';
import '../common/strings.dart';
import '../common/utils.dart';
import '../common/validation.dart';
import '../firebase.dart' as firebase;
import '../firebase/firebase_android_writes.dart';
import '../firebase/firebase_apple_writes.dart';
import '../firebase/firebase_dart_configuration_write.dart';
import '../firebase/firebase_platform_options.dart';
import '../firebase/firebase_project.dart';
import '../flutter_app.dart';
import './reconfigure.dart';
import 'base.dart';


class ConfigCommand extends FlutterFireCommand {
  ConfigCommand(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
    argParser.addOption(
      kOutFlag,
      valueHelp: 'filePath',
      defaultsTo: 'lib${currentPlatform.pathSeparator}firebase_options.dart',
      abbr: 'o',
      help: 'The output file path of the Dart file that will be generated with '
          'your Firebase configuration options.',
    );
    argParser.addFlag(
      kYesFlag,
      abbr: 'y',
      negatable: false,
      help:
          'Skip the Y/n confirmation prompts and accept default options (such as detected platforms).',
    );
    argParser.addOption(
      kPlatformsFlag,
      valueHelp: 'platforms',
      mandatory: isCI,
      help:
          'Optionally specify the platforms to generate configuration options for '
          'as a comma separated list. For example "android,ios,macos,web,linux,windows".',
    );
    argParser.addOption(
      kIosBundleIdFlag,
      valueHelp: 'bundleIdentifier',
      abbr: 'i',
      help: 'The bundle identifier of your iOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "ios" folder (if it exists).',
    );
    argParser.addOption(
      kMacosBundleIdFlag,
      valueHelp: 'bundleIdentifier',
      abbr: 'm',
      help: 'The bundle identifier of your macOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "macos" folder (if it exists).',
    );
    argParser.addOption(
      kAndroidAppIdFlag,
      valueHelp: 'applicationId',
      help:
          'DEPRECATED - use "android-package-name" instead. The application id of your Android app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists)',
    );
    argParser.addOption(
      kAndroidPackageNameFlag,
      valueHelp: 'packageName',
      abbr: 'a',
      help: 'The package name of your Android app, e.g. "com.example.app". '
          'If no package name is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists).',
    );
    argParser.addOption(
      kWebAppIdFlag,
      valueHelp: 'appId',
      abbr: 'w',
      help: 'The app id of your Web application, e.g. "1:XXX:web:YYY". '
          'If no app id is provided then an attempt will be made to '
          'automatically pick the first available web app id from remote. '
          'If no web app exists, we create a web app and suffix the name with "(web)"',
    );

    argParser.addOption(
      kWindowsAppIdFlag,
      valueHelp: 'windowsAppId',
      abbr: 'x',
      help: 'The app id of your Windows application, e.g. "1:XXX:web:YYY". '
          'If no app id is provided then an attempt will be made to '
          'automatically pick the first available windows app id from remote. '
          'If no windows app exists, we create a web app for Windows platform. '
          'We suffix the name with "(windows)"',
    );

    argParser.addOption(
      kTokenFlag,
      valueHelp: 'firebaseToken',
      abbr: 't',
      help: 'The token generated by running `firebase login:ci`',
    );

    argParser.addOption(
      kServiceAccountFlag,
      valueHelp: 'serviceAccount',
      help:
          'The path to a Google service account JSON file, used for authentication',
    );

    argParser.addFlag(
      kAppleGradlePluginFlag,
      defaultsTo: true,
      hide: true,
      abbr: 'g',
      help:
          "Whether to add the Firebase related Gradle plugins (such as Crashlytics and Performance) to your Android app's build.gradle files "
          'and create the google-services.json file in your ./android/app folder.',
    );

    argParser.addOption(
      kIosBuildConfigFlag,
      valueHelp: 'iosBuildConfiguration',
      help:
          'Name of iOS build configuration to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kMacosBuildConfigFlag,
      valueHelp: 'macosBuildConfiguration',
      help:
          'Name of macOS build configuration to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kIosTargetFlag,
      valueHelp: 'iosTargetName',
      help:
          'Name of iOS target to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kMacosTargetFlag,
      valueHelp: 'macosTargetName',
      help:
          'Name of macOS target to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kIosOutFlag,
      valueHelp: 'pathForIosConfig',
      help:
          'Where to write the `Google-Service-Info.plist` file for iOS platform. Useful for different flavors',
    );

    argParser.addOption(
      kMacosOutFlag,
      valueHelp: 'pathForMacosConfig',
      help:
          'Where to write the `Google-Service-Info.plist` file to be written for macOS platform. Useful for different flavors',
    );

    argParser.addOption(
      kAndroidOutFlag,
      valueHelp: 'pathForAndroidConfig',
      help:
          'Where to write the `google-services.json` file to be written for android platform. Useful for different flavors',
    );

    argParser.addFlag(
      kOverwriteFirebaseOptionsFlag,
      abbr: 'f',
      defaultsTo: null,
      help:
          "Rewrite the service file if you're running 'flutterfire configure' again due to updating project",
    );

    argParser.addOption(
      kTestAccessTokenFlag,
      valueHelp: 'testAccessToken',
      hide: true,
      help:
          'Firebase test access token for use in integration tests. This is not required for normal usage.',
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

  List<String> get platforms {
    final platformsString = argResults!['platforms'] as String?;
    if (platformsString == null || platformsString.isEmpty) {
      return <String>[];
    }
    return platformsString
        .split(',')
        .map((String platform) => platform.trim().toLowerCase())
        .where(
          (element) =>
              element == 'ios' ||
              element == 'android' ||
              element == 'macos' ||
              element == 'web' ||
              element == 'linux' ||
              element == 'windows',
        )
        .toList();
  }

  bool get applyGradlePlugins {
    return argResults!['apply-gradle-plugins'] as bool;
  }

  String? get iosBuildConfiguration {
    return argResults!['ios-build-config'] as String?;
  }

  String? get macosBuildConfiguration {
    return argResults!['macos-build-config'] as String?;
  }

  String? get iosTarget {
    return argResults!['ios-target'] as String?;
  }

  String? get macosTarget {
    return argResults!['macos-target'] as String?;
  }

  String? get macOSServiceFilePath {
    return argResults!['macos-out'] as String?;
  }

  String? get iOSServiceFilePath {
    return argResults!['ios-out'] as String?;
  }

  String? get androidServiceFilePath {
    return argResults!['android-out'] as String?;
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
    if (value != null) return value;

    if (isCI) {
      throw FirebaseCommandException(
        'configure',
        'Please provide value for ios-bundle-id.',
      );
    }
    return null;
  }

  String? get webAppId {
    final value = argResults!['web-app-id'] as String?;

    if (value != null) return value;

    if (isCI) {
      throw FirebaseCommandException(
        'configure',
        'Please provide value for web-app-id.',
      );
    }
    return null;
  }

  String? get windowsAppId {
    final value = argResults![kWindowsAppIdFlag] as String?;

    if (value != null) return value;

    if (isCI) {
      throw FirebaseCommandException(
        'configure',
        'Please provide value for $kWindowsAppIdFlag.',
      );
    }
    return null;
  }

  String? get macosBundleId {
    final value = argResults!['macos-bundle-id'] as String?;
    // TODO validate bundleId is valid if provided
    if (value != null) return value;

    if (isCI) {
      throw FirebaseCommandException(
        'configure',
        'Please provide value for macos-bundle-id.',
      );
    }
    return null;
  }

  String? get token {
    final value = argResults!['token'] as String?;
    return value;
  }

  String? get serviceAccount {
    final value = argResults!['service-account'] as String?;
    return value;
  }

  String get outputFilePath {
    return argResults!['out'] as String;
  }

  bool? get overwriteFirebaseOptions {
    return argResults!['overwrite-firebase-options'] as bool?;
  }

  // Still needed for local CI testing
  bool get testingEnvironment {
    return Platform.environment['TEST_ENVIRONMENT'] != null;
  }

  String? get testAccessToken {
    final value = argResults![kTestAccessTokenFlag] as String?;
    return value;
  }

  AppleInputs? macosInputs;
  AppleInputs? iosInputs;
  AndroidInputs? androidInputs;

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
      token: token,
      serviceAccount: serviceAccount,
    );
    creatingProjectSpinner.done();
    return newProject;
  }

  Future<FirebaseProject> _selectFirebaseProject() async {
    var selectedProjectId = projectId;
    var projectListFail = false;
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
        if (selectedProjectId != null && !projectListFail) {
          return '$baseMessage Selecting project ${AnsiStyles.cyan(selectedProjectId)}.';
        }
        return baseMessage;
      },
    );
    firebaseProjects = await firebase.getProjects(
      account: accountEmail,
      token: token,
      serviceAccount: serviceAccount,
    );

    try {
      firebaseProjects = await firebase
          .getProjects(
            account: accountEmail,
            token: token,
            serviceAccount: serviceAccount,
          )
          .timeout(const Duration(seconds: 15));

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
    } catch (e) {
      if (firebaseProjects == null) {
        projectListFail = true;
        // This won't have been called if `firebaseProjects` is null
        fetchingProjectsSpinner.done();

        // Warn user that we couldn't fetch projects
        // Prompt user if they would like to create a new project.
        // Cannot choose nor input project because we cannot validate if we cannot fetch projects.
        logger.stderr(
          'Failed to fetch your Firebase projects. Fetch failed with this: $e',
        );
        final createProject =
            promptBool('Would you like to create a new Firebase project?');

        if (createProject) {
          return _promptCreateFirebaseProject();
        } else {
          throw FirebaseProjectRequiredException();
        }
      } else {
        // It wasn't Firebase projects list API call, rethrow
        rethrow;
      }
    }
  }

  Map<String, bool> _selectPlatforms() {
    final selectedPlatforms = <String, bool>{
      kAndroid: platforms.contains(kAndroid) ||
          platforms.isEmpty && flutterApp!.android,
      kIos: platforms.contains(kIos) || platforms.isEmpty && flutterApp!.ios,
      kMacos:
          platforms.contains(kMacos) || platforms.isEmpty && flutterApp!.macos,
      kWeb: platforms.contains(kWeb) || platforms.isEmpty && flutterApp!.web,
      kWindows: platforms.contains(kWindows) ||
          platforms.isEmpty && flutterApp!.windows,
      if (flutterApp!.dependsOnPackage('firebase_core_desktop'))
        kLinux: platforms.contains(kLinux) ||
            platforms.isEmpty && flutterApp!.linux,
    };
    if (platforms.isNotEmpty || isCI || yes) {
      final selectedPlatformsString = selectedPlatforms.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList()
          .join(',');
      logger.stdout(
        AnsiStyles.bold(
          '${AnsiStyles.blue('i')} Selected platforms: ${AnsiStyles.green(selectedPlatformsString)}',
        ),
      );
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

  Future<bool> checkIfUserRequiresReconfigure() async {
    final firebaseJsonPath =
        path.join(flutterApp!.package.path, 'firebase.json');
    final file = File(firebaseJsonPath);

    if (file.existsSync()) {
      if (argResults != null &&
          (argResults!.arguments.isEmpty || testAccessToken != null)) {
        // If arguments are null, user is probably trying to call `flutterfire reconfigure`
        final reuseFirebaseJsonValues = testingEnvironment ||
            promptBool(
              'You have an existing `firebase.json` file and possibly already configured your project for Firebase. Would you prefer to reuse the values in your existing `firebase.json` file to configure your project?',
            );

        if (reuseFirebaseJsonValues) {
          final reconfigure = Reconfigure(flutterApp, token: testAccessToken);
          reconfigure.logger = logger;
          await reconfigure.run();
          return true;
        }
      }
    }

    return false;
  }

  @override
  Future<void> run() async {
    commandRequiresFlutterApp();
    final reconfigured = await checkIfUserRequiresReconfigure();

    if (reconfigured) {
      return;
    }

    // 1. Validate and prompt first
    if (Platform.isMacOS) {
      if (flutterApp!.ios) {
        iosInputs = await appleValidation(
          platform: kIos,
          flutterAppPath: flutterApp!.package.path,
          serviceFilePath: iOSServiceFilePath,
          target: iosTarget,
          buildConfiguration: iosBuildConfiguration,
        );
      }
      if (flutterApp!.macos) {
        macosInputs = await appleValidation(
          platform: kMacos,
          flutterAppPath: flutterApp!.package.path,
          serviceFilePath: macOSServiceFilePath,
          target: macosTarget,
          buildConfiguration: macosBuildConfiguration,
        );
      }
    }

    if (flutterApp!.android) {
      androidInputs = androidValidation(
        flutterAppPath: flutterApp!.package.path,
        serviceFilePath: androidServiceFilePath,
      );
    }

    final firebaseConfigurationFileInputs = dartConfigurationFileValidation(
      configurationFilePath: outputFilePath,
      flutterAppPath: flutterApp!.package.path,
      overwrite: yes,
    );

    final selectedFirebaseProject = await _selectFirebaseProject();
    final selectedPlatforms = _selectPlatforms();

    if (!selectedPlatforms.containsValue(true)) {
      throw NoFlutterPlatformsSelectedException();
    }

    // 2. Get values for all selected platforms
    final fetchedFirebaseOptions = await fetchAllFirebaseOptions(
      flutterApp: flutterApp!,
      firebaseProjectId: selectedFirebaseProject.projectId,
      firebaseAccount: accountEmail,
      androidApplicationId: androidApplicationId,
      iosBundleId: iosBundleId,
      macosBundleId: macosBundleId,
      token: token,
      serviceAccount: serviceAccount,
      webAppId: webAppId,
      windowsAppId: windowsAppId,
      android: selectedPlatforms[kAndroid]!,
      ios: selectedPlatforms[kIos]!,
      macos: selectedPlatforms[kMacos]!,
      web: selectedPlatforms[kWeb]!,
      windows: selectedPlatforms[kWindows]!,
      linux: selectedPlatforms[kLinux] != null && selectedPlatforms[kLinux]!,
    );

    // 3. Writes for all selected platforms
    final firebaseJsonWrites = <FirebaseJsonWrites>[];

    if (fetchedFirebaseOptions.androidOptions != null &&
        applyGradlePlugins &&
        flutterApp!.android &&
        androidInputs != null) {
      final firebaseJsonWrite = await FirebaseAndroidWrites(
        flutterApp: flutterApp!,
        firebaseOptions: fetchedFirebaseOptions.androidOptions!,
        logger: logger,
        androidServiceFilePath: androidInputs!.serviceFilePath,
        projectConfiguration: androidInputs!.projectConfiguration,
      ).apply();

      firebaseJsonWrites.add(firebaseJsonWrite);
    }
    if (Platform.isMacOS) {
      if (fetchedFirebaseOptions.iosOptions != null &&
          flutterApp!.ios &&
          iosInputs != null) {
        final firebaseJsonWrite = await appleWrites(
          platformOptions: fetchedFirebaseOptions.iosOptions!,
          flutterAppPath: flutterApp!.package.path,
          serviceFilePath: iosInputs!.serviceFilePath,
          logger: logger,
          buildConfiguration: iosInputs?.buildConfiguration,
          target: iosInputs?.target,
          platform: kIos,
          projectConfiguration: iosInputs!.projectConfiguration,
        );

        firebaseJsonWrites.add(firebaseJsonWrite);
      }

      if (fetchedFirebaseOptions.macosOptions != null &&
          flutterApp!.macos &&
          macosInputs != null) {
        final firebaseJsonWrite = await appleWrites(
          platformOptions: fetchedFirebaseOptions.macosOptions!,
          flutterAppPath: flutterApp!.package.path,
          serviceFilePath: macosInputs!.serviceFilePath,
          logger: logger,
          buildConfiguration: macosInputs?.buildConfiguration,
          target: macosInputs?.target,
          platform: kMacos,
          projectConfiguration: macosInputs!.projectConfiguration,
        );

        firebaseJsonWrites.add(firebaseJsonWrite);
      }
    }
    if (firebaseConfigurationFileInputs.writeConfigurationFile) {
      final firebaseJsonWrite = FirebaseDartConfigurationWrite(
        configurationFilePath:
            firebaseConfigurationFileInputs.configurationFilePath,
        firebaseProjectId: selectedFirebaseProject.projectId,
        flutterAppPath: flutterApp!.package.path,
        androidOptions: fetchedFirebaseOptions.androidOptions,
        iosOptions: fetchedFirebaseOptions.iosOptions,
        macosOptions: fetchedFirebaseOptions.macosOptions,
        webOptions: fetchedFirebaseOptions.webOptions,
        windowsOptions: fetchedFirebaseOptions.windowsOptions,
        linuxOptions: fetchedFirebaseOptions.linuxOptions,
      ).write();

      firebaseJsonWrites.add(firebaseJsonWrite);
    }

    // 4. Writes for "firebase.json" file in root of project
    if (firebaseJsonWrites.isNotEmpty) {
      await writeToFirebaseJson(
        listOfWrites: firebaseJsonWrites,
        firebaseJsonPath: path.join(flutterApp!.package.path, 'firebase.json'),
      );
    }

    logger.stdout('');
    logger.stdout(
      logFirebaseConfigGenerated(outputFilePath),
    );
    logger.stdout('');
    logger.stdout(
      listAsPaddedTable(
        [
          [AnsiStyles.bold('Platform'), AnsiStyles.bold('Firebase App Id')],
          if (fetchedFirebaseOptions.webOptions != null)
            [kWeb, fetchedFirebaseOptions.webOptions!.appId],
          if (fetchedFirebaseOptions.androidOptions != null)
            [kAndroid, fetchedFirebaseOptions.androidOptions!.appId],
          if (fetchedFirebaseOptions.iosOptions != null)
            [kIos, fetchedFirebaseOptions.iosOptions!.appId],
          if (fetchedFirebaseOptions.macosOptions != null)
            [kMacos, fetchedFirebaseOptions.macosOptions!.appId],
          if (fetchedFirebaseOptions.linuxOptions != null)
            [kLinux, fetchedFirebaseOptions.linuxOptions!.appId],
          if (fetchedFirebaseOptions.windowsOptions != null)
            [kWindows, fetchedFirebaseOptions.windowsOptions!.appId],
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

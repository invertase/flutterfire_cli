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
      'platforms',
      valueHelp: 'platforms',
      mandatory: isCI,
      help:
          'Optionally specify the platforms to generate configuration options for '
          'as a comma separated list. For example "android,ios,macos,web,linux,windows".',
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
    argParser.addOption(
      'web-app-id',
      valueHelp: 'appId',
      abbr: 'w',
      help: 'The app id of your Web application, e.g. "1:XXX:web:YYY". '
          'If no package name is provided then an attempt will be made to '
          'automatically pick the first available web app id from remote.',
    );
    argParser.addOption(
      'token',
      valueHelp: 'firebaseToken',
      abbr: 't',
      help: 'The token generated by running `firebase login:ci`',
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
      'debug-symbols-script',
      hide: true,
      abbr: 'd',
      help:
          "Whether you want an upload Crashlytic's debug symbols script adding to the build phases of your iOS project.",
    );

    argParser.addOption(
      'ios-out',
      valueHelp: 'pathForIosConfig',
      help:
          'Where to write the `Google-Service-Info.plist` file for the iOS platform. Useful for different flavors',
    );

    argParser.addOption(
      'macos-out',
      valueHelp: 'pathForMacosConfig',
      help:
          'Where would you like your `Google-Service-Info.plist` file to be written for macOS platform. Useful for different flavors',
    );

    argParser.addOption(
      'android-out',
      valueHelp: 'pathForAndroidConfig',
      help:
          'Where would you like your `google-services.json` file to be written for android platform. Useful for different flavors',
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

  bool get generateDebugSymbolScript {
    return argResults!['debug-symbols-script'] as bool;
  }

  String? get macosServiceFilePath {
    if (updatedMACOSServiceFilePath != null) {
      return updatedMACOSServiceFilePath;
    }
    return argResults!['macos-out'] as String?;
  }

  // This allows us to update to the required "GoogleService-Info.plist" file name for macOS target or scheme writes.
  String? updatedMACOSServiceFilePath;

  String? get iosServiceFilePath {
    if (updatedIOSServiceFilePath != null) {
      return updatedIOSServiceFilePath;
    }
    return argResults!['ios-out'] as String?;
  }

  // This allows us to update to the required "GoogleService-Info.plist" file name for iOS target or scheme writes.
  String? updatedIOSServiceFilePath;

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
    return value;
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

  String? get macosBundleId {
    final value = argResults!['macos-bundle-id'] as String?;
    // TODO validate bundleId is valid if provided
    return value;
  }

  String? get token {
    final value = argResults!['token'] as String?;
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
      token: token,
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
    firebaseProjects = await firebase.getProjects(
      account: accountEmail,
      token: token,
    );

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
      kAndroid: platforms.contains(kAndroid) ||
          platforms.isEmpty && flutterApp!.android,
      kIos: platforms.contains(kIos) || platforms.isEmpty && flutterApp!.ios,
      kMacos:
          platforms.contains(kMacos) || platforms.isEmpty && flutterApp!.macos,
      kWeb: platforms.contains(kWeb) || platforms.isEmpty && flutterApp!.web,
      if (flutterApp!.dependsOnPackage('firebase_core_desktop'))
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

  Future<void> _writeDebugScriptForScheme(
    String xcodeProjFilePath,
    String appId,
    String scheme,
  ) async {
    final adUploadSymbolsScript = addCrashylticsDebugSymbolScriptToScheme(
      xcodeProjFilePath,
      appId,
      scheme,
      '[firebase_crashlytics] upload debug symbols script for "$scheme" scheme',
    );

    final resultUploadScript = await Process.run('ruby', [
      '-e',
      adUploadSymbolsScript,
    ]);

    if (resultUploadScript.exitCode != 0) {
      throw Exception(resultUploadScript.stderr);
    }

    if (resultUploadScript.stdout != null) {
      logger.stdout(resultUploadScript.stdout as String);
    }
  }

  Future<void> _writeDebugScriptForTarget(
    String xcodeProjFilePath,
    String appId,
    String target,
  ) async {
    final addUploadSymbolsScript = addCrashylticsDebugSymbolScriptToTarget(
      xcodeProjFilePath,
      appId,
      target,
      '[firebase_crashlytics] upload debug symbols script for "$target" scheme',
    );

    final resultUploadScript = await Process.run('ruby', [
      '-e',
      addUploadSymbolsScript,
    ]);

    if (resultUploadScript.exitCode != 0) {
      throw Exception(resultUploadScript.stderr);
    }

    if (resultUploadScript.stdout != null) {
      logger.stdout(resultUploadScript.stdout as String);
    }
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
        token: token,
      );
    }

    FirebaseOptions? iosOptions;
    if (selectedPlatforms[kIos]!) {
      iosOptions = await FirebaseAppleOptions.forFlutterApp(
        flutterApp!,
        appleBundleIdentifier: iosBundleId,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        token: token,
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
        token: token,
      );
    }

    FirebaseOptions? webOptions;
    if (selectedPlatforms[kWeb]!) {
      webOptions = await FirebaseWebOptions.forFlutterApp(
        flutterApp!,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        token: token,
        webAppId: webAppId,
      );
    }

    FirebaseOptions? windowsOptions;
    if (selectedPlatforms[kWindows] != null && selectedPlatforms[kWindows]!) {
      windowsOptions = await FirebaseWebOptions.forFlutterApp(
        flutterApp!,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        platform: kWindows,
        token: token,
      );
    }

    FirebaseOptions? linuxOptions;
    if (selectedPlatforms[kLinux] != null && selectedPlatforms[kLinux]!) {
      linuxOptions = await FirebaseWebOptions.forFlutterApp(
        flutterApp!,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        platform: kLinux,
        token: token,
      );
    }

    final futures = <Future>[];

    final configFile = FirebaseConfigurationFile(
      outputFilePath,
      androidOptions: androidOptions,
      iosOptions: iosOptions,
      macosOptions: macosOptions,
      webOptions: webOptions,
      windowsOptions: windowsOptions,
      linuxOptions: linuxOptions,
      force: isCI || yes,
    );
    futures.add(configFile.write());

    if (androidOptions != null && applyGradlePlugins) {
      futures.add(
        FirebaseAndroidGradlePlugins(
          flutterApp!,
          androidOptions,
          logger,
          androidServiceFilePath,
        ).apply(force: isCI || yes),
      );
    }

    if (iosOptions != null) {
      final googleServiceInfoFile = path.join(
        flutterApp!.iosDirectory.path,
        'Runner',
        iosOptions.optionsSourceFileName,
      );
      var fullIOSServicePath =
          '${flutterApp!.package.path}${iosServiceFilePath!}';

      File file;
      // If "iosServiceFilePath" exists, we use a different configuration from Runner/GoogleService-Info.plist setup
      if (iosServiceFilePath != null) {
        final googleServiceFileName = path.basename(iosServiceFilePath!);

        if (googleServiceFileName != 'GoogleService-Info.plist') {
          final response = promptBool(
            'The file name must be "GoogleService-Info.plist" if you\'re bundling with your iOS target or scheme. Do you want to change filename to "GoogleService-Info.plist"?',
          );

          // Change filename to "GoogleService-Info.plist" if user wants to, it is required for target or scheme setup
          if (response == true) {
            updatedIOSServiceFilePath = path.join(
              path.dirname(iosServiceFilePath!),
              'GoogleService-Info.plist',
            );

            fullIOSServicePath =
                '${flutterApp!.package.path}$updatedIOSServiceFilePath';
          }
        }
        // Create new directory for file output if it doesn't currently exist
        await Directory(path.dirname(fullIOSServicePath))
            .create(recursive: true);

        file = File(fullIOSServicePath);
      } else {
        file = File(googleServiceInfoFile);
      }

      if (!file.existsSync()) {
        await file.writeAsString(iosOptions.optionsSourceContent);
      }

      final xcodeProjFilePath =
          path.join(flutterApp!.iosDirectory.path, 'Runner.xcodeproj');

      // We need to prompt user whether they want a scheme configured, target configured or to simply write to the path provided
      if (Platform.isMacOS) {
        if (iosServiceFilePath != null) {
          final fileName = path.basename(iosServiceFilePath!);
          final response = promptSelect(
            'Would you like your iOS $fileName to be associated with your iOS Scheme or Target (use arrow keys & space to select)?',
            [
              'Scheme',
              'Target',
              'No, just want to write the file to the path I chose'
            ],
          );

          // Add to scheme
          if (response == 0) {
            // Find the schemes available on the project
            final schemeScript = findingSchemesScript(xcodeProjFilePath);

            final result = await Process.run('ruby', [
              '-e',
              schemeScript,
            ]);

            if (result.exitCode != 0) {
              throw Exception(result.stderr);
            }
            // Retrieve the schemes to prompt the user to select one
            final schemes = (result.stdout as String).split(' ');

            final response = promptSelect(
              'Which scheme would you like your iOS $fileName to be included within your iOS app bundle?',
              schemes,
            );

            final runScriptName =
                '[firebase_core] add Firebase configuration to "${schemes[response]}" scheme';
            // Create bash script for adding Google service file to app bundle
            final addBuildPhaseScript = addServiceFileToSchemeScript(
              xcodeProjFilePath,
              schemes[response],
              runScriptName,
              fullIOSServicePath,
            );

            // Add script to Build Phases in Xcode project
            final resultBuildPhase = await Process.run('ruby', [
              '-e',
              addBuildPhaseScript,
            ]);

            if (resultBuildPhase.exitCode != 0) {
              throw Exception(resultBuildPhase.stderr);
            }

            if (resultBuildPhase.stdout != null) {
              logger.stdout(resultBuildPhase.stdout as String);
            }

            if (generateDebugSymbolScript) {
              await _writeDebugScriptForScheme(
                xcodeProjFilePath,
                iosOptions.appId,
                schemes[response],
              );
            } else {
              final addSymbolScript = promptBool(
                "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your iOS project's '${schemes[response]}' scheme?",
              );

              if (addSymbolScript == true) {
                await _writeDebugScriptForScheme(
                  xcodeProjFilePath,
                  iosOptions.appId,
                  schemes[response],
                );
              } else {
                logger.stdout(
                  logSkippingDebugSymbolScript,
                );
              }
            }

            // Add to target
          } else if (response == 1) {
            final targetScript = findingTargetsScript(xcodeProjFilePath);

            final result = await Process.run('ruby', [
              '-e',
              targetScript,
            ]);

            if (result.exitCode != 0) {
              throw Exception(result.stderr);
            }
            // Retrieve the targets to prompt the user to select one
            final targets = (result.stdout as String).split(' ');

            final response = promptSelect(
              'Which target would you like your iOS $fileName to be included within your iOS app bundle?',
              targets,
            );

            final addServiceFileToTargetScript = addServiceFileToTarget(
              xcodeProjFilePath,
              fullIOSServicePath,
              targets[response],
            );

            final resultServiceFileToTarget = await Process.run('ruby', [
              '-e',
              addServiceFileToTargetScript,
            ]);

            if (resultServiceFileToTarget.exitCode != 0) {
              throw Exception(resultServiceFileToTarget.stderr);
            }

            if (generateDebugSymbolScript) {
              await _writeDebugScriptForTarget(
                xcodeProjFilePath,
                iosOptions.appId,
                targets[response],
              );
            } else {
              final addSymbolScript = promptBool(
                "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your iOS project's '${targets[response]}' target?",
              );

              if (addSymbolScript == true) {
                await _writeDebugScriptForTarget(
                  xcodeProjFilePath,
                  iosOptions.appId,
                  targets[response],
                );
              } else {
                logger.stdout(
                  logSkippingDebugSymbolScript,
                );
              }
            }
          }
        } else {
          // Continue to write file to Runner/GoogleService-Info.plist if no "iosServiceFilePath" is provided
          final rubyScript =
              generateRubyScript(googleServiceInfoFile, xcodeProjFilePath);

          final result = await Process.run('ruby', [
            '-e',
            rubyScript,
          ]);

          if (result.exitCode != 0) {
            throw Exception(result.stderr);
          }

          if (generateDebugSymbolScript) {
            await _writeDebugScriptForTarget(
              xcodeProjFilePath,
              iosOptions.appId,
              'Runner',
            );
          } else {
            final addSymbolScript = promptBool(
              "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your iOS project's 'Runner' target?",
            );
            if (addSymbolScript == true) {
              await _writeDebugScriptForTarget(
                xcodeProjFilePath,
                iosOptions.appId,
                'Runner',
              );
            } else {
              logger.stdout(
                logSkippingDebugSymbolScript,
              );
            }
          }
        }
      }
    }

    if (macosOptions != null && Platform.isMacOS) {
      final googleServiceInfoFile = path.join(
        flutterApp!.macosDirectory.path,
        'Runner',
        macosOptions.optionsSourceFileName,
      );

      var fullMACOSServicePath =
          '${flutterApp!.package.path}${macosServiceFilePath!}';

      File file;

      if (Platform.isMacOS) {
        // If "macosServiceFilePath" exists, we use a different configuration from Runner/GoogleService-Info.plist setup
        if (macosServiceFilePath != null) {
          final googleServiceFileName = path.basename(macosServiceFilePath!);

          if (googleServiceFileName != 'GoogleService-Info.plist') {
            final response = promptBool(
              'The file name must be "GoogleService-Info.plist" if you\'re bundling with your macOS target or scheme. Do you want to change filename to "GoogleService-Info.plist"?',
            );

            // Change filename to "GoogleService-Info.plist" if user wants to, it is required for target or scheme setup
            if (response == true) {
              updatedMACOSServiceFilePath = path.join(
                path.dirname(macosServiceFilePath!),
                'GoogleService-Info.plist',
              );

              fullMACOSServicePath =
                  '${flutterApp!.package.path}$updatedMACOSServiceFilePath';
            }
          }
          // Create new directory for file output if it doesn't currently exist
          await Directory(path.dirname(fullMACOSServicePath))
              .create(recursive: true);

          file = File(fullMACOSServicePath);
        } else {
          file = File(googleServiceInfoFile);
        }

        if (!file.existsSync()) {
          await file.writeAsString(macosOptions.optionsSourceContent);
        }

        final xcodeProjFilePath =
            path.join(flutterApp!.macosDirectory.path, 'Runner.xcodeproj');

        // We need to prompt user whether they want a scheme configured, target configured or to simply write to the path provided
        if (macosServiceFilePath != null) {
          final fileName = path.basename(macosServiceFilePath!);
          final response = promptSelect(
            'Would you like your macOS $fileName to be associated with your macOS Scheme or Target (use arrow keys & space to select)?',
            [
              'Scheme',
              'Target',
              'No, just want to write the file to the path I chose'
            ],
          );

          // Add to scheme
          if (response == 0) {
            // Find the schemes available on the project
            final schemeScript = findingSchemesScript(xcodeProjFilePath);

            final result = await Process.run('ruby', [
              '-e',
              schemeScript,
            ]);

            if (result.exitCode != 0) {
              throw Exception(result.stderr);
            }
            // Retrieve the schemes to prompt the user to select one
            final schemes = (result.stdout as String).split(' ');

            final response = promptSelect(
              'Which scheme would you like your macOS $fileName to be included within the macOS app bundle?',
              schemes,
            );

            final runScriptName =
                '[firebase_core] add Firebase configuration to "${schemes[response]}" scheme';
            // Create bash script for adding Google service file to app bundle
            final addBuildPhaseScript = addServiceFileToSchemeScript(
              xcodeProjFilePath,
              schemes[response],
              runScriptName,
              fullMACOSServicePath,
            );

            // Add script to Build Phases in Xcode project
            final resultBuildPhase = await Process.run('ruby', [
              '-e',
              addBuildPhaseScript,
            ]);

            if (resultBuildPhase.exitCode != 0) {
              throw Exception(resultBuildPhase.stderr);
            }

            if (resultBuildPhase.stdout != null) {
              logger.stdout(resultBuildPhase.stdout as String);
            }

            if (generateDebugSymbolScript) {
              await _writeDebugScriptForScheme(
                xcodeProjFilePath,
                macosOptions.appId,
                schemes[response],
              );
            } else {
              final addSymbolScript = promptBool(
                "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your macOS project's '${schemes[response]}' scheme?",
              );

              if (addSymbolScript == true) {
                await _writeDebugScriptForScheme(
                  xcodeProjFilePath,
                  macosOptions.appId,
                  schemes[response],
                );
              } else {
                logger.stdout(
                  logSkippingDebugSymbolScript,
                );
              }
            }

            // Add to target
          } else if (response == 1) {
            final targetScript = findingTargetsScript(xcodeProjFilePath);

            final result = await Process.run('ruby', [
              '-e',
              targetScript,
            ]);

            if (result.exitCode != 0) {
              throw Exception(result.stderr);
            }
            // Retrieve the targets to prompt the user to select one
            final targets = (result.stdout as String).split(' ');

            final response = promptSelect(
              'Which target would you like your macOS $fileName to be included within your macOS app bundle?',
              targets,
            );

            final addServiceFileToTargetScript = addServiceFileToTarget(
              xcodeProjFilePath,
              fullMACOSServicePath,
              targets[response],
            );

            final resultServiceFileToTarget = await Process.run('ruby', [
              '-e',
              addServiceFileToTargetScript,
            ]);

            if (resultServiceFileToTarget.exitCode != 0) {
              throw Exception(resultServiceFileToTarget.stderr);
            }

            if (generateDebugSymbolScript) {
              await _writeDebugScriptForTarget(
                xcodeProjFilePath,
                macosOptions.appId,
                targets[response],
              );
            } else {
              final addSymbolScript = promptBool(
                "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your macOS project's '${targets[response]}' target?",
              );

              if (addSymbolScript == true) {
                await _writeDebugScriptForTarget(
                  xcodeProjFilePath,
                  macosOptions.appId,
                  targets[response],
                );
              } else {
                logger.stdout(
                  logSkippingDebugSymbolScript,
                );
              }
            }
          }
        } else {
          // Continue to write file to Runner/GoogleService-Info.plist if no "macosServiceFilePath" is provided
          final rubyScript =
              generateRubyScript(googleServiceInfoFile, xcodeProjFilePath);

          final result = await Process.run('ruby', [
            '-e',
            rubyScript,
          ]);

          if (result.exitCode != 0) {
            throw Exception(result.stderr);
          }

          if (generateDebugSymbolScript) {
            await _writeDebugScriptForTarget(
              xcodeProjFilePath,
              macosOptions.appId,
              'Runner',
            );
          } else {
            final addSymbolScript = promptBool(
              "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your macOS project's 'Runner' target?",
            );
            if (addSymbolScript == true) {
              await _writeDebugScriptForTarget(
                xcodeProjFilePath,
                macosOptions.appId,
                'Runner',
              );
            } else {
              logger.stdout(
                logSkippingDebugSymbolScript,
              );
            }
          }
        }
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
          if (linuxOptions != null) [kLinux, linuxOptions.appId],
          if (windowsOptions != null) [kWindows, windowsOptions.appId],
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

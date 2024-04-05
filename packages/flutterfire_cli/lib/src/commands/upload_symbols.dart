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
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../common/strings.dart';
import '../common/utils.dart';
import '../flutter_app.dart';
import 'base.dart';

class ConfigurationResults {
  ConfigurationResults(
    this.appId,
    this.projectId,
    this.runDebugSymbolsScript,
    this.keyToConfig,
  );

  final String appId;
  final String projectId;
  final String keyToConfig;
  final bool? runDebugSymbolsScript;
}

class UploadCrashlyticsSymbols extends FlutterFireCommand {
  UploadCrashlyticsSymbols(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();

    argParser.addOption(
      'upload-symbols-script-path',
      valueHelp: 'uploadSymbolsScriptPath',
      help:
          'The absolute path to the upload symbols script path found in the Pod/FirebaseCrashlytics.',
    );

    argParser.addOption(
      'debug-symbols-path',
      valueHelp: 'debugSymbolsPath',
      help: 'The absolute path to the debug symbols directory.',
    );

    argParser.addOption(
      'info-plist-path',
      valueHelp: 'infoPlistPath',
      help: 'The absolute path to the Info.plist file.',
    );

    argParser.addOption(
      'build-configuration',
      valueHelp: 'buildConfiguration',
      help: 'The name of the build configuration.',
    );

    argParser.addOption(
      'target',
      valueHelp: 'targetName',
      help: 'The name of the target.',
    );

    argParser.addOption(
      'apple-project-path',
      valueHelp: 'appleProjectPath',
      help:
          'The absolute path to the flutter app apple directory (macOS or iOS directory).',
    );

    argParser.addOption(
      'platform',
      valueHelp: 'platformName',
      help: 'Either "macos" or "ios"',
    );

    argParser.addOption(
      'default-config',
      valueHelp: 'defaultConfigSetup',
      help:
          'Value is always ""default". This is for backwards compatibility of default configuration',
    );

    argParser.addOption(
      'env-platform-name',
      valueHelp: 'envPlatformName',
      help:
          'Required environment variable for running `upload-symbols` script.',
    );

    argParser.addOption(
      'env-configuration',
      valueHelp: 'envConfiguration',
      help:
          'Required environment variable for running `upload-symbols` script.',
    );

    argParser.addOption(
      'env-project-dir',
      valueHelp: 'envProjectDir',
      help:
          'Required environment variable for running `upload-symbols` script.',
    );

    argParser.addOption(
      'env-built-products-dir',
      valueHelp: 'envBuildProductsDir',
      help:
          'Required environment variable for running `upload-symbols` script.',
    );

    argParser.addOption(
      'env-dwarf-dsym-folder-path',
      valueHelp: 'envDwarfDsymFolderPath',
      help:
          'Required environment variable for running `upload-symbols` script.',
    );

    argParser.addOption(
      'env-dwarf-dsym-file-name',
      valueHelp: 'envDwarfDsymFileName',
      help:
          'Required environment variable for running `upload-symbols` script.',
    );

    argParser.addOption(
      'env-infoplist-path',
      valueHelp: 'envInfoPlistPath',
      help:
          'Required environment variable for running `upload-symbols` script.',
    );
  }

  @override
  final bool hidden = true;

  @override
  final String description =
      'Upload Crashlytics debug symbols to Firebase Crashlytics server upon building application.';

  @override
  final String name = 'upload-crashlytics-symbols';

  String get uploadSymbolsScriptPath {
    return argResults!['upload-symbols-script-path'] as String;
  }

  String get envPlatformName {
    return argResults!['env-platform-name'] as String;
  }

  String get envConfiguration {
    return argResults!['env-configuration'] as String;
  }

  String get envProjectDir {
    return argResults!['env-project-dir'] as String;
  }

  String get envBuildProductsDir {
    return argResults!['env-built-products-dir'] as String;
  }

  String get envDwarfDsymFolderPath {
    return argResults!['env-dwarf-dsym-folder-path'] as String;
  }

  String get envDwarfDsymFileName {
    return argResults!['env-dwarf-dsym-file-name'] as String;
  }

  String get envInfoPlistPath {
    return argResults!['env-infoplist-path'] as String;
  }

  String? get buildConfiguration {
    return argResults!['build-configuration'] as String?;
  }

  String? get target {
    return argResults!['target'] as String?;
  }

  String? get defaultConfig {
    return argResults!['default-config'] as String?;
  }

  String get appleProjectPath {
    return argResults!['apple-project-path'] as String;
  }

  String get platform {
    return argResults!['platform'] as String;
  }

  String get appIdFileName {
    return 'app_id_file.json';
  }

  String get appIdPropertyName {
    return 'GOOGLE_APP_ID';
  }

  String get projectIdPropertyName {
    return 'FIREBASE_PROJECT_ID';
  }

  ProjectConfiguration get projectConfiguration {
    if (buildConfiguration != null) {
      return ProjectConfiguration.buildConfiguration;
    }

    if (target != null) {
      return ProjectConfiguration.target;
    }

    return ProjectConfiguration.defaultConfig;
  }

  // "buildConfigurations", "targets" or "default" property
  String get configuration {
    return getProjectConfigurationProperty(projectConfiguration);
  }

  Future<String> _findOrCreateAppIdFile(
    String pathToAppIdFile,
    String appId,
    String projectId,
  ) async {
    // Will do nothing if it already exists
    await Directory(pathToAppIdFile).create(recursive: true);

    final file = File(path.join(pathToAppIdFile, appIdFileName));

    if (file.existsSync()) {
      final fileAsString = await file.readAsString();

      final map = jsonDecode(fileAsString) as Map;

      final fileAppId = map[appIdPropertyName] as String?;

      if (appId == fileAppId) {
        // App ID matches the one from firebase.json, return the path
        return file.path;
      } else {
        // Update app ID to match the current one from firebase.json
        map[appIdPropertyName] = appId;
        final updatedMapJson = json.encode(map);
        file.writeAsStringSync(updatedMapJson);

        return file.path;
      }
    } else {
      // Create file if it does not exist
      await file.create(recursive: true);
      final map = {appIdPropertyName: appId, projectIdPropertyName: projectId};

      final mapJson = json.encode(map);

      file.writeAsStringSync(mapJson);

      return file.path;
    }
  }

  Future<ConfigurationResults> _getConfigurationFromFirebaseJsonFile() async {
    final platformConfig =
        await appleConfigFromFirebaseJson(appleProjectPath, platform);

    String? appId;
    String? projectId;
    bool? uploadDebugSymbols;
    Map configurationMaps;
    String keyToConfig;
    try {
      configurationMaps = platformConfig[configuration] as Map;
      Map configurationMap;

      switch (projectConfiguration) {
        case ProjectConfiguration.buildConfiguration:
          keyToConfig = buildConfiguration!;
          // ignore: cast_nullable_to_non_nullable
          configurationMap =
              configurationMaps[keyToConfig] as Map<String, dynamic>;
          break;
        case ProjectConfiguration.target:
          keyToConfig = target!;
          // ignore: cast_nullable_to_non_nullable
          configurationMap =
              configurationMaps[keyToConfig] as Map<String, dynamic>;
          break;
        case ProjectConfiguration.defaultConfig:
          keyToConfig = defaultConfig!;
          // There is no more nested maps in "default" configuration, it is one single default configuration map
          configurationMap = configurationMaps;
      }

      uploadDebugSymbols = configurationMap[kUploadDebugSymbols] as bool?;
      appId = configurationMap[kAppId] as String?;
      projectId = configurationMap[kProjectId] as String?;
    } catch (e) {
      throw FirebaseJsonException();
    }

    if (projectId == null || appId == null) {
      throw FirebaseJsonException();
    }

    return ConfigurationResults(
      appId,
      projectId,
      uploadDebugSymbols,
      keyToConfig,
    );
  }

  @override
  Future<void> run() async {
    if (!Platform.isMacOS) return;

    final configurationResults = await _getConfigurationFromFirebaseJsonFile();
    final uploadDebugSymbols = configurationResults.runDebugSymbolsScript;
    final appId = configurationResults.appId;
    final projectId = configurationResults.projectId;
    final configurationKey = configurationResults.keyToConfig;

    // Exit if the user chooses not to run debug upload symbol script
    if (uploadDebugSymbols == false || uploadDebugSymbols == null) return;
    final appIdFileDirectory = path.join(
      path.dirname(Directory.current.path),
      '.dart_tool',
      'flutterfire',
      'platforms',
      platform,
      // We don't want the path to be "default/default" so we remove if it is
      configuration == 'default' ? '' : configuration,
      configurationKey,
      projectId,
    );
    final appIdFilePath =
        await _findOrCreateAppIdFile(appIdFileDirectory, appId, projectId);

    final appFrameworkDsymPath = path.join(
      envBuildProductsDir,
      'App.framework.dSYM',
    );

    final buildDirectory = Directory(appFrameworkDsymPath);

    // Set configuration to "Release" if "App.framework.dSYM" exists. Otherwise, "Debug". This is to ensure successful upload of symbols
    final buildConfiguration =
        buildDirectory.existsSync() ? 'Release' : 'Debug';

    // Validation script
    final validationScript = await Process.run(
      uploadSymbolsScriptPath,
      [
        '--validate',
        '--flutter-project',
        appIdFilePath,
      ],
      environment: {
        'PLATFORM_NAME': envPlatformName,
        'CONFIGURATION': buildConfiguration,
        'PROJECT_DIR': envProjectDir,
        'DWARF_DSYM_FOLDER_PATH': envDwarfDsymFolderPath,
        'DWARF_DSYM_FILE_NAME': envDwarfDsymFileName,
        'INFOPLIST_PATH': envInfoPlistPath,
        'BUILT_PRODUCTS_DIR': envBuildProductsDir,
      },
    );

    if (validationScript.exitCode != 0) {
      throw Exception(validationScript.stderr);
    }

    // Upload script
    final uploadScript = await Process.run(
      uploadSymbolsScriptPath,
      [
        '--flutter-project',
        appIdFilePath,
      ],
      environment: {
        'PLATFORM_NAME': envPlatformName,
        'CONFIGURATION': buildConfiguration,
        'PROJECT_DIR': envProjectDir,
        'DWARF_DSYM_FOLDER_PATH': envDwarfDsymFolderPath,
        'DWARF_DSYM_FILE_NAME': envDwarfDsymFileName,
        'INFOPLIST_PATH': envInfoPlistPath,
        'BUILT_PRODUCTS_DIR': envBuildProductsDir,
      },
    );

    if (uploadScript.exitCode != 0) {
      throw Exception(uploadScript.stderr);
    }

    if (uploadScript.stdout != null) {
      stdout.write(uploadScript.stdout as String);
      logger.stdout(uploadScript.stdout as String);
    }
  }
}

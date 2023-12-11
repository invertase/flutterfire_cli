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

import 'package:ansi_styles/ansi_styles.dart';
import 'package:ci/ci.dart' as ci;
import 'package:interact/interact.dart' as interact;
import 'package:path/path.dart'
    show relative, normalize, windows, joinAll, dirname, join;

import '../flutter_app.dart';
import 'platform.dart';

/// Key for windows platform.
const String kWindows = 'windows';

/// Key for macos platform.
const String kMacos = 'macos';

/// Key for linux platform.
const String kLinux = 'linux';

/// Key for IPA (iOS) platform. Shared with key for firebase.json
const String kIos = 'ios';

/// Key for APK (Android) platform.
const String kAndroid = 'android';

/// Key for Web platform.
const String kWeb = 'web';

// Keys for firebase.json
const String kFlutter = 'flutter';
const String kPlatforms = 'platforms';
const String kDart = 'dart';
const String kBuildConfiguration = 'buildConfigurations';
const String kTargets = 'targets';
const String kUploadDebugSymbols = 'uploadDebugSymbols';
const String kAppId = 'appId';
const String kProjectId = 'projectId';
const String kFileOutput = 'fileOutput';
const String kDefaultConfig = 'default';
const String kConfigurations = 'configurations';

// Flags for "flutterfire configure" command
const String kOutFlag = 'out';
const String kYesFlag = 'yes';
const String kPlatformsFlag = 'platforms';
const String kIosBundleIdFlag = 'ios-bundle-id';
const String kMacosBundleIdFlag = 'macos-bundle-id';
const String kAndroidAppIdFlag = 'android-app-id';
const String kAndroidPackageNameFlag = 'android-package-name';
const String kWebAppIdFlag = 'web-app-id';
const String kWindowsAppIdFlag = 'windows-app-id';
const String kTokenFlag = 'token';
const String kServiceAccountFlag = 'service-account';
const String kAppleGradlePluginFlag = 'apply-gradle-plugins';
const String kIosBuildConfigFlag = 'ios-build-config';
const String kMacosBuildConfigFlag = 'macos-build-config';
const String kIosTargetFlag = 'ios-target';
const String kMacosTargetFlag = 'macos-target';
const String kIosOutFlag = 'ios-out';
const String kMacosOutFlag = 'macos-out';
const String kAndroidOutFlag = 'android-out';
const String kOverwriteFirebaseOptionsFlag = 'overwrite-firebase-options';
const String kTestAccessTokenFlag = 'test-access-token';

enum ProjectConfiguration {
  target,
  buildConfiguration,
  defaultConfig,
}

extension Let<T> on T? {
  R? let<R>(R Function(T value) cb) {
    if (this == null) return null;

    return cb(this as T);
  }
}

bool get isCI {
  return ci.isCI;
}

int get terminalWidth {
  if (stdout.hasTerminal) {
    return stdout.terminalColumns;
  }

  return 80;
}

String listAsPaddedTable(List<List<String>> table, {int paddingSize = 1}) {
  final output = <String>[];
  final maxColumnSizes = <int, int>{};
  for (final row in table) {
    var i = 0;
    for (final column in row) {
      if (maxColumnSizes[i] == null ||
          maxColumnSizes[i]! < AnsiStyles.strip(column).length) {
        maxColumnSizes[i] = AnsiStyles.strip(column).length;
      }
      i++;
    }
  }

  for (final row in table) {
    var i = 0;
    final rowBuffer = StringBuffer();
    for (final column in row) {
      final colWidth = maxColumnSizes[i]! + paddingSize;
      final cellWidth = AnsiStyles.strip(column).length;
      var padding = colWidth - cellWidth;
      if (padding < paddingSize) padding = paddingSize;

      // last cell of the list, no need for padding
      if (i + 1 >= row.length) padding = 0;

      rowBuffer.write('$column${List.filled(padding, ' ').join()}');
      i++;
    }
    output.add(rowBuffer.toString());
  }

  return output.join('\n');
}

bool promptBool(
  String prompt, {
  bool defaultValue = true,
}) {
  return interact.Confirm(
    prompt: prompt,
    defaultValue: defaultValue,
  ).interact();
}

int promptSelect(
  String prompt,
  List<String> choices, {
  int initialIndex = 0,
}) {
  return interact.Select(
    prompt: prompt,
    options: choices,
    initialIndex: initialIndex,
  ).interact();
}

List<int> promptMultiSelect(
  String prompt,
  List<String> choices, {
  List<bool>? defaultSelection,
}) {
  return interact.MultiSelect(
    prompt: prompt,
    options: choices,
    defaults: defaultSelection,
  ).interact();
}

String promptInput(
  String prompt, {
  String? defaultValue,
  dynamic Function(String)? validator,
}) {
  return interact.Input(
    prompt: prompt,
    defaultValue: defaultValue,
    validator: (String input) {
      if (validator == null) return true;
      final Object? validatorResult = validator(input);
      if (validatorResult is bool) {
        return validatorResult;
      }
      if (validatorResult is String) {
        // ignore: only_throw_errors
        throw interact.ValidationError(validatorResult);
      }
      return false;
    },
  ).interact();
}

interact.SpinnerState? activeSpinnerState;
interact.SpinnerState spinner(String Function(bool) rightPrompt) {
  activeSpinnerState = interact.Spinner(
    icon: AnsiStyles.blue('i'),
    rightPrompt: rightPrompt,
  ).interact();
  return activeSpinnerState!;
}

String firebaseRcPathForDirectory(Directory directory) {
  return joinAll([directory.path, '.firebaserc']);
}

String pubspecPathForDirectory(Directory directory) {
  return joinAll([directory.path, 'pubspec.yaml']);
}

String androidAppBuildGradlePathForAppDirectory(Directory directory) {
  return joinAll([directory.path, 'android', 'app', 'build.gradle']);
}

File xcodeProjectFileInDirectory(Directory directory, String platform) {
  return File(
    joinAll(
      [directory.path, platform, 'Runner.xcodeproj', 'project.pbxproj'],
    ),
  );
}

File xcodeAppInfoConfigFileInDirectory(Directory directory, String platform) {
  return File(
    joinAll(
      [directory.path, platform, 'Runner', 'Configs', 'AppInfo.xcconfig'],
    ),
  );
}

String androidManifestPathForAppDirectory(Directory directory) {
  return joinAll([
    directory.path,
    'android',
    'app',
    'src',
    'main',
    'AndroidManifest.xml',
  ]);
}

String relativePath(String path, String from) {
  if (currentPlatform.isWindows) {
    return windows
        .normalize(relative(path, from: from))
        .replaceAll(r'\', r'\\');
  }
  return normalize(relative(path, from: from));
}

String replaceBackslash(String path) {
  if (currentPlatform.isWindows) {
    return normalize(path).replaceAll(r'\', '/');
  }
  return path;
}

String removeForwardBackwardSlash(String input) {
  var output = input;
  if (input.startsWith('/')) {
    output = input.substring(1);
  }

  if (input.endsWith('/')) {
    output = output.substring(0, output.length - 1);
  }

  return output;
}

Future<Map> appleConfigFromFirebaseJson(
  String appleProjectPath,
  String platform,
) async {
  // Pull values from firebase.json in root of project
  final flutterAppPath = dirname(appleProjectPath);
  final firebaseJson =
      await File('$flutterAppPath/firebase.json').readAsString();

  final decodedMap = json.decode(firebaseJson) as Map;

  final flutterConfig = decodedMap[kFlutter] as Map;
  final applePlatform = flutterConfig[kPlatforms] as Map;
  final appleConfig =
      applePlatform[platform.toLowerCase() == 'ios' ? kIos : kMacos] as Map;

  return appleConfig;
}

String getProjectConfigurationProperty(
  ProjectConfiguration projectConfiguration,
) {
  switch (projectConfiguration) {
    case ProjectConfiguration.defaultConfig:
      return kDefaultConfig;
    case ProjectConfiguration.buildConfiguration:
      return kBuildConfiguration;
    case ProjectConfiguration.target:
      return kTargets;
  }
}

Map<String, dynamic> _generateFlutterMap() {
  return <String, dynamic>{
    kFlutter: {kPlatforms: <String, Object>{}},
  };
}

Future<void> writeFirebaseJsonFile(
  FlutterApp flutterApp,
) async {
  final file = File('${flutterApp.package.path}/firebase.json');

  if (file.existsSync()) {
    final decodedMap =
        json.decode(await file.readAsString()) as Map<String, dynamic>;

    // Flutter map exists, exit
    if (decodedMap[kFlutter] != null) return;

    // Update existing map with Flutter map
    final updatedMap = <String, dynamic>{
      ...decodedMap,
      ..._generateFlutterMap(),
    };

    final mapJson = json.encode(updatedMap);

    file.writeAsStringSync(mapJson);
  } else {
    final map = _generateFlutterMap();

    final mapJson = json.encode(map);

    file.writeAsStringSync(mapJson);
  }
}

class FirebaseJsonWrites {
  FirebaseJsonWrites({
    required this.pathToMap,
    this.uploadDebugSymbols,
    this.projectId,
    this.appId,
    this.fileOutput,
    this.configurations,
  });
  //list of keys to map
  //list of values that can be null, if null, then don't write
  List<String> pathToMap;
  String? projectId;
  String? appId;
  bool? uploadDebugSymbols;
  String? fileOutput;
  // We need for dart configuration file
  Map<String, String>? configurations;
}

Future<void> writeToFirebaseJson({
  required List<FirebaseJsonWrites> listOfWrites,
  required String firebaseJsonPath,
}) async {
  final file = File(firebaseJsonPath);

  final decodedMap = !file.existsSync()
      ? <String, dynamic>{}
      : json.decode(await file.readAsString()) as Map<String, dynamic>;

  for (final write in listOfWrites) {
    final map = getNestedMap(decodedMap, write.pathToMap);

    if (write.projectId != null) {
      map[kProjectId] = write.projectId;
    }

    if (write.appId != null) {
      map[kAppId] = write.appId;
    }

    if (write.uploadDebugSymbols != null) {
      map[kUploadDebugSymbols] = write.uploadDebugSymbols;
    }

    if (write.fileOutput != null) {
      map[kFileOutput] = write.fileOutput;
    }

    if (write.configurations != null) {
      map[kConfigurations] = write.configurations;
    }
  }

  final mapJson = json.encode(decodedMap);

  file.writeAsStringSync(mapJson);
}

Map<String, dynamic> getNestedMap(Map<String, dynamic> map, List<String> keys) {
  final lastNestedMap = keys.fold<Map<String, dynamic>>(map, (currentMap, key) {
    return currentMap.putIfAbsent(key, () => <String, dynamic>{})
        as Map<String, dynamic>;
  });

  return lastNestedMap;
}

bool doesNestedMapExist(Map<String, dynamic> map, List<String> keys) {
  var currentMap = map;
  return keys.every((key) {
    if (currentMap.containsKey(key) &&
        currentMap[key] is Map<String, dynamic>) {
      currentMap = currentMap[key] as Map<String, dynamic>;
      return true;
    }
    return false;
  });
}

Future<List<String>> findTargetsAvailable(
  String platform,
  String xcodeProjectPath,
) async {
  final targetScript = '''
      require 'xcodeproj'
      xcodeProject='$xcodeProjectPath'
      project = Xcodeproj::Project.open(xcodeProject)

      response = Array.new

      project.targets.each do |target|
        response << target.name
      end

      if response.length == 0
        abort("There are no targets in your Xcode workspace. Please create a target and try again.")
      end

      \$stdout.write response.join(',')
    ''';

  final result = await Process.run('ruby', [
    '-e',
    targetScript,
  ]);

  if (result.exitCode != 0) {
    throw Exception(result.stderr);
  }
  // Retrieve the targets to to check if it exists on the project
  final targets = (result.stdout as String).split(',');

  return targets;
}

Future<List<String>> findBuildConfigurationsAvailable(
  String platform,
  String xcodeProjectPath,
) async {
  final buildConfigurationScript = '''
      require 'xcodeproj'
      xcodeProject='$xcodeProjectPath'

      project = Xcodeproj::Project.open(xcodeProject)

      response = Array.new

      project.build_configurations.each do |configuration|
        response << configuration
      end

      if response.length == 0
        abort("There are no build configurations in your Xcode workspace. Please create a build configuration and try again.")
      end

      \$stdout.write response.join(',')
    ''';

  final result = await Process.run('ruby', [
    '-e',
    buildConfigurationScript,
  ]);

  if (result.exitCode != 0) {
    throw Exception(result.stderr);
  }
  // Retrieve the build configurations to check if it exists on the project
  final buildConfigurations = (result.stdout as String).split(',');

  return buildConfigurations;
}

String getXcodeProjectPath(String platform) {
  return join(
    Directory.current.path,
    platform,
    'Runner.xcodeproj',
  );
}

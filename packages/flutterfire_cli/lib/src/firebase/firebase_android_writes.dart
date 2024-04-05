import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import '../common/strings.dart';
import '../common/utils.dart';
import '../flutter_app.dart';
import 'firebase_options.dart';

// https://regex101.com/r/Lj93lx/1
final _androidBuildGradleRegex = RegExp(
  r'dependencies\s*\{',
  multiLine: true,
);
// https://regex101.com/r/OZnO1j/1
final _androidAppBuildGradleRegex = RegExp(
  r'''(?:(^[\s]*?apply[\s]+plugin\:[\s]+['"]{1}com\.android\.application['"]{1})|(^[\s]*?id[\s]+["']com\.android\.application["']))''',
  multiLine: true,
);
// https://regex101.com/r/ndlYVL/1
final _androidBuildGradleGoogleServicesRegex = RegExp(
  r'''((?<indentation>^[\s]*?)classpath\s?['"]{1}com\.google\.gms:google-services:.*?['"]{1}\s*?$)''',
  multiLine: true,
);
// https://regex101.com/r/pP1k6i/1
final _androidAppBuildGradleGoogleServicesRegex = RegExp(
  r'''(?:(^[\s]*?apply[\s]+plugin\:[\s]+['"]{1}com\.google\.gms\.google-services['"]{1})|(^[\s]*?id[\s]+['"]com\.google\.gms\.google-services['"]))''',
  multiLine: true,
);

// Google services JSON.
const _googleServicesPluginClass = 'com.google.gms:google-services';
const _googleServicesPluginName = 'com.google.gms.google-services';
// TODO read from firebase_core pubspec.yaml firebase.google_services_gradle_plugin_version
const _googleServicesPluginVersion = '4.3.15';
const _googleServicesPlugin =
    "classpath '$_googleServicesPluginClass:$_googleServicesPluginVersion'";

// Firebase Crashlytics
const _crashlyticsPluginClassPath =
    'com.google.firebase:firebase-crashlytics-gradle';
// TODO read from firebase_core pubspec.yaml firebase.crashlytics_gradle_plugin_version
const _crashlyticsPluginClassPathVersion = '2.8.1';
const _crashlyticsPluginClass = 'com.google.firebase.crashlytics';

// Firebase Performance
const _performancePluginClassPath = 'com.google.firebase:perf-plugin';
// TODO read from firebase_core pubspec.yaml firebase.performance_gradle_plugin_version
const _performancePluginClassPathVersion = '1.4.1';
const _performancePluginClass = 'com.google.firebase.firebase-perf';

const _flutterFireConfigCommentStart = '// START: FlutterFire Configuration';
const _flutterFireConfigCommentEnd = '// END: FlutterFire Configuration';

String _applyGradleSettingsDependency(
  String dependency,
  String version, {
  bool flutterfireComments = false,
}) {
  if (flutterfireComments) {
    return '\n    $_flutterFireConfigCommentStart\n    id "$dependency" version "$version" apply false\n    $_flutterFireConfigCommentEnd';
  }
  return '\n    id "$dependency" version "$version" apply false';
}

enum BuildGradleConfiguration {
  legacy1,
  legacy2,
  latest,
}

class AndroidGradleContents {
  AndroidGradleContents({
    required this.buildGradleContent,
    required this.appBuildGradleContent,
    required this.gradleSettingsContent,
  });

  final String buildGradleContent;
  final String appBuildGradleContent;
  final String gradleSettingsContent;
}

class FirebaseAndroidWrites {
  FirebaseAndroidWrites({
    required this.flutterApp,
    required this.firebaseOptions,
    required this.logger,
    this.androidServiceFilePath,
    required this.projectConfiguration,
  }) : assert(
          projectConfiguration == ProjectConfiguration.buildConfiguration &&
              androidServiceFilePath != null,
          '"androidServiceFilePath" must be provided when projectConfiguration is "buildConfiguration"',
        );

  final FlutterApp flutterApp;
  final FirebaseOptions firebaseOptions;
  final Logger logger;
  final String? androidServiceFilePath;
  ProjectConfiguration projectConfiguration;

  File get androidGoogleServicesJsonFile {
    if (projectConfiguration == ProjectConfiguration.buildConfiguration) {
      return File(
        path.join(
          flutterApp.package.path,
          androidServiceFilePath,
        ),
      );
    } else {
      return File(
        path.join(
          flutterApp.androidDirectory.path,
          'app',
          firebaseOptions.optionsSourceFileName,
        ),
      );
    }
  }

  Future<void> _writeAndroidGoogleServicesJsonFile() async {
    if (projectConfiguration == ProjectConfiguration.buildConfiguration) {
      final updatedPath = path.join(
        flutterApp.package.path,
        androidServiceFilePath,
      );
      await File(updatedPath).create(recursive: true);
    }

    await androidGoogleServicesJsonFile.writeAsString(
      firebaseOptions.optionsSourceContent,
    );
  }

  FirebaseJsonWrites _firebaseJsonWrites() {
    final keysToMap = [kFlutter, kPlatforms, kAndroid];
    String? relativeServiceFile;
    if (projectConfiguration == ProjectConfiguration.buildConfiguration) {
      keysToMap.add(kBuildConfiguration);

      final segments = path.split(androidServiceFilePath!);
      final appIndex = segments.indexOf('app');
      // We have already validated that the "app" segment is on the path
      final newPath = path.joinAll(segments.sublist(appIndex + 1));
      // The key used for "firebase.json"
      // If not default, there will be a build type key. e.g. "staging"
      keysToMap.add(path.dirname(newPath));

      relativeServiceFile =
          path.relative(androidServiceFilePath!, from: flutterApp.package.path);
    } else {
      keysToMap.add(kDefaultConfig);

      relativeServiceFile = path.join(
        'android',
        'app',
        androidServiceFileName,
      );
    }

    return FirebaseJsonWrites(
      pathToMap: keysToMap,
      projectId: firebaseOptions.projectId,
      appId: firebaseOptions.appId,
      fileOutput: replaceBackslash(relativeServiceFile),
    );
  }

  Future<FirebaseJsonWrites> apply() async {
    await _writeAndroidGoogleServicesJsonFile();

    await gradleContentUpdates(flutterApp);

    return _firebaseJsonWrites();
  }
}

Future<void> gradleContentUpdates(
  FlutterApp flutterApp,
) async {
  final androidBuildGradleFile = File(
    path.join(
      flutterApp.androidDirectory.path,
      'build.gradle',
    ),
  );
  final androidBuildGradleFileContents =
      androidBuildGradleFile.readAsStringSync();

  final androidAppBuildGradleFile = File(
    path.join(
      flutterApp.androidDirectory.path,
      'app',
      'build.gradle',
    ),
  );
  final androidAppBuildGradleFileContents =
      androidAppBuildGradleFile.readAsStringSync();

  final androidGradleSettingsFile = File(
    path.join(
      flutterApp.androidDirectory.path,
      'settings.gradle',
    ),
  );

  final androidGradleSettingsFileContents =
      androidGradleSettingsFile.readAsStringSync();

  var content = AndroidGradleContents(
    buildGradleContent: androidBuildGradleFileContents,
    appBuildGradleContent: androidAppBuildGradleFileContents,
    gradleSettingsContent: androidGradleSettingsFileContents,
  );

  // Legacy build.gradle's update 1
  // android/build.gradle - update the dependencies block
  // android/app/build.gradle - update via apply plugins
  // We check if "apply plugin: 'com.android.application'" is present in the android/app/build.gradle file
  if (androidAppBuildGradleFileContents
      .contains("apply plugin: 'com.android.application'")) {
    content = _applyGoogleServicesPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
    );
    content = _applyCrashlyticsPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
    );
    content = _applyPerformancePlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
    );
  }

  // Legacy build.gradle's update 2
  // android/build.gradle - update the dependencies block
  // android/app/build.gradle - update plugins block containing "id "com.android.application""
  // We check if plugins block does not contain "id "com.android.application"" in the android/gradle.settings file
  // & android/app/build.gradle file does not contain "apply plugin: 'com.android.application"
  if (!androidGradleSettingsFileContents
          .contains('id "com.android.application"') &&
      !androidAppBuildGradleFileContents
          .contains("apply plugin: 'com.android.application'")) {
    content = _applyGoogleServicesPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
    );
    content = _applyCrashlyticsPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
    );
    content = _applyPerformancePlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
    );
  }

  // Latest build.gradle's update 3
  // do nothing to android/build.gradle
  // android/app/build.gradle - update plugins block containing "id "com.android.application""
  // android/settings.gradle - update the plugins block containing "id "com.android.application""
  // We check if plugins block containing "id "com.android.application"" is present in the android/settings.gradle file
  if (androidGradleSettingsFileContents
      .contains('id "com.android.application"')) {
    content = _applyGoogleServicesPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
    );
    content = _applyCrashlyticsPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
    );
    content = _applyPerformancePlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
    );

    // WRITE <app>/android/settings.gradle. We only need to do this with latest Flutter version >= 3.16.5
    await androidGradleSettingsFile.writeAsString(
      content.gradleSettingsContent,
    );
  }

  // WRITE <app>/android/build.gradle
  await androidBuildGradleFile.writeAsString(content.buildGradleContent);

  // WRITE <app>/android/app/build.gradle
  await androidAppBuildGradleFile.writeAsString(
    content.appBuildGradleContent,
  );
}

AndroidGradleContents _legacyUpdateAndroidBuildGradle(
  AndroidGradleContents content,
) {
  var androidBuildGradleFileContents = content.buildGradleContent;

  if (!androidBuildGradleFileContents.contains(_googleServicesPluginClass)) {
    final hasMatch =
        _androidBuildGradleRegex.hasMatch(androidBuildGradleFileContents);
    if (!hasMatch) {
      // Unable to match the pattern in the android/build.gradle file
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: content.appBuildGradleContent,
        gradleSettingsContent: content.gradleSettingsContent,
      );
    }
  } else {
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleFileContents,
      appBuildGradleContent: content.appBuildGradleContent,
      gradleSettingsContent: content.gradleSettingsContent,
    );
  }
  androidBuildGradleFileContents = androidBuildGradleFileContents
      .replaceFirstMapped(_androidBuildGradleRegex, (match) {
    const indentation = '        ';
    return '${match.group(0)}\n$indentation$_flutterFireConfigCommentStart\n$indentation$_googleServicesPlugin\n$indentation$_flutterFireConfigCommentEnd';
  });

  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleFileContents,
    appBuildGradleContent: content.appBuildGradleContent,
    gradleSettingsContent: content.gradleSettingsContent,
  );
}

AndroidGradleContents _applyGoogleServicesPlugin(
  FlutterApp flutterApp,
  AndroidGradleContents content,
  BuildGradleConfiguration buildGradleConfiguration,
) {
  var androidBuildGradleFileContents = content.buildGradleContent;
  var androidAppBuildGradleFileContents = content.appBuildGradleContent;
  var androidGradleSettingsFileContents = content.gradleSettingsContent;

  if (buildGradleConfiguration == BuildGradleConfiguration.legacy1 ||
      buildGradleConfiguration == BuildGradleConfiguration.legacy2) {
    final updatedContent = _legacyUpdateAndroidBuildGradle(content);
    androidBuildGradleFileContents = updatedContent.buildGradleContent;
  }

  if (!androidAppBuildGradleFileContents.contains(_googleServicesPluginClass)) {
    final hasMatch =
        _androidAppBuildGradleRegex.hasMatch(androidAppBuildGradleFileContents);
    if (!hasMatch) {
      // Unable to match the pattern in the android/app/build.gradle file
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: androidAppBuildGradleFileContents,
        gradleSettingsContent: androidGradleSettingsFileContents,
      );
    }
  } else {
    // Already applied.
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleFileContents,
      appBuildGradleContent: androidAppBuildGradleFileContents,
      gradleSettingsContent: androidGradleSettingsFileContents,
    );
  }

  if (!androidAppBuildGradleFileContents.contains(_googleServicesPluginName)) {
    androidAppBuildGradleFileContents = androidAppBuildGradleFileContents
        .replaceFirstMapped(_androidAppBuildGradleRegex, (match) {
      // Check which pattern was matched and insert the appropriate content
      if (match.group(0) != null) {
        if (buildGradleConfiguration == BuildGradleConfiguration.legacy2 ||
            buildGradleConfiguration == BuildGradleConfiguration.latest) {
          // This is legacy2 & latest
          // If matched pattern is 'id "com.android.application"'
          return "${match.group(0)}\n    $_flutterFireConfigCommentStart\n    id '$_googleServicesPluginName'\n    $_flutterFireConfigCommentEnd";
        } else {
          // This is legacy1
          // If matched pattern is 'apply plugin:...'
          return "${match.group(0)}\n$_flutterFireConfigCommentStart\napply plugin: '$_googleServicesPluginName'\n$_flutterFireConfigCommentEnd";
        }
      }
      throw Exception(
        'Could not match pattern in android/app `build.gradle` file for plugin $_googleServicesPluginName',
      );
    });
  }

  if (buildGradleConfiguration == BuildGradleConfiguration.latest) {
    final pluginExists = androidGradleSettingsFileContents
        .contains(_androidAppBuildGradleGoogleServicesRegex);

    if (!pluginExists) {
      final pattern =
          RegExp(r'id "com\.android\.application" version "[^"]*" apply false');
      final match = pattern.firstMatch(androidGradleSettingsFileContents);

      if (match != null) {
        // Find the index where to insert the new line
        final endIndex = match.end;
        final toInsert = _applyGradleSettingsDependency(
          _googleServicesPluginName,
          _googleServicesPluginVersion,
          flutterfireComments: true,
        );

        // Insert the new line
        androidGradleSettingsFileContents =
            androidGradleSettingsFileContents.substring(0, endIndex) +
                toInsert +
                androidGradleSettingsFileContents.substring(endIndex);
      }
    }
  }
  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleFileContents,
    appBuildGradleContent: androidAppBuildGradleFileContents,
    gradleSettingsContent: androidGradleSettingsFileContents,
  );
}

AndroidGradleContents _applyCrashlyticsPlugin(
  FlutterApp flutterApp,
  AndroidGradleContents content,
  BuildGradleConfiguration buildGradleConfiguration,
) {
  // do not apply if firebase_crashlytics is not present
  if (!flutterApp.dependsOnPackage('firebase_crashlytics')) return content;

  return _applyFirebaseAndroidPlugin(
    pluginClassPath: _crashlyticsPluginClassPath,
    pluginClassPathVersion: _crashlyticsPluginClassPathVersion,
    pluginClass: _crashlyticsPluginClass,
    content: content,
    buildGradleConfiguration: buildGradleConfiguration,
  );
}

AndroidGradleContents _applyPerformancePlugin(
  FlutterApp flutterApp,
  AndroidGradleContents content,
  BuildGradleConfiguration buildGradleConfiguration,
) {
  // do not apply if firebase_performance is not present
  if (!flutterApp.dependsOnPackage('firebase_performance')) return content;

  return _applyFirebaseAndroidPlugin(
    pluginClassPath: _performancePluginClassPath,
    pluginClassPathVersion: _performancePluginClassPathVersion,
    pluginClass: _performancePluginClass,
    content: content,
    buildGradleConfiguration: buildGradleConfiguration,
  );
}

AndroidGradleContents _applyFirebaseAndroidPlugin({
  required String pluginClassPath,
  required String pluginClassPathVersion,
  required String pluginClass,
  required AndroidGradleContents content,
  required BuildGradleConfiguration buildGradleConfiguration,
}) {
  var androidBuildGradleFileContents = content.buildGradleContent;
  var androidAppBuildGradleFileContents = content.appBuildGradleContent;
  var androidGradleSettingsFileContents = content.gradleSettingsContent;

  if (BuildGradleConfiguration.legacy1 == buildGradleConfiguration ||
      BuildGradleConfiguration.legacy2 == buildGradleConfiguration) {
    if (!androidBuildGradleFileContents.contains(pluginClassPath)) {
      final hasMatch = _androidBuildGradleGoogleServicesRegex
          .hasMatch(androidBuildGradleFileContents);
      if (!hasMatch) {
        // Unable to match the pattern in the android/app/build.gradle file
        return AndroidGradleContents(
          buildGradleContent: androidBuildGradleFileContents,
          appBuildGradleContent: androidAppBuildGradleFileContents,
          gradleSettingsContent: androidGradleSettingsFileContents,
        );
      }
    } else {
      // Already applied.
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: androidAppBuildGradleFileContents,
        gradleSettingsContent: androidGradleSettingsFileContents,
      );
    }
    androidBuildGradleFileContents = androidBuildGradleFileContents
        .replaceFirstMapped(_androidBuildGradleGoogleServicesRegex, (match) {
      final indentation = match.group(2);
      return "${match.group(1)}\n${indentation}classpath '$pluginClassPath:$pluginClassPathVersion'";
    });
  }

  if (!androidAppBuildGradleFileContents.contains(pluginClass)) {
    final hasMatch = _androidAppBuildGradleGoogleServicesRegex
        .hasMatch(androidAppBuildGradleFileContents);
    if (!hasMatch) {
      // TODO some unrecoverable error here?
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: androidAppBuildGradleFileContents,
        gradleSettingsContent: androidGradleSettingsFileContents,
      );
    }
  } else {
    // Already applied.
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleFileContents,
      appBuildGradleContent: androidAppBuildGradleFileContents,
      gradleSettingsContent: androidGradleSettingsFileContents,
    );
  }
  androidAppBuildGradleFileContents = androidAppBuildGradleFileContents
      .replaceFirstMapped(_androidAppBuildGradleGoogleServicesRegex, (match) {
    // Check which pattern was matched and insert the appropriate content
    if (match.group(0) != null) {
      if (BuildGradleConfiguration.legacy2 == buildGradleConfiguration ||
          BuildGradleConfiguration.latest == buildGradleConfiguration) {
        // This is legacy2 & latest
        // If matched pattern is 'id "com.google.gms.google-services"'
        return "${match.group(0)}\n    id '$pluginClass'";
      } else {
        // If matched pattern is 'apply plugin:...'
        return "${match.group(0)}\napply plugin: '$pluginClass'";
      }
    }
    throw Exception(
      'Could not match pattern in android/app `build.gradle` file for plugin $pluginClass',
    );
  });

  if (BuildGradleConfiguration.latest == buildGradleConfiguration) {
    // We need to update the android/settings.gradle file
    final pluginExists =
        androidGradleSettingsFileContents.contains(RegExp(pluginClassPath));

    if (!pluginExists) {
      final pattern = RegExp(
        r'id "com\.google\.gms\.google-services" version "\d+\.\d+\.\d+" apply false',
      );

      final match = pattern.firstMatch(androidGradleSettingsFileContents);

      if (match != null) {
        // Find the index where to insert the new line
        final endIndex = match.end;
        final toInsert = _applyGradleSettingsDependency(
          // Need to use plugin class rather than plugin class path in settings.gradle
          pluginClassPath.contains('crashlytics')
              ? _crashlyticsPluginClass
              : _performancePluginClass,
          pluginClassPathVersion,
        );

        // Insert the new line
        androidGradleSettingsFileContents =
            androidGradleSettingsFileContents.substring(0, endIndex) +
                toInsert +
                androidGradleSettingsFileContents.substring(endIndex);
      }
    }
  }

  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleFileContents,
    appBuildGradleContent: androidAppBuildGradleFileContents,
    gradleSettingsContent: androidGradleSettingsFileContents,
  );
}

import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../common/strings.dart';
import '../common/utils.dart';
import '../flutter_app.dart';
import 'firebase_options.dart';
import 'firebase_pubspec_model.dart';

// Gradle Groovy DSL RegExp

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

// Gradle Kotlin DSL RegExp
// https://regex101.com/r/wgXNuN/1
final _androidBuildGradleKtsRegex = RegExp(
  r'dependencies\s*\{',
  multiLine: true,
);
// https://regex101.com/r/Qubo6v/1
final _androidAppBuildGradleKtsRegex = RegExp(
  r'^\s*id\s*\(\s*"com\.android\.application"\s*\)',
  multiLine: true,
);
// https://regex101.com/r/l6LvNV/1
final _androidBuildGradleKtsGoogleServicesRegex = RegExp(
  r'''((?<indentation>^[\s]*?)classpath\s?\("{1}com\.google\.gms:google-services:.*?"\){1}\s*?$)''',
  multiLine: true,
);
// https://regex101.com/r/w5cW65/2
final _androidAppBuildGradleKtsGoogleServicesRegex = RegExp(
  r'''(?:(^[\s]*?apply[\s]*\(plugin[\s]*=[\s]*"{1}com\.google\.gms\.google-services"\){1})|(^[\s]*?id[\s]*\("com\.google\.gms\.google-services"\)))''',
  multiLine: true,
);

// Google services JSON.
const _googleServicesPluginClassPath = 'com.google.gms:google-services';
const _googleServicesPluginClass = 'com.google.gms.google-services';
const _googleServicesPluginClassPathFallbackVersion = '4.3.15';

// Firebase Crashlytics
const _crashlyticsPluginClassPath =
    'com.google.firebase:firebase-crashlytics-gradle';
const _crashlyticsPluginClass = 'com.google.firebase.crashlytics';
const _crashlyticsPluginClassPathFallbackVersion = '2.8.1';

// Firebase Performance
const _performancePluginClassPath = 'com.google.firebase:perf-plugin';
const _performancePluginClass = 'com.google.firebase.firebase-perf';
const _performancePluginClassPathFallbackVersion = '1.4.1';

const _flutterFireConfigCommentStart = '// START: FlutterFire Configuration';
const _flutterFireConfigCommentEnd = '// END: FlutterFire Configuration';

// Public regex patterns for testing
/// Pattern for matching Android application plugin with mixed quotes in settings.gradle
final androidApplicationPluginPattern = RegExp(
  "id ([\"']com\\.android\\.application[\"']) version ([\"'][^\"']*[\"']) apply false",
);

/// Pattern for matching Google Services plugin with mixed quotes in settings.gradle
final googleServicesPluginPattern = RegExp(
  "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
);

/// Pattern for matching Kotlin DSL Google Services plugin with mixed quotes in settings.gradle.kts
final kotlinGoogleServicesPluginPattern = RegExp(
  "id\\(([\"']com\\.google\\.gms\\.google-services[\"'])\\) version\\(([\"']\\d+\\.\\d+\\.\\d+[\"'])\\) apply false",
);

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

String _applyGradleSettingsDependencyKts(
  String dependency,
  String version, {
  bool flutterfireComments = false,
}) {
  if (flutterfireComments) {
    return '\n    $_flutterFireConfigCommentStart\n    id("$dependency") version("$version") apply false\n    $_flutterFireConfigCommentEnd';
  }
  return '\n    id("$dependency") version("$version") apply false';
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

  if (androidBuildGradleFile.existsSync()) {
    return _gradleContentUpdates(flutterApp);
  }

  final androidBuildGradleKtsFile = File(
    path.join(
      flutterApp.androidDirectory.path,
      'build.gradle.kts',
    ),
  );

  if (androidBuildGradleKtsFile.existsSync()) {
    return _gradleKtsContentUpdates(flutterApp);
  }

  throw UnimplementedError(
    'Neither build.gradle nor build.gradle.kts were found at Paths:\n${androidBuildGradleFile.path}\n${androidBuildGradleKtsFile.path}',
  );
}

Future<void> _gradleContentUpdates(
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

  final firebaseCorePubSpec = await getFirebaseCorePubSpec();

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
      firebaseCorePubSpec.googleServicesGradlePluginVersion,
    );
    content = _applyCrashlyticsPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
      firebaseCorePubSpec.crashlyticsGradlePluginVersion,
    );
    content = _applyPerformancePlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
      firebaseCorePubSpec.performanceGradlePluginVersion,
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
      firebaseCorePubSpec.googleServicesGradlePluginVersion,
    );
    content = _applyCrashlyticsPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
      firebaseCorePubSpec.crashlyticsGradlePluginVersion,
    );
    content = _applyPerformancePlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
      firebaseCorePubSpec.performanceGradlePluginVersion,
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
      firebaseCorePubSpec.googleServicesGradlePluginVersion,
    );
    content = _applyCrashlyticsPlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
      firebaseCorePubSpec.crashlyticsGradlePluginVersion,
    );
    content = _applyPerformancePlugin(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
      firebaseCorePubSpec.performanceGradlePluginVersion,
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
  String googleServicesGradlePluginVersion,
) {
  var androidBuildGradleFileContents = content.buildGradleContent;

  if (!androidBuildGradleFileContents
      .contains(_googleServicesPluginClassPath)) {
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
    final googleServicesPlugin =
        "classpath '$_googleServicesPluginClassPath:$googleServicesGradlePluginVersion'";
    return '${match.group(0)}\n$indentation$_flutterFireConfigCommentStart\n$indentation$googleServicesPlugin\n$indentation$_flutterFireConfigCommentEnd';
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
  String googleServicesGradlePluginVersion,
) {
  var androidBuildGradleFileContents = content.buildGradleContent;
  var androidAppBuildGradleFileContents = content.appBuildGradleContent;
  var androidGradleSettingsFileContents = content.gradleSettingsContent;

  if (buildGradleConfiguration == BuildGradleConfiguration.legacy1 ||
      buildGradleConfiguration == BuildGradleConfiguration.legacy2) {
    final updatedContent = _legacyUpdateAndroidBuildGradle(
      content,
      googleServicesGradlePluginVersion,
    );
    androidBuildGradleFileContents = updatedContent.buildGradleContent;
  }

  if (!androidAppBuildGradleFileContents
      .contains(_googleServicesPluginClassPath)) {
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

  if (!androidAppBuildGradleFileContents.contains(_googleServicesPluginClass)) {
    androidAppBuildGradleFileContents = androidAppBuildGradleFileContents
        .replaceFirstMapped(_androidAppBuildGradleRegex, (match) {
      // Check which pattern was matched and insert the appropriate content
      if (match.group(0) != null) {
        if (buildGradleConfiguration == BuildGradleConfiguration.legacy2 ||
            buildGradleConfiguration == BuildGradleConfiguration.latest) {
          // This is legacy2 & latest
          // If matched pattern is 'id "com.android.application"'
          return "${match.group(0)}\n    $_flutterFireConfigCommentStart\n    id '$_googleServicesPluginClass'\n    $_flutterFireConfigCommentEnd";
        } else {
          // This is legacy1
          // If matched pattern is 'apply plugin:...'
          return "${match.group(0)}\n$_flutterFireConfigCommentStart\napply plugin: '$_googleServicesPluginClass'\n$_flutterFireConfigCommentEnd";
        }
      }
      throw Exception(
        'Could not match pattern in android/app `build.gradle` file for plugin $_googleServicesPluginClass',
      );
    });
  }

  if (buildGradleConfiguration == BuildGradleConfiguration.latest) {
    final pluginExists = androidGradleSettingsFileContents
        .contains(_androidAppBuildGradleGoogleServicesRegex);

    if (!pluginExists) {
      final pattern = androidApplicationPluginPattern;
      final match = pattern.firstMatch(androidGradleSettingsFileContents);

      if (match != null) {
        // Find the index where to insert the new line
        final endIndex = match.end;
        final toInsert = _applyGradleSettingsDependency(
          _googleServicesPluginClass,
          googleServicesGradlePluginVersion,
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
  String crashlyticsGradlePluginVersion,
) {
  // do not apply if firebase_crashlytics is not present
  if (!flutterApp.dependsOnPackage('firebase_crashlytics')) return content;

  return _applyFirebaseAndroidPlugin(
    pluginClassPath: _crashlyticsPluginClassPath,
    pluginClassPathVersion: crashlyticsGradlePluginVersion,
    pluginClass: _crashlyticsPluginClass,
    content: content,
    buildGradleConfiguration: buildGradleConfiguration,
  );
}

AndroidGradleContents _applyPerformancePlugin(
  FlutterApp flutterApp,
  AndroidGradleContents content,
  BuildGradleConfiguration buildGradleConfiguration,
  String performanceGradlePluginVersion,
) {
  // do not apply if firebase_performance is not present
  if (!flutterApp.dependsOnPackage('firebase_performance')) return content;

  return _applyFirebaseAndroidPlugin(
    pluginClassPath: _performancePluginClassPath,
    pluginClassPathVersion: performanceGradlePluginVersion,
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
      final pattern = googleServicesPluginPattern;

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

// Handle Gradle files written in Kotlin DSL,
// i.e., build.gradle.kts, app/build.gradle.kts and settings.gradle.kts files
Future<void> _gradleKtsContentUpdates(
  FlutterApp flutterApp,
) async {
  final androidBuildGradleKtsFile = File(
    path.join(
      flutterApp.androidDirectory.path,
      'build.gradle.kts',
    ),
  );
  final androidBuildGradleKtsFileContents =
      androidBuildGradleKtsFile.readAsStringSync();

  final androidAppBuildGradleKtsFile = File(
    path.join(
      flutterApp.androidDirectory.path,
      'app',
      'build.gradle.kts',
    ),
  );
  final androidAppBuildGradleKtsFileContents =
      androidAppBuildGradleKtsFile.readAsStringSync();

  final androidGradleSettingsKtsFile = File(
    path.join(
      flutterApp.androidDirectory.path,
      'settings.gradle.kts',
    ),
  );

  final firebaseCorePubSpec = await getFirebaseCorePubSpec();

  final androidGradleSettingsKtsFileContents =
      androidGradleSettingsKtsFile.readAsStringSync();

  var content = AndroidGradleContents(
    buildGradleContent: androidBuildGradleKtsFileContents,
    appBuildGradleContent: androidAppBuildGradleKtsFileContents,
    gradleSettingsContent: androidGradleSettingsKtsFileContents,
  );

  // Legacy build.gradle.kts's update 1
  // android/build.gradle.kts - update the dependencies block
  // android/app/build.gradle.kts - update via apply plugins
  // We check if "apply plugin: 'com.android.application'" is present in the android/app/build.gradle.kts file
  if (androidAppBuildGradleKtsFileContents
      .contains('''apply(plugin = "com.android.application")''')) {
    content = _applyGoogleServicesPluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
      firebaseCorePubSpec.googleServicesGradlePluginVersion,
    );
    content = _applyCrashlyticsPluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
      firebaseCorePubSpec.crashlyticsGradlePluginVersion,
    );
    content = _applyPerformancePluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy1,
      firebaseCorePubSpec.performanceGradlePluginVersion,
    );
  }

  // Legacy build.gradle.kts's update 2
  // android/build.gradle.kts - update the dependencies block
  // android/app/build.gradle.kts - update plugins block containing "id "com.android.application""
  // We check if plugins block does not contain "id "com.android.application"" in the android/gradle.settings.kts file
  // & android/app/build.gradle.kts file does not contain "apply plugin: 'com.android.application"
  if (!androidGradleSettingsKtsFileContents
          .contains('id("com.android.application")') &&
      !androidAppBuildGradleKtsFileContents
          .contains('''apply(plugin = "com.android.application")''')) {
    content = _applyGoogleServicesPluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
      firebaseCorePubSpec.googleServicesGradlePluginVersion,
    );
    content = _applyCrashlyticsPluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
      firebaseCorePubSpec.crashlyticsGradlePluginVersion,
    );
    content = _applyPerformancePluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.legacy2,
      firebaseCorePubSpec.performanceGradlePluginVersion,
    );
  }

  // Latest build.gradle.kts's update 3
  // do nothing to android/build.gradle.kts
  // android/app/build.gradle.kts - update plugins block containing "id "com.android.application""
  // android/settings.gradle.kts - update the plugins block containing "id "com.android.application""
  // We check if plugins block containing "id "com.android.application"" is present in the android/settings.gradle.kts file
  if (androidGradleSettingsKtsFileContents
      .contains('id("com.android.application")')) {
    content = _applyGoogleServicesPluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
      firebaseCorePubSpec.googleServicesGradlePluginVersion,
    );
    content = _applyCrashlyticsPluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
      firebaseCorePubSpec.crashlyticsGradlePluginVersion,
    );
    content = _applyPerformancePluginKts(
      flutterApp,
      content,
      BuildGradleConfiguration.latest,
      firebaseCorePubSpec.performanceGradlePluginVersion,
    );

    // WRITE <app>/android/settings.gradle.kts. We only need to do this with latest Flutter version >= 3.16.5
    await androidGradleSettingsKtsFile.writeAsString(
      content.gradleSettingsContent,
    );
  }

  // WRITE <app>/android/build.gradle.kts
  await androidBuildGradleKtsFile.writeAsString(content.buildGradleContent);

  // WRITE <app>/android/app/build.gradle.kts
  await androidAppBuildGradleKtsFile.writeAsString(
    content.appBuildGradleContent,
  );
}

AndroidGradleContents _legacyUpdateAndroidBuildGradleKts(
  AndroidGradleContents content,
  String googleServicesGradlePluginVersion,
) {
  var androidBuildGradleKtsFileContents = content.buildGradleContent;

  if (!androidBuildGradleKtsFileContents
      .contains(_googleServicesPluginClassPath)) {
    final hasMatch =
        _androidBuildGradleKtsRegex.hasMatch(androidBuildGradleKtsFileContents);
    if (!hasMatch) {
      // Unable to match the pattern in the android/build.gradle file
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleKtsFileContents,
        appBuildGradleContent: content.appBuildGradleContent,
        gradleSettingsContent: content.gradleSettingsContent,
      );
    }
  } else {
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleKtsFileContents,
      appBuildGradleContent: content.appBuildGradleContent,
      gradleSettingsContent: content.gradleSettingsContent,
    );
  }
  androidBuildGradleKtsFileContents = androidBuildGradleKtsFileContents
      .replaceFirstMapped(_androidBuildGradleKtsRegex, (match) {
    const indentation = '        ';
    final googleServicesPluginKts =
        'classpath("$_googleServicesPluginClassPath:$googleServicesGradlePluginVersion")';
    return '${match.group(0)}\n$indentation$_flutterFireConfigCommentStart\n$indentation$googleServicesPluginKts\n$indentation$_flutterFireConfigCommentEnd';
  });

  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleKtsFileContents,
    appBuildGradleContent: content.appBuildGradleContent,
    gradleSettingsContent: content.gradleSettingsContent,
  );
}

AndroidGradleContents _applyGoogleServicesPluginKts(
  FlutterApp flutterApp,
  AndroidGradleContents content,
  BuildGradleConfiguration buildGradleConfiguration,
  String googleServicesGradlePluginVersion,
) {
  var androidBuildGradleKtsFileContents = content.buildGradleContent;
  var androidAppBuildGradleKtsFileContents = content.appBuildGradleContent;
  var androidGradleSettingsKtsFileContents = content.gradleSettingsContent;

  if (buildGradleConfiguration == BuildGradleConfiguration.legacy1 ||
      buildGradleConfiguration == BuildGradleConfiguration.legacy2) {
    final updatedContent = _legacyUpdateAndroidBuildGradleKts(
      content,
      googleServicesGradlePluginVersion,
    );
    androidBuildGradleKtsFileContents = updatedContent.buildGradleContent;
  }

  if (!androidAppBuildGradleKtsFileContents
      .contains(_googleServicesPluginClassPath)) {
    final hasMatch = _androidAppBuildGradleKtsRegex
        .hasMatch(androidAppBuildGradleKtsFileContents);
    if (!hasMatch) {
      // Unable to match the pattern in the android/app/build.gradle.kts file
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleKtsFileContents,
        appBuildGradleContent: androidAppBuildGradleKtsFileContents,
        gradleSettingsContent: androidGradleSettingsKtsFileContents,
      );
    }
  } else {
    // Already applied.
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleKtsFileContents,
      appBuildGradleContent: androidAppBuildGradleKtsFileContents,
      gradleSettingsContent: androidGradleSettingsKtsFileContents,
    );
  }

  if (!androidAppBuildGradleKtsFileContents
      .contains(_googleServicesPluginClass)) {
    androidAppBuildGradleKtsFileContents = androidAppBuildGradleKtsFileContents
        .replaceFirstMapped(_androidAppBuildGradleKtsRegex, (match) {
      // Check which pattern was matched and insert the appropriate content
      if (match.group(0) != null) {
        if (buildGradleConfiguration == BuildGradleConfiguration.legacy2 ||
            buildGradleConfiguration == BuildGradleConfiguration.latest) {
          // This is legacy2 & latest
          // If matched pattern is 'id("com.android.application")'
          return '${match.group(0)}\n    $_flutterFireConfigCommentStart\n    id("$_googleServicesPluginClass")\n    $_flutterFireConfigCommentEnd';
        } else {
          // This is legacy1
          // If matched pattern is 'apply plugin:...'
          return '${match.group(0)}\n$_flutterFireConfigCommentStart\napply(plugin = "$_googleServicesPluginClass")\n$_flutterFireConfigCommentEnd';
        }
      }
      throw Exception(
        'Could not match pattern in android/app `build.gradle.kts` file for plugin $_googleServicesPluginClass',
      );
    });
  }

  if (buildGradleConfiguration == BuildGradleConfiguration.latest) {
    final pluginExists = androidGradleSettingsKtsFileContents
        .contains(_androidAppBuildGradleKtsGoogleServicesRegex);

    if (!pluginExists) {
      final pattern = RegExp(
        r'^.*id\("com\.android\.application"\).*',
        multiLine: true,
      );
      final match = pattern.firstMatch(androidGradleSettingsKtsFileContents);

      if (match != null) {
        // Find the index where to insert the new line
        final endIndex = match.end;
        final toInsert = _applyGradleSettingsDependencyKts(
          _googleServicesPluginClass,
          googleServicesGradlePluginVersion,
          flutterfireComments: true,
        );

        // Insert the new line
        androidGradleSettingsKtsFileContents =
            androidGradleSettingsKtsFileContents.substring(0, endIndex) +
                toInsert +
                androidGradleSettingsKtsFileContents.substring(endIndex);
      }
    }
  }
  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleKtsFileContents,
    appBuildGradleContent: androidAppBuildGradleKtsFileContents,
    gradleSettingsContent: androidGradleSettingsKtsFileContents,
  );
}

AndroidGradleContents _applyCrashlyticsPluginKts(
  FlutterApp flutterApp,
  AndroidGradleContents content,
  BuildGradleConfiguration buildGradleConfiguration,
  String crashlyticsGradlePluginVersion,
) {
  // do not apply if firebase_crashlytics is not present
  if (!flutterApp.dependsOnPackage('firebase_crashlytics')) return content;

  return _applyFirebaseAndroidPluginKts(
    pluginClassPath: _crashlyticsPluginClassPath,
    pluginClassPathVersion: crashlyticsGradlePluginVersion,
    pluginClass: _crashlyticsPluginClass,
    content: content,
    buildGradleConfiguration: buildGradleConfiguration,
  );
}

AndroidGradleContents _applyPerformancePluginKts(
  FlutterApp flutterApp,
  AndroidGradleContents content,
  BuildGradleConfiguration buildGradleConfiguration,
  String performanceGradlePluginVersion,
) {
  // do not apply if firebase_performance is not present
  if (!flutterApp.dependsOnPackage('firebase_performance')) return content;

  return _applyFirebaseAndroidPluginKts(
    pluginClassPath: _performancePluginClassPath,
    pluginClassPathVersion: performanceGradlePluginVersion,
    pluginClass: _performancePluginClass,
    content: content,
    buildGradleConfiguration: buildGradleConfiguration,
  );
}

AndroidGradleContents _applyFirebaseAndroidPluginKts({
  required String pluginClassPath,
  required String pluginClassPathVersion,
  required String pluginClass,
  required AndroidGradleContents content,
  required BuildGradleConfiguration buildGradleConfiguration,
}) {
  var androidBuildGradleKtsFileContents = content.buildGradleContent;
  var androidAppBuildGradleKtsFileContents = content.appBuildGradleContent;
  var androidGradleSettingsKtsFileContents = content.gradleSettingsContent;

  if (BuildGradleConfiguration.legacy1 == buildGradleConfiguration ||
      BuildGradleConfiguration.legacy2 == buildGradleConfiguration) {
    if (!androidBuildGradleKtsFileContents.contains(pluginClassPath)) {
      final hasMatch = _androidBuildGradleKtsGoogleServicesRegex
          .hasMatch(androidBuildGradleKtsFileContents);
      if (!hasMatch) {
        // Unable to match the pattern in the android/app/build.gradle.kts file
        return AndroidGradleContents(
          buildGradleContent: androidBuildGradleKtsFileContents,
          appBuildGradleContent: androidAppBuildGradleKtsFileContents,
          gradleSettingsContent: androidGradleSettingsKtsFileContents,
        );
      }
    } else {
      // Already applied.
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleKtsFileContents,
        appBuildGradleContent: androidAppBuildGradleKtsFileContents,
        gradleSettingsContent: androidGradleSettingsKtsFileContents,
      );
    }
    androidBuildGradleKtsFileContents = androidBuildGradleKtsFileContents
        .replaceFirstMapped(_androidBuildGradleKtsGoogleServicesRegex, (match) {
      final indentation = match.group(2);
      return '${match.group(1)}\n${indentation}classpath("$pluginClassPath:$pluginClassPathVersion")';
    });
  }

  if (!androidAppBuildGradleKtsFileContents.contains(pluginClass)) {
    final hasMatch = _androidAppBuildGradleKtsGoogleServicesRegex
        .hasMatch(androidAppBuildGradleKtsFileContents);
    if (!hasMatch) {
      // TODO some unrecoverable error here as well?
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleKtsFileContents,
        appBuildGradleContent: androidAppBuildGradleKtsFileContents,
        gradleSettingsContent: androidGradleSettingsKtsFileContents,
      );
    }
  } else {
    // Already applied.
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleKtsFileContents,
      appBuildGradleContent: androidAppBuildGradleKtsFileContents,
      gradleSettingsContent: androidGradleSettingsKtsFileContents,
    );
  }
  androidAppBuildGradleKtsFileContents = androidAppBuildGradleKtsFileContents
      .replaceFirstMapped(_androidAppBuildGradleKtsGoogleServicesRegex,
          (match) {
    // Check which pattern was matched and insert the appropriate content
    if (match.group(0) != null) {
      if (BuildGradleConfiguration.legacy2 == buildGradleConfiguration ||
          BuildGradleConfiguration.latest == buildGradleConfiguration) {
        // This is legacy2 & latest
        // If matched pattern is 'id "com.google.gms.google-services"'
        return '${match.group(0)}\n    id("$pluginClass")';
      } else {
        // If matched pattern is 'apply plugin:...'
        return '${match.group(0)}\napply(plugin = "$pluginClass")';
      }
    }
    throw Exception(
      'Could not match pattern in android/app `build.gradle` file for plugin $pluginClass',
    );
  });

  if (BuildGradleConfiguration.latest == buildGradleConfiguration) {
    // We need to update the android/settings.gradle file
    final pluginExists =
        androidGradleSettingsKtsFileContents.contains(RegExp(pluginClassPath));

    if (!pluginExists) {
      final pattern = kotlinGoogleServicesPluginPattern;

      final match = pattern.firstMatch(androidGradleSettingsKtsFileContents);

      if (match != null) {
        // Find the index where to insert the new line
        final endIndex = match.end;
        final toInsert = _applyGradleSettingsDependencyKts(
          // Need to use plugin class rather than plugin class path in settings.gradle
          pluginClassPath.contains('crashlytics')
              ? _crashlyticsPluginClass
              : _performancePluginClass,
          pluginClassPathVersion,
        );

        // Insert the new line
        androidGradleSettingsKtsFileContents =
            androidGradleSettingsKtsFileContents.substring(0, endIndex) +
                toInsert +
                androidGradleSettingsKtsFileContents.substring(endIndex);
      }
    }
  }

  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleKtsFileContents,
    appBuildGradleContent: androidAppBuildGradleKtsFileContents,
    gradleSettingsContent: androidGradleSettingsKtsFileContents,
  );
}

Future<FirebasePubSpecModel> getFirebaseCorePubSpec() async {
  try {
    const packageName = 'firebase_core-';
    final pubCacheFolder = _getPubCacheDirectory();
    final items = pubCacheFolder.listSync();
    final firebaseCoreItems = items
        // Take only folders
        .whereType<Directory>()
        // Take only folders from firebase_core package
        .where(
          (e) => e.uri.pathSegments
              .where((p) => p.isNotEmpty)
              .last
              .startsWith(packageName),
        )
        // Sort by version
        .sorted(
      (a, b) {
        final aVersion = Version.parse(
          a.uri.pathSegments
              .where((p) => p.isNotEmpty)
              .last
              .replaceFirst(packageName, ''),
        );

        final bVersion = Version.parse(
          b.uri.pathSegments
              .where((p) => p.isNotEmpty)
              .last
              .replaceFirst(packageName, ''),
        );

        return aVersion.compareTo(bVersion);
      },
    );

    final firebaseCoreDirectory = firebaseCoreItems.last;
    final firebaseCorePubspecFile =
        pubspecPathForDirectory(firebaseCoreDirectory);
    final content = await File(firebaseCorePubspecFile).readAsString();
    final yamlMap = loadYaml(content) as YamlMap;
    final unparsedJson = yamlMap['firebase'] as YamlMap?;
    if (unparsedJson != null) {
      return FirebasePubSpecModel.fromJson(
        unparsedJson.cast<String, dynamic>(),
      );
    }
  } catch (_) {
    // If we cannot find the firebase_core package, we return the fallback versions
  }

  return const FirebasePubSpecModel(
    googleServicesGradlePluginVersion:
        _googleServicesPluginClassPathFallbackVersion,
    crashlyticsGradlePluginVersion: _crashlyticsPluginClassPathFallbackVersion,
    performanceGradlePluginVersion: _performancePluginClassPathFallbackVersion,
  );
}

Directory _getPubCacheDirectory() {
  final env = Platform.environment;

  if (env.containsKey('PUB_CACHE')) {
    return Directory(env['PUB_CACHE']!);
  } else if (Platform.isWindows) {
    return Directory(
      path.join(env['LOCALAPPDATA']!, 'Pub', 'Cache', 'hosted', 'pub.dev'),
    );
  } else {
    return Directory(
      path.join('${env['HOME']}/.pub-cache', 'hosted', 'pub.dev'),
    );
  }
}

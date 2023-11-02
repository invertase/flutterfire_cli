import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import '../common/strings.dart';
import '../common/utils.dart';
import '../flutter_app.dart';
import 'firebase_options.dart';

// https://regex101.com/r/zIMgBI/1
final _androidBuildGradleRegex = RegExp(
  r'''(?:(?<indentation>^[\s]*?)classpath\s?['"]{1}com\.android\.tools\.build:gradle:.*?['"]{1}\s*?$)''',
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

class AndroidGradleContents {
  AndroidGradleContents({
    required this.buildGradleContent,
    required this.appBuildGradleContent,
  });

  final String buildGradleContent;
  final String appBuildGradleContent;
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
      fileOutput: relativeServiceFile,
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

  var content = AndroidGradleContents(
    buildGradleContent: androidBuildGradleFileContents,
    appBuildGradleContent: androidAppBuildGradleFileContents,
  );

  content = _applyGoogleServicesPlugin(
    flutterApp,
    content,
  );

  if (flutterApp.dependsOnPackage('firebase_crashlytics')) {
    // Apply only if firebase_crashlytics is present
    content = _applyCrashlyticsPlugin(
      flutterApp,
      content,
    );
  }

  if (flutterApp.dependsOnPackage('firebase_performance')) {
    // Apply only if firebase_performance is present
    content = _applyPerformancePlugin(
      flutterApp,
      content,
    );
  }

  // WRITE <app>/android/build.gradle
  await androidBuildGradleFile.writeAsString(content.buildGradleContent);

  // WRITE <app>/android/app/build.gradle
  await androidAppBuildGradleFile.writeAsString(
    content.appBuildGradleContent,
  );
}

AndroidGradleContents _applyGoogleServicesPlugin(
  FlutterApp flutterApp,
  AndroidGradleContents content,
) {
  var androidBuildGradleFileContents = content.buildGradleContent;
  var androidAppBuildGradleFileContents = content.appBuildGradleContent;

  if (!androidBuildGradleFileContents.contains(_googleServicesPluginClass)) {
    final hasMatch =
        _androidBuildGradleRegex.hasMatch(androidBuildGradleFileContents);
    if (!hasMatch) {
      // TODO some unrecoverable error here
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: androidAppBuildGradleFileContents,
      );
    }
  } else {
    // TODO already contains google services, should we upgrade version?
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleFileContents,
      appBuildGradleContent: androidAppBuildGradleFileContents,
    );
  }
  androidBuildGradleFileContents = androidBuildGradleFileContents
      .replaceFirstMapped(_androidBuildGradleRegex, (match) {
    final indentation = match.group(1);
    return '${match.group(0)}\n$indentation$_flutterFireConfigCommentStart\n$indentation$_googleServicesPlugin\n$indentation$_flutterFireConfigCommentEnd';
  });

  if (!androidAppBuildGradleFileContents.contains(_googleServicesPluginClass)) {
    final hasMatch =
        _androidAppBuildGradleRegex.hasMatch(androidAppBuildGradleFileContents);
    if (!hasMatch) {
      // TODO some unrecoverable error here?
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: androidAppBuildGradleFileContents,
      );
    }
  } else {
    // Already applied.
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleFileContents,
      appBuildGradleContent: androidAppBuildGradleFileContents,
    );
  }

  androidAppBuildGradleFileContents = androidAppBuildGradleFileContents
      .replaceFirstMapped(_androidAppBuildGradleRegex, (match) {
    // Check which pattern was matched and insert the appropriate content
    if (match.group(0) != null) {
      if (match.group(0)!.trim().startsWith('id')) {
        // If matched pattern is 'id "com.android.application"'
        return "${match.group(0)}\n    $_flutterFireConfigCommentStart\n    id '$_googleServicesPluginName'\n    $_flutterFireConfigCommentEnd";
      } else {
        // If matched pattern is 'apply plugin:...'
        return "${match.group(0)}\n$_flutterFireConfigCommentStart\napply plugin: '$_googleServicesPluginName'\n$_flutterFireConfigCommentEnd";
      }
    }
    throw Exception(
      'Could not match pattern in android/app `build.gradle` file for plugin $_googleServicesPluginName',
    );
  });

  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleFileContents,
    appBuildGradleContent: androidAppBuildGradleFileContents,
  );
}

AndroidGradleContents _applyCrashlyticsPlugin(
  FlutterApp flutterApp,
  AndroidGradleContents content,
) {
  return _applyFirebaseAndroidPlugin(
    pluginClassPath: _crashlyticsPluginClassPath,
    pluginClassPathVersion: _crashlyticsPluginClassPathVersion,
    pluginClass: _crashlyticsPluginClass,
    content: content,
  );
}

AndroidGradleContents _applyPerformancePlugin(
  FlutterApp flutterApp,
  AndroidGradleContents content,
) {
  return _applyFirebaseAndroidPlugin(
    pluginClassPath: _performancePluginClassPath,
    pluginClassPathVersion: _performancePluginClassPathVersion,
    pluginClass: _performancePluginClass,
    content: content,
  );
}

AndroidGradleContents _applyFirebaseAndroidPlugin({
  required String pluginClassPath,
  required String pluginClassPathVersion,
  required String pluginClass,
  required AndroidGradleContents content,
}) {
  var androidBuildGradleFileContents = content.buildGradleContent;
  var androidAppBuildGradleFileContents = content.appBuildGradleContent;

  if (!androidBuildGradleFileContents.contains(pluginClassPath)) {
    final hasMatch = _androidBuildGradleGoogleServicesRegex
        .hasMatch(androidBuildGradleFileContents);
    if (!hasMatch) {
      // TODO some unrecoverable error here
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: androidAppBuildGradleFileContents,
      );
    }
  } else {
    // TODO already contains plugin, should we upgrade version?
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleFileContents,
      appBuildGradleContent: androidAppBuildGradleFileContents,
    );
  }
  androidBuildGradleFileContents = androidBuildGradleFileContents
      .replaceFirstMapped(_androidBuildGradleGoogleServicesRegex, (match) {
    final indentation = match.group(2);
    return "${match.group(1)}\n${indentation}classpath '$pluginClassPath:$pluginClassPathVersion'";
  });

  if (!androidAppBuildGradleFileContents.contains(pluginClass)) {
    final hasMatch = _androidAppBuildGradleGoogleServicesRegex
        .hasMatch(androidAppBuildGradleFileContents);
    if (!hasMatch) {
      // TODO some unrecoverable error here?
      return AndroidGradleContents(
        buildGradleContent: androidBuildGradleFileContents,
        appBuildGradleContent: androidAppBuildGradleFileContents,
      );
    }
  } else {
    // Already applied.
    return AndroidGradleContents(
      buildGradleContent: androidBuildGradleFileContents,
      appBuildGradleContent: androidAppBuildGradleFileContents,
    );
  }
  androidAppBuildGradleFileContents = androidAppBuildGradleFileContents
      .replaceFirstMapped(_androidAppBuildGradleGoogleServicesRegex, (match) {
    // Check which pattern was matched and insert the appropriate content
    if (match.group(0) != null) {
      if (match.group(0)!.trim().startsWith('id')) {
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

  return AndroidGradleContents(
    buildGradleContent: androidBuildGradleFileContents,
    appBuildGradleContent: androidAppBuildGradleFileContents,
  );
}

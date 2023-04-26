import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import '../common/strings.dart';
import '../common/utils.dart';
import '../flutter_app.dart';
import 'firebase_options.dart';

// https://regex101.com/r/w2ovos/1
final _androidBuildGradleRegex = RegExp(
  r'''(?:\s*?dependencies\s?{$\n(?<indentation>[\s\S\w]*?)classpath\s?['"]{1}com\.android\.tools\.build:gradle:.*?['"]{1}\s*?$)''',
  multiLine: true,
);
// https://regex101.com/r/rbfAdd/1
final _androidAppBuildGradleRegex = RegExp(
  r'''(?:^[\s]*?apply[\s]+plugin\:[\s]+['"]{1}com\.android\.application['"]{1})''',
  multiLine: true,
);
// https://regex101.com/r/ndlYVL/1
final _androidBuildGradleGoogleServicesRegex = RegExp(
  r'''((?<indentation>^[\s]*?)classpath\s?['"]{1}com\.google\.gms:google-services:.*?['"]{1}\s*?$)''',
  multiLine: true,
);
// https://regex101.com/r/buEbed/1
final _androidAppBuildGradleGoogleServicesRegex = RegExp(
  r'''(?:^[\s]*?apply[\s]+plugin\:[\s]+['"]{1}com\.google\.gms\.google-services['"]{1})''',
  multiLine: true,
);

// Google services JSON.
const _googleServicesPluginClass = 'com.google.gms:google-services';
const _googleServicesPluginName = 'com.google.gms.google-services';
// TODO read from firebase_core pubspec.yaml firebase.google_services_gradle_plugin_version
const _googleServicesPluginVersion = '4.3.10';
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

  Future<void> createAndroidGoogleServicesJsonFile() async {
    if (projectConfiguration == ProjectConfiguration.buildConfiguration) {
      final updatedPath = path.join(
        flutterApp.package.path,
        androidServiceFilePath,
      );
      await File(updatedPath).create(recursive: true);
    }
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

  File get androidBuildGradleFile =>
      File(path.join(flutterApp.androidDirectory.path, 'build.gradle'));
  String? _androidBuildGradleFileContents;
  set androidBuildGradleFileContents(String contents) =>
      _androidBuildGradleFileContents = contents;
  String get androidBuildGradleFileContents =>
      _androidBuildGradleFileContents ??=
          androidBuildGradleFile.readAsStringSync();

  File get androidAppBuildGradleFile =>
      File(path.join(flutterApp.androidDirectory.path, 'app', 'build.gradle'));
  String? _androidAppBuildGradleFileContents;
  set androidAppBuildGradleFileContents(String contents) =>
      _androidAppBuildGradleFileContents = contents;
  String get androidAppBuildGradleFileContents =>
      _androidAppBuildGradleFileContents ??=
          androidAppBuildGradleFile.readAsStringSync();

  Future<void> applyGoogleServicesPlugin({
    bool force = false,
  }) async {
    await createAndroidGoogleServicesJsonFile();

    await androidGoogleServicesJsonFile.writeAsString(
      firebaseOptions.optionsSourceContent,
    );

    if (!androidBuildGradleFileContents.contains(_googleServicesPluginClass)) {
      final hasMatch =
          _androidBuildGradleRegex.hasMatch(androidBuildGradleFileContents);
      if (!hasMatch) {
        // TODO some unrecoverable error here
        return;
      }
    } else {
      // TODO already contains google services, should we upgrade version?
      return;
    }
    androidBuildGradleFileContents = androidBuildGradleFileContents
        .replaceFirstMapped(_androidBuildGradleRegex, (match) {
      final indentation = match.group(1);
      return '${match.group(0)}\n$indentation$_flutterFireConfigCommentStart\n$indentation$_googleServicesPlugin\n$indentation$_flutterFireConfigCommentEnd';
    });

    if (!androidAppBuildGradleFileContents
        .contains(_googleServicesPluginClass)) {
      final hasMatch = _androidAppBuildGradleRegex
          .hasMatch(androidAppBuildGradleFileContents);
      if (!hasMatch) {
        // TODO some unrecoverable error here?
        return;
      }
    } else {
      // Already applied.
      return;
    }
    androidAppBuildGradleFileContents = androidAppBuildGradleFileContents
        .replaceFirstMapped(_androidAppBuildGradleRegex, (match) {
      return "${match.group(0)}\n$_flutterFireConfigCommentStart\napply plugin: '$_googleServicesPluginName'\n$_flutterFireConfigCommentEnd";
    });
  }

  void _applyFirebaseAndroidPlugin({
    required String pluginClassPath,
    required String pluginClassPathVersion,
    required String pluginClass,
  }) {
    if (!androidBuildGradleFileContents.contains(pluginClassPath)) {
      final hasMatch = _androidBuildGradleGoogleServicesRegex
          .hasMatch(androidBuildGradleFileContents);
      if (!hasMatch) {
        // TODO some unrecoverable error here
        return;
      }
    } else {
      // TODO already contains plugin, should we upgrade version?
      return;
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
        return;
      }
    } else {
      // Already applied.
      return;
    }
    androidAppBuildGradleFileContents = androidAppBuildGradleFileContents
        .replaceFirstMapped(_androidAppBuildGradleGoogleServicesRegex, (match) {
      return "${match.group(0)}\napply plugin: '$pluginClass'";
    });
  }

  Future<void> applyCrashlyticsPlugin({
    bool force = false,
  }) async {
    if (!flutterApp.dependsOnPackage('firebase_crashlytics')) {
      // Skip since user doesn't have the plugin installed.
      return;
    }
    _applyFirebaseAndroidPlugin(
      pluginClassPath: _crashlyticsPluginClassPath,
      pluginClassPathVersion: _crashlyticsPluginClassPathVersion,
      pluginClass: _crashlyticsPluginClass,
    );
  }

  Future<void> applyPerformancePlugin({
    bool force = false,
  }) async {
    if (!flutterApp.dependsOnPackage('firebase_performance')) {
      // Skip since user doesn't have the plugin installed.
      return;
    }
    _applyFirebaseAndroidPlugin(
      pluginClassPath: _performancePluginClassPath,
      pluginClassPathVersion: _performancePluginClassPathVersion,
      pluginClass: _performancePluginClass,
    );
  }

  Future<FirebaseJsonWrites> apply({
    bool force = false,
  }) async {
    await applyGoogleServicesPlugin(force: force);
    await applyCrashlyticsPlugin(force: force);
    await applyPerformancePlugin(force: force);

    // WRITE <app>/android/build.gradle
    await androidBuildGradleFile.writeAsString(androidBuildGradleFileContents);

    // WRITE <app>/android/app/build.gradle
    await androidAppBuildGradleFile.writeAsString(
      androidAppBuildGradleFileContents,
    );

    return _firebaseJsonWrites();
  }
}

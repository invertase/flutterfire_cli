import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import '../common/utils.dart';
import '../flutter_app.dart';
import 'firebase_android_options.dart';
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

class FirebaseAndroidGradlePlugins {
  FirebaseAndroidGradlePlugins(
    this.flutterApp,
    this.firebaseOptions,
    this.logger,
  );

  final FlutterApp flutterApp;
  final FirebaseOptions firebaseOptions;
  final Logger logger;

  File get androidGoogleServicesJsonFile => File(
        path.join(
          flutterApp.androidDirectory.path,
          'app',
          firebaseOptions.optionsSourceFileName,
        ),
      );

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
    var existingProjectId = '';
    var shouldPromptOverwriteGoogleServicesJson = false;
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
        'Do you want to replace it with Firebase project ${AnsiStyles.green(firebaseOptions.projectId)}?',
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
    if (!flutterApp.package.dependencies.contains('firebase_crashlytics') &&
        !flutterApp.package.devDependencies.contains('firebase_crashlytics')) {
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
    if (!flutterApp.package.dependencies.contains('firebase_performance') &&
        !flutterApp.package.devDependencies.contains('firebase_performance')) {
      // Skip since user doesn't have the plugin installed.
      return;
    }
    _applyFirebaseAndroidPlugin(
      pluginClassPath: _performancePluginClassPath,
      pluginClassPathVersion: _performancePluginClassPathVersion,
      pluginClass: _performancePluginClass,
    );
  }

  Future<void> apply({
    bool force = false,
  }) async {
    if (!flutterApp.android) {
      // Flutter application is not configured to target Android.
      return;
    }
    final originalAndroidBuildGradleContents = androidBuildGradleFileContents;
    final originalAndroidAppBuildGradleContents =
        androidAppBuildGradleFileContents;

    await applyGoogleServicesPlugin(force: force);
    await applyCrashlyticsPlugin(force: force);
    await applyPerformancePlugin(force: force);

    final shouldPromptUpdateAndroidBuildGradle =
        originalAndroidBuildGradleContents != androidBuildGradleFileContents;
    final shouldPromptUpdateAndroidAppBuildGradle =
        originalAndroidAppBuildGradleContents !=
            androidAppBuildGradleFileContents;
    if ((shouldPromptUpdateAndroidBuildGradle ||
            shouldPromptUpdateAndroidAppBuildGradle) &&
        !force) {
      final updateAndroidGradleFiles = promptBool(
        'The files ${AnsiStyles.cyan('android/build.gradle')} & ${AnsiStyles.cyan('android/app/build.gradle')} will be updated to apply Firebase configuration and build plugins. '
        'Do you want to continue?',
      );
      if (!updateAndroidGradleFiles) {
        logger.stdout(
          'Skipping applying Firebase gradle plugins for Android. This may cause issues with some Firebase services on Android in your application.',
        );
        return;
      }
    }

    // WRITE <app>/android/build.gradle
    if (shouldPromptUpdateAndroidBuildGradle) {
      await androidBuildGradleFile
          .writeAsString(androidBuildGradleFileContents);
    }

    // WRITE <app>/android/app/build.gradle
    if (shouldPromptUpdateAndroidAppBuildGradle) {
      await androidAppBuildGradleFile.writeAsString(
        androidAppBuildGradleFileContents,
      );
    }
  }
}

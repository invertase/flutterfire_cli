import 'dart:convert';
import 'dart:io';

import 'package:flutterfire_cli/src/firebase/firebase_android_writes.dart';
import 'package:flutterfire_cli/src/flutter_app.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Writes a `firebase_core` package into [pubCache], declaring
/// [googleServicesVersion] as its Google Services Gradle plugin version.
Directory _writeFirebaseCore(
  Directory pubCache, {
  required String version,
  required String googleServicesVersion,
}) {
  final directory = Directory(
    path.join(pubCache.path, 'firebase_core-$version'),
  )..createSync(recursive: true);
  File(path.join(directory.path, 'pubspec.yaml')).writeAsStringSync('''
name: firebase_core
version: $version
firebase:
  google_services_gradle_plugin_version: '$googleServicesVersion'
  crashlytics_gradle_plugin_version: '3.0.3'
  performance_gradle_plugin_version: '1.4.2'
''');
  return directory;
}

/// Writes the `package_config.json` of [appDirectory], resolving
/// `firebase_core` to [firebaseCoreRootUri].
void _writePackageConfig(
  Directory appDirectory, {
  required String firebaseCoreRootUri,
}) {
  final dartTool = Directory(path.join(appDirectory.path, '.dart_tool'))
    ..createSync(recursive: true);
  File(path.join(dartTool.path, 'package_config.json')).writeAsStringSync(
    jsonEncode({
      'configVersion': 2,
      'packages': [
        {
          'name': 'firebase_core',
          'rootUri': firebaseCoreRootUri,
          'packageUri': 'lib/',
        },
      ],
    }),
  );
}

/// Creates a Flutter app in [appDirectory] with the given Android Gradle
/// files, written in the Kotlin DSL when [kotlin] is true.
Future<FlutterApp> _createAndroidApp(
  Directory appDirectory, {
  required String settings,
  required String appBuildGradle,
  bool kotlin = false,
}) async {
  final extension = kotlin ? '.kts' : '';
  final androidApp = Directory(path.join(appDirectory.path, 'android', 'app'))
    ..createSync(recursive: true);

  File(path.join(appDirectory.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.10.0
''');
  File(path.join(appDirectory.path, 'android', 'build.gradle$extension'))
      .writeAsStringSync('// Top-level build file\n');
  File(path.join(appDirectory.path, 'android', 'settings.gradle$extension'))
      .writeAsStringSync(settings);
  File(path.join(androidApp.path, 'build.gradle$extension'))
      .writeAsStringSync(appBuildGradle);

  return (await FlutterApp.load(appDirectory))!;
}

void main() {
  group('Firebase Android Writes - Regex Pattern Tests', () {
    group('Android Application Pattern Tests', () {
      test('should match android application with double quotes', () {
        final pattern = androidApplicationPluginPattern;

        const testString =
            'id "com.android.application" version "8.1.0" apply false';
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals('"com.android.application"'));
        expect(match.group(2), equals('"8.1.0"'));
      });

      test('should match android application with single quotes', () {
        final pattern = androidApplicationPluginPattern;

        const testString =
            "id 'com.android.application' version '8.1.0' apply false";
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals("'com.android.application'"));
        expect(match.group(2), equals("'8.1.0'"));
      });

      test('should match android application with mixed quotes', () {
        final pattern = androidApplicationPluginPattern;

        final testStrings = [
          'id "com.android.application" version \'8.1.0\' apply false',
          'id \'com.android.application\' version "8.1.0" apply false',
        ];

        for (final testString in testStrings) {
          expect(
            pattern.hasMatch(testString),
            isTrue,
            reason: 'Failed for: $testString',
          );
        }
      });

      test('should not match invalid android application patterns', () {
        final pattern = androidApplicationPluginPattern;

        final invalidStrings = [
          'id com.android.application version 8.1.0 apply false', // no quotes
          'id "com.android.library" version "8.1.0" apply false', // wrong plugin
          'id "com.android.application" version "8.1.0"', // missing apply false
        ];

        for (final testString in invalidStrings) {
          expect(
            pattern.hasMatch(testString),
            isFalse,
            reason: 'Should not match: $testString',
          );
        }
      });
    });

    group('Google Services Pattern Tests', () {
      test('should match google services with double quotes', () {
        final pattern = googleServicesPluginPattern;

        const testString =
            'id "com.google.gms.google-services" version "4.4.0" apply false';
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals('"com.google.gms.google-services"'));
        expect(match.group(2), equals('"4.4.0"'));
      });

      test('should match google services with single quotes', () {
        final pattern = googleServicesPluginPattern;

        const testString =
            "id 'com.google.gms.google-services' version '4.4.0' apply false";
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals("'com.google.gms.google-services'"));
        expect(match.group(2), equals("'4.4.0'"));
      });

      test('should match google services with mixed quotes', () {
        final pattern = googleServicesPluginPattern;

        final testStrings = [
          'id "com.google.gms.google-services" version \'4.4.0\' apply false',
          'id \'com.google.gms.google-services\' version "4.4.0" apply false',
        ];

        for (final testString in testStrings) {
          expect(
            pattern.hasMatch(testString),
            isTrue,
            reason: 'Failed for: $testString',
          );
        }
      });

      test('should match different version formats', () {
        final pattern = googleServicesPluginPattern;

        final testStrings = [
          'id "com.google.gms.google-services" version "4.3.15" apply false',
          'id "com.google.gms.google-services" version "4.4.0" apply false',
          'id "com.google.gms.google-services" version "5.0.1" apply false',
          "id 'com.google.gms.google-services' version '10.2.3' apply false",
        ];

        for (final testString in testStrings) {
          expect(
            pattern.hasMatch(testString),
            isTrue,
            reason: 'Failed for: $testString',
          );
        }
      });
    });

    group('Kotlin DSL Google Services Pattern Tests', () {
      test('should match kotlin DSL with double quotes', () {
        final pattern = kotlinGoogleServicesPluginPattern;

        const testString =
            'id("com.google.gms.google-services") version("4.4.0") apply false';
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals('"com.google.gms.google-services"'));
        expect(match.group(2), equals('"4.4.0"'));
      });

      test('should match kotlin DSL with single quotes', () {
        final pattern = kotlinGoogleServicesPluginPattern;

        const testString =
            "id('com.google.gms.google-services') version('4.4.0') apply false";
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals("'com.google.gms.google-services'"));
        expect(match.group(2), equals("'4.4.0'"));
      });

      test('should match kotlin DSL with mixed quotes', () {
        final pattern = kotlinGoogleServicesPluginPattern;

        final testStrings = [
          'id("com.google.gms.google-services") version(\'4.4.0\') apply false',
          'id(\'com.google.gms.google-services\') version("4.4.0") apply false',
        ];

        for (final testString in testStrings) {
          expect(
            pattern.hasMatch(testString),
            isTrue,
            reason: 'Failed for: $testString',
          );
        }
      });
    });

    group('Firebase Performance Plugin Pattern Tests', () {
      test('should match performance plugin patterns with various quotes', () {
        // Pattern used in settings.gradle
        final pattern = googleServicesPluginPattern;

        // Test that performance plugin would be found after google services
        const gradleContent = '''
plugins {
    id "com.android.application" version "8.1.0" apply false
    id "com.google.gms.google-services" version "4.4.0" apply false
    id 'com.google.firebase.firebase-perf' version "1.4.2" apply false
    id "com.google.firebase.crashlytics" version '2.9.9' apply false
}
''';

        expect(pattern.hasMatch(gradleContent), isTrue);

        // Test that it works with the actual example from the user
        const performancePattern =
            "id 'com.google.firebase.firebase-perf' version \"1.4.2\" apply false";
        const crashlyticsPattern =
            'id "com.google.firebase.crashlytics" version \'2.9.9\' apply false';

        expect(gradleContent.contains(performancePattern), isTrue);
        expect(gradleContent.contains(crashlyticsPattern), isTrue);
      });
    });

    group('Real-world gradle content patterns', () {
      test('should handle user-reported mixed quote scenarios', () {
        final googleServicesPattern = googleServicesPluginPattern;

        // Example content from the user's issue
        const gradleContent = '''
plugins {
    id "com.google.gms.google-services" version "4.4.0" apply false
    id 'com.google.firebase.firebase-perf' version "1.4.2" apply false
    id "com.google.firebase.crashlytics" version '2.9.9' apply false
}
''';

        // Should find the google services plugin
        expect(googleServicesPattern.hasMatch(gradleContent), isTrue);

        // Should find performance and crashlytics patterns if we create patterns for them
        final perfPattern = RegExp(
          "id ([\"']com\\.google\\.firebase\\.firebase-perf[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );
        final crashlyticsPattern = RegExp(
          "id ([\"']com\\.google\\.firebase\\.crashlytics[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        expect(perfPattern.hasMatch(gradleContent), isTrue);
        expect(crashlyticsPattern.hasMatch(gradleContent), isTrue);
      });

      test('should work with kotlin DSL mixed quotes', () {
        final kotlinPattern = kotlinGoogleServicesPluginPattern;

        const kotlinContent = '''
plugins {
    id("com.android.application") version("8.1.0") apply false
    id("com.google.gms.google-services") version("4.4.0") apply false
    id('com.google.firebase.firebase-perf') version("1.4.2") apply false
    id("com.google.firebase.crashlytics") version('2.9.9') apply false
}
''';

        expect(kotlinPattern.hasMatch(kotlinContent), isTrue);
      });
    });

    group('Edge cases and error scenarios', () {
      test('should not match malformed patterns', () {
        final pattern = googleServicesPluginPattern;

        final badPatterns = [
          'id "com.google.gms.google-services version "4.4.0" apply false', // missing quote
          'id "com.google.gms.google-services" version 4.4.0 apply false', // no version quotes
          'id "com.google.gms.google-services" version "4.4" apply false', // wrong version format
          'id "com.google.gms.google-services" version "4.4.0"', // missing apply false
        ];

        for (final badPattern in badPatterns) {
          expect(
            pattern.hasMatch(badPattern),
            isFalse,
            reason: 'Should not match: $badPattern',
          );
        }
      });

      test('should handle empty and whitespace-only strings', () {
        final pattern = googleServicesPluginPattern;

        expect(pattern.hasMatch(''), isFalse);
        expect(pattern.hasMatch('   '), isFalse);
        expect(pattern.hasMatch('\n\t'), isFalse);
      });
    });

    group('Version number validation', () {
      test('should match valid semantic version numbers', () {
        final pattern = googleServicesPluginPattern;

        final validVersions = [
          'id "com.google.gms.google-services" version "0.0.1" apply false',
          'id "com.google.gms.google-services" version "1.0.0" apply false',
          'id "com.google.gms.google-services" version "99.99.99" apply false',
          'id "com.google.gms.google-services" version "4.3.15" apply false',
        ];

        for (final version in validVersions) {
          expect(
            pattern.hasMatch(version),
            isTrue,
            reason: 'Should match version: $version',
          );
        }
      });

      test('should not match invalid version formats', () {
        final pattern = googleServicesPluginPattern;

        final invalidVersions = [
          'id "com.google.gms.google-services" version "4.4" apply false', // missing patch
          'id "com.google.gms.google-services" version "1" apply false', // too short
          'id "com.google.gms.google-services" version "1.0.0.1" apply false', // too long
          'id "com.google.gms.google-services" version "1.0.a" apply false', // non-numeric
        ];

        for (final version in invalidVersions) {
          expect(
            pattern.hasMatch(version),
            isFalse,
            reason: 'Should not match version: $version',
          );
        }
      });
    });
  });

  group('upgradeGoogleServicesPluginVersion', () {
    const groovySettings = '''
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.3.0" apply false
    // START: FlutterFire Configuration
    id "com.google.gms.google-services" version "4.3.15" apply false
    // END: FlutterFire Configuration
    id "org.jetbrains.kotlin.android" version "2.3.0" apply false
}

include ":app"
''';

    const ktsSettings = '''
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.3.0" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
}

include(":app")
''';

    const ktsInfixSettings = '''
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.3.0" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version "4.4.4" apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
}

include(":app")
''';

    test('upgrades an older Groovy DSL pin (4.3.15 -> 4.7.0)', () {
      final result =
          upgradeGoogleServicesPluginVersion(groovySettings, '4.7.0');

      expect(
        result,
        contains(
          'id "com.google.gms.google-services" version "4.7.0" apply false',
        ),
      );
      expect(result, isNot(contains('4.3.15')));
      expect(
        result.replaceFirst('4.7.0', '4.3.15'),
        equals(groovySettings),
      );
    });

    test('upgrades an older Kotlin DSL pin (4.4.4 -> 4.7.0)', () {
      final result = upgradeGoogleServicesPluginVersion(
        ktsSettings,
        '4.7.0',
        kotlin: true,
      );

      expect(
        result,
        contains(
          'id("com.google.gms.google-services") version("4.7.0") apply false',
        ),
      );
      expect(result, isNot(contains('4.4.4')));
      expect(result.replaceFirst('4.7.0', '4.4.4'), equals(ktsSettings));
    });

    test('upgrades an older Kotlin DSL infix pin (4.4.4 -> 4.7.0)', () {
      final result = upgradeGoogleServicesPluginVersion(
        ktsInfixSettings,
        '4.7.0',
        kotlin: true,
      );

      expect(
        result,
        contains(
          'id("com.google.gms.google-services") version "4.7.0" apply false',
        ),
      );
      expect(result, isNot(contains('4.4.4')));
      expect(result.replaceFirst('4.7.0', '4.4.4'), equals(ktsInfixSettings));
    });

    test('preserves single-quote style when upgrading', () {
      const settings =
          "id 'com.google.gms.google-services' version '4.3.15' apply false";

      final result = upgradeGoogleServicesPluginVersion(settings, '4.7.0');

      expect(
        result,
        equals(
          "id 'com.google.gms.google-services' version '4.7.0' apply false",
        ),
      );
    });

    test('is a no-op when the pin is already at the target version', () {
      final result =
          upgradeGoogleServicesPluginVersion(groovySettings, '4.3.15');
      expect(result, equals(groovySettings));
    });

    test('never downgrades a newer pin', () {
      final result =
          upgradeGoogleServicesPluginVersion(groovySettings, '4.3.0');
      expect(result, equals(groovySettings));
    });

    test('is a no-op when the plugin is not declared', () {
      const settings = '''
plugins {
    id "com.android.application" version "8.3.0" apply false
}
''';
      final result = upgradeGoogleServicesPluginVersion(settings, '4.7.0');
      expect(result, equals(settings));
    });

    test('is a no-op for an unparseable target version', () {
      final result =
          upgradeGoogleServicesPluginVersion(groovySettings, 'not-a-version');
      expect(result, equals(groovySettings));
    });

    test('is idempotent across repeated configure runs', () {
      final once = upgradeGoogleServicesPluginVersion(groovySettings, '4.7.0');
      final twice = upgradeGoogleServicesPluginVersion(once, '4.7.0');
      expect(twice, equals(once));
    });

    test('does not touch the Groovy pin when asked to upgrade Kotlin DSL', () {
      final result = upgradeGoogleServicesPluginVersion(
        groovySettings,
        '4.7.0',
        kotlin: true,
      );
      expect(result, equals(groovySettings));
    });

    test('upgrades the declaration below a commented-out one', () {
      const settings = '''
plugins {
    // id "com.google.gms.google-services" version "4.7.0" apply false
    id "com.google.gms.google-services" version "4.3.15" apply false
}
''';

      final result = upgradeGoogleServicesPluginVersion(settings, '4.7.0');

      expect(
        result,
        equals('''
plugins {
    // id "com.google.gms.google-services" version "4.7.0" apply false
    id "com.google.gms.google-services" version "4.7.0" apply false
}
'''),
      );
    });

    test('does not rewrite a commented-out declaration', () {
      const settings = '''
plugins {
    // id("com.google.gms.google-services") version "4.3.15" apply false
    /*
    id("com.google.gms.google-services") version "4.4.0" apply false
    */
    id("com.google.gms.google-services") version "4.4.4" apply false // pinned
}
''';

      final result = upgradeGoogleServicesPluginVersion(
        settings,
        '4.7.0',
        kotlin: true,
      );

      expect(
        result,
        equals('''
plugins {
    // id("com.google.gms.google-services") version "4.3.15" apply false
    /*
    id("com.google.gms.google-services") version "4.4.0" apply false
    */
    id("com.google.gms.google-services") version "4.7.0" apply false // pinned
}
'''),
      );
    });

    test('does not treat "//" inside a string as a comment', () {
      const settings = '''
pluginManagement {
    repositories { maven { url "https://maven.google.com" } }
}
plugins { id "com.google.gms.google-services" version "4.3.15" apply false }
''';

      final result = upgradeGoogleServicesPluginVersion(settings, '4.7.0');

      expect(result, equals(settings.replaceFirst('4.3.15', '4.7.0')));
    });

    test('upgrades a Kotlin DSL declaration that uses "apply(false)"', () {
      const settings =
          'id("com.google.gms.google-services") version "4.3.15" apply(false)';

      final result = upgradeGoogleServicesPluginVersion(
        settings,
        '4.7.0',
        kotlin: true,
      );

      expect(
        result,
        equals(
          'id("com.google.gms.google-services") version "4.7.0" apply(false)',
        ),
      );
    });

    test('upgrades a Groovy declaration with extra whitespace', () {
      const settings =
          'id  "com.google.gms.google-services"\tversion   "4.3.15"  apply\tfalse';

      final result = upgradeGoogleServicesPluginVersion(settings, '4.7.0');

      expect(
        result,
        equals(
          'id  "com.google.gms.google-services"\tversion   "4.7.0"  apply\tfalse',
        ),
      );
    });

    test('upgrades a Groovy declaration written with parentheses', () {
      const settings =
          "id('com.google.gms.google-services') version('4.3.15') apply false";

      final result = upgradeGoogleServicesPluginVersion(settings, '4.7.0');

      expect(
        result,
        equals(
          "id('com.google.gms.google-services') version('4.7.0') apply false",
        ),
      );
    });

    test('reports declarations whose version cannot be read', () {
      const settings = '''
plugins {
    // id("com.google.gms.google-services") version "not-a-version"
    id("com.google.gms.google-services") version libs.versions.gms apply false
    id("com.google.gms.google-services") version "4.4" apply false
}
''';
      final unsupported = <String>[];

      final result = upgradeGoogleServicesPluginVersion(
        settings,
        '4.7.0',
        kotlin: true,
        onUnsupportedDeclaration: unsupported.add,
      );

      expect(result, equals(settings));
      expect(
        unsupported,
        equals([
          'id("com.google.gms.google-services") version libs.versions.gms apply false',
          'id("com.google.gms.google-services") version "4.4" apply false',
        ]),
      );
    });

    test('does not report a declaration it can read', () {
      final unsupported = <String>[];

      upgradeGoogleServicesPluginVersion(
        groovySettings,
        '4.7.0',
        onUnsupportedDeclaration: unsupported.add,
      );
      upgradeGoogleServicesPluginVersion(
        groovySettings,
        '4.3.0',
        onUnsupportedDeclaration: unsupported.add,
      );

      expect(unsupported, isEmpty);
    });
  });

  group('getResolvedFirebaseCorePubSpec', () {
    late Directory tempDirectory;
    late Directory pubCache;

    setUp(() {
      tempDirectory =
          Directory.systemTemp.createTempSync('flutterfire_cli_android');
      pubCache = Directory(
        path.join(tempDirectory.path, 'pub-cache', 'hosted', 'pub.dev'),
      );
    });

    tearDown(() {
      tempDirectory.deleteSync(recursive: true);
    });

    test(
        'reads the firebase_core the app resolves to, not the highest version '
        'in the pub cache', () async {
      final resolved = _writeFirebaseCore(
        pubCache,
        version: '3.10.0',
        googleServicesVersion: '4.4.2',
      );
      _writeFirebaseCore(
        pubCache,
        version: '3.15.0',
        googleServicesVersion: '4.7.0',
      );
      final appDirectory = Directory(path.join(tempDirectory.path, 'app'));
      _writePackageConfig(
        appDirectory,
        firebaseCoreRootUri: resolved.uri.toString(),
      );

      final pubSpec = await getResolvedFirebaseCorePubSpec(appDirectory.path);

      expect(pubSpec?.googleServicesGradlePluginVersion, equals('4.4.2'));
      expect(pubSpec?.crashlyticsGradlePluginVersion, equals('3.0.3'));
      expect(pubSpec?.performanceGradlePluginVersion, equals('1.4.2'));
    });

    test('follows a root URI relative to the ".dart_tool" directory', () async {
      _writeFirebaseCore(
        pubCache,
        version: '3.10.0',
        googleServicesVersion: '4.4.2',
      );
      final appDirectory = Directory(path.join(tempDirectory.path, 'app'));
      _writePackageConfig(
        appDirectory,
        firebaseCoreRootUri:
            '../../pub-cache/hosted/pub.dev/firebase_core-3.10.0',
      );

      final pubSpec = await getResolvedFirebaseCorePubSpec(appDirectory.path);

      expect(pubSpec?.googleServicesGradlePluginVersion, equals('4.4.2'));
    });

    test('finds the package_config.json of a pub workspace', () async {
      final resolved = _writeFirebaseCore(
        pubCache,
        version: '3.10.0',
        googleServicesVersion: '4.4.2',
      );
      final workspace = Directory(path.join(tempDirectory.path, 'workspace'));
      _writePackageConfig(
        workspace,
        firebaseCoreRootUri: resolved.uri.toString(),
      );
      final appDirectory = Directory(
        path.join(workspace.path, 'packages', 'app'),
      )..createSync(recursive: true);

      final pubSpec = await getResolvedFirebaseCorePubSpec(appDirectory.path);

      expect(pubSpec?.googleServicesGradlePluginVersion, equals('4.4.2'));
    });

    test('returns null when the dependencies are not resolved', () async {
      final appDirectory = Directory(path.join(tempDirectory.path, 'app'))
        ..createSync(recursive: true);

      expect(await getResolvedFirebaseCorePubSpec(appDirectory.path), isNull);
    });
  });

  group('gradleContentUpdates', () {
    const groovySettings = '''
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.3.0" apply false
    id "com.google.gms.google-services" version "4.3.15" apply false
}

include ":app"
''';
    const groovyLegacyAppBuildGradle = '''
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}

plugins {
    id "com.android.application"
}
''';
    const ktsSettings = '''
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.3.0" apply false
    id("com.google.gms.google-services") version "4.3.15" apply(false)
}

include(":app")
''';
    const ktsLegacyAppBuildGradle = '''
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
    }
}

plugins {
    id("com.android.application")
}
''';

    late Directory tempDirectory;
    late Directory appDirectory;

    setUp(() {
      tempDirectory =
          Directory.systemTemp.createTempSync('flutterfire_cli_android');
      appDirectory = Directory(path.join(tempDirectory.path, 'app'));
    });

    tearDown(() {
      tempDirectory.deleteSync(recursive: true);
    });

    void resolveFirebaseCore({required String googleServicesVersion}) {
      final firebaseCore = _writeFirebaseCore(
        Directory(path.join(tempDirectory.path, 'pub-cache')),
        version: '3.10.0',
        googleServicesVersion: googleServicesVersion,
      );
      _writePackageConfig(
        appDirectory,
        firebaseCoreRootUri: firebaseCore.uri.toString(),
      );
    }

    String readAndroidFile(String relativePath) {
      return File(path.join(appDirectory.path, 'android', relativePath))
          .readAsStringSync();
    }

    test(
        'upgrades the settings.gradle pin when app/build.gradle has the '
        'legacy classpath declaration', () async {
      final flutterApp = await _createAndroidApp(
        appDirectory,
        settings: groovySettings,
        appBuildGradle: groovyLegacyAppBuildGradle,
      );
      resolveFirebaseCore(googleServicesVersion: '4.4.2');

      await gradleContentUpdates(flutterApp);

      expect(
        readAndroidFile('settings.gradle'),
        equals(groovySettings.replaceFirst('4.3.15', '4.4.2')),
      );
      expect(
        readAndroidFile(path.join('app', 'build.gradle')),
        equals(groovyLegacyAppBuildGradle),
      );
    });

    test(
        'upgrades the settings.gradle.kts pin when app/build.gradle.kts has '
        'the legacy classpath declaration', () async {
      final flutterApp = await _createAndroidApp(
        appDirectory,
        settings: ktsSettings,
        appBuildGradle: ktsLegacyAppBuildGradle,
        kotlin: true,
      );
      resolveFirebaseCore(googleServicesVersion: '4.4.2');

      await gradleContentUpdates(flutterApp);

      expect(
        readAndroidFile('settings.gradle.kts'),
        equals(ktsSettings.replaceFirst('4.3.15', '4.4.2')),
      );
      expect(
        readAndroidFile(path.join('app', 'build.gradle.kts')),
        equals(ktsLegacyAppBuildGradle),
      );
    });

    test('never downgrades a pin that is newer than the resolved firebase_core',
        () async {
      final flutterApp = await _createAndroidApp(
        appDirectory,
        settings: groovySettings,
        appBuildGradle: groovyLegacyAppBuildGradle,
      );
      resolveFirebaseCore(googleServicesVersion: '4.3.0');

      await gradleContentUpdates(flutterApp);

      expect(readAndroidFile('settings.gradle'), equals(groovySettings));
    });

    test('leaves the pin alone when firebase_core is not resolved', () async {
      final flutterApp = await _createAndroidApp(
        appDirectory,
        settings: groovySettings,
        appBuildGradle: groovyLegacyAppBuildGradle,
      );

      await gradleContentUpdates(flutterApp);

      expect(readAndroidFile('settings.gradle'), equals(groovySettings));
    });
  });
}

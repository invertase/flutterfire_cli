import 'package:test/test.dart';

void main() {
  group('Firebase Android Writes - Regex Pattern Tests', () {
    group('Android Application Pattern Tests', () {
      test('should match android application with double quotes', () {
        final pattern = RegExp(
          "id ([\"']com\\.android\\.application[\"']) version ([\"'][^\"']*[\"']) apply false",
        );

        final testString =
            'id "com.android.application" version "8.1.0" apply false';
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals('"com.android.application"'));
        expect(match.group(2), equals('"8.1.0"'));
      });

      test('should match android application with single quotes', () {
        final pattern = RegExp(
          "id ([\"']com\\.android\\.application[\"']) version ([\"'][^\"']*[\"']) apply false",
        );

        final testString =
            "id 'com.android.application' version '8.1.0' apply false";
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals("'com.android.application'"));
        expect(match.group(2), equals("'8.1.0'"));
      });

      test('should match android application with mixed quotes', () {
        final pattern = RegExp(
          "id ([\"']com\\.android\\.application[\"']) version ([\"'][^\"']*[\"']) apply false",
        );

        final testStrings = [
          'id "com.android.application" version \'8.1.0\' apply false',
          'id \'com.android.application\' version "8.1.0" apply false',
        ];

        for (final testString in testStrings) {
          expect(pattern.hasMatch(testString), isTrue,
              reason: 'Failed for: $testString');
        }
      });

      test('should not match invalid android application patterns', () {
        final pattern = RegExp(
          "id ([\"']com\\.android\\.application[\"']) version ([\"'][^\"']*[\"']) apply false",
        );

        final invalidStrings = [
          'id com.android.application version 8.1.0 apply false', // no quotes
          'id "com.android.library" version "8.1.0" apply false', // wrong plugin
          'id "com.android.application" version "8.1.0"', // missing apply false
        ];

        for (final testString in invalidStrings) {
          expect(pattern.hasMatch(testString), isFalse,
              reason: 'Should not match: $testString');
        }
      });
    });

    group('Google Services Pattern Tests', () {
      test('should match google services with double quotes', () {
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        final testString =
            'id "com.google.gms.google-services" version "4.4.0" apply false';
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals('"com.google.gms.google-services"'));
        expect(match.group(2), equals('"4.4.0"'));
      });

      test('should match google services with single quotes', () {
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        final testString =
            "id 'com.google.gms.google-services' version '4.4.0' apply false";
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals("'com.google.gms.google-services'"));
        expect(match.group(2), equals("'4.4.0'"));
      });

      test('should match google services with mixed quotes', () {
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        final testStrings = [
          'id "com.google.gms.google-services" version \'4.4.0\' apply false',
          'id \'com.google.gms.google-services\' version "4.4.0" apply false',
        ];

        for (final testString in testStrings) {
          expect(pattern.hasMatch(testString), isTrue,
              reason: 'Failed for: $testString');
        }
      });

      test('should match different version formats', () {
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        final testStrings = [
          'id "com.google.gms.google-services" version "4.3.15" apply false',
          'id "com.google.gms.google-services" version "4.4.0" apply false',
          'id "com.google.gms.google-services" version "5.0.1" apply false',
          "id 'com.google.gms.google-services' version '10.2.3' apply false",
        ];

        for (final testString in testStrings) {
          expect(pattern.hasMatch(testString), isTrue,
              reason: 'Failed for: $testString');
        }
      });
    });

    group('Kotlin DSL Google Services Pattern Tests', () {
      test('should match kotlin DSL with double quotes', () {
        final pattern = RegExp(
          "id\\(([\"']com\\.google\\.gms\\.google-services[\"'])\\) version\\(([\"']\\d+\\.\\d+\\.\\d+[\"'])\\) apply false",
        );

        final testString =
            'id("com.google.gms.google-services") version("4.4.0") apply false';
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals('"com.google.gms.google-services"'));
        expect(match.group(2), equals('"4.4.0"'));
      });

      test('should match kotlin DSL with single quotes', () {
        final pattern = RegExp(
          "id\\(([\"']com\\.google\\.gms\\.google-services[\"'])\\) version\\(([\"']\\d+\\.\\d+\\.\\d+[\"'])\\) apply false",
        );

        final testString =
            "id('com.google.gms.google-services') version('4.4.0') apply false";
        expect(pattern.hasMatch(testString), isTrue);

        final match = pattern.firstMatch(testString);
        expect(match, isNotNull);
        expect(match!.group(1), equals("'com.google.gms.google-services'"));
        expect(match.group(2), equals("'4.4.0'"));
      });

      test('should match kotlin DSL with mixed quotes', () {
        final pattern = RegExp(
          "id\\(([\"']com\\.google\\.gms\\.google-services[\"'])\\) version\\(([\"']\\d+\\.\\d+\\.\\d+[\"'])\\) apply false",
        );

        final testStrings = [
          'id("com.google.gms.google-services") version(\'4.4.0\') apply false',
          'id(\'com.google.gms.google-services\') version("4.4.0") apply false',
        ];

        for (final testString in testStrings) {
          expect(pattern.hasMatch(testString), isTrue,
              reason: 'Failed for: $testString');
        }
      });
    });

    group('Firebase Performance Plugin Pattern Tests', () {
      test('should match performance plugin patterns with various quotes', () {
        // Pattern used in settings.gradle
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        // Test that performance plugin would be found after google services
        final gradleContent = '''
plugins {
    id "com.android.application" version "8.1.0" apply false
    id "com.google.gms.google-services" version "4.4.0" apply false
    id 'com.google.firebase.firebase-perf' version "1.4.2" apply false
    id "com.google.firebase.crashlytics" version '2.9.9' apply false
}
''';

        expect(pattern.hasMatch(gradleContent), isTrue);

        // Test that it works with the actual example from the user
        final performancePattern =
            "id 'com.google.firebase.firebase-perf' version \"1.4.2\" apply false";
        final crashlyticsPattern =
            'id "com.google.firebase.crashlytics" version \'2.9.9\' apply false';

        expect(gradleContent.contains(performancePattern), isTrue);
        expect(gradleContent.contains(crashlyticsPattern), isTrue);
      });
    });

    group('Real-world gradle content patterns', () {
      test('should handle user-reported mixed quote scenarios', () {
        final androidAppPattern = RegExp(
          "id ([\"']com\\.android\\.application[\"']) version ([\"'][^\"']*[\"']) apply false",
        );

        final googleServicesPattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        // Example content from the user's issue
        final gradleContent = '''
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
        final kotlinPattern = RegExp(
          "id\\(([\"']com\\.google\\.gms\\.google-services[\"'])\\) version\\(([\"']\\d+\\.\\d+\\.\\d+[\"'])\\) apply false",
        );

        final kotlinContent = '''
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
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        final badPatterns = [
          'id "com.google.gms.google-services version "4.4.0" apply false', // missing quote
          'id "com.google.gms.google-services" version 4.4.0 apply false', // no version quotes
          'id "com.google.gms.google-services" version "4.4" apply false', // wrong version format
          'id "com.google.gms.google-services" version "4.4.0"', // missing apply false
        ];

        for (final badPattern in badPatterns) {
          expect(pattern.hasMatch(badPattern), isFalse,
              reason: 'Should not match: $badPattern');
        }
      });

      test('should handle empty and whitespace-only strings', () {
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        expect(pattern.hasMatch(''), isFalse);
        expect(pattern.hasMatch('   '), isFalse);
        expect(pattern.hasMatch('\n\t'), isFalse);
      });
    });

    group('Version number validation', () {
      test('should match valid semantic version numbers', () {
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        final validVersions = [
          'id "com.google.gms.google-services" version "0.0.1" apply false',
          'id "com.google.gms.google-services" version "1.0.0" apply false',
          'id "com.google.gms.google-services" version "99.99.99" apply false',
          'id "com.google.gms.google-services" version "4.3.15" apply false',
        ];

        for (final version in validVersions) {
          expect(pattern.hasMatch(version), isTrue,
              reason: 'Should match version: $version');
        }
      });

      test('should not match invalid version formats', () {
        final pattern = RegExp(
          "id ([\"']com\\.google\\.gms\\.google-services[\"']) version ([\"']\\d+\\.\\d+\\.\\d+[\"']) apply false",
        );

        final invalidVersions = [
          'id "com.google.gms.google-services" version "4.4" apply false', // missing patch
          'id "com.google.gms.google-services" version "1" apply false', // too short
          'id "com.google.gms.google-services" version "1.0.0.1" apply false', // too long
          'id "com.google.gms.google-services" version "1.0.a" apply false', // non-numeric
        ];

        for (final version in invalidVersions) {
          expect(pattern.hasMatch(version), isFalse,
              reason: 'Should not match version: $version');
        }
      });
    });
  });
}

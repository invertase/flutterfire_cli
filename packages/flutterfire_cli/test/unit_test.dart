import 'dart:convert';

import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:flutterfire_cli/src/firebase/firebase_app.dart';
import 'package:test/test.dart';

void main() {
  group('Apple App Bundle ID Validator', () {
    test('Valid bundle IDs', () {
      expect(
        () => validateAppBundleId(
          'com.example.app',
          kIos,
        ),
        returnsNormally,
      );
      expect(
        () => validateAppBundleId(
          'io.flutter.dev',
          kIos,
        ),
        returnsNormally,
      );
      expect(
        () => validateAppBundleId(
          'org.dartlang.camelCase',
          kIos,
        ),
        returnsNormally,
      );
      expect(
        () => validateAppBundleId(
          'com.example-app.test',
          kIos,
        ),
        returnsNormally,
      );
      expect(
        () => validateAppBundleId(
          'uk.co.companyname.appname',
          kIos,
        ),
        returnsNormally,
      );
      expect(
        () => validateAppBundleId(
          'example',
          kIos,
        ),
        returnsNormally,
      );
      expect(
        () => validateAppBundleId(
          'exampleEN',
          kIos,
        ),
        returnsNormally,
      );
    });

    test('Invalid bundle IDs', () {
      expect(
        () => validateAppBundleId(
          'com..example',
          kIos,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateAppBundleId(
          '-com.example.app',
          kIos,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateAppBundleId(
          'com.example!.app',
          kIos,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateAppBundleId(
          'com.example/app',
          kIos,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Android Package Name Validator', () {
    test('Valid Package names', () {
      expect(
        () => validateAndroidPackageName('com.example.some_valid_name'),
        returnsNormally,
      );
      expect(
        () => validateAndroidPackageName('io.flutter.dev'),
        returnsNormally,
      );
      expect(
        () => validateAndroidPackageName('org.dartlang.sample'),
        returnsNormally,
      );
      expect(
        () => validateAndroidPackageName('uk.co.companyname.appname'),
        returnsNormally,
      );
      expect(
        () => validateAndroidPackageName('com.example123.app456'),
        returnsNormally,
      );
      expect(
        () => validateAndroidPackageName('abc123.com.example.app'),
        returnsNormally,
      );
    });

    test('Invalid Package names', () {
      expect(
        () => validateAndroidPackageName('com..example'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateAndroidPackageName('com.example!app'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateAndroidPackageName('com'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateAndroidPackageName('_com.example.app'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateAndroidPackageName('123.com.example.app'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('FirebaseApp displayName handling', () {
    test('FirebaseApp.fromJson correctly parses displayName from JSON', () {
      final json = {
        'platform': 'ANDROID',
        'appId': '1:123456:android:abc',
        'displayName': 'My Cool App',
        'name': 'projects/test/apps/abc',
        'packageName': 'com.example.app',
      };

      final app = FirebaseApp.fromJson(json);

      expect(app.displayName, 'My Cool App');
      expect(app.name, 'projects/test/apps/abc');
      expect(app.platform, 'android');
      expect(app.packageNameOrBundleIdentifier, 'com.example.app');
    });

    test('FirebaseApp.fromJson handles null or missing displayName', () {
      // Test with null displayName
      final jsonWithNull = {
        'platform': 'IOS',
        'appId': '1:123456:ios:xyz',
        'displayName': null,
        'name': 'projects/test/apps/xyz',
        'bundleId': 'com.example.app',
      };

      final appWithNull = FirebaseApp.fromJson(jsonWithNull);
      expect(appWithNull.displayName, null);

      // Test with missing displayName field
      final jsonWithoutField = {
        'platform': 'WEB',
        'appId': '1:123456:web:def',
        'name': 'projects/test/apps/def',
      };

      final appWithoutField = FirebaseApp.fromJson(jsonWithoutField);
      expect(appWithoutField.displayName, null);
    });
  });

  group(
    'Firebase CLI JSON response parser function `firebaseCLIJsonParse()`',
    () {
      test('Valid JSON response from Firebase CLI', () {
        const jsonData = '''
          {
            "status": "success",
            "result": [
              {
                "projectId": "project-id",
                "projectNumber": "2380",
                "displayName": "Display",
                "name": "projects/project-id",
                "resources": {
                  "hostingSite": "project-id",
                  "storageBucket": "project-id.appspot.com",
                  "locationId": "europe-west"
                },
                "state": "ACTIVE",
                "etag": "1_c74d64e0-ba66-42e6-88se-303ds3222dsds"
              },
              {
                "projectId": "rtc-test-94090",
                "projectNumber": "978336444",
                "displayName": "rtc-test",
                "name": "projects/rtc-test-9848",
                "resources": {
                  "hostingSite": "rtc-test-93d9839"
                },
                "state": "ACTIVE",
                "etag": "1_81c10fa0-f712-4cbf-b0fd-e35e0403094"
              }
            ]
          }
          ''';

        final jsonString = firebaseCLIJsonParse(jsonData);
        // This should succeed in parsing JSON
        final result = Map<String, dynamic>.from(
          const JsonDecoder().convert(jsonString) as Map,
        );

        expect(result['status'], 'success');
      });

      test('Invalid JSON response from Firebase CLI', () {
        const jsonData = '''
          {
            "status": "success",
            "result": [
              {
                "projectId": "project-id",
                "projectNumber": "2380",
                "displayName": "Display",
                "name": "projects/project-id",
                "resources": {
                  "hostingSite": "project-id",
                  "storageBucket": "project-id.appspot.com",
                  "locationId": "europe-west"
                },
                "state": "ACTIVE",
                "etag": "1_c74d64e0-ba66-42e6-88se-303ds3222dsds"
              },
              {
                "projectId": "rtc-test-94090",
                "projectNumber": "978336444",
                "displayName": "rtc-test",
                "name": "projects/rtc-test-9848",
                "resources": {
                  "hostingSite": "rtc-test-93d9839"
                },
                "state": "ACTIVE",
                "etag": "1_81c10fa0-f712-4cbf-b0fd-e35e0403094"
              }
            ]
          }{
            "status": "error",
            "error": "Timed out."
          }
          ''';

        final jsonString = firebaseCLIJsonParse(jsonData);
        // This should succeed in parsing JSON
        final result = Map<String, dynamic>.from(
          const JsonDecoder().convert(jsonString) as Map,
        );

        expect(result['status'], 'success');
      });
    },
  );
}

import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
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
          'org.dartlang.sample',
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
      expect(
        () => validateAppBundleId(
          'example',
          kIos,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Android Package Name Validator', () {
    test('Valid Package names', () {
      expect(
        () => validateAndroidPackageName('com.example.app'),
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
}

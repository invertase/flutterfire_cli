import 'package:flutterfire_cli/src/firebase.dart';
import 'package:flutterfire_cli/src/firebase/firebase_android_options.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseAndroidOptions', () {
    group('convertConfigToOptions', () {
      test('parses recaptcha_site_key from client_info', () {
        final config = FirebaseAppSdkConfig(
          fileName: 'google-services.json',
          fileContents: '''
{
  "project_info": {
    "project_number": "1234567890",
    "project_id": "test-project",
    "firebase_url": "https://test-project.firebaseio.com",
    "storage_bucket": "test-project.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:1234567890:android:abcdef1234567890",
        "recaptcha_site_key": "test-android-recaptcha-site-key"
      },
      "api_key": [
        {
          "current_key": "test-api-key"
        }
      ]
    }
  ]
}''',
        );

        final options = FirebaseAndroidOptions.convertConfigToOptions(
          config,
          '1:1234567890:android:abcdef1234567890',
          'test-project',
        );

        expect(options.projectId, 'test-project');
        expect(options.appId, '1:1234567890:android:abcdef1234567890');
        expect(options.apiKey, 'test-api-key');
        expect(options.messagingSenderId, '1234567890');
        expect(options.recaptchaSiteKey, 'test-android-recaptcha-site-key');
      });

      test('parses recaptcha_site_key from client root', () {
        final config = FirebaseAppSdkConfig(
          fileName: 'google-services.json',
          fileContents: '''
{
  "project_info": {
    "project_number": "1234567890",
    "project_id": "test-project"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:1234567890:android:abcdef1234567890"
      },
      "recaptcha_site_key": "test-android-recaptcha-site-key",
      "api_key": [
        {
          "current_key": "test-api-key"
        }
      ]
    }
  ]
}''',
        );

        final options = FirebaseAndroidOptions.convertConfigToOptions(
          config,
          '1:1234567890:android:abcdef1234567890',
          'test-project',
        );

        expect(options.recaptchaSiteKey, 'test-android-recaptcha-site-key');
      });
    });
  });
}

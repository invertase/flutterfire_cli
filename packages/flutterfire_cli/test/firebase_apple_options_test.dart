import 'package:flutterfire_cli/src/firebase.dart';
import 'package:flutterfire_cli/src/firebase/firebase_apple_options.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseAppleOptions', () {
    group('convertConfigToOptions', () {
      test('parses RECAPTCHA_SITE_KEY', () {
        final config = FirebaseAppSdkConfig(
          fileName: 'GoogleService-Info.plist',
          fileContents: '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key>
  <string>test-api-key</string>
  <key>GOOGLE_APP_ID</key>
  <string>1:1234567890:ios:abcdef1234567890</string>
  <key>GCM_SENDER_ID</key>
  <string>1234567890</string>
  <key>PROJECT_ID</key>
  <string>test-project</string>
  <key>STORAGE_BUCKET</key>
  <string>test-project.appspot.com</string>
  <key>BUNDLE_ID</key>
  <string>com.example.test</string>
  <key>RECAPTCHA_SITE_KEY</key>
  <string>test-apple-recaptcha-site-key</string>
</dict>
</plist>''',
        );

        final options = FirebaseAppleOptions.convertConfigToOptions(
          config,
          '1:1234567890:ios:abcdef1234567890',
          'test-project',
        );

        expect(options.projectId, 'test-project');
        expect(options.appId, '1:1234567890:ios:abcdef1234567890');
        expect(options.apiKey, 'test-api-key');
        expect(options.messagingSenderId, '1234567890');
        expect(options.iosBundleId, 'com.example.test');
        expect(options.recaptchaSiteKey, 'test-apple-recaptcha-site-key');
      });
    });
  });
}

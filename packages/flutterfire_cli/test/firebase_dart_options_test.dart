import 'package:flutterfire_cli/src/firebase.dart';
import 'package:flutterfire_cli/src/firebase/firebase_dart_options.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseDartOptions', () {
    group('convertConfigToOptions', () {
      test('parses traditional JavaScript format correctly', () {
        final config = FirebaseAppSdkConfig(
          fileName: 'firebase-config.js',
          fileContents: '''
firebase.initializeApp({
  "projectId": "test-project",
  "appId": "1:1234567890:web:abcdef1234567890",
  "apiKey": "test-api-key",
  "authDomain": "test-project.firebaseapp.com",
  "messagingSenderId": "1234567890",
  "measurementId": "G-ABCDEF1234"
});''',
        );

        final options = FirebaseDartOptions.convertConfigToOptions(
          config,
          'test-project',
        );

        expect(options.projectId, 'test-project');
        expect(options.appId, '1:1234567890:web:abcdef1234567890');
        expect(options.apiKey, 'test-api-key');
        expect(options.messagingSenderId, '1234567890');
        expect(options.measurementId, 'G-ABCDEF1234');
      });

      test('parses new JSON format correctly', () {
        final config = FirebaseAppSdkConfig(
          fileName: 'firebase-config.json',
          fileContents: '''
{
  "projectId": "test-project",
  "appId": "1:1234567890:web:abcdef1234567890",
  "apiKey": "test-api-key",
  "authDomain": "test-project.firebaseapp.com",
  "messagingSenderId": "1234567890",
  "measurementId": "G-ABCDEF1234"
}''',
        );

        final options = FirebaseDartOptions.convertConfigToOptions(
          config,
          'test-project',
        );

        expect(options.projectId, 'test-project');
        expect(options.appId, '1:1234567890:web:abcdef1234567890');
        expect(options.apiKey, 'test-api-key');
        expect(options.messagingSenderId, '1234567890');
        expect(options.measurementId, 'G-ABCDEF1234');
      });

      test('throws FirebaseCommandException for invalid format', () {
        final config = FirebaseAppSdkConfig(
          fileName: 'invalid-config.txt',
          fileContents: 'Invalid config format',
        );

        expect(
          () => FirebaseDartOptions.convertConfigToOptions(
            config,
            'test-project',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
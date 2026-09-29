// The stub Firebase CLI below is a shell script.
@TestOn('mac-os || linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _appId = '1:123:android:abc';
const _serviceFileContents = '{"project_info":{"project_id":"fake-project"}}';

/// Runs `flutterfire reconfigure` on an Android-only app, against a stub
/// `firebase` on the PATH that is authenticated without `firebase login`,
/// i.e. with no refresh token in the configstore.
///
/// Returns the arguments each stub `firebase` call received.
Future<List<String>> _reconfigure(
  Directory root, {
  required void Function(Directory home) setUpHome,
}) async {
  final app = Directory(path.join(root.path, 'app'))..createSync();
  File(path.join(app.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
''');
  File(path.join(app.path, 'firebase.json')).writeAsStringSync(
    jsonEncode({
      'flutter': {
        'platforms': {
          'android': {
            'default': {
              'projectId': 'fake-project',
              'appId': _appId,
              'fileOutput': 'android/app/google-services.json',
            },
          },
        },
      },
    }),
  );
  // Gradle files that already apply the Google Services plugin, so
  // reconfigure has nothing to change in them.
  final android = Directory(path.join(app.path, 'android'));
  Directory(path.join(android.path, 'app')).createSync(recursive: true);
  File(path.join(android.path, 'build.gradle.kts')).writeAsStringSync('');
  File(path.join(android.path, 'settings.gradle.kts')).writeAsStringSync('''
plugins {
    id("com.android.application") version "8.7.0" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
}
''');
  File(path.join(android.path, 'app', 'build.gradle.kts')).writeAsStringSync('''
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
}
''');

  final bin = Directory(path.join(root.path, 'bin'))..createSync();
  final calls = File(path.join(root.path, 'calls.log'));
  final sdkConfig = jsonEncode({
    'status': 'success',
    'result': {
      'fileName': 'google-services.json',
      'fileContents': _serviceFileContents,
    },
  });
  final firebase = File(path.join(bin.path, 'firebase'))..writeAsStringSync('''
#!/bin/sh
echo "\$@" >> '${calls.path}'
case "\$1" in
  --version) echo 14.0.0 ;;
  apps:sdkconfig) printf '%s' '$sdkConfig' ;;
  *) echo '{"status":"error","error":"unexpected command"}'; exit 1 ;;
esac
''');
  Process.runSync('chmod', ['+x', firebase.path]);

  final home = Directory(path.join(root.path, 'home'))..createSync();
  setUpHome(home);

  final result = await Process.run(
    Platform.resolvedExecutable,
    [
      path.join(Directory.current.path, 'bin', 'flutterfire.dart'),
      'reconfigure',
    ],
    workingDirectory: app.path,
    environment: {
      'HOME': home.path,
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
    },
  );
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

  final serviceFile =
      File(path.join(app.path, 'android', 'app', 'google-services.json'));
  expect(
    serviceFile.existsSync(),
    isTrue,
    reason: 'google-services.json was not written:\n${result.stdout}',
  );
  expect(serviceFile.readAsStringSync(), _serviceFileContents);

  return calls.readAsLinesSync();
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flutterfire_reconfigure');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test(
    'reconfigure fetches the service file through the Firebase CLI when there '
    'is no configstore file',
    () async {
      final calls = await _reconfigure(root, setUpHome: (_) {});

      expect(calls, contains('apps:sdkconfig android $_appId --json'));
    },
  );

  test(
    'reconfigure fetches the service file through the Firebase CLI when the '
    'configstore has no refresh token',
    () async {
      final calls = await _reconfigure(
        root,
        setUpHome: (home) {
          File(
            path.join(
              home.path,
              '.config',
              'configstore',
              'firebase-tools.json',
            ),
          )
            ..createSync(recursive: true)
            ..writeAsStringSync('{}');
        },
      );

      expect(calls, contains('apps:sdkconfig android $_appId --json'));
    },
  );
}

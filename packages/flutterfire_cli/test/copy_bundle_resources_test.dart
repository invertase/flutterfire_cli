import 'dart:convert';
import 'dart:io';

import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory appDirectory;

  setUp(() {
    appDirectory =
        Directory.systemTemp.createTempSync('flutterfire_cli_firebase_json');
  });

  tearDown(() {
    appDirectory.deleteSync(recursive: true);
  });

  void writeFirebaseJson(Object contents) {
    File(path.join(appDirectory.path, 'firebase.json')).writeAsStringSync(
      contents is String ? contents : jsonEncode(contents),
    );
  }

  group('configuredBuildConfigurations()', () {
    test('lists the build configurations of the platform', () async {
      writeFirebaseJson({
        'flutter': {
          'platforms': {
            'ios': {
              'buildConfigurations': {
                'Release': <String, dynamic>{},
                'Debug': <String, dynamic>{},
              },
            },
            'macos': {
              'buildConfigurations': {'Profile': <String, dynamic>{}},
            },
          },
        },
      });

      expect(
        await configuredBuildConfigurations(appDirectory.path, kIos),
        {'Release', 'Debug'},
      );
      expect(
        await configuredBuildConfigurations(appDirectory.path, kMacos),
        {'Profile'},
      );
    });

    test('is empty when the platform has no build configurations', () async {
      writeFirebaseJson({
        'flutter': {
          'platforms': {
            'ios': {
              'default': <String, dynamic>{},
            },
          },
        },
      });

      expect(
        await configuredBuildConfigurations(appDirectory.path, kIos),
        isEmpty,
      );
    });

    test('is empty when "firebase.json" does not exist', () async {
      expect(
        await configuredBuildConfigurations(appDirectory.path, kIos),
        isEmpty,
      );
    });

    test('is empty when "firebase.json" cannot be read', () async {
      writeFirebaseJson('{ not json');

      expect(
        await configuredBuildConfigurations(appDirectory.path, kIos),
        isEmpty,
      );
    });
  });
}

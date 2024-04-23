import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  String? projectPath;
  setUp(() async {
    projectPath = await createFlutterProject();
  });

  tearDown(() {
    Directory(p.dirname(projectPath!)).delete(recursive: true);
  });

  test(
    'Success on basic install',
    () async {
      final result = Process.runSync(
        'flutterfire',
        [
          'install',
          '--version=0.1.0',
          '--plugins=firebase_auth,firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final parsedPubspec =
          await PubSpec.loadFile(p.join(projectPath!, 'pubspec.yaml'));

      expect(parsedPubspec.dependencies['firebase_auth'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec.dependencies['cloud_firestore'], isNull);

      expect(result.stdout.toString().contains('Successfully installed'), true);
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'Fails on unknown BoM version',
    () async {
      final result = Process.runSync(
        'flutterfire',
        [
          'install',
          '--version=unknown',
          '--plugins=firebase_auth,firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      expect(result.exitCode, 1);
      expect(
        result.stderr.toString().contains('BoM version unknown not found'),
        true,
      );
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'Installs then removes dependency',
    () async {
      final result = Process.runSync(
        'flutterfire',
        [
          'install',
          '--version=0.1.0',
          '--plugins=firebase_auth,firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final parsedPubspec =
          await PubSpec.loadFile(p.join(projectPath!, 'pubspec.yaml'));

      expect(parsedPubspec.dependencies['firebase_auth'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec.dependencies['cloud_firestore'], isNull);

      expect(result.stdout.toString().contains('Successfully installed'), true);

      final result2 = Process.runSync(
        'flutterfire',
        [
          'install',
          '--version=0.1.0',
          '--plugins=firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr as String);
      }

      final parsedPubspec2 =
          await PubSpec.loadFile(p.join(projectPath!, 'pubspec.yaml'));

      expect(parsedPubspec2.dependencies['firebase_auth'], isNull);
      expect(parsedPubspec2.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec2.dependencies['cloud_firestore'], isNull);

      expect(result.stdout.toString().contains('Successfully installed'), true);
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );
}

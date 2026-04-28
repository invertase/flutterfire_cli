import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

Future<bool> _waitForLine(StreamQueue<String> queue, String content) async {
  while (await queue.hasNext) {
    final line = await queue.next;
    if (line.contains(content)) return true;
  }
  return false;
}

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
          '--version=1.0.0',
          '--plugins=firebase_auth,firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final parsedPubspec = Pubspec.parse(
        await File(p.join(projectPath!, 'pubspec.yaml')).readAsString(),
      );

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
          '--version=1.0.0',
          '--plugins=firebase_auth,firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final parsedPubspec = Pubspec.parse(
        await File(p.join(projectPath!, 'pubspec.yaml')).readAsString(),
      );

      expect(parsedPubspec.dependencies['firebase_auth'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec.dependencies['cloud_firestore'], isNull);

      expect(result.stdout.toString().contains('Successfully installed'), true);

      final result2 = Process.runSync(
        'flutterfire',
        [
          'install',
          '--version=1.0.0',
          '--plugins=firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr as String);
      }

      final parsedPubspec2 = Pubspec.parse(
        await File(p.join(projectPath!, 'pubspec.yaml')).readAsString(),
      );

      expect(parsedPubspec2.dependencies['firebase_auth'], isNull);
      expect(parsedPubspec2.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec2.dependencies['cloud_firestore'], isNull);

      expect(result.stdout.toString().contains('Successfully installed'), true);
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );
  test(
    'Installs then use --only-pubspec-plugins flag to remove dependency',
    () async {
      final result = Process.runSync(
        'flutterfire',
        [
          'install',
          '--version=1.0.0',
          '--plugins=firebase_auth,firebase_core',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final parsedPubspec = Pubspec.parse(
        await File(p.join(projectPath!, 'pubspec.yaml')).readAsString(),
      );

      expect(parsedPubspec.dependencies['firebase_auth'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec.dependencies['cloud_firestore'], isNull);

      expect(result.stdout.toString().contains('Successfully installed'), true);

      final result2 = Process.runSync(
        'flutterfire',
        [
          'install',
          '--version=1.0.0',
          '--only-pubspec-plugins',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr as String);
      }

      final parsedPubspec2 = Pubspec.parse(
        await File(p.join(projectPath!, 'pubspec.yaml')).readAsString(),
      );

      expect(parsedPubspec2.dependencies['firebase_auth'], isNotNull);
      expect(parsedPubspec2.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec2.dependencies['cloud_firestore'], isNull);

      expect(result.stdout.toString().contains('Successfully installed'), true);
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );
  test(
    'Installs from CLI',
    () async {
      final process = await Process.start(
        'flutterfire',
        [
          'install',
          '4.10.0',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );
      final stdoutLines = StreamQueue(
        process.stdout
            .transform(utf8.decoder) /*.transform(const LineSplitter())*/,
      );

      await _waitForLine(
        stdoutLines,
        'Select the Firebase plugins you would like to install',
      );

      // Core
      process.stdin.write(' ');

      // Analytics
      process.stdin.write('\x1b[B');
      process.stdin.write(' ');

      // Crashlytics
      process.stdin.write('\x1b[B' * 4);
      process.stdin.write(' ');

      // Messaging
      process.stdin.write('\x1b[B' * 5);
      process.stdin.write(' ');

      // Performance
      process.stdin.write('\x1b[B' * 2);
      process.stdin.write(' ');

      // Remote Config
      process.stdin.write('\x1b[B');
      process.stdin.write(' ');

      // confirm selection
      process.stdin.write('\r');

      await process.stdin.flush();

      final installSuccess =
          await _waitForLine(stdoutLines, 'Successfully installed');
      expect(installSuccess, isTrue);

      // finish
      await process.stdin.flush();
      await process.stdin.close();

      if (await process.exitCode != 0) {
        final errorOutput = await process.stderr.transform(utf8.decoder).join();
        fail(errorOutput);
      }

      final parsedPubspec = Pubspec.parse(
        await File(p.join(projectPath!, 'pubspec.yaml')).readAsString(),
      );

      expect(parsedPubspec.dependencies['firebase_analytics'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_core'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_performance'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_remote_config'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_crashlytics'], isNotNull);
      expect(parsedPubspec.dependencies['firebase_messaging'], isNotNull);

      expect(parsedPubspec.dependencies['firebase_in_app_messaging'], isNull);
      expect(
        parsedPubspec.dependencies['firebase_ml_model_downloader'],
        isNull,
      );
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );
}

import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:flutterfire_cli/src/commands/update.dart';
import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class _Invocation {
  _Invocation(
    this.executable,
    this.arguments,
    this.workingDirectory,
    this.runInShell,
  );

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final bool runInShell;
}

/// Records what would have been run, and answers with [exitCodes] keyed by the
/// arguments joined with a space.
class _FakeProcesses {
  _FakeProcesses({this.exitCodes = const {}});

  final Map<String, int> exitCodes;
  final invocations = <_Invocation>[];

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    invocations.add(
      _Invocation(executable, arguments, workingDirectory, runInShell),
    );

    final key = arguments.join(' ');

    return ProcessResult(0, exitCodes[key] ?? 0, '', 'boom');
  }
}

void main() {
  late Directory appDirectory;
  late File pubspecLock;

  setUp(() {
    appDirectory =
        Directory.systemTemp.createTempSync('flutterfire_cli_update');
    pubspecLock = File(path.join(appDirectory.path, 'pubspec.lock'))
      ..writeAsStringSync('# lock');
  });

  tearDown(() {
    appDirectory.deleteSync(recursive: true);
  });

  Future<_FakeProcesses> update({Map<String, int> exitCodes = const {}}) async {
    final processes = _FakeProcesses(exitCodes: exitCodes);

    await updateFlutterFirePackages(
      flutterAppPath: appDirectory.path,
      logger: Logger.standard(),
      runProcess: processes.run,
    );

    return processes;
  }

  test('runs every Flutter command through a shell', () async {
    final processes = await update();

    expect(processes.invocations, isNotEmpty);
    for (final invocation in processes.invocations) {
      expect(invocation.executable, 'flutter');
      // "flutter" is "flutter.bat" on Windows and `Process.run` does not
      // resolve it through PATHEXT. https://github.com/dart-lang/sdk/issues/31291
      expect(invocation.runInShell, isTrue);
      expect(invocation.workingDirectory, appDirectory.path);
    }
  });

  test('cleans, upgrades every plugin, then runs "pub get"', () async {
    final processes = await update();
    final arguments = processes.invocations
        .map((invocation) => invocation.arguments)
        .toList();

    expect(arguments.first, ['clean']);
    expect(arguments.last, ['pub', 'get']);
    for (final package in flutterfirePackages) {
      expect(
        arguments,
        contains(equals(['pub', 'upgrade', '--major-versions', package])),
      );
    }
  });

  test('deletes "pubspec.lock"', () async {
    await update();

    expect(pubspecLock.existsSync(), isFalse);
  });

  test('carries on when "flutter clean" fails', () async {
    final processes = await update(exitCodes: {'clean': 1});

    // A locked "build" directory is no reason to leave the app un-upgraded.
    expect(processes.invocations.last.arguments, ['pub', 'get']);
    expect(pubspecLock.existsSync(), isFalse);
  });

  test('throws when "flutter pub get" fails', () async {
    expect(
      update(exitCodes: {'pub get': 1}),
      throwsA(
        isA<FlutterCommandException>().having(
          (e) => e.toString(),
          'toString()',
          allOf(contains('flutter pub get'), contains('boom')),
        ),
      ),
    );
  });

  test('does nothing about a missing "pubspec.lock"', () async {
    pubspecLock.deleteSync();

    final processes = await update();

    expect(processes.invocations.last.arguments, ['pub', 'get']);
  });
}

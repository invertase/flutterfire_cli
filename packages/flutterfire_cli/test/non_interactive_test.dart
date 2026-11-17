import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:flutterfire_cli/src/common/prompts/android_prompts.dart';
import 'package:flutterfire_cli/src/common/prompts/apple_prompts.dart';
import 'package:flutterfire_cli/src/common/prompts/dart_file_prompts.dart';
import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:flutterfire_cli/src/common/validation.dart';
import 'package:flutterfire_cli/src/firebase/firebase_android_options.dart';
import 'package:flutterfire_cli/src/firebase/firebase_apple_options.dart';
import 'package:flutterfire_cli/src/flutter_app.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

enum _StdinKind {
  /// A pipe, e.g. `echo | flutterfire`.
  pipe(hasTerminal: false, isTerminal: false),

  /// `</dev/null`, how scripts and AI agents commonly run commands. Dart
  /// reports any character device as a terminal.
  devNull(hasTerminal: true, isTerminal: false),

  /// An actual terminal.
  terminal(hasTerminal: true, isTerminal: true);

  const _StdinKind({required this.hasTerminal, required this.isTerminal});

  final bool hasTerminal;
  final bool isTerminal;
}

class _FakeStdin implements Stdin {
  _FakeStdin(this.kind);

  final _StdinKind kind;

  @override
  bool get hasTerminal => kind.hasTerminal;

  // Like `tcgetattr()`, it only works on a terminal.
  @override
  bool get echoMode {
    if (!kind.isTerminal) {
      throw const StdinException('Error getting terminal echo mode');
    }
    return true;
  }

  // Prompts read stdin a byte at a time, and `</dev/null` would answer with
  // EOF forever, so fail loudly rather than hang.
  @override
  int readByteSync() {
    throw StateError('Prompted for input instead of failing.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

T _withStdin<T>(_StdinKind kind, T Function() body) {
  return IOOverrides.runZoned(body, stdin: () => _FakeStdin(kind));
}

T _withoutTerminal<T>(T Function() body) =>
    _withStdin(_StdinKind.devNull, body);

Matcher _throwsNaming<T extends FlutterFireException>(List<String> flags) {
  return throwsA(
    isA<T>().having(
      (e) => e.toString(),
      'message',
      allOf([for (final flag in flags) contains(flag)]),
    ),
  );
}

/// A Flutter app with no platform directories, so nothing can be detected.
Future<Directory> _createFlutterApp() async {
  final directory =
      await Directory.systemTemp.createTemp('flutterfire_no_terminal_');
  addTearDown(() => directory.delete(recursive: true));

  await File(p.join(directory.path, 'pubspec.yaml')).writeAsString('''
name: no_terminal_app
environment:
  sdk: ^3.6.0
dependencies:
  flutter:
    sdk: flutter
''');

  return directory;
}

const _onCI = 'Prompts are always disabled on CI.';

void main() {
  group('isNonInteractive', () {
    test('is true when stdin is a pipe', () {
      expect(_withStdin(_StdinKind.pipe, () => isNonInteractive), isTrue);
    });

    test('is true when stdin is /dev/null', () {
      expect(_withStdin(_StdinKind.devNull, () => isNonInteractive), isTrue);
    });

    test(
      'is false with a terminal attached to stdin',
      () {
        expect(
          _withStdin(_StdinKind.terminal, () => isNonInteractive),
          isFalse,
        );
      },
      skip: isCI ? _onCI : null,
    );

    test(
      'explains that no terminal is attached',
      () {
        expect(
          _withoutTerminal(() => nonInteractiveReason),
          'without a terminal attached to stdin',
        );
      },
      skip: isCI ? _onCI : null,
    );
  });

  group('Prompt helpers without a terminal', () {
    test('promptBool throws instead of prompting', () {
      expect(
        () => _withoutTerminal(() => promptBool('Proceed?')),
        throwsA(
          isA<NonInteractiveException>().having(
            (e) => e.message,
            'message',
            contains('"Proceed?"'),
          ),
        ),
      );
    });

    test('promptSelect throws instead of prompting', () {
      expect(
        () => _withoutTerminal(
          () => promptSelect('Pick a target', ['Runner', 'Widget']),
        ),
        throwsA(
          isA<NonInteractiveException>().having(
            (e) => e.message,
            'message',
            contains('"Pick a target"'),
          ),
        ),
      );
    });

    test('promptMultiSelect throws instead of prompting', () {
      expect(
        () => _withoutTerminal(
          () => promptMultiSelect('Pick platforms', [kAndroid, kIos]),
        ),
        throwsA(
          isA<NonInteractiveException>().having(
            (e) => e.message,
            'message',
            contains('"Pick platforms"'),
          ),
        ),
      );
    });

    test('promptInput throws instead of prompting, without ANSI codes', () {
      expect(
        () => _withoutTerminal(
          () => promptInput('Enter a ${AnsiStyles.cyan('project id')}'),
        ),
        throwsA(
          isA<NonInteractiveException>().having(
            (e) => e.message,
            'message',
            contains('"Enter a project id"'),
          ),
        ),
      );
    });
  });

  group('Without a terminal, configure names the flag to pass', () {
    test('for a FirebaseOptions path that is not a Dart file', () async {
      final app = await _createFlutterApp();

      expect(
        () => _withoutTerminal(
          () => getFirebaseConfigurationFile(
            configurationFilePath: 'lib/firebase_options',
            flutterAppPath: app.path,
          ),
        ),
        _throwsNaming<ValidationException>(['--$kOutFlag']),
      );
    });

    test('to overwrite an existing FirebaseOptions file', () async {
      final app = await _createFlutterApp();
      await File(p.join(app.path, 'lib', 'firebase_options.dart'))
          .create(recursive: true);

      expect(
        () => _withoutTerminal(
          () => dartConfigurationFileValidation(
            configurationFilePath: 'lib/firebase_options.dart',
            flutterAppPath: app.path,
            overwrite: false,
          ),
        ),
        _throwsNaming<ValidationException>(
          ['--$kOverwriteFirebaseOptionsFlag', '--$kYesFlag'],
        ),
      );
    });

    test('but overwrites the FirebaseOptions file when told to', () async {
      final app = await _createFlutterApp();
      await File(p.join(app.path, 'lib', 'firebase_options.dart'))
          .create(recursive: true);

      final inputs = _withoutTerminal(
        () => dartConfigurationFileValidation(
          configurationFilePath: 'lib/firebase_options.dart',
          flutterAppPath: app.path,
          overwrite: true,
        ),
      );

      expect(inputs.writeConfigurationFile, isTrue);
    });

    test(
      'but writes a FirebaseOptions file that does not exist yet',
      () async {
        final app = await _createFlutterApp();

        final inputs = _withoutTerminal(
          () => dartConfigurationFileValidation(
            configurationFilePath: 'lib/firebase_options.dart',
            flutterAppPath: app.path,
            overwrite: false,
          ),
        );

        expect(inputs.writeConfigurationFile, isTrue);
      },
      // CI requires `--overwrite-firebase-options` or `--yes` regardless.
      skip: isCI ? _onCI : null,
    );

    test('for an invalid "google-services.json" path', () async {
      final app = await _createFlutterApp();

      expect(
        () => _withoutTerminal(
          () => getAndroidServiceFile(
            serviceFilePath: 'config/google-services.json',
            flutterAppPath: app.path,
          ),
        ),
        _throwsNaming<ValidationException>(['--$kAndroidOutFlag']),
      );
    });

    test('for an invalid "GoogleService-Info.plist" path', () async {
      final app = await _createFlutterApp();

      expect(
        () => _withoutTerminal(
          () => getAppleServiceFile('ios/dev/Info.plist', kIos, app.path),
        ),
        _throwsNaming<ValidationException>(['--$kIosOutFlag']),
      );
      expect(
        () => _withoutTerminal(
          () => getAppleServiceFile(null, kMacos, app.path),
        ),
        _throwsNaming<ValidationException>(['--$kMacosOutFlag']),
      );
    });

    test('when both an Apple target and build configuration are set', () async {
      final app = await _createFlutterApp();

      await expectLater(
        _withoutTerminal(
          () => appleValidation(
            platform: kIos,
            flutterAppPath: app.path,
            target: 'Runner',
            buildConfiguration: 'Debug',
            serviceFilePath: 'ios/dev',
          ),
        ),
        _throwsNaming<ValidationException>(
          ['--$kIosBuildConfigFlag', '--$kIosTargetFlag'],
        ),
      );
    });

    test('when an Apple service file path has no target', () async {
      final app = await _createFlutterApp();

      await expectLater(
        _withoutTerminal(
          () => appleValidation(
            platform: kMacos,
            flutterAppPath: app.path,
            serviceFilePath: 'macos/dev',
          ),
        ),
        _throwsNaming<ValidationException>(
          ['--$kMacosBuildConfigFlag', '--$kMacosTargetFlag'],
        ),
      );
    });

    test('when no Android package name can be detected', () async {
      final flutterApp = (await FlutterApp.load(await _createFlutterApp()))!;

      await expectLater(
        _withoutTerminal(
          () => FirebaseAndroidOptions.forFlutterApp(
            flutterApp,
            firebaseProjectId: 'project-id',
            displayName: 'app',
            token: null,
            serviceAccount: null,
          ),
        ),
        _throwsNaming<ValidationException>(['--$kAndroidPackageNameFlag']),
      );
    });

    test('when no Apple bundle id can be detected', () async {
      final flutterApp = (await FlutterApp.load(await _createFlutterApp()))!;

      await expectLater(
        _withoutTerminal(
          () => FirebaseAppleOptions.forFlutterApp(
            flutterApp,
            firebaseProjectId: 'project-id',
            displayName: 'app',
            token: null,
            serviceAccount: null,
          ),
        ),
        _throwsNaming<ValidationException>(['--$kIosBundleIdFlag']),
      );
      await expectLater(
        _withoutTerminal(
          () => FirebaseAppleOptions.forFlutterApp(
            flutterApp,
            macos: true,
            firebaseProjectId: 'project-id',
            displayName: 'app',
            token: null,
            serviceAccount: null,
          ),
        ),
        _throwsNaming<ValidationException>(['--$kMacosBundleIdFlag']),
      );
    });
  });

  group('flutterfire run without a terminal', () {
    late String cliPath;

    setUpAll(() async {
      final libUri = await Isolate.resolvePackageUri(
        Uri.parse('package:flutterfire_cli/'),
      );
      cliPath = p.join(
        p.dirname(p.fromUri(libUri)),
        'bin',
        'flutterfire.dart',
      );
    });

    /// Runs the CLI the way a script or an AI agent does, with nothing ever
    /// written to stdin: either a pipe closed straight away, or `/dev/null`.
    Future<({int exitCode, String stderr})> runCli(
      List<String> arguments,
      Directory workingDirectory, {
      bool devNull = false,
    }) async {
      final environment = Map.of(Platform.environment)
        ..remove('TEST_ENVIRONMENT');
      final command = [Platform.resolvedExecutable, cliPath, ...arguments];
      final process = await Process.start(
        devNull ? 'sh' : command.first,
        devNull
            ? ['-c', r'exec "$0" "$@" </dev/null', ...command]
            : command.skip(1).toList(),
        workingDirectory: workingDirectory.path,
        environment: environment,
        includeParentEnvironment: false,
      );
      await process.stdin.close();

      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(
        const Duration(minutes: 1),
        onTimeout: () {
          process.kill();
          fail('`flutterfire ${arguments.join(' ')}` hung on a prompt.');
        },
      );
      await stdout;

      return (exitCode: exitCode, stderr: await stderr);
    }

    for (final devNull in [false, true]) {
      test(
        'configure asks for --project instead of prompting for one, '
        'with stdin ${devNull ? 'from /dev/null' : 'piped'}',
        () async {
          final app = await _createFlutterApp();

          final result = await runCli(
            // `--platforms` is mandatory on CI.
            ['configure', '--$kPlatformsFlag=android'],
            app,
            devNull: devNull,
          );

          expect(result.exitCode, 1);
          expect(result.stderr, contains('FirebaseProjectRequiredException'));
          expect(result.stderr, contains('--project'));
        },
        timeout: const Timeout(Duration(minutes: 2)),
        skip: devNull && Platform.isWindows ? 'No /dev/null on Windows.' : null,
      );
    }

    test(
      'configure does not ask whether to reuse "firebase.json"',
      () async {
        final app = await _createFlutterApp();
        await File(p.join(app.path, 'firebase.json')).writeAsString('{}');

        final result = await runCli(['configure'], app);

        expect(result.exitCode, 1);
        expect(result.stderr, contains('NonInteractiveException'));
        expect(result.stderr, contains('flutterfire reconfigure'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
      // `--platforms` is mandatory on CI, so this never gets that far.
      skip: isCI ? _onCI : null,
    );
  });
}

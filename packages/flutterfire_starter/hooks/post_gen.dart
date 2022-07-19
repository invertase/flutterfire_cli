import 'dart:io';

import 'package:flutterfire_cli/src/command_runner.dart';
import 'package:flutterfire_cli/src/flutter_app.dart';
import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  await _removeFiles(context, '.gitkeep');
  await _installDependencies(context);
  await _copyGeneratedFilesToLib(context);
  await _runFlutterFireConfigure(context);
  await _copyConfigFile(context);
}

Future<void> _removeFiles(HookContext context, String name) async {
  final removingFilesDone =
      context.logger.progress('removing .gitkeep files ...');
  final dir = Directory('.');
  dir
      .list(recursive: true)
      .where((element) => element.toString().contains(name))
      .listen(
    (element) {
      element.delete();
    },
    onDone: () => removingFilesDone.complete('.gitkeep files removed!'),
  );
}

Future<void> _installDependencies(HookContext context) async {
  final installDone = context.logger.progress('Installing dependencies...');
  final result = await Process.run(
    'flutter',
    ['pub', 'add', 'firebase_core'],
    workingDirectory: './{{name}}',
  );
  if (result.exitCode == 0) {
    installDone.complete('Dependencies installed!');
  } else {
    installDone.fail(result.stderr.toString());
  }
}

Future<void> _copyGeneratedFilesToLib(HookContext context) async {
  final done = context.logger.progress('Copying files to lib...');
  await Process.run('rm', [
    '-rf',
    './{{name}}/lib/',
  ]);

  final results = await Future.wait<ProcessResult>([
    Process.run('mv', [
      'lib',
      './{{name}}/',
    ]),
    Process.run('mv', [
      'macos/Podfile',
      './{{name}}/macos',
    ])
  ]);

  // Cleaning empty folders
  await Process.run('rm', ['-rf', 'macos']);

  if (results.every((element) => element.exitCode == 0)) {
    done.complete('Files copied successfully');
  } else {
    done.fail(
      results.firstWhere((element) => element.exitCode != 0).stderr.toString(),
    );
  }
}

Future<void> _runFlutterFireConfigure(HookContext context) async {
  context.logger.info('Running FlutterFire configure...');
  final app = await FlutterApp.load(Directory('./{{name}}'));
  final flutterFire = FlutterFireCommandRunner(app);

  await flutterFire.run(['config']);
}

Future<void> _copyConfigFile(HookContext context) async {
  final done = context.logger.progress('Copying generated config to lib...');

  final result = await Process.run('mv', [
    'lib/firebase_options.dart',
    './{{name}}/lib/',
  ]);

  await Process.run('rm', [
    '-rf',
    './lib/',
  ]);

  if (result.exitCode == 0) {
    done.complete('Files copied successfully');
  } else {
    done.fail(result.stderr.toString());
  }
}

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
  final removingFilesDone = context.logger.progress('removing $name files ...');
  final dir = Directory('.');
  dir
      .list(recursive: true)
      .where((element) => element.toString().contains(name))
      .listen(
    (element) {
      element.delete();
    },
    onDone: () => removingFilesDone.complete('$name files removed!'),
  );
}

Future<void> _installDependencies(HookContext context) async {
  final installDependencies = context.logger.progress('Installing dependencies...');
  final appName = context.vars['name'] as String;
  final dependencies = <String>[
    'firebase_core',
    ...context.vars['firebase_packages']
  ];

  final processes = dependencies.map(
    (package) => Process.run(
      'flutter',
      ['pub', 'add', package],
      workingDirectory: './$appName',
    ),
  );

  final results = await Future.wait<ProcessResult>(processes);

  if (results.every((element) => element.exitCode == 0)) {
    installDependencies.complete('Dependencies installed!');
  } else {
    installDependencies.fail(
      results.firstWhere((element) => element.exitCode != 0).stderr.toString(),
    );
  }
}

Future<void> _copyGeneratedFilesToLib(HookContext context) async {
  final done = context.logger.progress('Copying files to lib...');
  final appName = context.vars['name'] as String;
  await Process.run('rm', [
    '-rf',
    './$appName/lib/',
  ]);

  final results = await Future.wait<ProcessResult>([
    Process.run('mv', [
      'lib',
      './$appName/',
    ]),
    Process.run('mv', [
      'ios/Podfile',
      './$appName/ios',
    ]),
    Process.run('mv', [
      'macos/Podfile',
      './$appName/macos',
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
  final appName = context.vars['name'] as String;
  final app = await FlutterApp.load(Directory('./$appName'));
  final flutterFire = FlutterFireCommandRunner(app);

  await flutterFire.run(['config']);
}

Future<void> _copyConfigFile(HookContext context) async {
  final done = context.logger.progress('Copying generated config to lib...');
  final appName = context.vars['name'] as String;
  final result = await Process.run('mv', [
    'lib/firebase_options.dart',
    './$appName/lib/',
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

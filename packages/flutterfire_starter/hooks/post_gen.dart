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
  await _format(context);

  context.logger.progress('');
  context.logger.progress('Ready to use Firebase with Flutter! 🚀');
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
  final installDone = context.logger.progress('Installing dependencies...');
  final appName = context.vars['name'] as String;
  final result = await Process.run(
    'flutter',
    ['pub', 'add', 'firebase_core'],
    workingDirectory: './$appName',
  );

  final varsPlugins = (context.vars['plugins'] as List<dynamic>).cast<String>();
  final varsPluginsName = varsPlugins.map((e) => e.split(' ')[0]).toList();
  if (varsPluginsName.contains('Analytics')) {
    await Process.run(
      'flutter',
      ['pub', 'add', 'firebase_analytics'],
      workingDirectory: './$appName',
    );
  }
  if (varsPlugins.contains('Analytics with GoRouter')) {
    await Process.run(
      'flutter',
      ['pub', 'add', 'go_router'],
      workingDirectory: './$appName',
    );
  }

  if (result.exitCode == 0) {
    installDone.complete('Dependencies installed!');
  } else {
    installDone.fail(result.stderr.toString());
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

Future<void> _format(HookContext context) async {
  final done = context.logger.progress('Formatting files...');
  final appName = context.vars['name'] as String;
  final result = await Process.run('flutter', [
    'format',
    './$appName',
  ]);

  if (result.exitCode == 0) {
    done.complete('Files formatted successfully');
  } else {
    done.fail(result.stderr.toString());
  }
}

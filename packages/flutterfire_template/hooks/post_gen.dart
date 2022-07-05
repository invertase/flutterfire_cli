import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  await _removeFiles(context, '.gitkeep');
  await _installDependencies(context);
  await _copyGeneratedFilesToLib(context);
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

  await Process.run('mkdir', [
    './{{name}}/lib/',
  ]);

  final result = await Process.run('mv', [
    'src',
    'main.dart',
    './{{name}}/lib/',
  ]);
  if (result.exitCode == 0) {
    done.complete('Files copied successfully');
  } else {
    done.fail(result.stderr.toString());
  }
}

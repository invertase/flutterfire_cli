import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  final appGenerated = context.logger.progress('Generating a Flutter App');
  final firebaseAdditionalPackages =
      context.vars['firebase_packages'] as List;
  try {
    context.vars = <String, dynamic>{
      ...context.vars,
      'uses_firestore': firebaseAdditionalPackages.contains('cloud_firestore')
    };
    await _generateApp(context);
    appGenerated.complete('Flutter App generated!');
  } catch (e) {
    appGenerated.fail('Generation failed: $e');
  }
}

Future<ProcessResult> _generateApp(HookContext context) async {
  context.logger.info('Running flutter create...');
  final appName = context.vars['name'] as String;
  final appDescription = context.vars['description'] as String;
  final nameOrg = context.vars['org'] as String;
  return Process.run('flutter', [
    'create',
    appName,
    '-t',
    'skeleton',
    '--description',
    appDescription,
    '--org',
    nameOrg,
  ]);
}

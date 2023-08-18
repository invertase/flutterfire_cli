import 'dart:io';

import 'package:mason/mason.dart';

Future<void> run(HookContext context) async {
  _validatePluginList(context);
  _injectInContext(context);

  final appGenerated = context.logger.progress('Generating a Flutter App');
  try {
    await _generateApp(context);
    appGenerated.complete('Flutter App generated!');
  } catch (e) {
    appGenerated.fail('Generation failed: $e');
  }
}

void _validatePluginList(HookContext context) {
  final varsPlugins = (context.vars['plugins'] as List<dynamic>)
      .cast<String>()
      .map((e) => e.split(' ')[0])
      .toList();
  final setPlugins = varsPlugins.toSet().toList();
  if (setPlugins.length != varsPlugins.length) {
    context.logger.err(
      "You have duplicate plugins in your plugin's list. Please remove them.",
    );
    exit(1);
  }
}

// Inject the array of plugins into the context
void _injectInContext(HookContext context) {
  // Default values
  context.vars = <String, dynamic>{
    'analyticswithgorouter': false,
    'analyticswithnavigator': false,
    ...context.vars,
  };
  final varsPlugins = (context.vars['plugins'] as List<dynamic>).cast<String>();
  for (final element in varsPlugins) {
    context.vars[element.replaceAll(' ', '').toLowerCase()] = true;
  }
}

Future<void> _generateApp(HookContext context) async {
  context.logger.info('Running flutter create...');
  final appName = context.vars['name'] as String;
  final appDescription = context.vars['description'] as String;
  final nameOrg = context.vars['org'] as String;
  final runScript = await Process.run('flutter', [
    'create',
    appName,
    '-t',
    'skeleton',
    '--description',
    appDescription,
    '--org',
    nameOrg,
  ]);

  if (runScript.exitCode != 0) {
    throw Exception(runScript.stderr);
  }
}

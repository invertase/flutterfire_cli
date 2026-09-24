/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import '../common/strings.dart';

/// Runs a process. Only exists so the tests can see what the bundler invokes
/// without running npm.
typedef NpmProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell,
});

/// Where the user's own service worker code lives when the worker is bundled,
/// relative to the Flutter app. The bundle itself is minified, so it cannot
/// carry hand written code the way the compat worker does.
const webMessagingServiceWorkerUserFileName = 'firebase-messaging-sw.user.js';

/// esbuild version used to bundle the worker, matching the flutterfire
/// example's `bundled-service-worker`.
const _esbuildVersion = '^0.28.1';

/// Prefixes the line recording what a bundled worker was built from, so it
/// can be rebuilt without `firebase_options.dart` - by `flutterfire update`
/// after a `flutter clean`, for instance.
const _bundleInputsPrefix = '// flutterfire-bundle: ';

/// What a bundled service worker was built from.
@immutable
class WebMessagingServiceWorkerBundleInputs {
  const WebMessagingServiceWorkerBundleInputs({
    required this.firebaseConfig,
    required this.firebaseJsSdkVersion,
  });

  /// Reads the inputs back from a bundled worker, or returns null when
  /// [content] is not one.
  static WebMessagingServiceWorkerBundleInputs? parse(String content) {
    final line = LineSplitter.split(content).firstWhere(
      (line) => line.startsWith(_bundleInputsPrefix),
      orElse: () => '',
    );
    if (line.isEmpty) return null;

    try {
      final json = jsonDecode(line.substring(_bundleInputsPrefix.length))
          as Map<String, dynamic>;
      return WebMessagingServiceWorkerBundleInputs(
        firebaseConfig: (json['firebaseConfig'] as Map<String, dynamic>)
            .cast<String, String>(),
        firebaseJsSdkVersion: json['sdkVersion'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  final Map<String, String> firebaseConfig;
  final String firebaseJsSdkVersion;

  String toHeaderLine() => '$_bundleInputsPrefix${jsonEncode({
            'sdkVersion': firebaseJsSdkVersion,
            'firebaseConfig': firebaseConfig,
          })}';
}

/// Whether npm can be run, which bundling needs.
Future<bool> isNpmAvailable({NpmProcessRunner runProcess = Process.run}) async {
  try {
    final result = await runProcess('npm', ['--version'], runInShell: true);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Bundles the service worker with the modular Firebase JS SDK and writes it
/// to [outputPath], prefixed with [header].
///
/// The build runs in `.dart_tool/flutterfire/firebase-messaging-sw/`, which
/// is disposable: `npm install` runs again whenever it is missing or the SDK
/// version changed.
///
/// Returns false, having logged why, when npm or esbuild fails.
Future<bool> bundleWebMessagingServiceWorker({
  required String flutterAppPath,
  required String outputPath,
  required String header,
  required WebMessagingServiceWorkerBundleInputs inputs,
  required Logger logger,
  NpmProcessRunner runProcess = Process.run,
}) async {
  final buildDirectory = Directory(
    path.join(
      flutterAppPath,
      '.dart_tool',
      'flutterfire',
      'firebase-messaging-sw',
    ),
  );
  await buildDirectory.create(recursive: true);

  final nodeModules = path.join(buildDirectory.path, 'node_modules');
  final userFile = File(
    path.join(flutterAppPath, webMessagingServiceWorkerUserFileName),
  );

  final packageJsonFile = File(path.join(buildDirectory.path, 'package.json'));
  final packageJson = webMessagingServiceWorkerPackageJson(
    inputs.firebaseJsSdkVersion,
  );
  final needsInstall = !Directory(nodeModules).existsSync() ||
      !packageJsonFile.existsSync() ||
      packageJsonFile.readAsStringSync() != packageJson;

  await packageJsonFile.writeAsString(packageJson);
  await File(path.join(buildDirectory.path, 'entry.js')).writeAsString(
    webMessagingServiceWorkerEntry(
      inputs.firebaseConfig,
      userFilePath: userFile.existsSync() ? userFile.absolute.path : null,
    ),
  );
  await File(path.join(buildDirectory.path, 'build.mjs'))
      .writeAsString(webMessagingServiceWorkerBuildScript(nodeModules));

  // `runInShell` is required on Windows, where npm is `npm.cmd`.
  Future<bool> run(String executable, List<String> arguments) async {
    final result = await runProcess(
      executable,
      arguments,
      workingDirectory: buildDirectory.path,
      runInShell: true,
    );
    if (result.exitCode == 0) return true;

    logger.stderr(
      logWebMessagingServiceWorkerBundleFailed(
        '$executable ${arguments.join(' ')}',
        '${result.stdout}${result.stderr}'.trim(),
      ),
    );
    return false;
  }

  if (needsInstall) {
    logger.stdout(
      'Installing the Firebase JS SDK ${inputs.firebaseJsSdkVersion} to '
      'bundle the messaging service worker ...',
    );
    if (!await run(
      'npm',
      ['install', '--no-audit', '--no-fund', '--loglevel=error'],
    )) {
      return false;
    }
  }

  if (!await run('node', ['build.mjs'])) return false;

  final bundle =
      await File(path.join(buildDirectory.path, 'out.js')).readAsString();
  await File(outputPath).writeAsString(
    '$header\n${inputs.toHeaderLine()}\n\n$bundle',
  );

  return true;
}

@visibleForTesting
String webMessagingServiceWorkerPackageJson(String firebaseJsSdkVersion) =>
    '${const JsonEncoder.withIndent('  ').convert({
          'private': true,
          'type': 'module',
          'dependencies': {
            'esbuild': _esbuildVersion,
            'firebase': firebaseJsSdkVersion,
          },
        })}\n';

/// The worker's entry point. The user's file, if any, default exports a
/// function that is called with the initialized `Messaging` instance: imports
/// are evaluated before the importing module, so code at the top level of the
/// user's file would run before `initializeApp()`.
@visibleForTesting
String webMessagingServiceWorkerEntry(
  Map<String, String> firebaseConfig, {
  String? userFilePath,
}) {
  const encoder = JsonEncoder.withIndent('  ');

  return '''
import { initializeApp } from 'firebase/app';
import { getMessaging } from 'firebase/messaging/sw';
${userFilePath == null ? '' : 'import * as userCode from ${jsonEncode(userFilePath)};\n'}
const app = initializeApp(${encoder.convert(firebaseConfig)});

const messaging = getMessaging(app);
${userFilePath == null ? '' : '''
if (typeof userCode.default === 'function') {
  userCode.default(messaging);
}
'''}''';
}

/// Uses esbuild's JS API rather than its CLI: no argument quoting through a
/// Windows shell, and `nodePaths` lets the user's file, which sits outside
/// the build directory, import from `firebase` too.
@visibleForTesting
String webMessagingServiceWorkerBuildScript(String nodeModulesPath) => '''
import { build } from 'esbuild';

await build({
  entryPoints: ['entry.js'],
  outfile: 'out.js',
  bundle: true,
  minify: true,
  format: 'iife',
  platform: 'browser',
  nodePaths: [${jsonEncode(nodeModulesPath)}],
  logLevel: 'warning',
});
''';

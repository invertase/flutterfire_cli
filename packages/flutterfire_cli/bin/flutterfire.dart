// ignore_for_file: avoid_print
/*
 * Copyright (c) 2020-present Invertase Limited & Contributors
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

import 'dart:io';

import 'package:flutterfire_cli/src/command_runner.dart';
import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart' as utils;
import 'package:flutterfire_cli/src/flutter_app.dart';
import 'package:flutterfire_cli/version.g.dart';
import 'package:pub_updater/pub_updater.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--version') || arguments.contains('-v')) {
    print(cliVersion);
    // No version checks on CIs.
    if (utils.isCI) return;

    // Check for updates.
    final pubUpdater = PubUpdater();
    const packageName = 'flutterfire_cli';
    final isUpToDate = await pubUpdater.isUpToDate(
      packageName: packageName,
      currentVersion: cliVersion,
    );
    if (!isUpToDate) {
      final latestVersion = await pubUpdater.getLatestVersion(packageName);
      final shouldUpdate = utils.promptBool(
        logPromptNewCliVersionAvailable(packageName, latestVersion),
      );
      if (shouldUpdate) {
        await pubUpdater.update(packageName: packageName);
        print(logCliUpdated(packageName, latestVersion));
      }
    }

    return;
  }

  try {
    FlutterApp? flutterApp;
    // upload-crashlytics-symbols & bundle-service-file scripts are ran from Xcode environment
    if (!arguments.contains('upload-crashlytics-symbols') &&
        !arguments.contains('bundle-service-file')) {
      flutterApp = await FlutterApp.load(Directory.current);
    }

    await FlutterFireCommandRunner(flutterApp).run(arguments);
  } on FlutterFireException catch (err) {
    if (utils.activeSpinnerState != null) {
      try {
        utils.activeSpinnerState!.done();
      } catch (_) {}
    }
    stderr.writeln(err.toString());
    exitCode = 1;
  } catch (err) {
    exitCode = 1;
    rethrow;
  }
}

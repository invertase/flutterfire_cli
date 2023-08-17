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

import 'dart:io';

import '../flutter_app.dart';
import 'base.dart';

/// List of firebase packages that are supported by the CLI.
final flutterfirePackages = [
  'firebase_app_check',
  'firebase_dynamic_links',
  'firebase_performance',
  'firebase_ui_localizations',
  'flutterfire_ui',
  'cloud_firestore',
  'firebase_app_installations',
  'firebase_in_app_messaging',
  'firebase_remote_config',
  'firebase_ui_oauth',
  'cloud_firestore_odm',
  'firebase_auth',
  'firebase_messaging',
  'firebase_storage',
  'firebase_ui_oauth_apple',
  'cloud_functions',
  'firebase_core',
  'firebase_ml_custom',
  'firebase_ui_auth',
  'firebase_ui_oauth_facebook',
  'firebase_crashlytics',
  'firebase_ml_model_downloader',
  'firebase_ui_database',
  'firebase_ui_oauth_google',
  'firebase_analytics',
  'firebase_database',
  'firebase_ml_vision',
  'firebase_ui_firestore',
  'firebase_ui_oauth_twitter',
];

class UpdateCommand extends FlutterFireCommand {
  UpdateCommand(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
  }

  @override
  final String name = 'update';

  @override
  final String description =
      'Update the version of firebase plugins in your pubspec '
      'to the latest version and clean your workspace to ensure that everything '
      'works properly.';

  bool get yes {
    return argResults!['yes'] as bool || false;
  }

  @override
  Future<void> run() async {
    commandRequiresFlutterApp();

    logger.stdout('Cleaning up current workspace ...');
    await Process.run(
      'flutter',
      ['clean'],
    );
    await Process.run(
      'rm',
      ['pubspec.lock'],
    );

    logger.stdout('Upgrading all firebase plugins to the latest version ...');
    for (final package in flutterfirePackages) {
      // We run each package individually because chaining them
      // will fail at the first package not in the pubspec.
      await Process.run(
        'flutter',
        ['pub', 'upgrade', '--major-versions', package],
      );
    }

    logger.stdout("Running 'flutter pub get'...");
    await Process.run(
      'flutter',
      ['pub', 'get'],
    );

    logger.stdout('Ready to use the latest version of FlutterFire! 🚀');
  }
}

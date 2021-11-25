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

import '../flutter_app.dart';

import 'base.dart';

class ConfigCommand extends FlutterFireCommand {
  ConfigCommand(FlutterApp flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
    argParser.addOption(
      'ios-bundle-id',
      valueHelp: 'bundleIdentifier',
      abbr: 'i',
      help: 'The bundle identifier of your iOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "ios" folder (if it exists).',
    );
    argParser.addOption(
      'macos-bundle-id',
      valueHelp: 'bundleIdentifier',
      abbr: 'm',
      help: 'The bundle identifier of your macOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "macos" folder (if it exists).',
    );
    argParser.addOption(
      'android-app-id',
      valueHelp: 'applicationId',
      abbr: 'a',
      help: 'The application id of you Android app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists).',
    );
  }

  @override
  final String name = 'config';

  @override
  final String description = 'Configure Firebase for your Flutter app. This '
      'command will fetch Firebase configuration for you and generate a '
      'lib/firebase_config.dart file with FirebaseOptions you can use.';

  @override
  Future<void> run() async {
    // TODO
  }
}

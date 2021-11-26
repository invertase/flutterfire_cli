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

import 'package:ansi_styles/ansi_styles.dart';

/// A base class for all FlutterFire CLI exceptions.
abstract class FlutterFireException implements Exception {}

class FlutterAppRequiredException implements FlutterFireException {
  @override
  String toString() {
    return 'FlutterAppRequiredException: The current directory does not appear to be a Flutter application project.';
  }
}

class FirebaseProjectRequiredException implements FlutterFireException {
  @override
  String toString() {
    return 'FirebaseProjectRequiredException: A Firebase project id must be specified, either via the `--project` option or a `.firebaserc` file.';
  }
}

class FirebaseProjectNotFoundException implements FlutterFireException {
  FirebaseProjectNotFoundException(this.projectId) : super();

  final String projectId;

  @override
  String toString() {
    return 'FirebaseProjectNotFoundException: Firebase project id "$projectId" could not be found on this Firebase account.';
  }
}

class FirebaseCommandException implements FlutterFireException {
  FirebaseCommandException(this.command, this.error) : super();

  final String command;

  final String error;

  @override
  String toString() {
    return '${AnsiStyles.red('FirebaseCommandException: An error occured on the Firebase CLI when attempting to run a command.\n')}COMMAND: ${AnsiStyles.cyan('firebase $command')} \nERROR: $error';
  }
}

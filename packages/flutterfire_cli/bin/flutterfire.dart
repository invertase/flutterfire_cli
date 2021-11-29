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
import 'package:flutterfire_cli/src/common/exception.dart';
import 'package:flutterfire_cli/src/common/utils.dart' as utils;
import 'package:flutterfire_cli/src/flutter_app.dart';
import 'package:flutterfire_cli/version.g.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--version')) {
    // ignore: avoid_print
    print(cliVersion);
    return;
  }
  try {
    final flutterApp = await FlutterApp.load(Directory.current);
    await FlutterFireCommandRunner(flutterApp).run(arguments);
  } on FlutterFireException catch (err) {
    if (utils.activeSpinnerState != null) {
      utils.activeSpinnerState!.done();
    }
    stderr.writeln(err.toString());
    exitCode = 1;
  } catch (err) {
    exitCode = 1;
    rethrow;
  }
}

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

import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../firebase.dart';
import '../flutter_app.dart';
import 'firebase_options.dart';

extension FirebaseDartOptions on FirebaseOptions {
  static Future<FirebaseOptions> forFlutterApp(
    FlutterApp flutterApp, {
    required String firebaseProjectId,
    String? firebaseAccount,
    String? webAppId,
    String platform = kWeb,
    required String? token,
    required String? serviceAccount,
  }) async {
    final firebaseApp = await firebase.findOrCreateFirebaseApp(
      displayName: flutterApp.package.pubSpec.name ?? 'flutterfire_app',
      platform: platform,
      project: firebaseProjectId,
      account: firebaseAccount,
      token: token,
      serviceAccount: serviceAccount,
      webAppId: webAppId,
    );
    final appSdkConfig = await firebase.getAppSdkConfig(
      appId: firebaseApp.appId,
      platform: kWeb,
      account: firebaseAccount,
      token: token,
      serviceAccount: serviceAccount,
    );

    return convertConfigToOptions(appSdkConfig, firebaseProjectId);
  }

  static FirebaseOptions convertConfigToOptions(
    FirebaseAppSdkConfig appSdkConfig,
    String firebaseProjectId,
  ) {
    final jsonBodyRegex = RegExp(
      r'''firebase\.initializeApp\({(?<jsonBody>[\S\s]*)}\);''',
      multiLine: true,
    );
    final match = jsonBodyRegex.firstMatch(appSdkConfig.fileContents);
    var jsonBody = '';
    if (match != null) {
      jsonBody = match.namedGroup('jsonBody')!;
    }
    return FirebaseOptions.fromMap(
      const JsonDecoder().convert('{$jsonBody}') as Map,
    );
  }
}

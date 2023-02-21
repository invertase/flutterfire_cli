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
import 'package:deep_pick/deep_pick.dart';

import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../firebase.dart';
import '../flutter_app.dart';
import 'firebase_options.dart';

extension FirebaseAndroidOptions on FirebaseOptions {
  static String projectIdFromFileContents(String fileContents) {
    final appSdkConfigMap =
        const JsonDecoder().convert(fileContents) as Map<String, dynamic>;
    return pick(appSdkConfigMap, 'project_info', 'project_id')
        .asStringOrThrow();
  }

  static Future<FirebaseOptions> forFlutterApp(
    FlutterApp flutterApp, {
    String? androidApplicationId,
    required String firebaseProjectId,
    String? firebaseAccount,
    required String? token,
    required String? serviceAccount,
  }) async {
    var selectedAndroidApplicationId =
        androidApplicationId ?? flutterApp.androidApplicationId;
    selectedAndroidApplicationId ??= promptInput(
      "Which Android application id (or package name) do you want to use for this configuration, e.g. 'com.example.app'?",
      defaultValue: selectedAndroidApplicationId,
    );
    final firebaseApp = await firebase.findOrCreateFirebaseApp(
      packageNameOrBundleIdentifier: selectedAndroidApplicationId,
      displayName: flutterApp.package.pubSpec.name ?? 'flutterfire_app',
      platform: kAndroid,
      project: firebaseProjectId,
      account: firebaseAccount,
      token: token,
      serviceAccount: serviceAccount,
    );
    final appSdkConfig = await firebase.getAppSdkConfig(
      appId: firebaseApp.appId,
      platform: kAndroid,
      account: firebaseAccount,
      token: token,
      serviceAccount: serviceAccount,
    );

    return convertConfigToOptions(
      appSdkConfig,
      firebaseApp.appId,
      firebaseProjectId,
    );
  }

  static FirebaseOptions convertConfigToOptions(
    FirebaseAppSdkConfig appSdkConfig,
    String appId,
    String firebaseProjectId,
  ) {
    final appSdkConfigMap = const JsonDecoder()
        .convert(appSdkConfig.fileContents) as Map<String, dynamic>;
    final clientMap =
        pick(appSdkConfigMap, 'client').asListOrThrow<Map>((pick) {
      return pick.asMapOrEmpty<String, dynamic>();
    }).firstWhere(
      (client) =>
          pick(client, 'client_info', 'mobilesdk_app_id').asStringOrThrow() ==
          appId,
    );
    return FirebaseOptions(
      optionsSourceContent: appSdkConfig.fileContents,
      optionsSourceFileName: appSdkConfig.fileName,
      apiKey: pick(clientMap, 'api_key', 0, 'current_key').asStringOrThrow(),
      appId: appId,
      projectId: firebaseProjectId,
      messagingSenderId: pick(appSdkConfigMap, 'project_info', 'project_number')
          .asStringOrThrow(),
      databaseURL: pick(appSdkConfigMap, 'project_info', 'firebase_url')
          .asStringOrNull(),
      storageBucket: pick(appSdkConfigMap, 'project_info', 'storage_bucket')
          .asStringOrNull(),
    );
  }
}

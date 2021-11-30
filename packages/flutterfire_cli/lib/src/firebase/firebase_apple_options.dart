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

import 'package:deep_pick/deep_pick.dart';
import '../common/plist.dart';
import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../flutter_app.dart';
import 'firebase_options.dart';

extension FirebaseAppleOptions on FirebaseOptions {
  static Future<FirebaseOptions> forFlutterApp(
    FlutterApp flutterApp, {
    String? appleBundleIdentifier,
    bool macos = false,
    required String firebaseProjectId,
    String? firebaseAccount,
  }) async {
    final platformIdentifier = macos ? kMacos : kIos;
    var selectedAppleBundleId = appleBundleIdentifier ??
        (macos ? flutterApp.macosBundleId : flutterApp.iosBundleId);
    selectedAppleBundleId ??= promptInput(
      "Which $platformIdentifier bundle id do you want to use for this configuration, e.g. 'com.example.app'?",
      defaultValue: selectedAppleBundleId,
      validator: (value) {
        if (value.isEmpty) return 'bundle identifier must not be empty';
        // TODO validate valid bundle id?
        return true;
      },
    );
    final firebaseApp = await firebase.findOrCreateFirebaseApp(
      packageNameOrBundleIdentifier: selectedAppleBundleId,
      displayName: flutterApp.package.pubSpec.name ?? 'flutterfire_app',
      platform: platformIdentifier,
      project: firebaseProjectId,
      account: firebaseAccount,
    );
    final appSdkConfigString = await firebase.getAppSdkConfig(
      appId: firebaseApp.appId,
      platform: platformIdentifier,
      account: firebaseAccount,
    );
    final appSdkConfigMap = parsePlist(appSdkConfigString);
    return FirebaseOptions(
      apiKey: pick(appSdkConfigMap, 'API_KEY').asStringOrThrow(),
      appId: firebaseApp.appId,
      projectId: firebaseProjectId,
      messagingSenderId:
          pick(appSdkConfigMap, 'GCM_SENDER_ID').asStringOrThrow(),
      databaseURL: pick(appSdkConfigMap, 'DATABASE_URL').asStringOrNull(),
      storageBucket: pick(appSdkConfigMap, 'STORAGE_BUCKET').asStringOrNull(),
      // iOS/macOS specific
      androidClientId:
          pick(appSdkConfigMap, 'ANDROID_CLIENT_ID').asStringOrNull(),
      iosClientId: pick(appSdkConfigMap, 'CLIENT_ID').asStringOrNull(),
      iosBundleId: pick(appSdkConfigMap, 'BUNDLE_ID').asStringOrNull(),
      // TODO: Unknown as to where these fields are located, not showing on plist files
      // trackingId: null,
      // appGroupId: null,
      // deepLinkURLScheme: null,
    );
  }
}

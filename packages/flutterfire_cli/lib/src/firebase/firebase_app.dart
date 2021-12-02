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

class FirebaseApp {
  const FirebaseApp({
    required this.name,
    required this.displayName,
    required this.platform,
    required this.appId,
    required this.packageNameOrBundleIdentifier,
  });

  FirebaseApp.fromJson(Map<dynamic, dynamic> json)
      : this(
          platform: (json['platform'] as String).toLowerCase(),
          appId: json['appId'] as String,
          displayName: json['displayName'] as String?,
          name: json['name'] as String,
          packageNameOrBundleIdentifier:
              (json['packageName'] ?? json['bundleId']) as String?,
        );

  final String platform;

  final String? displayName;

  final String name;

  final String appId;

  final String? packageNameOrBundleIdentifier;

  @override
  String toString() {
    return 'FirebaseApp["$displayName", "$packageNameOrBundleIdentifier", "$platform"]';
  }
}

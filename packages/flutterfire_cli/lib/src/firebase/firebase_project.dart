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

class FirebaseProjectResources {
  const FirebaseProjectResources({
    this.hostingSite,
    this.realtimeDatabaseInstance,
    this.storageBucket,
    this.locationId,
  });

  FirebaseProjectResources.fromJson(Map<String, dynamic> json)
      : this(
          hostingSite: json['hostingSite'] as String?,
          realtimeDatabaseInstance: json['realtimeDatabaseInstance'] as String?,
          storageBucket: json['storageBucket'] as String?,
          locationId: json['locationId'] as String?,
        );

  final String? hostingSite;

  final String? realtimeDatabaseInstance;

  final String? storageBucket;

  final String? locationId;
}

class FirebaseProject {
  const FirebaseProject({
    required this.projectId,
    required this.projectNumber,
    required this.displayName,
    required this.name,
    required this.state,
    required this.resources,
  });

  FirebaseProject.fromJson(Map<dynamic, dynamic> json)
      : this(
          projectId: json['projectId'] as String,
          projectNumber: json['projectNumber'] as String,
          displayName:
              json['displayName'] as String? ?? json['projectId'] as String,
          name: json['name'] as String,
          state: json['state'] as String,
          resources: FirebaseProjectResources.fromJson(
            Map<String, dynamic>.from(json['resources'] as Map),
          ),
        );

  final String projectId;

  final String? displayName;

  final String name;

  final String projectNumber;

  final String state;

  final FirebaseProjectResources resources;

  @override
  String toString() {
    return 'FirebaseProject["$name", $state]';
  }
}

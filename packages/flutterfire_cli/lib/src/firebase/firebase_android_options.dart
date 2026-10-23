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

import '../common/global.dart';
import '../common/strings.dart';
import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../firebase.dart';
import '../flutter_app.dart';
import 'firebase_options.dart';

extension FirebaseAndroidOptions on FirebaseOptions {
  static bool matchesSha1(String? certificateHash, String? query) {
    if (debugMode) {
      // ignore: avoid_print
      print('[FlutterFire CLI] Checking certificate_hash: "$certificateHash" against query: "$query"');
    }
    if (certificateHash == null || query == null || query.isEmpty) return true;

    String normalize(String s, {bool isQuery = false}) {
      var res = s.replaceAll(RegExp(r'[:\-]'), '');
      if (isQuery) {
        res = res.replaceAll(RegExp('^=+'), '');
      }
      return res.toLowerCase();
    }

    final normalizedHash = normalize(certificateHash);
    final normalizedQuery = normalize(query, isQuery: true);

    if (normalizedQuery.contains('*') || normalizedQuery.contains('?')) {
      final pattern = '^${normalizedQuery
          .replaceAll('.', r'\.')
          .replaceAll('*', '.*')
          .replaceAll('?', '.')
        }\$';
      try {
        final matches = RegExp(pattern).hasMatch(normalizedHash);
        if (debugMode) {
          // ignore: avoid_print
          print('[FlutterFire CLI] Wildcard match result for "$certificateHash" with pattern "$pattern": $matches');
        }
        return matches;
      } catch (e) {
        if (debugMode) {
          // ignore: avoid_print
          print('[FlutterFire CLI] Wildcard regex error: $e');
        }
        return false;
      }
    }

    final matches = normalizedHash == normalizedQuery;
    if (debugMode) {
      // ignore: avoid_print
      print('[FlutterFire CLI] Exact match result for "$certificateHash" with query "$query": $matches');
    }
    return matches;
  }

  static Map<Object?, Object?>? getAndroidClientId(
    Map<Object?, Object?> clientMap, {
    String? androidSha1,
  }) {
    final oauthClients =
        pick(clientMap, 'oauth_client').asListOrNull<Map>((pick) {
      return pick.asMapOrEmpty<Object?, Object?>();
    });
    if (debugMode) {
      // ignore: avoid_print
      print('[FlutterFire CLI] getAndroidClientId: found ${oauthClients?.length ?? 0} oauth_clients for client. androidSha1 filter: $androidSha1');
    }
    if (oauthClients == null || oauthClients.isEmpty) return null;

    // Filter for Android client type (client_type == 1)
    final androidOauthClients = oauthClients.where((client) {
      final clientType = client['client_type'];
      return clientType == 1 || clientType == '1';
    }).toList();

    if (debugMode) {
      // ignore: avoid_print
      print('[FlutterFire CLI] getAndroidOAuthClient: found ${androidOauthClients.length} Android oauth clients (client_type == 1)');
    }

    if (androidOauthClients.isEmpty) return null;

    if (androidSha1 != null && androidSha1.isNotEmpty) {
      for (final client in androidOauthClients) {
        final androidInfo = client['android_info'];
        final certificateHash = androidInfo is Map
            ? androidInfo['certificate_hash'] as String?
            : null;
        if (debugMode) {
          // ignore: avoid_print
          print('[FlutterFire CLI] Examining Android OAuth client: clientId=${client['client_id']}, certificateHash=$certificateHash');
        }
        if (matchesSha1(certificateHash, androidSha1)) {
          if (debugMode) {
            // ignore: avoid_print
            print('[FlutterFire CLI] Matched Android OAuth client: $client');
          }
          return client;
        }
      }
    }

    // Fallback to the first Android OAuth client if no SHA-1 filter or no match found
    if (debugMode) {
      // ignore: avoid_print
      print('[FlutterFire CLI] Fallback to first Android OAuth client: ${androidOauthClients.first}');
    }
    return androidOauthClients.first;
  }

  static Future<Map<Object?, Object?>?> getAndroidClientIdForProject({
    required String projectId,
    required String? account,
    required String? token,
    required String? serviceAccount,
    required String androidSha1,
  }) async {
    if (debugMode) {
      // ignore: avoid_print
      print('[FlutterFire CLI] getAndroidClientIdForProject starting with projectId=$projectId, androidSha1=$androidSha1');
    }
    try {
      final androidApps = await firebase.getApps(
        project: projectId,
        account: account,
        platform: kAndroid,
        token: token,
        serviceAccount: serviceAccount,
      );
      if (debugMode) {
        // ignore: avoid_print
        print('[FlutterFire CLI] Found ${androidApps.length} android apps in project.');
      }
      for (final app in androidApps) {
        if (debugMode) {
          // ignore: avoid_print
          print('[FlutterFire CLI] Fetching SDK config for appId=${app.appId}, packageName=${app.packageNameOrBundleIdentifier}');
        }
        final appSdkConfig = await firebase.getAppSdkConfig(
          appId: app.appId,
          platform: kAndroid,
          account: account,
          token: token,
          serviceAccount: serviceAccount,
        );
        final appSdkConfigMap = const JsonDecoder()
            .convert(appSdkConfig.fileContents) as Map<String, dynamic>;
        final clients =
            pick(appSdkConfigMap, 'client').asListOrThrow<Map>((pick) {
          return pick.asMapOrEmpty<Object?, Object?>();
        });
        if (debugMode) {
          // ignore: avoid_print
          print('[FlutterFire CLI] Found ${clients.length} clients in appSdkConfigMap.');
        }

        for (final client in clients) {
          final oauthClient = getAndroidClientId(client, androidSha1: androidSha1);
          if (oauthClient != null) {
            final androidInfo = oauthClient['android_info'];
            final certificateHash = androidInfo is Map
                ? androidInfo['certificate_hash'] as String?
                : null;
            if (matchesSha1(certificateHash, androidSha1)) {
              if (debugMode) {
                // ignore: avoid_print
                print('[FlutterFire CLI] getAndroidClientIdForProject matched oauthClient: $oauthClient');
              }
              return oauthClient;
            }
          }
        }
      }
    } catch (e, st) {
      if (debugMode) {
        // ignore: avoid_print
        print('[FlutterFire CLI] getAndroidClientIdForProject error: $e\n$st');
      }
    }
    if (debugMode) {
      // ignore: avoid_print
      print('[FlutterFire CLI] getAndroidClientIdForProject found no match.');
    }
    return null;
  }

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
    required String displayName,
    required String? token,
    required String? serviceAccount,
    String? androidSha1,
  }) async {
    var selectedAndroidApplicationId =
        androidApplicationId ?? flutterApp.androidApplicationId;

    if (isCI && selectedAndroidApplicationId == null) {
      throw ValidationException(
        kAndroid,
        'A valid application package name is required when configuring on CI. Please use the `--android-package-name` flag',
      );
    }
    selectedAndroidApplicationId ??= promptInput(
      "Which Android application id (or package name) do you want to use for this configuration, e.g. 'com.example.app'?",
      defaultValue: selectedAndroidApplicationId,
    );
    final firebaseApp = await firebase.findOrCreateFirebaseApp(
      packageNameOrBundleIdentifier: selectedAndroidApplicationId,
      displayName: displayName,
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
      androidSha1: androidSha1,
    );
  }

  static FirebaseOptions convertConfigToOptions(
    FirebaseAppSdkConfig appSdkConfig,
    String appId,
    String firebaseProjectId, {
    String? androidSha1,
  }) {
    final appSdkConfigMap = const JsonDecoder()
        .convert(appSdkConfig.fileContents) as Map<String, dynamic>;

    final clients = pick(appSdkConfigMap, 'client').asListOrThrow<Map>((pick) {
      return pick.asMapOrEmpty<Object?, Object?>();
    });

    Map<Object?, Object?>? clientMap;

    if (androidSha1 != null && androidSha1.isNotEmpty) {
      for (final client in clients) {
        final oauthClients =
            pick(client, 'oauth_client').asListOrNull<Map>((pick) {
          return pick.asMapOrEmpty<Object?, Object?>();
        });
        if (oauthClients != null) {
          for (final oauthClient in oauthClients) {
            final clientType = oauthClient['client_type'];
            if (clientType == 1 || clientType == '1') {
              final androidInfo = oauthClient['android_info'];
              final certificateHash = androidInfo is Map
                  ? androidInfo['certificate_hash'] as String?
                  : null;
              if (matchesSha1(certificateHash, androidSha1)) {
                clientMap = client;
                break;
              }
            }
          }
        }
        if (clientMap != null) break;
      }
    }

    clientMap ??= clients.firstWhere(
      (client) =>
          pick(client, 'client_info', 'mobilesdk_app_id').asStringOrThrow() ==
          appId,
      orElse: () => clients.first,
    );

    final resolvedAppId =
        pick(clientMap, 'client_info', 'mobilesdk_app_id').asStringOrNull() ??
            appId;

    final androidOAuthClient = getAndroidClientId(clientMap, androidSha1: androidSha1);

    return FirebaseOptions(
      optionsSourceContent: appSdkConfig.fileContents,
      optionsSourceFileName: appSdkConfig.fileName,
      apiKey: pick(clientMap, 'api_key', 0, 'current_key').asStringOrThrow(),
      appId: resolvedAppId,
      projectId: firebaseProjectId,
      messagingSenderId: pick(appSdkConfigMap, 'project_info', 'project_number')
          .asStringOrThrow(),
      databaseURL: pick(appSdkConfigMap, 'project_info', 'firebase_url')
          .asStringOrNull(),
      storageBucket: pick(appSdkConfigMap, 'project_info', 'storage_bucket')
          .asStringOrNull(),
      androidClientId: androidOAuthClient?['client_id'] as String?,
    );
  }
}

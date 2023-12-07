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
import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'common/strings.dart';
import 'common/utils.dart';
import 'firebase/firebase_app.dart';
import 'firebase/firebase_project.dart';

/// Simple check to verify Firebase Tools CLI is installed.
bool? _existsCache;
Future<bool> exists() async {
  if (_existsCache != null) {
    return _existsCache!;
  }
  final process = await Process.run(
    'firebase',
    ['--version'],
    runInShell: true,
  );
  return _existsCache = process.exitCode == 0;
}

/// Tries to read the default Firebase project id from the
/// .firbaserc file at the root of the dart project if it exists.
Future<String?> getDefaultFirebaseProjectId() async {
  final firebaseRcFile = File(firebaseRcPathForDirectory(Directory.current));
  if (!firebaseRcFile.existsSync()) return null;
  final fileContents = firebaseRcFile.readAsStringSync();
  try {
    final jsonMap =
        const JsonDecoder().convert(fileContents) as Map<String, dynamic>;
    if (jsonMap['projects'] != null &&
        (jsonMap['projects'] as Map)['default'] != null) {
      return (jsonMap['projects'] as Map)['default'] as String;
    }
  } catch (e) {
    return null;
  }
  return null;
}

/// Executes a command on the Firebase CLI and returns
/// the result as a parsed JSON Map.
/// Example:
///   final result = await runFirebaseCommand(['projects:list']);
///   print(result);
Future<Map<String, dynamic>> runFirebaseCommand(
  List<String> commandAndArgs, {
  String? project,
  String? account,
  String? serviceAccount,
}) async {
  final cliExists = await exists();
  if (!cliExists) {
    throw FirebaseCommandException(
      '--version',
      logMissingFirebaseCli,
    );
  }
  final workingDirectoryPath = Directory.current.path;
  final execArgs = [
    ...commandAndArgs,
    '--json',
    if (project != null) '--project=$project',
    if (account != null) '--account=$account',
  ];

  final process = await Process.run(
    'firebase',
    execArgs,
    workingDirectory: workingDirectoryPath,
    environment: {
      if (serviceAccount != null)
        'GOOGLE_APPLICATION_CREDENTIALS': serviceAccount,
    },
    runInShell: true,
  );

  final jsonString = process.stdout.toString();

  Map<String, dynamic> commandResult;

  try {
    commandResult = Map<String, dynamic>.from(
      const JsonDecoder().convert(jsonString) as Map,
    );
  } catch (e) {
    // ignore: avoid_print
    print(
      'Failed to parse JSON response from Firebase CLI. JSON response: $jsonString',
    );
    rethrow;
  }

  if (process.exitCode > 0 || commandResult['status'] == 'error') {
    throw FirebaseCommandException(
      execArgs.join(' '),
      commandResult['error'] as String,
    );
  }

  return commandResult;
}

/// Get all available Firebase projects for the authenticated CLI user
/// or for the account provided.
Future<List<FirebaseProject>> getProjects({
  String? account,
  String? token,
  String? serviceAccount,
}) async {
  final response = await runFirebaseCommand(
    [
      'projects:list',
      if (token != null) '--token=$token',
    ],
    account: account,
    serviceAccount: serviceAccount,
  );
  final result = List<Map<String, dynamic>>.from(response['result'] as List);
  return result
      .map<FirebaseProject>(
        (Map<String, dynamic> e) =>
            FirebaseProject.fromJson(Map<String, dynamic>.from(e)),
      )
      .where((project) => project.state == 'ACTIVE')
      .toList();
}

/// Create a new [FirebaseProject].
Future<FirebaseProject> createProject({
  required String projectId,
  String? displayName,
  String? account,
  String? token,
  String? serviceAccount,
}) async {
  final response = await runFirebaseCommand(
    [
      'projects:create',
      projectId,
      if (displayName != null) displayName,
      if (token != null) '--token=$token',
    ],
    account: account,
    serviceAccount: serviceAccount,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseProject.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'state': 'ACTIVE',
  });
}

/// Get registered Firebase apps for a project.
Future<List<FirebaseApp>> getApps({
  required String project,
  String? account,
  String? platform,
  String? token,
  String? serviceAccount,
}) async {
  if (platform != null) _assertFirebaseSupportedPlatform(platform);
  final response = await runFirebaseCommand(
    [
      'apps:list',
      if (platform != null) platform,
      if (token != null) '--token=$token',
    ],
    project: project,
    account: account,
    serviceAccount: serviceAccount,
  );
  final result = List<Map<String, dynamic>>.from(response['result'] as List);
  return result
      .map<FirebaseApp>(
        (Map<String, dynamic> e) =>
            FirebaseApp.fromJson(Map<String, dynamic>.from(e)),
      )
      .toList();
}

class FirebaseAppSdkConfig {
  FirebaseAppSdkConfig({
    required this.fileName,
    required this.fileContents,
  });
  final String fileName;
  final String fileContents;
}

/// Get registered Firebase apps for a project.
Future<FirebaseAppSdkConfig> getAppSdkConfig({
  required String appId,
  required String platform,
  String? account,
  String? token,
  String? serviceAccount,
}) async {
  final platformFirebase = platform == kMacos ? kIos : platform;
  _assertFirebaseSupportedPlatform(platformFirebase);
  final response = await runFirebaseCommand(
    [
      'apps:sdkconfig',
      platformFirebase,
      appId,
      if (token != null) '--token=$token',
    ],
    account: account,
    serviceAccount: serviceAccount,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  final fileContents = result['fileContents'] as String;
  final fileName = result['fileName'] as String;
  return FirebaseAppSdkConfig(
    fileName: fileName,
    fileContents: fileContents,
  );
}

void _assertFirebaseSupportedPlatform(String platformIdentifier) {
  if (![kAndroid, kWeb, kIos].contains(platformIdentifier)) {
    throw FirebasePlatformNotSupportedException(platformIdentifier);
  }
}

Future<FirebaseApp> findOrCreateFirebaseApp({
  required String platform,
  required String displayName,
  required String project,
  String? packageNameOrBundleIdentifier,
  String? account,
  String? token,
  String? serviceAccount,
  // used for web and windows.
  String? webAppId,
}) async {
  var foundFirebaseApp = false;
  final displayNameWithPlatform = '$displayName ($platform)';
  var platformFirebase = platform;
  if (platformFirebase == kMacos) platformFirebase = kIos;
  if (platformFirebase == kWindows) platformFirebase = kWeb;
  if (platformFirebase == kLinux) platformFirebase = kWeb;

  _assertFirebaseSupportedPlatform(platformFirebase);
  final fetchingAppsSpinner = spinner(
    (done) {
      final loggingAppName =
          packageNameOrBundleIdentifier ?? webAppId ?? displayNameWithPlatform;
      if (!done) {
        return AnsiStyles.bold(
          'Fetching registered ${AnsiStyles.cyan(platform)} Firebase apps for project ${AnsiStyles.cyan(project)}',
        );
      }
      if (!foundFirebaseApp) {
        return AnsiStyles.bold(
          'Firebase ${AnsiStyles.cyan(platform)} app ${AnsiStyles.cyan(loggingAppName)} is not registered on Firebase project ${AnsiStyles.cyan(project)}.',
        );
      }
      return AnsiStyles.bold(
        'Firebase ${AnsiStyles.cyan(platform)} app ${AnsiStyles.cyan(loggingAppName)} registered.',
      );
    },
  );
  final unfilteredFirebaseApps = await getApps(
    project: project,
    account: account,
    platform: platformFirebase,
    token: token,
    serviceAccount: serviceAccount,
  );

  Iterable<FirebaseApp> filteredFirebaseApps;

  if (platform == kWeb || platform == kWindows) {
    if (webAppId != null) {
      final flagOption = platform == kWeb ? kWebAppIdFlag : kWindowsAppIdFlag;
      // Find provided web app id for web and windows, otherwise, throw Exception that it doesn't exist
      final webApp = unfilteredFirebaseApps.firstWhere(
        (firebaseApp) => firebaseApp.appId == webAppId,
        orElse: () {
          fetchingAppsSpinner.done();
          throw Exception(
            'The $flagOption: $webAppId provided does not match the web app id of any existing Firebase app.',
          );
        },
      );
      foundFirebaseApp = true;
      fetchingAppsSpinner.done();
      return webApp;
    }
    // Find web app for web and windows using display name with this signature: "flutter_app_name (platform)
    filteredFirebaseApps = unfilteredFirebaseApps.where(
      (firebaseApp) {
        if (firebaseApp.displayName == displayNameWithPlatform) {
          return true;
        }
        return false;
      },
    );
    // Find any for that platform if no web app found with display name
    if (filteredFirebaseApps.isEmpty) {
      filteredFirebaseApps = unfilteredFirebaseApps.where(
        (firebaseApp) {
          return firebaseApp.platform == platform;
        },
      );
    }
  } else {
    filteredFirebaseApps = unfilteredFirebaseApps.where(
      (firebaseApp) {
        if (packageNameOrBundleIdentifier != null) {
          return firebaseApp.packageNameOrBundleIdentifier ==
                  packageNameOrBundleIdentifier &&
              firebaseApp.platform == platformFirebase;
        }
        return false;
      },
    );
  }

  foundFirebaseApp = filteredFirebaseApps.isNotEmpty;
  fetchingAppsSpinner.done();
  if (foundFirebaseApp) {
    return filteredFirebaseApps.first;
  }

  // Existing app not found so we need to create it.
  Future<FirebaseApp> createFirebaseAppFuture;
  switch (platformFirebase) {
    case kAndroid:
      createFirebaseAppFuture = createAndroidApp(
        project: project,
        displayName: displayNameWithPlatform,
        packageName: packageNameOrBundleIdentifier!,
        account: account,
        token: token,
        serviceAccount: serviceAccount,
      );
      break;
    case kIos:
      createFirebaseAppFuture = createAppleApp(
        project: project,
        displayName: displayNameWithPlatform,
        bundleId: packageNameOrBundleIdentifier!,
        account: account,
        token: token,
        serviceAccount: serviceAccount,
      );
      break;
    case kWeb:
      // This is used to also create windows app, Firebase has no concept of a windows app
      createFirebaseAppFuture = createWebApp(
        project: project,
        displayName: displayNameWithPlatform,
        account: account,
        token: token,
        serviceAccount: serviceAccount,
      );
      break;
    default:
      throw FlutterPlatformNotSupportedException(platform);
  }

  final creatingAppSpinner = spinner(
    (done) {
      if (!done) {
        return AnsiStyles.bold(
          'Registering new Firebase ${AnsiStyles.cyan(platform)} app on Firebase project ${AnsiStyles.cyan(project)}.',
        );
      }
      return AnsiStyles.bold(
        'Registered a new Firebase ${AnsiStyles.cyan(platform)} app on Firebase project ${AnsiStyles.cyan(project)}.',
      );
    },
  );
  final firebaseApp = await createFirebaseAppFuture;
  creatingAppSpinner.done();
  return firebaseApp;
}

/// Create a new web [FirebaseApp].
Future<FirebaseApp> createWebApp({
  required String project,
  required String displayName,
  String? account,
  String? token,
  String? serviceAccount,
}) async {
  final response = await runFirebaseCommand(
    ['apps:create', 'web', displayName, if (token != null) '--token=$token'],
    project: project,
    account: account,
    serviceAccount: serviceAccount,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseApp.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'platform': kWeb,
  });
}

/// Create a new android [FirebaseApp].
Future<FirebaseApp> createAndroidApp({
  required String project,
  required String displayName,
  required String packageName,
  String? account,
  String? token,
  String? serviceAccount,
}) async {
  final response = await runFirebaseCommand(
    [
      'apps:create',
      'android',
      displayName,
      '--package-name=$packageName',
      if (token != null) '--token=$token',
    ],
    project: project,
    account: account,
    serviceAccount: serviceAccount,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseApp.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'platform': kAndroid,
  });
}

/// Create a new iOS or macOS [FirebaseApp].
Future<FirebaseApp> createAppleApp({
  required String project,
  required String displayName,
  required String bundleId,
  String? account,
  String? token,
  String? serviceAccount,
}) async {
  final response = await runFirebaseCommand(
    [
      'apps:create',
      'ios',
      displayName,
      '--bundle-id=$bundleId',
      if (token != null) '--token=$token',
    ],
    project: project,
    account: account,
    serviceAccount: serviceAccount,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseApp.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'platform': kIos,
  });
}

Future<String> getAccessToken() async {
  // Use refresh token to get access token, cannot simply use access token found in "firebase-tools.json"
  final homeDir = Platform.isWindows
      ? Platform.environment['UserProfile']!
      : Platform.environment['HOME']!;
  // Path to 'firebase-tools.json'
  final configPath =
      path.join(homeDir, '.config', 'configstore', 'firebase-tools.json');
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    throw Exception(
      'Failed to find "firebase-tools.json" file, it should be located at "$configPath',
    );
  }
  final map = await configFile.readAsString();
  final configJson = jsonDecode(map) as Map<String, dynamic>;
  final tokens = configJson['tokens'] as Map<String, dynamic>;
  final refreshToken = tokens['refresh_token'] as String;

  final response = await http.post(
    Uri.parse('https://oauth2.googleapis.com/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    // Values for obtaining the access token are taken from the Firebase CLI source code: https://github.com/firebase/firebase-tools/blob/b14b5f38fe23da6543778a588811b0e2391427c0/src/api.ts#L18
    body:
        'grant_type=refresh_token&client_id=563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com&client_secret=j9iVZfS8kkCEFUPaAeJV0sAi&refresh_token=$refreshToken',
  );

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['access_token'] as String;
  } else {
    throw Exception(
      'Failed to obtain an access token for making Firebase Management REST API requests. Status code: ${response.statusCode}. Response body: ${response.body}',
    );
  }
}

// Return string value of "GoogleService-Info.plist" or "google-services.json" file for relevant platform
Future<String> getServiceFileContent(
  String projectId,
  String appId,
  String accessToken,
  String platform,
) async {
  String? uri;

  if (platform == kIos || platform == kMacos) {
    uri =
        'https://firebase.googleapis.com/v1beta1/projects/$projectId/iosApps/$appId/config';
  } else if (platform == kAndroid) {
    uri =
        'https://firebase.googleapis.com/v1beta1/projects/$projectId/androidApps/$appId/config';
  } else {
    throw ServiceFileException(
      platform,
      'Invalid platform: $platform. Use $kIos, $kAndroid or $kMacos to write service file content.',
    );
  }

  final response = await http.get(
    Uri.parse(
      uri,
    ),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final decodedBytes = base64.decode(json['configFileContents'] as String);
    final decodedContent = utf8.decode(decodedBytes);

    return decodedContent;
  } else {
    final serviceFileName = platform == kIos || platform == kMacos
        ? appleServiceFileName
        : androidServiceFileName;
    throw ServiceFileException(
      platform,
      'Failed to obtain the service file: $serviceFileName for $platform. Response code: ${response.statusCode}. Response body: ${response.body}',
    );
  }
}

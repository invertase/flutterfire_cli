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

/// Mirrored from FlutterFire
class FirebaseOptions {
  const FirebaseOptions({
    required this.optionsSourceContent,
    required this.optionsSourceFileName,
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
    this.databaseURL,
    this.storageBucket,
    this.measurementId,
    // ios specific
    this.trackingId,
    this.deepLinkURLScheme,
    this.androidClientId,
    this.iosClientId,
    this.iosBundleId,
    this.appGroupId,
  });

  /// Named constructor to create [FirebaseOptions] from a Map.
  ///
  /// This constructor is used when platforms cannot directly return a
  /// [FirebaseOptions] instance, for example when data is sent back from a
  FirebaseOptions.fromMap(Map<dynamic, dynamic> map)
      : assert(map['apiKey'] != null, "'apiKey' cannot be null."),
        assert(map['appId'] != null, "'appId' cannot be null."),
        assert(
          map['messagingSenderId'] != null,
          "'messagingSenderId' cannot be null.",
        ),
        assert(map['projectId'] != null, "'projectId' cannot be null."),
        apiKey = map['apiKey'] as String,
        appId = map['appId'] as String,
        messagingSenderId = map['messagingSenderId'] as String,
        projectId = map['projectId'] as String,
        authDomain = map['authDomain'] as String?,
        databaseURL = map['databaseURL'] as String?,
        storageBucket = map['storageBucket'] as String?,
        measurementId = map['measurementId'] as String?,
        trackingId = map['trackingId'] as String?,
        deepLinkURLScheme = map['deepLinkURLScheme'] as String?,
        androidClientId = map['androidClientId'] as String?,
        iosClientId = map['iosClientId'] as String?,
        iosBundleId = map['iosBundleId'] as String?,
        appGroupId = map['appGroupId'] as String?,
        optionsSourceContent = const JsonEncoder().convert(map),
        optionsSourceFileName = 'firebase-options.json';

  /// An API key used for authenticating requests from your app, for example
  /// "AIxxxxxxxxxxxxxxxxxxxxxxDk", used to identify your app to
  /// Google servers.
  final String apiKey;

  /// The Google App ID that is used to uniquely identify an instance of an app.
  final String appId;

  /// The unique sender ID value used in messaging to identify your app.
  final String messagingSenderId;

  /// The Project ID from the Firebase console, for example "my-awesome-app".
  final String projectId;

  /// The auth domain used to handle redirects from OAuth provides on web
  /// platforms, for example "my-awesome-app.firebaseapp.com".
  final String? authDomain;

  /// The database root URL, for example "https://my-awesome-app.firebaseio.com."
  ///
  /// This property should be set for apps that use Firebase Database.
  final String? databaseURL;

  /// The Google Cloud Storage bucket name, for example
  /// "my-awesome-app.appspot.com".
  final String? storageBucket;

  /// The project measurement ID value used on web platforms with analytics.
  final String? measurementId;

  /// The tracking ID for Google Analytics, for example "UA-12345678-1", used to
  /// configure Google Analytics.
  ///
  /// This property is used on iOS only.
  final String? trackingId;

  /// The URL scheme used by iOS secondary apps for Dynamic Links.
  final String? deepLinkURLScheme;

  /// The Android client ID from the Firebase Console, for example
  /// "12345.apps.googleusercontent.com."
  ///
  /// This value is used by android only.
  final String? androidClientId;

  /// The iOS client ID from the Firebase Console, for example
  /// "12345.apps.googleusercontent.com."
  ///
  /// This value is used by iOS only.
  final String? iosClientId;

  /// The iOS bundle ID for the application. Defaults to `[[NSBundle mainBundle] bundleID]`
  /// when not set manually or in a plist.
  ///
  /// This property is used on iOS only.
  final String? iosBundleId;

  /// The iOS App Group identifier to share data between the application and the
  /// application extensions.
  ///
  /// Note that if using this then the App Group must be configured in the
  /// application and on the Apple Developer Portal.
  ///
  /// This property is used on iOS only.
  final String? appGroupId;

  /// The source content that the options were retreived from, e.g.
  /// for Android this is content of the `google-services.json` file.
  final String optionsSourceContent;

  /// The source content file name that the options were retreived from, e.g.
  /// for Android this is `google-services.json`.
  final String optionsSourceFileName;

  /// The current instance as a [Map].
  Map<String, String?> get asMap {
    return <String, String?>{
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'authDomain': authDomain,
      'databaseURL': databaseURL,
      'storageBucket': storageBucket,
      'measurementId': measurementId,
      'trackingId': trackingId,
      'deepLinkURLScheme': deepLinkURLScheme,
      'androidClientId': androidClientId,
      'iosClientId': iosClientId,
      'iosBundleId': iosBundleId,
      'appGroupId': appGroupId,
    };
  }

  @override
  String toString() => asMap.toString();
}

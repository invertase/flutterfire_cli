import 'package:ansi_styles/ansi_styles.dart';

import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../flutter_app.dart';
import 'firebase_app.dart';
import 'firebase_options.dart';

class FirebaseAndroidOptions {
  FirebaseAndroidOptions(this.applicationId, this.options);

  final FirebaseOptions options;

  final String applicationId;

  static Future<FirebaseAndroidOptions> forFlutterApp(
    FlutterApp flutterApp, {
    String? androidApplicationId,
    required String firebaseProjectId,
    String? firebaseAccount,
  }) async {
    var selectedAndroidApplicationId =
        androidApplicationId ?? flutterApp.androidApplicationId;
    selectedAndroidApplicationId ??= promptInput(
      "Which Android application id (or package name) do you want to use for this configuration, e.g. 'com.example.app'?",
      defaultValue: selectedAndroidApplicationId,
    );

    final firebaseApp = await firebase.findOrCreateFirebaseApp(
      packageNameOrBundleIdentifier: selectedAndroidApplicationId,
      displayName: flutterApp.package.pubSpec.name ?? 'FlutterFire App',
      platformIdentifier: kAndroid,
      project: firebaseProjectId,
      firebaseAccount: firebaseAccount,
    );
    print(firebaseApp);
    return FirebaseAndroidOptions(
      '',
      FirebaseOptions(
        apiKey: '',
        appId: '',
        projectId: '',
        messagingSenderId: '',
      ),
    );
  }
}

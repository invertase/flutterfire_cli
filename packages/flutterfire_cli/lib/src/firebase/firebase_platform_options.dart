import '../common/utils.dart';
import '../flutter_app.dart';
import 'firebase_android_options.dart';
import 'firebase_apple_options.dart';
import 'firebase_dart_options.dart';
import 'firebase_options.dart';

class FirebasePlatformOptions {
  FirebasePlatformOptions({
    required FlutterApp flutterApp,
    required String firebaseProjectId,
    required bool windows,
    required bool linux,
    required bool web,
    required bool ios,
    required bool macos,
    required bool android,
    String? firebaseAccount,
    String? webAppId,
    String? androidApplicationId,
    String? iosBundleId,
    String? macosBundleId,
    String? token,
  })  : _flutterApp = flutterApp,
        _androidApplicationId = androidApplicationId,
        _firebaseProjectId = firebaseProjectId,
        _firebaseAccount = firebaseAccount,
        _iosBundleId = iosBundleId,
        _macosBundleId = macosBundleId,
        _webAppId = webAppId,
        _windows = windows,
        _linux = linux,
        _web = web,
        _ios = ios,
        _macos = macos,
        _android = android,
        _token = token;

  // Private inputs
  final FlutterApp _flutterApp;
  final String? _androidApplicationId;
  final String? _iosBundleId;
  final String? _macosBundleId;
  final String? _firebaseAccount;
  final String _firebaseProjectId;
  final String? _webAppId;
  final bool _windows;
  final bool _linux;
  final bool _web;
  final bool _ios;
  final bool _macos;
  final bool _android;
  final String? _token;

  // Public outputs
  FirebaseOptions? androidOptions;
  FirebaseOptions? iosOptions;
  FirebaseOptions? macosOptions;
  FirebaseOptions? webOptions;
  FirebaseOptions? linuxOptions;
  FirebaseOptions? windowsOptions;

  Future<FirebasePlatformOptions> fetch() async {
    if (_android) {
      androidOptions = await FirebaseAndroidOptions.forFlutterApp(
        _flutterApp,
        androidApplicationId: _androidApplicationId,
        firebaseProjectId: _firebaseProjectId,
        firebaseAccount: _firebaseAccount,
        token: _token,
      );
    }

    if (_ios) {
      iosOptions = await FirebaseAppleOptions.forFlutterApp(
        _flutterApp,
        appleBundleIdentifier: _iosBundleId,
        firebaseProjectId: _firebaseProjectId,
        firebaseAccount: _firebaseAccount,
        token: _token,
      );
    }
    if (_macos) {
      macosOptions = await FirebaseAppleOptions.forFlutterApp(
        _flutterApp,
        appleBundleIdentifier: _macosBundleId,
        firebaseProjectId: _firebaseProjectId,
        firebaseAccount: _firebaseAccount,
        macos: true,
        token: _token,
      );
    }

    if (_web) {
      webOptions = await FirebaseDartOptions.forFlutterApp(
        _flutterApp,
        firebaseProjectId: _firebaseProjectId,
        firebaseAccount: _firebaseAccount,
        webAppId: _webAppId,
        token: _token,
      );
    }

    if (_windows) {
      windowsOptions = await FirebaseDartOptions.forFlutterApp(
        _flutterApp,
        firebaseProjectId: _firebaseProjectId,
        firebaseAccount: _firebaseAccount,
        platform: kWindows,
        token: _token,
      );
    }

    if (_linux) {
      linuxOptions = await FirebaseDartOptions.forFlutterApp(
        _flutterApp,
        firebaseProjectId: _firebaseProjectId,
        firebaseAccount: _firebaseAccount,
        platform: kLinux,
        token: _token,
      );
    }

    return this;
  }
}
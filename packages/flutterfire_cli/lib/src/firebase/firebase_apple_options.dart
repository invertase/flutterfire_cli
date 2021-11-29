import '../flutter_app.dart';
import 'firebase_options.dart';

class FirebaseAppleOptions {
  FirebaseAppleOptions(this.bundleIdentifier, this.options);

  final FirebaseOptions options;

  final String bundleIdentifier;

  static Future<FirebaseAppleOptions> forFlutterIosApp(
    FlutterApp flutterApp,
  ) async {
    // TODO
    return FirebaseAppleOptions(
      'TODO',
      const FirebaseOptions(
        apiKey: '',
        appId: '',
        projectId: '',
        messagingSenderId: '',
      ),
    );
  }

  static Future<FirebaseAppleOptions> forFlutterMacosApp(
    FlutterApp flutterApp,
  ) async {
    // TODO
    return FirebaseAppleOptions(
      'TODO',
      const FirebaseOptions(
        apiKey: '',
        appId: '',
        projectId: '',
        messagingSenderId: '',
      ),
    );
  }
}

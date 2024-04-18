import 'package:path/path.dart' as path;

import '../strings.dart';
import '../utils.dart';

String getAndroidServiceFile({
  required String serviceFilePath,
  required String flutterAppPath,
}) {
  final segments = removeForwardBackwardSlash(serviceFilePath).split('/');
  // Path should have the signature:
  // android/app/google-services.json
  // android/app/development
  // android/app
  if (segments[0] == 'android' &&
      segments[1] == 'app' &&
      (segments.last == androidServiceFileName ||
          !segments.last.contains('.'))) {
    if (segments.last == androidServiceFileName) {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(serviceFilePath),
      );
    } else {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(serviceFilePath),
        androidServiceFileName,
      );
    }
  } else {
    if (isCI) {
      throw ValidationException(
        kAndroid,
        'The path: $serviceFilePath is not a valid path for the Android `google-services.json` file. Please re-run the command with a valid path.',
      );
    }
    // Prompt for service file path
    final promptedServiceFilePath = promptInput(
      'Enter a path for your android "$androidServiceFileName" file ("$kAndroidOutFlag" flag.) relative to the root of your Flutter project. Example input: android/app/staging/$androidServiceFileName',
      validator: (String x) {
        final segments = removeForwardBackwardSlash(x).split('/');

        if (segments[0] == 'android' && segments[1] == 'app') {
          final last = segments.last;

          if (!last.contains('.')) {
            // Just path, no file name
            return true;
          } else {
            if (last == androidServiceFileName) {
              return true;
            } else {
              return 'The file name must be "$androidServiceFileName"';
            }
          }
        } else {
          return 'The path must start with `android/app`. See documentation for more information: https://firebase.google.com/docs/projects/multiprojects';
        }
      },
    );

    if (path.basename(promptedServiceFilePath) == androidServiceFileName) {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(promptedServiceFilePath),
      );
    } else {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(promptedServiceFilePath),
        androidServiceFileName,
      );
    }
  }
}

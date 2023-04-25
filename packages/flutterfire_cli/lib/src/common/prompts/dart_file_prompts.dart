import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

String getFirebaseConfigurationFile({
  required String configurationFilePath,
  required String flutterAppPath,
}) {
  final segments = removeForwardBackwardSlash(configurationFilePath).split('/');

  if (segments.last.contains('.dart')) {
    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(configurationFilePath),
    );
  } else {
    final configurationFilePath = promptInput(
      'Enter a path for your FirebaseOptions file. It must be to a dart file. Example input: lib/firebase_options.dart',
      validator: (String x) {
        final segments = removeForwardBackwardSlash(x).split('/');

        if (segments.last.contains('.dart')) {
          return true;
        } else {
          return 'The path must be to a dart file. Example input: lib/firebase_options.dart';
        }
      },
    );

    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(configurationFilePath),
    );
  }
}

bool promptWriteConfigurationFile({
  required String configurationFilePath,
}) {
  final outputFile = File(configurationFilePath);
  final fileExists = outputFile.existsSync();

  if (!fileExists || isCI) {
    return true;
  } else {
    final shouldOverwrite = promptBool(
      'Generated FirebaseOptions file ${AnsiStyles.cyan(configurationFilePath)} already exists, do you want to override it?',
    );

    return shouldOverwrite;
  }
}

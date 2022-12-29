import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;

import '../common/strings.dart';
import '../common/utils.dart';
import '../firebase/firebase_options.dart';

import '../flutter_app.dart';

class FirebaseIOSSetup {
  FirebaseIOSSetup(
    this.iosOptions,
    this.flutterApp,
    this.fulliOSServicePath,
    this.iosServiceFilePath,
    this.logger,
    this.generateDebugSymbolScript,
    this.scheme,
    this.target,
  );

  final FlutterApp? flutterApp;
  final FirebaseOptions iosOptions;
  String? fulliOSServicePath;
  String? iosServiceFilePath;
  final Logger logger;
  final bool generateDebugSymbolScript;
// This allows us to update to the required "GoogleService-Info.plist" file name for iOS target or scheme writes.
  String? updatedIOSServiceFilePath;
  String? scheme;
  String? target;

  String get xcodeProjFilePath {
    return path.join(flutterApp!.iosDirectory.path, 'Runner.xcodeproj');
  }

  Future<void> apply() async {
    final googleServiceInfoFile = path.join(
      flutterApp!.iosDirectory.path,
      'Runner',
      iosOptions.optionsSourceFileName,
    );

    File file;
    // If "iosServiceFilePath" exists, we use a different configuration from Runner/GoogleService-Info.plist setup
    if (fulliOSServicePath != null) {
      final googleServiceFileName = path.basename(iosServiceFilePath!);

      if (googleServiceFileName != 'GoogleService-Info.plist') {
        final response = promptBool(
          'The file name must be "GoogleService-Info.plist" if you\'re bundling with your iOS target or scheme. Do you want to change filename to "GoogleService-Info.plist"?',
        );

        // Change filename to "GoogleService-Info.plist" if user wants to, it is required for target or scheme setup
        if (response == true) {
          iosServiceFilePath = path.join(
            path.dirname(iosServiceFilePath!),
            'GoogleService-Info.plist',
          );

          fulliOSServicePath =
              '${flutterApp!.package.path}${iosServiceFilePath!}';
        }
      }
      // Create new directory for file output if it doesn't currently exist
      await Directory(path.dirname(fulliOSServicePath!))
          .create(recursive: true);

      file = File(fulliOSServicePath!);
    } else {
      file = File(googleServiceInfoFile);
    }

    if (!file.existsSync()) {
      await file.writeAsString(iosOptions.optionsSourceContent);
    }

    if (Platform.isMacOS) {
      if (fulliOSServicePath != null) {
        if (scheme != null) {
          final schemes = await findSchemesAvailable(xcodeProjFilePath);

          final schemeExists = schemes.contains(scheme);

          if (schemeExists) {
            await writeSchemeScriptToProject(
              xcodeProjFilePath,
              iosServiceFilePath!,
              scheme!,
              logger,
            );
            await writeDebugSymbolScriptForScheme(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              iosOptions.appId,
              logger,
              scheme!,
              'iOS',
            );
          } else {
            throw MissingFromXcodeProjectException(
              'iOS',
              'scheme',
              scheme!,
              schemes,
            );
          }
        } else if (target != null) {
          final targets = await findTargetsAvailable(xcodeProjFilePath);

          final targetExists = targets.contains(target);

          if (targetExists) {
            await writeToTargetProject(
              xcodeProjFilePath,
              fulliOSServicePath!,
              target!,
            );

            await writeDebugSymbolScriptForTarget(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              iosOptions.appId,
              logger,
              target!,
              'iOS',
            );
          } else {
            throw MissingFromXcodeProjectException(
              'iOS',
              'target',
              target!,
              targets,
            );
          }
        } else {
          // We need to prompt user whether they want a scheme configured, target configured or to simply write to the path provided
          final fileName = path.basename(fulliOSServicePath!);
          final response = promptSelect(
            'Would you like your iOS $fileName to be associated with your iOS Scheme or Target (use arrow keys & space to select)?',
            [
              'Scheme',
              'Target',
              'No, I want to write the file to the path I chose'
            ],
          );

          // Add to scheme
          if (response == 0) {
            final schemes = await findSchemesAvailable(xcodeProjFilePath);

            final response = promptSelect(
              'Which scheme would you like your iOS $fileName to be included within your iOS app bundle?',
              schemes,
            );
            await writeSchemeScriptToProject(
              xcodeProjFilePath,
              iosServiceFilePath!,
              schemes[response],
              logger,
            );
            await writeDebugSymbolScriptForScheme(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              iosOptions.appId,
              logger,
              schemes[response],
              'iOS',
            );

            // Add to target
          } else if (response == 1) {
            final targets = await findTargetsAvailable(xcodeProjFilePath);

            final response = promptSelect(
              'Which target would you like your iOS $fileName to be included within your iOS app bundle?',
              targets,
            );
            await writeToTargetProject(
              xcodeProjFilePath,
              fulliOSServicePath!,
              targets[response],
            );
            await writeDebugSymbolScriptForTarget(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              iosOptions.appId,
              logger,
              targets[response],
              'iOS',
            );
          }
        }
      } else {
        // Continue to write file to Runner/GoogleService-Info.plist if no "iosServiceFilePath" is provided
        final rubyScript = addServiceFileToRunnerScript(
          googleServiceInfoFile,
          xcodeProjFilePath,
        );

        final result = await Process.run('ruby', [
          '-e',
          rubyScript,
        ]);

        if (result.exitCode != 0) {
          throw Exception(result.stderr);
        }

        await writeDebugSymbolScriptForTarget(
          generateDebugSymbolScript,
          xcodeProjFilePath,
          iosOptions.appId,
          logger,
          'Runner',
          'iOS',
        );
      }
    }
  }
}

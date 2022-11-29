import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;

import '../common/strings.dart';
import '../common/utils.dart';
import '../firebase/firebase_options.dart';

import '../flutter_app.dart';

class FirebaseMacOSSetup {
  FirebaseMacOSSetup(
    this.macosOptions,
    this.flutterApp,
    this.fullMacOSServicePath,
    this.macosServiceFilePath,
    this.updatedMacOSServiceFilePath,
    this.logger,
    this.generateDebugSymbolScript,
  );

  final FlutterApp? flutterApp;
  final FirebaseOptions macosOptions;
  final String? fullMacOSServicePath;
  final String? macosServiceFilePath;
  final Logger logger;
  final bool generateDebugSymbolScript;
// This allows us to update to the required "GoogleService-Info.plist" file name for iOS target or scheme writes.
  String? updatedMacOSServiceFilePath;

  Future<void> apply() async {
    final googleServiceInfoFile = path.join(
      flutterApp!.macosDirectory.path,
      'Runner',
      macosOptions.optionsSourceFileName,
    );

    File file;

    // If "macosServiceFilePath" exists, we use a different configuration from Runner/GoogleService-Info.plist setup
    if (fullMacOSServicePath != null) {
      final googleServiceFileName = path.basename(fullMacOSServicePath!);

      if (googleServiceFileName != 'GoogleService-Info.plist') {
        final response = promptBool(
          'The file name must be "GoogleService-Info.plist" if you\'re bundling with your macOS target or scheme. Do you want to change filename to "GoogleService-Info.plist"?',
        );

        // Change filename to "GoogleService-Info.plist" if user wants to, it is required for target or scheme setup
        if (response == true) {
          updatedMacOSServiceFilePath = path.join(
            path.dirname(macosServiceFilePath!),
            'GoogleService-Info.plist',
          );
        }
      }
      // Create new directory for file output if it doesn't currently exist
      await Directory(path.dirname(fullMacOSServicePath!))
          .create(recursive: true);

      file = File(fullMacOSServicePath!);
    } else {
      file = File(googleServiceInfoFile);
    }

    if (!file.existsSync()) {
      await file.writeAsString(macosOptions.optionsSourceContent);
    }

    final xcodeProjFilePath =
        path.join(flutterApp!.macosDirectory.path, 'Runner.xcodeproj');

    if (Platform.isMacOS) {
      // We need to prompt user whether they want a scheme configured, target configured or to simply write to the path provided
      if (fullMacOSServicePath != null) {
        final fileName = path.basename(fullMacOSServicePath!);
        final response = promptSelect(
          'Would you like your macOS $fileName to be associated with your macOS Scheme or Target (use arrow keys & space to select)?',
          [
            'Scheme',
            'Target',
            'No, I want to write the file to the path I chose'
          ],
        );

        // Add to scheme
        if (response == 0) {
          // Find the schemes available on the project
          final schemeScript = findingSchemesScript(xcodeProjFilePath);

          final result = await Process.run('ruby', [
            '-e',
            schemeScript,
          ]);

          if (result.exitCode != 0) {
            throw Exception(result.stderr);
          }
          // Retrieve the schemes to prompt the user to select one
          final schemes = (result.stdout as String).split(',');

          final response = promptSelect(
            'Which scheme would you like your macOS $fileName to be included within the macOS app bundle?',
            schemes,
          );

          final runScriptName =
              '[firebase_core] add Firebase configuration to "${schemes[response]}" scheme';
          // Create bash script for adding Google service file to app bundle
          final addBuildPhaseScript = addServiceFileToSchemeScript(
            xcodeProjFilePath,
            schemes[response],
            runScriptName,
            removeForwardSlash(macosServiceFilePath!),
          );

          // Add script to Build Phases in Xcode project
          final resultBuildPhase = await Process.run('ruby', [
            '-e',
            addBuildPhaseScript,
          ]);

          if (resultBuildPhase.exitCode != 0) {
            throw Exception(resultBuildPhase.stderr);
          }

          if (resultBuildPhase.stdout != null) {
            logger.stdout(resultBuildPhase.stdout as String);
          }

          if (generateDebugSymbolScript) {
            await writeDebugScriptForScheme(
              xcodeProjFilePath,
              macosOptions.appId,
              schemes[response],
              logger,
            );
          } else {
            final addSymbolScript = promptBool(
              "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your macOS project's '${schemes[response]}' scheme?",
            );

            if (addSymbolScript == true) {
              await writeDebugScriptForScheme(
                xcodeProjFilePath,
                macosOptions.appId,
                schemes[response],
                logger,
              );
            } else {
              logger.stdout(
                logSkippingDebugSymbolScript,
              );
            }
          }

          // Add to target
        } else if (response == 1) {
          final targetScript = findingTargetsScript(xcodeProjFilePath);

          final result = await Process.run('ruby', [
            '-e',
            targetScript,
          ]);

          if (result.exitCode != 0) {
            throw Exception(result.stderr);
          }
          // Retrieve the targets to prompt the user to select one
          final targets = (result.stdout as String).split(',');

          final response = promptSelect(
            'Which target would you like your macOS $fileName to be included within your macOS app bundle?',
            targets,
          );

          final addServiceFileToTargetScript = addServiceFileToTarget(
            xcodeProjFilePath,
            fullMacOSServicePath!,
            targets[response],
          );

          final resultServiceFileToTarget = await Process.run('ruby', [
            '-e',
            addServiceFileToTargetScript,
          ]);

          if (resultServiceFileToTarget.exitCode != 0) {
            throw Exception(resultServiceFileToTarget.stderr);
          }

          if (generateDebugSymbolScript) {
            await writeDebugScriptForTarget(
              xcodeProjFilePath,
              macosOptions.appId,
              targets[response],
              logger,
            );
          } else {
            final addSymbolScript = promptBool(
              "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your macOS project's '${targets[response]}' target?",
            );

            if (addSymbolScript == true) {
              await writeDebugScriptForTarget(
                xcodeProjFilePath,
                macosOptions.appId,
                targets[response],
                logger,
              );
            } else {
              logger.stdout(
                logSkippingDebugSymbolScript,
              );
            }
          }
        }
      } else {
        // Continue to write file to Runner/GoogleService-Info.plist if no "macosServiceFilePath" is provided
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

        if (generateDebugSymbolScript) {
          await writeDebugScriptForTarget(
            xcodeProjFilePath,
            macosOptions.appId,
            'Runner',
            logger,
          );
        } else {
          final addSymbolScript = promptBool(
            "Do you want an 'upload Crashlytic's debug symbols script' adding to the build phases of your macOS project's 'Runner' target?",
          );
          if (addSymbolScript == true) {
            await writeDebugScriptForTarget(
              xcodeProjFilePath,
              macosOptions.appId,
              'Runner',
              logger,
            );
          } else {
            logger.stdout(
              logSkippingDebugSymbolScript,
            );
          }
        }
      }
    }
  }
}
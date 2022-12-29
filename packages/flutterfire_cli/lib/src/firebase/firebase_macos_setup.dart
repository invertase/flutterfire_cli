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
    this.logger,
    this.generateDebugSymbolScript,
    this.scheme,
    this.target,
  );

  final FlutterApp? flutterApp;
  final FirebaseOptions macosOptions;
  String? fullMacOSServicePath;
  String? macosServiceFilePath;
  final Logger logger;
  final bool generateDebugSymbolScript;
  String? scheme;
  String? target;

  String get xcodeProjFilePath {
    return path.join(flutterApp!.macosDirectory.path, 'Runner.xcodeproj');
  }

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
          macosServiceFilePath = path.join(
            path.dirname(macosServiceFilePath!),
            'GoogleService-Info.plist',
          );
          fullMacOSServicePath =
              '${flutterApp!.package.path}${macosServiceFilePath!}';
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

    if (Platform.isMacOS) {
      // We need to prompt user whether they want a scheme configured, target configured or to simply write to the path provided
      if (fullMacOSServicePath != null) {
        if (scheme != null) {
          final schemes = await findSchemesAvailable(xcodeProjFilePath);

          final schemeExists = schemes.contains(scheme);

          if (schemeExists) {
            await writeSchemeScriptToProject(
              xcodeProjFilePath,
              macosServiceFilePath!,
              scheme!,
              logger,
            );
            await writeDebugSymbolScriptForScheme(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              macosOptions.appId,
              logger,
              scheme!,
              'macOS',
            );
          } else {
            throw MissingFromXcodeProjectException(
              'macOS',
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
              fullMacOSServicePath!,
              target!,
            );

            await writeDebugSymbolScriptForTarget(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              macosOptions.appId,
              logger,
              target!,
              'macOS',
            );
          } else {
            throw MissingFromXcodeProjectException(
              'macOS',
              'target',
              target!,
              targets,
            );
          }
        } else {
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
            final schemes = await findSchemesAvailable(xcodeProjFilePath);

            final response = promptSelect(
              'Which scheme would you like your macOS $fileName to be included within the macOS app bundle?',
              schemes,
            );

            await writeSchemeScriptToProject(
              xcodeProjFilePath,
              macosServiceFilePath!,
              schemes[response],
              logger,
            );
            await writeDebugSymbolScriptForScheme(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              macosOptions.appId,
              logger,
              schemes[response],
              'macOS',
            );

            // Add to target
          } else if (response == 1) {
            final targets = await findTargetsAvailable(xcodeProjFilePath);

            final response = promptSelect(
              'Which target would you like your macOS $fileName to be included within your macOS app bundle?',
              targets,
            );

            await writeToTargetProject(
              xcodeProjFilePath,
              fullMacOSServicePath!,
              targets[response],
            );
            await writeDebugSymbolScriptForTarget(
              generateDebugSymbolScript,
              xcodeProjFilePath,
              macosOptions.appId,
              logger,
              targets[response],
              'macOS',
            );
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

        await writeDebugSymbolScriptForTarget(
          generateDebugSymbolScript,
          xcodeProjFilePath,
          macosOptions.appId,
          logger,
          'Runner',
          'macOS',
        );
      }
    }
  }
}

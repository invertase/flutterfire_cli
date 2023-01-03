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
    this.relativeiOSServiceFilePath,
    this.logger,
    this.generateDebugSymbolScript,
    this.scheme,
    this.target,
  );

  final FlutterApp? flutterApp;
  final FirebaseOptions iosOptions;
  String? fulliOSServicePath;
  String? relativeiOSServiceFilePath;
  final Logger logger;
  final bool? generateDebugSymbolScript;
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

    if (scheme != null && fulliOSServicePath == null) {
      // if the user has selected a  scheme but no "ios-out" argument, they need to specify the location of "GoogleService-Info.plist" so it can be used at build time.
      // No need to do the same for target as it is included with bundle resources
      final pathToServiceFile = promptInput(
        'Enter a path for your iOS "GoogleService-Info.plist" ("ios-out" argument.) file in your Flutter project. It is required if you set "ios-scheme" argument. Example input: ios/dev',
        validator: (String x) {
          if (RegExp(r'^(?![#\/.])(?!.*[#\/.]$).*').hasMatch(x) &&
              !path.basename(x).contains('.')) {
            return true;
          } else {
            return 'Do not start or end path with a backslash, nor specify the filename. Example: ios/dev';
          }
        },
      );

      fulliOSServicePath =
          '${flutterApp!.package.path}/$pathToServiceFile/${iosOptions.optionsSourceFileName}';

      relativeiOSServiceFilePath =
          '$pathToServiceFile/${iosOptions.optionsSourceFileName}';

      await Directory(path.dirname(fulliOSServicePath!))
          .create(recursive: true);

      file = File(fulliOSServicePath!);
      // If "iosServiceFilePath" exists, we use a different configuration from Runner/GoogleService-Info.plist setup
    } else if (fulliOSServicePath != null) {
      final googleServiceFileName = path.basename(relativeiOSServiceFilePath!);

      if (googleServiceFileName != iosOptions.optionsSourceFileName) {
        final response = promptBool(
          'The file name must be "${iosOptions.optionsSourceFileName}" if you\'re bundling with your iOS target or scheme. Do you want to change filename to "${iosOptions.optionsSourceFileName}"?',
        );

        // Change filename to "GoogleService-Info.plist" if user wants to, it is required for target or scheme setup
        if (response == true) {
          relativeiOSServiceFilePath = path.join(
            path.dirname(relativeiOSServiceFilePath!),
            iosOptions.optionsSourceFileName,
          );

          fulliOSServicePath =
              '${flutterApp!.package.path}${relativeiOSServiceFilePath!}';
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
              relativeiOSServiceFilePath!,
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
              relativeiOSServiceFilePath!,
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

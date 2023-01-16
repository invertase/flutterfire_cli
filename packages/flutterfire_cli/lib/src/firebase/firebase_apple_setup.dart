import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;

import '../common/strings.dart';
import '../common/utils.dart';
import '../firebase/firebase_options.dart';

import '../flutter_app.dart';

// Use for both macOS & iOS
class FirebaseAppleSetup {
  FirebaseAppleSetup(
    this.platformOptions,
    this.flutterApp,
    this.fullPathToServiceFile,
    this.googleServicePathSpecified,
    this.logger,
    this.generateDebugSymbolScript,
    this.scheme,
    this.target,
    this.platform,
  );
  // Either "iOS" or "macOS"
  final String platform;
  final FlutterApp? flutterApp;
  final FirebaseOptions platformOptions;
  String? fullPathToServiceFile;
  bool googleServicePathSpecified;
  final Logger logger;
  final bool? generateDebugSymbolScript;
// This allows us to update to the required "GoogleService-Info.plist" file name for iOS target or scheme writes.
  String? updatedServiceFilePath;
  String? scheme;
  String? target;

  String get xcodeProjFilePath {
    return path.join(
        Directory.current.path, platform.toLowerCase(), 'Runner.xcodeproj');
  }

  Future<void> _addFlutterFireDebugSymbolsScript(
    String xcodeProjFilePath,
    Logger logger,
    ProjectConfiguration projectConfiguration, {
    String target = 'Runner',
  }) async {
    final paths = _addPathToExecutablesForDebugScript();
    if (paths != null) {
      final debugSymbolScript = await Process.run('ruby', [
        '-e',
        _debugSymbolsScript(
          xcodeProjFilePath,
          target,
          paths,
          projectConfiguration,
        ),
      ]);

      if (debugSymbolScript.exitCode != 0) {
        throw Exception(debugSymbolScript.stderr);
      }

      if (debugSymbolScript.stdout != null) {
        logger.stdout(debugSymbolScript.stdout as String);
      }
    }
  }

  String _debugSymbolsScript(
    String xcodeProjFilePath,
    // Always "Runner" for "scheme" setup
    String target,
    String pathsToExecutables,
    ProjectConfiguration projectConfiguration,
  ) {
    var command =
        r'flutterfire upload-crashlytics-symbols --uploadSymbolsScriptPath=$PODS_ROOT/FirebaseCrashlytics/upload-symbols --debugSymbolsPath=${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME} --infoPlistPath=${SRCROOT}/${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH} --iosProjectPath=${SRCROOT} ';

    switch (projectConfiguration) {
      case ProjectConfiguration.scheme:
        command += r'--scheme=${CONFIGURATION}';
        break;
      case ProjectConfiguration.target:
        command += '--target=$target';
        break;
      case ProjectConfiguration.defaultConfig:
        command += '--defaultConfig=default';
    }

    return '''
require 'xcodeproj'
xcodeFile='$xcodeProjFilePath'
runScriptName='$runScriptName'
project = Xcodeproj::Project.open(xcodeFile)


# multi line argument for bash script
bashScript = %q(
#!/bin/bash
PATH=\${PATH}:$pathsToExecutables
$command
)

for target in project.targets 
  if (target.name == '$target')
    phase = target.shell_script_build_phases().find do |item|
      if defined? item && item.name
        item.name == runScriptName
      end
    end

    if (!phase.nil?)
      phase.remove_from_project()
    end
    
    phase = target.new_shell_script_build_phase(runScriptName)
    phase.shell_script = bashScript
    project.save()   
  end  
end
''';
  }

  final runScriptName = 'FlutterFire: "flutterfire upload-crashlytics-symbols"';

  Future<void> _updateFirebaseJsonFile(
    FlutterApp flutterApp,
    String appId,
    String projectId,
    bool debugSymbolScript,
    String schemeOrTargetName,
    String pathToServiceFile,
    ProjectConfiguration projectConfiguration,
  ) async {
    final file = File('${flutterApp.package.path}/firebase.json');

    final relativePathFromProject =
        path.relative(pathToServiceFile, from: flutterApp.package.path);

    // "schemes", "targets" or "default" property
    final configuration = getProjectConfigurationProperty(projectConfiguration);

    final fileAsString = await file.readAsString();

    final map = jsonDecode(fileAsString) as Map;

    final flutterConfig = map[kFlutter] as Map?;
    final platform = flutterConfig?[kPlatforms] as Map?;
    final iosConfig = platform?[kIos] as Map?;

    final configurationMaps = iosConfig?[configuration] as Map?;

    if (configurationMaps?[schemeOrTargetName] == null) {
      // ignore: implicit_dynamic_map_literal
      configurationMaps?[schemeOrTargetName] = {};
    }

    final configurationMap = configurationMaps?[schemeOrTargetName] as Map;
    configurationMap[kProjectId] = projectId;
    configurationMap[kAppId] = appId;
    configurationMap[kUploadDebugSymbols] = debugSymbolScript;
    configurationMap[kServiceFileOutput] = relativePathFromProject;

    final mapJson = json.encode(map);

    file.writeAsStringSync(mapJson);
  }

  bool _shouldRunUploadDebugSymbolScript(
    bool? generateDebugSymbolScript,
    Logger logger,
  ) {
    // ignore: use_if_null_to_convert_nulls_to_bools
    if (generateDebugSymbolScript == true ||
        generateDebugSymbolScript == false) {
      return generateDebugSymbolScript!;
    } else {
      // Unspecified, so we prompt
      final addSymbolScript = promptBool(
        "Do you want an '$runScriptName' adding to the build phases of your $platform project?",
      );

      if (addSymbolScript == false) {
        logger.stdout(
          logSkippingDebugSymbolScript,
        );
      }
      return addSymbolScript;
    }
  }

  Future<void> _updateFirebaseJsonAndDebugSymbolScript(
    String pathToServiceFile,
    ProjectConfiguration projectConfiguration,
    String targetOrScheme,
  ) async {
    final runDebugSymbolScript = _shouldRunUploadDebugSymbolScript(
      generateDebugSymbolScript,
      logger,
    );

    if (runDebugSymbolScript) {
      await _addFlutterFireDebugSymbolsScript(
        xcodeProjFilePath,
        logger,
        projectConfiguration,
      );
    }

    await _updateFirebaseJsonFile(
      flutterApp!,
      platformOptions.appId,
      platformOptions.projectId,
      runDebugSymbolScript,
      targetOrScheme,
      pathToServiceFile,
      projectConfiguration,
    );
  }

  String? _addPathToExecutablesForDebugScript() {
    final envVars = Platform.environment;
    final paths = envVars['PATH'];
    if (paths != null) {
      final array = paths.split(':');

      final pathsToAddToScript = array.where((path) {
        if (path.contains('dart-sdk') ||
            path.contains('flutter') ||
            path.contains('.pub-cache')) {
          return true;
        }
        return false;
      });

      return pathsToAddToScript.join(':');
    } else {
      logger.stdout(
        noPathVariableFound,
      );
      return null;
    }
  }

  Future<File> _createServiceFileToSpecifiedPath(
    String pathToServiceFile,
  ) async {
    await Directory(path.dirname(pathToServiceFile)).create(recursive: true);

    return File(pathToServiceFile);
  }

  Future<void> _writeGoogleServiceFileToPath(String pathToServiceFile) async {
    final file = await _createServiceFileToSpecifiedPath(pathToServiceFile);

    if (!file.existsSync()) {
      await file.writeAsString(platformOptions.optionsSourceContent);
    } else {
      logger.stdout(serviceFileAlreadyExists);
    }
  }

  String _promptForPathToServiceFile() {
    final pathToServiceFile = promptInput(
      'Enter a path for your $platform "GoogleService-Info.plist" ("${platform.toLowerCase()}-out" argument.) file in your Flutter project. It is required if you set "${platform.toLowerCase()}-scheme" argument. Example input: ${platform.toLowerCase()}/dev',
      validator: (String x) {
        if (RegExp(r'^(?![#\/.])(?!.*[#\/.]$).*').hasMatch(x) &&
            !path.basename(x).contains('.')) {
          return true;
        } else {
          return 'Do not start or end path with a forward slash, nor specify the filename. Example: ${platform.toLowerCase()}/dev';
        }
      },
    );

    return '${flutterApp!.package.path}/$pathToServiceFile/${platformOptions.optionsSourceFileName}';
  }

  Future<void> _createSchemeSetup(String pathToServiceFile) async {
    final schemes = await findSchemesAvailable(xcodeProjFilePath);

    final schemeExists = schemes.contains(scheme);

    if (schemeExists) {
      await _schemeWrites(pathToServiceFile);
    } else {
      throw MissingFromXcodeProjectException(
        platform,
        'scheme',
        scheme!,
        schemes,
      );
    }
  }

  Future<void> _createTargetSetup(String pathToServiceFile) async {
    final targets = await findTargetsAvailable(xcodeProjFilePath);

    final targetExists = targets.contains(target);

    if (targetExists) {
      await _targetWrites(pathToServiceFile);
    } else {
      throw MissingFromXcodeProjectException(
        platform,
        'target',
        target!,
        targets,
      );
    }
  }

  Future<void> _schemeWrites(String pathToServiceFile) async {
    await _writeGoogleServiceFileToPath(pathToServiceFile);
    await writeSchemeScriptToProject(
      xcodeProjFilePath,
      fullPathToServiceFile!,
      scheme!,
      logger,
    );
    await _updateFirebaseJsonAndDebugSymbolScript(
      pathToServiceFile,
      ProjectConfiguration.scheme,
      scheme!,
    );
  }

  Future<void> _targetWrites(String pathToServiceFile) async {
    await _writeGoogleServiceFileToPath(pathToServiceFile);
    await writeGoogleServiceFileToTargetProject(
      xcodeProjFilePath,
      pathToServiceFile,
      target!,
    );

    await _updateFirebaseJsonAndDebugSymbolScript(
      pathToServiceFile,
      ProjectConfiguration.target,
      target!,
    );
  }

  Future<void> apply() async {
    if (!googleServicePathSpecified) {
      // if the user has selected a  scheme but no "[ios-macos]-out" argument, they need to specify the location of "GoogleService-Info.plist" so it can be used at build time.
      fullPathToServiceFile = _promptForPathToServiceFile();

      if (target != null) {
        await _createTargetSetup(fullPathToServiceFile!);
      }
      if (scheme != null) {
        await _createSchemeSetup(fullPathToServiceFile!);
      }
    } else if (googleServicePathSpecified) {
      final googleServiceFileName = path.basename(fullPathToServiceFile!);

      if (googleServiceFileName != platformOptions.optionsSourceFileName) {
        final response = promptBool(
          'The file name must be "${platformOptions.optionsSourceFileName}" if you\'re bundling with your $platform target or scheme. Do you want to change filename to "${platformOptions.optionsSourceFileName}"?',
        );

        // Change filename to "GoogleService-Info.plist" if user wants to, it is required for target or scheme setup
        if (response == true) {
          fullPathToServiceFile =
              '${path.dirname(fullPathToServiceFile!)}/${platformOptions.optionsSourceFileName}';
        }
      }

      if (scheme != null) {
        await _createSchemeSetup(fullPathToServiceFile!);
      } else if (target != null) {
        await _createTargetSetup(fullPathToServiceFile!);
      } else {
        // We need to prompt user whether they want a scheme configured, target configured or to simply write to the path provided
        final fileName = path.basename(fullPathToServiceFile!);
        final response = promptSelect(
          'Would you like your $platform $fileName to be associated with your $platform Scheme or Target (use arrow keys & space to select)?',
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
            'Which scheme would you like your $platform $fileName to be included within your $platform app bundle?',
            schemes,
          );

          scheme = schemes[response];
          await _schemeWrites(fullPathToServiceFile!);

          // Add to target
        } else if (response == 1) {
          final targets = await findTargetsAvailable(xcodeProjFilePath);

          final response = promptSelect(
            'Which target would you like your $platform $fileName to be included within your $platform app bundle?',
            targets,
          );
          target = targets[response];
          await _targetWrites(fullPathToServiceFile!);
        }
      }
    } else {
      // Continue to write file to Runner/GoogleService-Info.plist if no "fullPathToServiceFile", "scheme" and "target" is provided
      // Update "Runner", default target
      final defaultProjectPath =
          '${Directory.current.path}/${platform.toLowerCase()}/Runner/${platformOptions.optionsSourceFileName}';
      // Make target default "Runner"
      target = 'Runner';
      await _targetWrites(defaultProjectPath);
    }
  }
}

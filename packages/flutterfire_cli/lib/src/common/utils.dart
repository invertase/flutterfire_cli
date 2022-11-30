/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:io';
import 'package:ansi_styles/ansi_styles.dart';
import 'package:ci/ci.dart' as ci;
import 'package:cli_util/cli_logging.dart';
import 'package:interact/interact.dart' as interact;
import 'package:path/path.dart' show relative, normalize, windows, joinAll;
import 'platform.dart';

/// Key for windows platform.
const String kWindows = 'windows';

/// Key for macos platform.
const String kMacos = 'macos';

/// Key for linux platform.
const String kLinux = 'linux';

/// Key for IPA (iOS) platform.
const String kIos = 'ios';

/// Key for APK (Android) platform.
const String kAndroid = 'android';

/// Key for Web platform.
const String kWeb = 'web';

extension Let<T> on T? {
  R? let<R>(R Function(T value) cb) {
    if (this == null) return null;

    return cb(this as T);
  }
}

bool get isCI {
  return ci.isCI;
}

int get terminalWidth {
  if (stdout.hasTerminal) {
    return stdout.terminalColumns;
  }

  return 80;
}

String listAsPaddedTable(List<List<String>> table, {int paddingSize = 1}) {
  final output = <String>[];
  final maxColumnSizes = <int, int>{};
  for (final row in table) {
    var i = 0;
    for (final column in row) {
      if (maxColumnSizes[i] == null ||
          maxColumnSizes[i]! < AnsiStyles.strip(column).length) {
        maxColumnSizes[i] = AnsiStyles.strip(column).length;
      }
      i++;
    }
  }

  for (final row in table) {
    var i = 0;
    final rowBuffer = StringBuffer();
    for (final column in row) {
      final colWidth = maxColumnSizes[i]! + paddingSize;
      final cellWidth = AnsiStyles.strip(column).length;
      var padding = colWidth - cellWidth;
      if (padding < paddingSize) padding = paddingSize;

      // last cell of the list, no need for padding
      if (i + 1 >= row.length) padding = 0;

      rowBuffer.write('$column${List.filled(padding, ' ').join()}');
      i++;
    }
    output.add(rowBuffer.toString());
  }

  return output.join('\n');
}

bool promptBool(
  String prompt, {
  bool defaultValue = true,
}) {
  return interact.Confirm(
    prompt: prompt,
    defaultValue: defaultValue,
  ).interact();
}

int promptSelect(
  String prompt,
  List<String> choices, {
  int initialIndex = 0,
}) {
  return interact.Select(
    prompt: prompt,
    options: choices,
    initialIndex: initialIndex,
  ).interact();
}

List<int> promptMultiSelect(
  String prompt,
  List<String> choices, {
  List<bool>? defaultSelection,
}) {
  return interact.MultiSelect(
    prompt: prompt,
    options: choices,
    defaults: defaultSelection,
  ).interact();
}

String promptInput(
  String prompt, {
  String? defaultValue,
  dynamic Function(String)? validator,
}) {
  return interact.Input(
    prompt: prompt,
    defaultValue: defaultValue,
    validator: (String input) {
      if (validator == null) return true;
      final Object? validatorResult = validator(input);
      if (validatorResult is bool) {
        return validatorResult;
      }
      if (validatorResult is String) {
        // ignore: only_throw_errors
        throw interact.ValidationError(validatorResult);
      }
      return false;
    },
  ).interact();
}

interact.SpinnerState? activeSpinnerState;
interact.SpinnerState spinner(String Function(bool) rightPrompt) {
  activeSpinnerState = interact.Spinner(
    icon: AnsiStyles.blue('i'),
    rightPrompt: rightPrompt,
  ).interact();
  return activeSpinnerState!;
}

String firebaseRcPathForDirectory(Directory directory) {
  return joinAll([directory.path, '.firebaserc']);
}

String pubspecPathForDirectory(Directory directory) {
  return joinAll([directory.path, 'pubspec.yaml']);
}

String androidAppBuildGradlePathForAppDirectory(Directory directory) {
  return joinAll([directory.path, 'android', 'app', 'build.gradle']);
}

File xcodeProjectFileInDirectory(Directory directory, String platform) {
  return File(
    joinAll(
      [directory.path, platform, 'Runner.xcodeproj', 'project.pbxproj'],
    ),
  );
}

File xcodeAppInfoConfigFileInDirectory(Directory directory, String platform) {
  return File(
    joinAll(
      [directory.path, platform, 'Runner', 'Configs', 'AppInfo.xcconfig'],
    ),
  );
}

String androidManifestPathForAppDirectory(Directory directory) {
  return joinAll([
    directory.path,
    'android',
    'app',
    'src',
    'main',
    'AndroidManifest.xml',
  ]);
}

String relativePath(String path, String from) {
  if (currentPlatform.isWindows) {
    return windows
        .normalize(relative(path, from: from))
        .replaceAll(r'\', r'\\');
  }
  return normalize(relative(path, from: from));
}

String removeForwardSlash(String input) {
  if (input.startsWith('/')) {
    return input.substring(1);
  } else {
    return input;
  }
}

Future<void> writeDebugScriptForScheme(
  String xcodeProjFilePath,
  String appId,
  String scheme,
  Logger logger,
) async {
  final adUploadSymbolsScript = addCrashlyticsDebugSymbolScriptToScheme(
    xcodeProjFilePath,
    appId,
    scheme,
    '[firebase_crashlytics] upload debug symbols script for "$scheme" scheme',
  );

  final resultUploadScript = await Process.run('ruby', [
    '-e',
    adUploadSymbolsScript,
  ]);

  if (resultUploadScript.exitCode != 0) {
    throw Exception(resultUploadScript.stderr);
  }

  if (resultUploadScript.stdout != null) {
    logger.stdout(resultUploadScript.stdout as String);
  }
}

Future<void> writeDebugScriptForTarget(
  String xcodeProjFilePath,
  String appId,
  String target,
  Logger logger,
) async {
  final addUploadSymbolsScript = addCrashlyticsDebugSymbolScriptToTarget(
    xcodeProjFilePath,
    appId,
    target,
    '[firebase_crashlytics] upload debug symbols script for "$target" scheme',
  );

  final resultUploadScript = await Process.run('ruby', [
    '-e',
    addUploadSymbolsScript,
  ]);

  if (resultUploadScript.exitCode != 0) {
    throw Exception(resultUploadScript.stderr);
  }

  if (resultUploadScript.stdout != null) {
    logger.stdout(resultUploadScript.stdout as String);
  }
}

String addServiceFileToRunnerScript(
  String googleServiceInfoFile,
  String xcodeProjFilePath,
) {
  return '''
require 'xcodeproj'
googleFile='$googleServiceInfoFile'
xcodeFile='$xcodeProjFilePath'

# define the path to your .xcodeproj file
project_path = xcodeFile
# open the xcode project
project = Xcodeproj::Project.open(project_path)

# check if `GoogleService-Info.plist` config is set in `project.pbxproj` file.
googleConfigExists = false
project.files.each do |file|
  if file.path == "Runner/GoogleService-Info.plist"
    googleConfigExists = true
    exit
  end
end

# Write only if config doesn't exist
if googleConfigExists == false
  file = project.new_file(googleFile)
  main_target = project.targets.find { |target| target.name == 'Runner' }
  
  if(main_target)
    main_target.add_resources([file])
    project.save
  else
    abort("Could not find target 'Runner' in your Xcode workspace. Please rename your target to 'Runner' and try again.")
  end  
end
''';
}

String findingSchemesScript(
  String xcodeProjFilePath,
) {
  return '''
require 'xcodeproj'
xcodeProject='$xcodeProjFilePath'

schemes = Xcodeproj::Project.schemes(xcodeProject)

response = Array.new

schemes.each do |scheme|
  response << scheme.to_s
end

if response.length == 0
  abort("There are no schemes in your Xcode workspace. Please create a scheme and try again.")
end

\$stdout.write response.join(',')
''';
}

String findingTargetsScript(
  String xcodeProjFilePath,
) {
  return '''
require 'xcodeproj'
xcodeProject='$xcodeProjFilePath'
project = Xcodeproj::Project.open(xcodeProject)

response = Array.new

project.targets.each do |target|
  response << target.name
end

if response.length == 0
  abort("There are no targets in your Xcode workspace. Please create a target and try again.")
end

\$stdout.write response.join(',')
''';
}

String addServiceFileToTarget(
  String xcodeProjFilePath,
  String googleServiceInfoFile,
  String targetName,
) {
  return '''
require 'xcodeproj'
googleFile='$googleServiceInfoFile'
xcodeFile='$xcodeProjFilePath'
targetName='$targetName'

project = Xcodeproj::Project.open(xcodeFile)

file = project.new_file(googleFile)
target = project.targets.find { |target| target.name == targetName }

if(target)
  exists = target.resources_build_phase.files.find do |file|
    if defined? file && file.file_ref && file.file_ref.path
      if file.file_ref.path.is_a? String
        file.file_ref.path.include? 'GoogleService-Info.plist'
      end
    end
  end  
  if !exists
    target.add_resources([file])
    project.save
  end
else
  abort("Could not find target: \$targetName in your Xcode workspace. Please create a target named \$targetName and try again.")
end  
''';
}

String addServiceFileToSchemeScript(
  String xcodeProjFilePath,
  String scheme,
  String runScriptName,
  String googleServiceFilePath,
) {
  return '''
require 'xcodeproj'
xcodeFile='$xcodeProjFilePath'
runScriptName='$runScriptName'
project = Xcodeproj::Project.open(xcodeFile)

# multi line argument for bash script
bashScript = %q(
#!/bin/bash

PLIST_DESTINATION=\${BUILT_PRODUCTS_DIR}/\${PRODUCT_NAME}.app
# Remove the "ios" segment from the SOURCE_ROOT environment variable as it could already be on "googleServiceFilePath"
GOOGLESERVICE_INFO_PATH=\${SOURCE_ROOT%/*}
GOOGLESERVICE_INFO_PATH=\${GOOGLESERVICE_INFO_PATH}/$googleServiceFilePath

# Copy GoogleService-Info.plist for appropriate scheme. Each scheme has multiple configurations (i.e. Debug-development, Debug-staging, etc).
# This is why we use *"scheme"*
# If scheme is "Runner", it is the default scheme for a Flutter iOS project so we allow for all configurations
if [[ "\${CONFIGURATION}" == *"$scheme"* ||  "Runner" = "$scheme" ]];
then
    echo "Copying \${GOOGLESERVICE_INFO_PATH} to \${PLIST_DESTINATION}"
    cp "\${GOOGLESERVICE_INFO_PATH}" "\${PLIST_DESTINATION}"
fi     
)

for target in project.targets 
  if target.name == 'Runner'
    phase = target.shell_script_build_phases().find do |item|
      if defined? item && item.name
        item.name == runScriptName
      end
    end

    if (phase.nil?)
        phase = target.new_shell_script_build_phase(runScriptName)
        phase.shell_script = bashScript
        project.save() 
    else
        \$stdout.write "Shell script already exists for bundling 'GoogleService-Info.plist' for $scheme scheme, skipping..."
        exit(0)
    end
  end  
end
''';
}

String addCrashlyticsDebugSymbolScriptToScheme(
  String xcodeProjFilePath,
  String appId,
  String scheme,
  String runScriptName,
) {
  return '''
require 'xcodeproj'
bashScript = %q(
#!/bin/bash

# Run upload symbol script for appropriate scheme. Each scheme has multiple configurations (i.e. Debug-development, Debug-staging, etc).
# This is why we use *"scheme"*
if [ "\${CONFIGURATION}" == *"$scheme"* && -f \$PODS_ROOT/FirebaseCrashlytics/upload-symbols];
then
    echo "Running $runScriptName"
    \$PODS_ROOT/FirebaseCrashlytics/upload-symbols --build-phase --validate -ai '$appId'
    \$PODS_ROOT/FirebaseCrashlytics/upload-symbols --build-phase -ai '$appId'
fi     
)

input_paths = ["\\"\${DWARF_DSYM_FOLDER_PATH}/\${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/\${TARGET_NAME}\\"", "\\"\$(SRCROOT)/\$(BUILT_PRODUCTS_DIR)/\$(INFOPLIST_PATH)\\""]

project = Xcodeproj::Project.open('$xcodeProjFilePath')

for target in project.targets
  if target.name == 'Runner'
    phase = target.shell_script_build_phases().find do |item|
      if defined? item && item.name
        item.name == '$runScriptName'
      end
    end
  
    if (phase.nil?)
      phase = target.new_shell_script_build_phase('$runScriptName')
      phase.shell_script = bashScript
      phase.input_paths = input_paths
      project.save() 
    else
      \$stdout.write "firebase_crashlytics upload debug symbols script script already exists, skipping..."
      exit(0)
    end
  end
end
''';
}

String addCrashlyticsDebugSymbolScriptToTarget(
  String xcodeProjFilePath,
  String appId,
  String target,
  String runScriptName,
) {
  return '''
require 'xcodeproj'
bashScript = %q(
#!/bin/bash

# Run upload symbol script for appropriate target.
if [ "\${TARGET_NAME}" == "$target" && -f \$PODS_ROOT/FirebaseCrashlytics/upload-symbols];
then
    echo "Running $runScriptName"
    \$PODS_ROOT/FirebaseCrashlytics/upload-symbols --build-phase --validate -ai '$appId'
    \$PODS_ROOT/FirebaseCrashlytics/upload-symbols --build-phase -ai '$appId'
fi     
)

input_paths = ["\\"\${DWARF_DSYM_FOLDER_PATH}/\${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/\${TARGET_NAME}\\"", "\\"\$(SRCROOT)/\$(BUILT_PRODUCTS_DIR)/\$(INFOPLIST_PATH)\\""]

project = Xcodeproj::Project.open('$xcodeProjFilePath')

for target in project.targets
  if (target.name == '$target')
    phase = target.shell_script_build_phases().find do |item|
      if !item.nil? && item.name.is_a?(String)
        item.name.include? '[firebase_crashlytics] upload debug symbols script'
      end
    end

    if (phase.nil?)
        phase = target.new_shell_script_build_phase('$runScriptName')
        phase.shell_script = bashScript
        phase.input_paths = input_paths
        project.save() 
    else
        \$stdout.write "firebase_crashlytics upload debug symbols script script already exists, skipping..."
        exit(0)
    end
  end  
end
''';
}

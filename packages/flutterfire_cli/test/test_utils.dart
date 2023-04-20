import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> createFlutterProject() async {
  final tempDir = Directory.systemTemp.createTempSync();
  const flutterProject = 'flutter_test_cli';
  await Process.run(
    'flutter',
    ['create', flutterProject],
    workingDirectory: tempDir.path,
  );

  final flutterProjectPath = p.join(tempDir.path, flutterProject);

  return flutterProjectPath;
}

String rubyScriptForTestingDefaultConfigure(
  String projectPath, {
  String targetName = 'Runner',
  String debugSymbolScriptName =
      'FlutterFire: "flutterfire upload-crashlytics-symbols"',
}) {
  return '''
      require 'xcodeproj'
      xcodeFile='$projectPath'
      debugSymbolScriptName='$debugSymbolScriptName'
      targetName='$targetName'
      project = Xcodeproj::Project.open(xcodeFile)
      target = project.targets.find { |target| target.name == targetName }
      if(target)
        # ensure debug symbol script does not exist in build phase scripts
        debugSymbolScript = target.shell_script_build_phases().find do |script|
          if defined? script && script.name
            script.name == debugSymbolScriptName
          end
        end
        
        # find "GoogleService-Info.plist" bundled with resources
        serviceFileInResources = target.resources_build_phase.files.find do |file|
          if defined? file && file.file_ref && file.file_ref.path
            if file.file_ref.path.is_a? String
              file.file_ref.path.include? 'GoogleService-Info.plist'
            end
          end
        end
        if(serviceFileInResources && !debugSymbolScript)
          \$stdout.write("success")
        else
          if(debugSymbolScript)
            abort("failed, debug symbol script #{debugSymbolScriptName} exists in run script build phases")
          end
          if(!serviceFileInResources)
            abort("failed, cannot find 'GoogleService-Info.plist' bundled in resources")
          end
        end
      else
        abort("failed, #{targetName} target not found.")
      end
''';
}

String rubyScriptForCheckingBundleResourcesScript(
  String projectPath,
  String platform, {
  String runScriptName = 'flutterfire bundle-service-file',
}) {
  final xcodeProjectPath = p.join(projectPath, platform, 'Runner.xcodeproj');
  return '''
require 'xcodeproj'
xcodeFile='$xcodeProjectPath'
runScriptName='$runScriptName'
project = Xcodeproj::Project.open(xcodeFile)


for target in project.targets 
  if (target.name == 'Runner')
    phase = target.shell_script_build_phases().find do |item|
      if defined?(item) && !item.name.nil? && item.name.is_a?(String)
        item.name.include?(runScriptName)
      end
    end

    if (phase.nil?)
      abort("failed, #{runScriptName} has not been found in build phase run scripts.")
    else
      \$stdout.write("success")
    end
  end  
end
    ''';
}

String removeWhitepaceAndNewLines(String string) {
  return string.replaceAll(RegExp(r'\s+|\n'), '');
}

String rubyScriptForTestingDebugSymbolScriptExists(
  String projectPath, {
  String targetName = 'Runner',
  String debugSymbolScriptName =
      'FlutterFire: "flutterfire upload-crashlytics-symbols"',
}) {
  return '''
      require 'xcodeproj'
      xcodeFile='$projectPath'
      debugSymbolScriptName='$debugSymbolScriptName'
      targetName='$targetName'
      project = Xcodeproj::Project.open(xcodeFile)
      target = project.targets.find { |target| target.name == targetName }
      if(target)
        # find debug symbol script in build phase scripts
        debugSymbolScript = target.shell_script_build_phases().find do |script|
          if defined? script && script.name
            script.name == debugSymbolScriptName
          end
        end
        
        if(debugSymbolScript)
          \$stdout.write("success")
        else
          abort("failed, cannot find debug symbol script #{debugSymbolScriptName} in run script build phases")
        end
      else
        abort("failed, #{targetName} target not found.")
      end
''';
}

Future<File> findFileInDirectory(
  String directoryPath,
  String fileName,
) async {
  final directory = Directory(directoryPath);
  if (directory.existsSync()) {
    final contents = directory.listSync();
    for (final entity in contents) {
      if (entity is File && entity.path.endsWith(fileName)) {
        return entity;
      }
    }
  } else {
    throw Exception('Directory does not exist: ${directory.path}}');
  }

  throw Exception('File not found: $fileName');
}

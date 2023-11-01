import 'dart:convert';
import 'dart:io';
import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const firebaseProjectId = 'flutterfire-cli-test-f6f57';
const appleAppId = '1:262904632156:ios:58c61e319713c6142f2799';
const androidAppId = '1:262904632156:android:eef79d5fec9aab142f2799';
const webAppId = '1:262904632156:web:b4a12a4ae43da5e42f2799';

// Secondary App Ids
const secondAppleAppId = '1:262904632156:ios:1de2ea53918d5e802f2799';
const secondAndroidAppId = '1:262904632156:android:efaa8538e6d346502f2799';
const secondWebAppId = '1:262904632156:web:cb3a00412ed430ca2f2799';

const secondAppleBundleId = 'com.example.secondApp';
const secondAndroidApplicationId = 'com.example.second_app';

const buildType = 'development';
const appleBuildConfiguration = 'Debug';

// Apple GoogleService-Info.plist values
const appleBundleId = 'com.example.flutterTestCli';
const appleApiKey = 'AIzaSyBKopB-r1-sAAc99XLfZ71dURkLHab1AJE';
const appleGcmSenderId = '262904632156';

const androidGradleUpdate = '''
        // START: FlutterFire Configuration
        classpath 'com.google.gms:google-services:4.3.15'
        // END: FlutterFire Configuration
''';

const androidAppGradleUpdate = '''
        // START: FlutterFire Configuration
        id 'com.google.gms.google-services'
        // END: FlutterFire Configuration
        ''';

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

bool containsInOrder(String content, List<String> lines) {
  var lastIndex = 0;

  for (final line in lines) {
    final trimmedLine = line.trim();

    if (lastIndex != 0 && content[lastIndex] != '\n') {
      // Ensure we are at the start of a new line
      lastIndex++;
    }

    final foundIndex = content.indexOf(trimmedLine, lastIndex);
    if (foundIndex == -1) return false;
    lastIndex = foundIndex + trimmedLine.length;

    // Check if the found line ends with a newline or the end of the content
    if (lastIndex < content.length && content[lastIndex] != '\n') {
      return false;
    }
  }
  return true;
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
    throw Exception('Directory does not exist: ${directory.path}');
  }

  throw Exception('File not found: $fileName');
}

String? getValue(XmlElement dictionary, String key) {
  final keyElement =
      dictionary.findElements('key').singleWhere((e) => e.innerText == key);
  final valueElement = keyElement.nextElementSibling;
  return valueElement?.innerText;
}

Future<void> testAppleServiceFileValues(
  String applePath,
  // ios or macos
  {
  String platform = kIos,
  String? bundleId = appleBundleId,
  String? appId = appleAppId,
}) async {
  File? appleFile;
  if (platform == kMacos) {
    // Need to find mac file like this for it to work on CI. No idea why.
    appleFile = await findFileInDirectory(applePath, appleServiceFileName);
  } else {
    appleFile = File(applePath);
  }

  final appleServiceFileContent = await appleFile.readAsString();

  final applePlist = XmlDocument.parse(appleServiceFileContent);

  final appleDictionary = applePlist.rootElement.findElements('dict').single;

  final appleProjectId = getValue(appleDictionary, 'PROJECT_ID');
  final appleBundleId = getValue(appleDictionary, 'BUNDLE_ID');
  final appleGoogleAppId = getValue(appleDictionary, 'GOOGLE_APP_ID');
  final appleApiKey = getValue(appleDictionary, 'API_KEY');
  final appleGcmSenderId = getValue(appleDictionary, 'GCM_SENDER_ID');

  expect(appleProjectId, firebaseProjectId);
  expect(appleBundleId, bundleId);
  expect(appleGoogleAppId, appId);
  expect(appleApiKey, appleApiKey);
  expect(appleGcmSenderId, appleGcmSenderId);
}

void testAndroidServiceFileValues(
  String serviceFilePath, {
  String? appId = androidAppId,
}) {
  final clientList = Map<String, dynamic>.from(
    jsonDecode(File(serviceFilePath).readAsStringSync())
        as Map<String, dynamic>,
  );

  final findClientMap =
      List<Map<String, dynamic>>.from(clientList['client'] as List<dynamic>)
          .firstWhere(
    // ignore: avoid_dynamic_calls
    (element) => element['client_info']['mobilesdk_app_id'] == appId,
  );

  expect(findClientMap, isA<Map<String, dynamic>>());
}

Future<void> testFirebaseOptionsFileValues(
  String firebaseOptionsPath,
) async {
  final baseRequiredProperties = [
    'apiKey',
    'appId',
    'messagingSenderId',
    'projectId',
    'storageBucket',
  ];

  // Reading the file as a string
  final content = await File(firebaseOptionsPath).readAsString();

  // Regular expressions to identify the static properties (e.g. web, android, ios, macos) and their values
  final propertyPattern = RegExp(r'static const FirebaseOptions (\w+) =');

  final matches = propertyPattern.allMatches(content);
  for (final match in matches) {
    final platform = match.group(1);
    final start = match.start;
    final end = content.indexOf(');', start);

    final propertyContent = content.substring(start, end);

    var requiredProperties = baseRequiredProperties;
    if (platform == kWeb) {
      requiredProperties = [
        ...requiredProperties,
        'measurementId',
        'authDomain',
      ];
    }
    if (platform == kMacos || platform == kIos) {
      requiredProperties = [
        ...requiredProperties,
        'iosClientId',
        'iosBundleId',
      ];
    }
    for (final prop in requiredProperties) {
      if (!propertyContent.contains(prop)) {
        fail('Property $prop is missing in - $platform FirebaseOptions.');
      }
    }
  }
}

void checkAppleFirebaseJsonValues(
  Map<String, dynamic> decodedFirebaseJson,
  List<String> keysToAppleMap,
  String pathToServiceFile, {
  String? appId = appleAppId,
}) {
  final appleDefaultConfig = getNestedMap(decodedFirebaseJson, keysToAppleMap);
  expect(appleDefaultConfig[kAppId], appId);
  expect(appleDefaultConfig[kProjectId], firebaseProjectId);
  expect(appleDefaultConfig[kUploadDebugSymbols], false);
  expect(
    appleDefaultConfig[kFileOutput],
    pathToServiceFile,
  );
}

void checkAndroidFirebaseJsonValues(
  Map<String, dynamic> decodedFirebaseJson,
  List<String> keysToMapAndroid,
  String pathToServiceFile, {
  String? appId = androidAppId,
}) {
  final androidDefaultConfig =
      getNestedMap(decodedFirebaseJson, keysToMapAndroid);
  expect(androidDefaultConfig[kAppId], appId);
  expect(androidDefaultConfig[kProjectId], firebaseProjectId);
  expect(
    androidDefaultConfig[kFileOutput],
    pathToServiceFile,
  );
}

void checkDartFirebaseJsonValues(
  Map<String, dynamic> decodedFirebaseJson,
  List<String> keysToMapDart, {
  String? appleAppId = appleAppId,
  String? androidAppId = androidAppId,
  String? webAppId = webAppId,
  bool checkIos = true,
  bool checkMacos = true,
  bool checkAndroid = true,
  bool checkWeb = true,
}) {
  final dartConfig = getNestedMap(decodedFirebaseJson, keysToMapDart);
  expect(dartConfig[kProjectId], firebaseProjectId);

  final defaultConfigurations =
      dartConfig[kConfigurations] as Map<String, dynamic>;

  if (checkIos) {
    expect(defaultConfigurations[kIos], appleAppId);
  }
  if (checkMacos) {
    expect(defaultConfigurations[kMacos], appleAppId);
  }
  if (checkAndroid) {
    expect(defaultConfigurations[kAndroid], androidAppId);
  }
  if (checkWeb) {
    expect(defaultConfigurations[kWeb], webAppId);
  }
}

// Use this variable to debug the process run commands in the integration tests
// const kDebugProcess = false;

// void debugProcessRun(ProcessResult result, String name) {

//   if (!kDebugProcess) {
//     return;
//   }
//   // ignore: avoid_print
//   print('------------------------------------');
//   // ignore: avoid_print
//   print(name);
//   // ignore: avoid_print
//   print('ERROR CODE: ${result.exitCode}');
//   // ignore: avoid_print
//   print('STDOUT: ${result.stdout}');
//   // ignore: avoid_print
//   print('STDERR: ${result.stderr}');
//   // ignore: avoid_print
//   print('------------------------------------');
// }

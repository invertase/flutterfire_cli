import 'dart:convert';
import 'dart:io';
import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const firebaseProjectId = 'flutterfire-cli-test-f6f57';
const testFileDirectory = 'test_files';
const appleAppId = '1:262904632156:ios:58c61e319713c6142f2799';
const androidAppId = '1:262904632156:android:eef79d5fec9aab142f2799';
const webAppId = '1:262904632156:web:22fdf07f28e76b062f2799';

// Secondary App Ids
const secondAppleAppId = '1:262904632156:ios:1de2ea53918d5e802f2799';
const secondAndroidAppId = '1:262904632156:android:efaa8538e6d346502f2799';
const secondWebAppId = '1:262904632156:web:22fdf07f28e76b062f2799';

const secondAppleBundleId = 'com.example.secondApp';

const buildType = 'development';
const appleBuildConfiguration = 'Debug';

// Apple GoogleService-Info.plist values
const appleBundleId = 'com.example.flutterTestCli';
const appleApiKey = 'AIzaSyBKopB-r1-sAAc99XLfZ71dURkLHab1AJE';
const appleGcmSenderId = '262904632156';

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

// TODO - we can update this for both apple platforms
Future<void> testAppleServiceFileValues(
  String iosPath,
  String macosPath, {
  String? bundleId = appleBundleId,
  String? appId = appleAppId,
}) async {
  // Need to find mac file like this for it to work on CI. No idea why.
  final macFile = await findFileInDirectory(macosPath, appleServiceFileName);

  final iosServiceFileContent = await File(iosPath).readAsString();

  final macosServiceFileContent = await macFile.readAsString();

  final iosPlist = XmlDocument.parse(iosServiceFileContent);
  final macosPlist = XmlDocument.parse(macosServiceFileContent);

  final iosDictionary = iosPlist.rootElement.findElements('dict').single;

  final iosProjectId = getValue(iosDictionary, 'PROJECT_ID');
  final iosBundleId = getValue(iosDictionary, 'BUNDLE_ID');
  final iosGoogleAppId = getValue(iosDictionary, 'GOOGLE_APP_ID');
  final iosApiKey = getValue(iosDictionary, 'API_KEY');
  final iosGcmSenderId = getValue(iosDictionary, 'GCM_SENDER_ID');

  expect(iosProjectId, firebaseProjectId);
  expect(iosBundleId, bundleId);
  expect(iosGoogleAppId, appId);
  expect(iosApiKey, appleApiKey);
  expect(iosGcmSenderId, appleGcmSenderId);

  final macosDictionary = macosPlist.rootElement.findElements('dict').single;

  final macosProjectId = getValue(macosDictionary, 'PROJECT_ID');
  final macosBundleId = getValue(macosDictionary, 'BUNDLE_ID');
  final macosGoogleAppId = getValue(macosDictionary, 'GOOGLE_APP_ID');
  final macosApiKey = getValue(macosDictionary, 'API_KEY');
  final macosGcmSenderId = getValue(macosDictionary, 'GCM_SENDER_ID');

  expect(macosProjectId, firebaseProjectId);
  expect(macosBundleId, bundleId);
  expect(macosGoogleAppId, appId);
  expect(macosApiKey, appleApiKey);
  expect(macosGcmSenderId, appleGcmSenderId);
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
  final testFirebaseOptions = p.join(
    Directory.current.path,
    'test',
    testFileDirectory,
    'firebase_options.dart',
  );

  final firebaseOptionsContent = await File(firebaseOptionsPath).readAsString();
  final testFirebaseOptionsContent =
      await File(testFirebaseOptions).readAsString();

  expect(firebaseOptionsContent, testFirebaseOptionsContent);
}

void checkAppleFirebaseJsonValues(
  Map<String, dynamic> decodedFirebaseJson,
  List<String> keysToAppleMap,
  String pathToServiceFile, {
  String? appId = appleAppId,
}) {
  final iosDefaultConfig = getNestedMap(decodedFirebaseJson, keysToAppleMap);
  expect(iosDefaultConfig[kAppId], appId);
  expect(iosDefaultConfig[kProjectId], firebaseProjectId);
  expect(iosDefaultConfig[kUploadDebugSymbols], false);
  expect(
    iosDefaultConfig[kFileOutput],
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
}) {
  final dartConfig = getNestedMap(decodedFirebaseJson, keysToMapDart);
  expect(dartConfig[kProjectId], firebaseProjectId);

  final defaultConfigurations =
      dartConfig[kConfigurations] as Map<String, dynamic>;

  expect(defaultConfigurations[kIos], appleAppId);
  expect(defaultConfigurations[kMacos], appleAppId);
  expect(defaultConfigurations[kAndroid], androidAppId);
  expect(defaultConfigurations[kWeb], webAppId);
}

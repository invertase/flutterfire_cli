import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:flutterfire_cli/src/firebase/firebase_apple_writes.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// dsymutil names the DWARF file after the executable. On macOS Flutter apps
// that is the app name, not the target name.
const dwarfInput =
    r'${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${EXECUTABLE_NAME}';

void main() {
  late Directory appDirectory;

  // Runs [body] with the iOS Runner target open as `project` and `target`.
  Future<String> runRuby(String body) async {
    final projectPath = path.join(appDirectory.path, kIos, 'Runner.xcodeproj');
    final result = await Process.run('ruby', [
      '-rxcodeproj',
      '-rjson',
      '-e',
      '''
project = Xcodeproj::Project.open('${escapeRubySingleQuoted(projectPath)}')
target = project.targets.find { |item| item.name == 'Runner' }
$body
''',
    ]);
    expect(result.exitCode, 0, reason: result.stderr as String);
    return result.stdout as String;
  }

  Future<void> addScript() async {
    // The Xcode project is found from the current directory. Overriding it
    // for this call leaves other test files running in the process alone.
    final added = await IOOverrides.runZoned(
      () => addFlutterFireDebugSymbolsScript(
        target: 'Runner',
        flutterAppPath: appDirectory.path,
        logger: Logger.standard(),
        platform: kIos,
        projectConfiguration: ProjectConfiguration.defaultConfig,
        isDevDependency: false,
      ),
      getCurrentDirectory: () => appDirectory,
    );
    expect(added, isTrue);
  }

  Future<List<String>> phaseNames() async {
    final output = await runRuby(
      'print JSON.generate(target.build_phases.map(&:display_name))',
    );
    return (jsonDecode(output) as List).cast<String>();
  }

  Future<List<String>> uploadPhaseInputs() async {
    final output = await runRuby('''
phase = target.shell_script_build_phases.find { |item| item.name == '${escapeRubySingleQuoted(debugSymbolScriptName)}' }
print JSON.generate(phase.input_paths)
''');
    return (jsonDecode(output) as List).cast<String>();
  }

  group(
    'Crashlytics upload symbols build phase',
    () {
      setUp(() async {
        appDirectory =
            Directory.systemTemp.createTempSync('flutterfire_cli_crashlytics');
        File(path.join(appDirectory.path, 'pubspec.yaml')).writeAsStringSync(
          'name: app\ndependencies:\n  firebase_crashlytics: any\n',
        );
        final projectPath =
            path.join(appDirectory.path, kIos, 'Runner.xcodeproj');
        final result = await Process.run('ruby', [
          '-rxcodeproj',
          '-e',
          '''
project = Xcodeproj::Project.new('${escapeRubySingleQuoted(projectPath)}')
project.new_target(:application, 'Runner', :ios, '15.0')
project.save
''',
        ]);
        expect(result.exitCode, 0, reason: result.stderr as String);
      });

      tearDown(() {
        appDirectory.deleteSync(recursive: true);
      });

      test('waits for the DWARF file in the dSYM', () async {
        await addScript();

        final inputs = await uploadPhaseInputs();
        expect(inputs, contains(dwarfInput));
        // Xcode matches input paths literally, so quotes never match a file.
        expect(inputs.where((input) => input.contains('"')), isEmpty);
      });

      test('adds the inputs to a phase written without them', () async {
        // Earlier versions wrote the same script with no inputs.
        await addScript();
        await runRuby('''
phase = target.shell_script_build_phases.find { |item| item.name == '${escapeRubySingleQuoted(debugSymbolScriptName)}' }
phase.input_paths = []
project.save
''');

        await addScript();

        expect(await uploadPhaseInputs(), contains(dwarfInput));
      });

      test('moves the phase after phases added later', () async {
        await addScript();
        // configure appends the bundle-service-file phase on every run, and
        // Xcode appends an embed phase when an app extension is added. An
        // embed phase after the upload phase is a build cycle.
        await runRuby('''
target.new_shell_script_build_phase('${escapeRubySingleQuoted(bundleServiceScriptName)}')
target.new_copy_files_build_phase('Embed Foundation Extensions')
project.save
''');

        await addScript();

        final names = await phaseNames();
        expect(names.last, debugSymbolScriptName);
        expect(names, contains('Embed Foundation Extensions'));
        expect(names, contains(bundleServiceScriptName));
      });

      test('leaves an up-to-date project unchanged', () async {
        await addScript();
        final pbxproj = File(
          path.join(
            appDirectory.path,
            kIos,
            'Runner.xcodeproj',
            'project.pbxproj',
          ),
        );
        final before = pbxproj.readAsStringSync();

        await addScript();

        expect(pbxproj.readAsStringSync(), before);
      });
    },
    // The phase is written with Ruby and the xcodeproj gem.
    skip: !Platform.isMacOS,
  );
}

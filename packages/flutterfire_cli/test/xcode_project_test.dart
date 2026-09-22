import 'dart:io';

import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:flutterfire_cli/src/flutter_app.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory appDirectory;

  setUp(() {
    appDirectory = Directory.systemTemp.createTempSync('flutterfire_cli_apple');
  });

  tearDown(() {
    appDirectory.deleteSync(recursive: true);
  });

  void createXcodeProject(String platform, String projectName) {
    Directory(
      path.join(appDirectory.path, platform, '$projectName.xcodeproj'),
    ).createSync(recursive: true);
  }

  group('xcodeProjectNameInDirectory()', () {
    test('finds the default "Runner" project', () {
      createXcodeProject(kIos, 'Runner');

      expect(xcodeProjectNameInDirectory(appDirectory, kIos), 'Runner');
    });

    test('finds a renamed project', () {
      createXcodeProject(kIos, 'MyApp');

      expect(xcodeProjectNameInDirectory(appDirectory, kIos), 'MyApp');
    });

    test('prefers "Runner" when several projects exist', () {
      createXcodeProject(kMacos, 'Runner');
      createXcodeProject(kMacos, 'MyApp');

      expect(xcodeProjectNameInDirectory(appDirectory, kMacos), 'Runner');
    });

    test('throws when several renamed projects exist', () {
      createXcodeProject(kIos, 'MyApp');
      createXcodeProject(kIos, 'MyOtherApp');

      expect(
        () => xcodeProjectNameInDirectory(appDirectory, kIos),
        throwsA(isA<XcodeProjectException>()),
      );
    });

    test('falls back to "Runner" when the platform directory is missing', () {
      expect(xcodeProjectNameInDirectory(appDirectory, kIos), 'Runner');
    });
  });

  group('xcodeProjectFileInDirectory()', () {
    test('points at the renamed project\'s "project.pbxproj"', () {
      createXcodeProject(kIos, 'MyApp');

      expect(
        xcodeProjectFileInDirectory(appDirectory, kIos).path,
        path.join(
          appDirectory.path,
          kIos,
          'MyApp.xcodeproj',
          'project.pbxproj',
        ),
      );
    });
  });

  group('xcodeAppInfoConfigFileInDirectory()', () {
    test('reads "AppInfo.xcconfig" from the renamed source directory', () {
      createXcodeProject(kMacos, 'MyApp');
      final appInfo = File(
        path.join(
          appDirectory.path,
          kMacos,
          'MyApp',
          'Configs',
          'AppInfo.xcconfig',
        ),
      )..createSync(recursive: true);

      expect(
        xcodeAppInfoConfigFileInDirectory(appDirectory, kMacos).path,
        appInfo.path,
      );
    });

    test('falls back to "Runner" when only the project was renamed', () {
      createXcodeProject(kMacos, 'MyApp');
      final appInfo = File(
        path.join(
          appDirectory.path,
          kMacos,
          'Runner',
          'Configs',
          'AppInfo.xcconfig',
        ),
      )..createSync(recursive: true);

      expect(
        xcodeAppInfoConfigFileInDirectory(appDirectory, kMacos).path,
        appInfo.path,
      );
    });
  });

  group('bundle id auto detection', () {
    Future<FlutterApp> flutterAppIn(Directory directory) async {
      await File(path.join(directory.path, 'pubspec.yaml')).writeAsString('''
name: test_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
''');

      return (await FlutterApp.load(directory))!;
    }

    test('falls back to prompting when the project is ambiguous', () async {
      // Auto detection runs on Windows and Linux too, where none of the Xcode
      // writes happen, so it must not take the command down.
      createXcodeProject(kIos, 'MyApp');
      createXcodeProject(kIos, 'MyOtherApp');

      expect((await flutterAppIn(appDirectory)).iosBundleId, isNull);
    });

    test('still reads the bundle id from a renamed project', () async {
      createXcodeProject(kIos, 'MyApp');
      await File(
        path.join(
          appDirectory.path,
          kIos,
          'MyApp.xcodeproj',
          'project.pbxproj',
        ),
      ).writeAsString('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.app;');

      expect(
        (await flutterAppIn(appDirectory)).iosBundleId,
        'com.example.app',
      );
    });
  });

  group('escapeRubySingleQuoted()', () {
    test('escapes apostrophes and backslashes', () {
      expect(escapeRubySingleQuoted("Bob's App"), r"Bob\'s App");
      expect(escapeRubySingleQuoted(r'C:\apps'), r'C:\\apps');
      expect(escapeRubySingleQuoted('Runner'), 'Runner');
    });
  });

  group('defaultAppleSourceDirectory()', () {
    late Directory previousDirectory;

    setUp(() {
      previousDirectory = Directory.current;
      Directory.current = appDirectory;
    });

    tearDown(() {
      Directory.current = previousDirectory;
    });

    test('uses the target directory when it exists', () {
      Directory(path.join(appDirectory.path, kIos, 'MyApp'))
          .createSync(recursive: true);

      expect(defaultAppleSourceDirectory(kIos, 'MyApp'), 'MyApp');
    });

    test('falls back to "Runner" when the target directory does not exist', () {
      Directory(path.join(appDirectory.path, kIos, 'Runner'))
          .createSync(recursive: true);

      expect(defaultAppleSourceDirectory(kIos, 'MyApp'), 'Runner');
    });

    test('falls back to the project directory for a "Runner" target', () {
      // The project and its source directory were renamed, the target was not.
      createXcodeProject(kIos, 'MyApp');
      Directory(path.join(appDirectory.path, kIos, 'MyApp'))
          .createSync(recursive: true);

      expect(defaultAppleSourceDirectory(kIos, 'Runner'), 'MyApp');
    });

    test('uses the target name when nothing is on disk yet', () {
      expect(defaultAppleSourceDirectory(kIos, 'MyApp'), 'MyApp');
    });
  });
}

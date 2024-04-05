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

import 'package:path/path.dart';

import '../common/utils.dart';
import 'firebase_options.dart';

class FirebaseDartConfigurationWrite {
  FirebaseDartConfigurationWrite({
    required this.configurationFilePath,
    required this.flutterAppPath,
    required this.firebaseProjectId,
    this.androidOptions,
    this.iosOptions,
    this.macosOptions,
    this.webOptions,
    this.windowsOptions,
    this.linuxOptions,
  });

  final StringBuffer _stringBuffer = StringBuffer();
  final String configurationFilePath;
  final String flutterAppPath;
  final String firebaseProjectId;

  FirebaseOptions? webOptions;

  FirebaseOptions? macosOptions;

  FirebaseOptions? androidOptions;

  FirebaseOptions? iosOptions;

  FirebaseOptions? windowsOptions;

  FirebaseOptions? linuxOptions;

  FirebaseJsonWrites write() {
    final outputFile = File(configurationFilePath);
    if (outputFile.existsSync()) {
      final updatedFileString = _updateExistingConfigurationFile(
        outputFile,
      );
      outputFile.writeAsStringSync(updatedFileString);
    } else {
      _writeHeader();
      _writeClass();

      outputFile.createSync(recursive: true);
      outputFile.writeAsStringSync(_stringBuffer.toString());
    }

    return _firebaseJsonWrites();
  }

  String _updateExistingConfigurationFile(
    File outputFile,
  ) {
    final fileConfigurationLines = outputFile.readAsLinesSync();

    final optionsList = [
      {'options': webOptions, 'platform': kWeb},
      {'options': macosOptions, 'platform': 'macOS'},
      {'options': iosOptions, 'platform': 'iOS'},
      {'options': androidOptions, 'platform': kAndroid},
      {'options': windowsOptions, 'platform': kWindows},
      {'options': linuxOptions, 'platform': kLinux},
    ];

    for (var i = 0; i < optionsList.length; i++) {
      final map = optionsList[i];
      final options = map['options'] as FirebaseOptions?;
      final platform = map['platform']! as String;

      // Stop this iteration if the FirebaseOptions are null for that platform
      if (options == null) continue;

      final configExists = fileConfigurationLines.any(
        (line) => line
            .contains('static const FirebaseOptions ${platform.toLowerCase()}'),
      );
      if (configExists) {
        // find the indexes for start/end of existing platform configuration
        final startIndex = fileConfigurationLines.indexWhere(
          (line) => line.contains(
            'static const FirebaseOptions ${platform.toLowerCase()}',
          ),
        );
        final endIndex = fileConfigurationLines.indexWhere(
          (line) => line.contains(');'),
          startIndex,
        );

        if (endIndex == -1 || startIndex == -1) {
          throw Exception(
            'unable to find existing Dart configuration for platform: $platform',
          );
        }

        fileConfigurationLines.removeRange(startIndex, endIndex + 1);

        // Insert the new platform configuration
        fileConfigurationLines.insertAll(
          startIndex - 1,
          _buildFirebaseOptions(
            options,
            platform.toLowerCase(),
          ),
        );
      } else {
        // remove `UnsupportedError` and write static const FirebaseOptions $platform
        final startIndex = fileConfigurationLines.indexWhere(
          (line) => line.contains(
            platform == kWeb ? 'if (kIsWeb)' : 'case TargetPlatform.$platform:',
          ),
        );
        final unsupportedErrorLineIndex = startIndex + 1;

        if (fileConfigurationLines[unsupportedErrorLineIndex]
            .contains('UnsupportedError')) {
          final endIndex = fileConfigurationLines.indexWhere(
            (line) => line.contains(');'),
            unsupportedErrorLineIndex,
          );
          fileConfigurationLines.removeRange(
            unsupportedErrorLineIndex,
            endIndex + 1,
          );
          // remove `UnsupportedError` exception & write the static property for the platform
          fileConfigurationLines.insert(
            unsupportedErrorLineIndex,
            platform == kWeb
                ? '      return ${platform.toLowerCase()};'
                : '        return ${platform.toLowerCase()};',
          );
        } else {
          throw Exception('`UnsupportedError` not found in $platform');
        }

        final insertIndex = fileConfigurationLines.lastIndexOf('}');

        // write the static property for the platform
        fileConfigurationLines.insertAll(
          insertIndex,
          _buildFirebaseOptions(
            options,
            platform.toLowerCase(),
          ),
        );
      }
    }

    return formatList(fileConfigurationLines).join('\n');
  }

  // ensure only one empty line between each static property
  List<String> formatList(List<String> items) {
    return items.fold<List<String>>([], (acc, item) {
      if (item.isNotEmpty || acc.isEmpty || acc.last.isNotEmpty) {
        acc.add(item);
      }
      return acc;
    });
  }

  List<String> _buildFirebaseOptions(
    FirebaseOptions options,
    String platform,
  ) {
    return <String>[
      '',
      '  static const FirebaseOptions $platform = FirebaseOptions(',
      ...options.asMap.entries
          .where((entry) => entry.value != null)
          .map((entry) => "    ${entry.key}: '${entry.value}',"),
      '  );', // FirebaseOptions
      '',
    ];
  }

  FirebaseJsonWrites _firebaseJsonWrites() {
    final relativePathConfigurationFile = replaceBackslash(
      relative(
        configurationFilePath,
        from: flutterAppPath,
      ),
    );

    final keysToMap = [
      kFlutter,
      kPlatforms,
      kDart,
      relativePathConfigurationFile,
    ];

    final configurations = <String, String>{};

    if (androidOptions != null) {
      configurations[kAndroid] = androidOptions!.appId;
    }
    if (iosOptions != null) {
      configurations[kIos] = iosOptions!.appId;
    }

    if (macosOptions != null) {
      configurations[kMacos] = macosOptions!.appId;
    }

    if (webOptions != null) {
      configurations[kWeb] = webOptions!.appId;
    }

    if (windowsOptions != null) {
      configurations[kWindows] = windowsOptions!.appId;
    }

    return FirebaseJsonWrites(
      pathToMap: keysToMap,
      projectId: firebaseProjectId,
      configurations: configurations,
    );
  }

  void _writeHeader() {
    _stringBuffer.writeAll(
      <String>[
        '// File generated by FlutterFire CLI.',
        '// ignore_for_file: type=lint',
        "import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;",
        "import 'package:flutter/foundation.dart'",
        '    show defaultTargetPlatform, kIsWeb, TargetPlatform;',
        '',
        '/// Default [FirebaseOptions] for use with your Firebase apps.',
        '///',
        '/// Example:',
        '/// ```dart',
        "/// import '${basename(configurationFilePath)}';",
        '/// // ...',
        '/// await Firebase.initializeApp(',
        '///   options: DefaultFirebaseOptions.currentPlatform,',
        '/// );',
        '/// ```',
        '',
      ],
      '\n',
    );
  }

  void _writeClass() {
    _stringBuffer.writeAll(
      <String>[
        'class DefaultFirebaseOptions {',
        '  static FirebaseOptions get currentPlatform {',
        '',
      ],
      '\n',
    );
    _writeCurrentPlatformWeb();
    _stringBuffer.writeln('    switch (defaultTargetPlatform) {');
    _writeCurrentPlatformSwitchAndroid();
    _writeCurrentPlatformSwitchIos();
    _writeCurrentPlatformSwitchMacos();
    _writeCurrentPlatformSwitchWindows();
    _writeCurrentPlatformSwitchLinux();
    _stringBuffer.write(
      '''
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
''',
    );
    _writeFirebaseOptionsStatic(kWeb, webOptions);
    _writeFirebaseOptionsStatic(kAndroid, androidOptions);
    _writeFirebaseOptionsStatic(kIos, iosOptions);
    _writeFirebaseOptionsStatic(kMacos, macosOptions);
    _writeFirebaseOptionsStatic(kWindows, windowsOptions);
    _writeFirebaseOptionsStatic(kLinux, linuxOptions);
    _stringBuffer.writeln('}'); // } DefaultFirebaseOptions
  }

  void _writeFirebaseOptionsStatic(String platform, FirebaseOptions? options) {
    if (options == null) return;
    _stringBuffer.writeAll(
      _buildFirebaseOptions(options, platform),
      '\n',
    );
  }

  void _writeThrowUnsupportedForPlatform(String platform, String indentation) {
    _stringBuffer.writeAll(
      <String>[
        '${indentation}throw UnsupportedError(',
        "$indentation  'DefaultFirebaseOptions have not been configured for $platform - '",
        "$indentation  'you can reconfigure this by running the FlutterFire CLI again.',",
        '$indentation);',
        '',
      ],
      '\n',
    );
  }

  void _writeCurrentPlatformWeb() {
    _stringBuffer.writeln('    if (kIsWeb) {');
    if (webOptions != null) {
      _stringBuffer.writeln('      return web;');
    } else {
      _writeThrowUnsupportedForPlatform(kWeb, '      ');
    }
    _stringBuffer.writeln('    }');
  }

  void _writeCurrentPlatformSwitchAndroid() {
    _stringBuffer.writeln('      case TargetPlatform.android:');
    if (androidOptions != null) {
      _stringBuffer.writeln('        return android;');
    } else {
      _writeThrowUnsupportedForPlatform(kAndroid, '        ');
    }
  }

  void _writeCurrentPlatformSwitchIos() {
    _stringBuffer.writeln('      case TargetPlatform.iOS:');
    if (iosOptions != null) {
      _stringBuffer.writeln('        return ios;');
    } else {
      _writeThrowUnsupportedForPlatform(kIos, '        ');
    }
  }

  void _writeCurrentPlatformSwitchMacos() {
    _stringBuffer.writeln('      case TargetPlatform.macOS:');
    if (macosOptions != null) {
      _stringBuffer.writeln('        return macos;');
    } else {
      _writeThrowUnsupportedForPlatform(kMacos, '        ');
    }
  }

  void _writeCurrentPlatformSwitchWindows() {
    _stringBuffer.writeln('      case TargetPlatform.windows:');
    if (windowsOptions != null) {
      _stringBuffer.writeln('        return windows;');
    } else {
      _writeThrowUnsupportedForPlatform(kWindows, '        ');
    }
  }

  void _writeCurrentPlatformSwitchLinux() {
    _stringBuffer.writeln('      case TargetPlatform.linux:');
    if (linuxOptions != null) {
      _stringBuffer.writeln('        return linux;');
    } else {
      _writeThrowUnsupportedForPlatform(kLinux, '        ');
    }
  }
}

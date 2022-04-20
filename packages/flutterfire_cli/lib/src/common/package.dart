/*
 * Copyright (c) 2020-present Invertase Limited & Contributors
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
import 'package:pubspec/pubspec.dart';
import 'strings.dart';
import 'utils.dart';

/// Enum representing what type of package this is.
enum PackageType {
  dartPackage,
  flutterPackage,
  flutterPlugin,
  flutterApp,
}

/// A representation of a dart package.
class Package {
  Package({
    required this.path,
    required this.pubSpec,
  });

  List<String> get devDependencies {
    return pubSpec.devDependencies.keys.toList();
  }

  List<String> get dependencies {
    return pubSpec.dependencies.keys.toList();
  }

  final String path;
  final PubSpec pubSpec;

  /// Loads the package located in the [projectDirectory]
  static Future<Package> load(Directory projectDirectory) async {
    if (!File(pubspecPathForDirectory(projectDirectory)).existsSync()) {
      throw FlutterAppRequiredException();
    }
    final pubSpec = await PubSpec.load(projectDirectory);
    return Package(
      path: projectDirectory.path,
      pubSpec: pubSpec,
    );
  }

  /// Type of this package, e.g. [PackageType.flutterApp].
  PackageType get type {
    if (isFlutterApp) return PackageType.flutterApp;
    if (isFlutterPlugin) return PackageType.flutterPlugin;
    if (isFlutterPackage) return PackageType.flutterPackage;
    return PackageType.dartPackage;
  }

  /// Returns whether this package is for Flutter.
  /// This is determined by whether the package depends on the Flutter SDK.
  late final bool isFlutterPackage = dependencies.contains('flutter') ||
      dependencies.contains('flutter_localizations');

  /// Returns whether this package is a Flutter app.
  /// This is determined by ensuring all the following conditions are met:
  ///  a) the package depends on the Flutter SDK.
  ///  b) the package does not define itself as a Flutter plugin inside pubspec.yaml.
  ///  c) a lib/main.dart file exists in the package.
  bool get isFlutterApp {
    // Must directly depend on the Flutter SDK.
    if (!isFlutterPackage) return false;

    // Must not have a Flutter plugin definition in it's pubspec.yaml.
    if (isFlutterPlugin) return false;

    return true;
  }

  /// Returns whether this package is a Flutter plugin.
  /// This is determined by whether the pubspec contains a flutter.plugin definition.
  bool get isFlutterPlugin => pubSpec.flutter?.isPlugin ?? false;
}

extension on PubSpec {
  Flutter? get flutter => (unParsedYaml?['flutter'] as Map<Object?, Object?>?)
      .let((value) => Flutter(value));
}

class Flutter {
  Flutter(this._flutter);

  final Map<Object?, Object?> _flutter;

  bool get isPlugin => _flutter['plugin'] != null;
}

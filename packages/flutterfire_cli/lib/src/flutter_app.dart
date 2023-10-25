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

import 'common/package.dart';
import 'common/platform.dart';
import 'common/strings.dart';
import 'common/utils.dart';

class FlutterApp {
  FlutterApp({
    required this.package,
  });

  /// The underlying dart package representation for this Flutter Apps
  /// pubspec.yaml.
  final Package package;

  /// Loads the Flutter app located in the [appDirectory]
  static Future<FlutterApp?> load(Directory appDirectory) async {
    if (!File(pubspecPathForDirectory(appDirectory)).existsSync()) {
      throw FlutterAppRequiredException();
    }
    final package = await Package.load(appDirectory);
    if (!package.isFlutterApp) {
      return null;
    }
    return FlutterApp(
      package: package,
    );
  }

  // Cached Android package name if available.
  String? _androidApplicationId;

  // Cached iOS bundle identifier if available.
  String? _iosBundleId;

  String? get iosBundleId {
    if (!ios) return null;
    if (_iosBundleId != null) {
      return _iosBundleId;
    }
    return _iosBundleId = _readBundleIdForPlatform(kIos);
  }

  // Cached macOS bundle identifier if available.
  String? _macosBundleId;

  String? get macosBundleId {
    if (!macos) return null;
    if (_macosBundleId != null) {
      return _macosBundleId;
    }
    return _macosBundleId = _readBundleIdForPlatform(kMacos);
  }

  String? _readBundleIdForPlatform(String platform) {
    final xcodeProjFile =
        xcodeProjectFileInDirectory(Directory(package.path), platform);
    final xcodeAppInfoConfigFile =
        xcodeAppInfoConfigFileInDirectory(Directory(package.path), platform);
    final bundleIdRegex = RegExp(
      r'''^[\s]*PRODUCT_BUNDLE_IDENTIFIER\s=\s(?<bundleId>[A-Za-z\d_\-\.]+)[;]*$''',
      multiLine: true,
    );

    // Check AppInfo.xcconfig file first. It doesn't exist for iOS, but macOS has it with correct value.
    // macOS project.pbxproj file contains incorrect PRODUCT_BUNDLE_IDENTIFIER value (e.g. some.project.RunnerTests).
    // iOS will skip this check and will use project.pbxproj file.
    if (xcodeAppInfoConfigFile.existsSync()) {
      final fileContents = xcodeAppInfoConfigFile.readAsStringSync();
      // TODO there can be multiple matches, e.g. build variants,
      //      perhaps we should build a set and prompt for a choice?
      final match = bundleIdRegex.firstMatch(fileContents);
      if (match != null) {
        return match.namedGroup('bundleId');
      }
    }

    if (xcodeProjFile.existsSync()) {
      final fileContents = xcodeProjFile.readAsStringSync();
      // TODO there can be multiple matches, e.g. build variants,
      //      perhaps we should build a set and prompt for a choice?
      final match = bundleIdRegex.firstMatch(fileContents);
      if (match != null) {
        return match.namedGroup('bundleId');
      }
    }

    return null;
  }

  /// The Android Application (or Package Name) for this Flutter
  /// application, or null if one could not be detected or the app
  /// does not target Android as a supported platform.
  String? get androidApplicationId {
    if (!android) return null;
    if (_androidApplicationId != null) {
      return _androidApplicationId;
    }

    String? applicationId;

    // Try extract via android/app/build.gradle
    final appGradleFile = File(
      androidAppBuildGradlePathForAppDirectory(
        Directory(package.path),
      ),
    );
    if (appGradleFile.existsSync()) {
      final fileContents = appGradleFile.readAsStringSync();
      final appIdRegex = RegExp(
        r'''applicationId\s['"]{1}(?<applicationId>([A-Za-z]{1}[A-Za-z\d_]*\.)+[A-Za-z][A-Za-z\d_]*)['"]{1}''',
      );
      final match = appIdRegex.firstMatch(fileContents);
      if (match != null) {
        applicationId = match.namedGroup('applicationId');
      }
    }

    // Try extract via android/app/src/main/AndroidManifest.xml
    if (applicationId == null) {
      final androidManifestFile = File(
        androidManifestPathForAppDirectory(
          Directory(package.path),
        ),
      );
      if (androidManifestFile.existsSync()) {
        final fileContents = androidManifestFile.readAsStringSync();
        final appIdRegex = RegExp(
          r'''package="(?<applicationId>([A-Za-z]{1}[A-Za-z\d_]*\.)+[A-Za-z][A-Za-z\d_]*)"''',
        );
        final match = appIdRegex.firstMatch(fileContents);
        if (match != null) {
          applicationId = match.namedGroup('applicationId');
        }
      }
    }

    return _androidApplicationId = applicationId;
  }

  /// Returns whether the package depends on the given package.
  bool dependsOnPackage(String packageName) {
    return package.dependencies.contains(packageName) ||
        package.devDependencies.contains(packageName);
  }

  /// Returns whether this Flutter app can run on Android.
  bool get android {
    if (!package.isFlutterApp) return false;
    return _supportsPlatform(kAndroid);
  }

  /// Returns the directory where the Android platform specific project exists.
  Directory get androidDirectory {
    return _platformDirectory(kAndroid);
  }

  /// Returns whether this Flutter app can run on Web.
  bool get web {
    if (!package.isFlutterApp) return false;
    return _supportsPlatform(kWeb);
  }

  /// Returns the directory where the Web platform specific project exists.
  Directory get webDirectory {
    return _platformDirectory(kWeb);
  }

  /// Returns whether this Flutter app can run on Windows.
  bool get windows {
    if (!package.isFlutterApp) return false;
    return _supportsPlatform(kWindows);
  }

  /// Returns the directory where the Windows platform specific project exists.
  Directory get windowsDirectory {
    return _platformDirectory(kWindows);
  }

  /// Returns whether this Flutter app can run on MacOS.
  bool get macos {
    if (!package.isFlutterApp) return false;
    return _supportsPlatform(kMacos);
  }

  /// Returns the directory where the macOS platform specific project exists.
  Directory get macosDirectory {
    return _platformDirectory(kMacos);
  }

  /// Returns whether this Flutter app can run on iOS.
  bool get ios {
    if (!package.isFlutterApp) return false;
    return _supportsPlatform(kIos);
  }

  /// Returns the directory where the iOS platform specific project exists.
  Directory get iosDirectory {
    return _platformDirectory(kIos);
  }

  /// Returns whether this Flutter app can run on Linux.
  bool get linux {
    if (!package.isFlutterApp) return false;
    return _supportsPlatform(kLinux);
  }

  /// Returns the directory where the Linux platform specific project exists.
  Directory get linuxDirectory {
    return _platformDirectory(kLinux);
  }

  Directory _platformDirectory(String platform) {
    assert(
      platform == kIos ||
          platform == kAndroid ||
          platform == kWeb ||
          platform == kMacos ||
          platform == kWindows ||
          platform == kLinux,
    );
    return Directory(
      '${package.path}${currentPlatform.pathSeparator}$platform',
    );
  }

  bool _supportsPlatform(String platform) {
    return _platformDirectory(platform).existsSync();
  }
}

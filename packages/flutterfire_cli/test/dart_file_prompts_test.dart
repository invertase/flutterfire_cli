import 'package:flutterfire_cli/src/common/prompts/dart_file_prompts.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {});

  tearDown(() {});

  test('getFirebaseConfigurationFile concatenates app path and config file', () async {
    const configFile = 'configfile.dart';
    const flutterAppPath = '/Users/username/Projects/flutter_app';

    final firebaseConfigurationFile =
        getFirebaseConfigurationFile(configurationFilePath: configFile, flutterAppPath: flutterAppPath);

    expect(firebaseConfigurationFile, equals('/Users/username/Projects/flutter_app/configfile.dart'));
  });

  test(
      'When configuration file path is absolute, getFirebaseConfigurationFile does not concatenate app path and config file',
      () async {
    const configFile = '/Users/username/Projects/test/configfile.dart';
    const flutterAppPath = '/Users/username/Projects/flutter_app';

    final firebaseConfigurationFile =
        getFirebaseConfigurationFile(configurationFilePath: configFile, flutterAppPath: flutterAppPath);

    expect(firebaseConfigurationFile, equals(configFile));
  });
}

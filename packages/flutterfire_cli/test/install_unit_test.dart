import 'package:args/args.dart';
import 'package:flutterfire_cli/src/commands/install.dart';
import 'package:test/test.dart';

import '../bin/flutterfire.dart';

void main() {
  group('install plugin selection', () {
    test('maps prompt indexes against the available plugins', () {
      final availablePlugins = [
        for (final plugin in FlutterFirePlugins.values)
          if (plugin != FlutterFirePlugins.dynamicLinks) plugin,
      ];

      expect(pluginsFromSelectionIndexes(availablePlugins, [9, 10, 13]), [
        FlutterFirePlugins.inAppMessaging,
        FlutterFirePlugins.messaging,
        FlutterFirePlugins.remoteConfig,
      ]);
    });
  });

  group('install version arguments', () {
    final parser = ArgParser()
      ..addOption('version')
      ..addFlag('only-pubspec-plugins', negatable: false);

    test('accepts a positional version with options', () {
      final results = parser.parse(['4.17.1', '--only-pubspec-plugins']);

      expect(bomVersionFromArguments(results), '4.17.1');
    });

    test('accepts the command version option', () {
      final results = parser.parse(['--version', '4.17.1']);

      expect(bomVersionFromArguments(results), '4.17.1');
    });

    test(
      'only treats a standalone global version flag as a CLI version request',
      () {
        expect(isCliVersionRequest(['--version']), isTrue);
        expect(isCliVersionRequest(['-v']), isTrue);
        expect(
          isCliVersionRequest(['install', '--version', '4.17.1']),
          isFalse,
        );
      },
    );
  });
}

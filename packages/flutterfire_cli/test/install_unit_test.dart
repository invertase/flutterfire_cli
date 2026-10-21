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

    test('maps selections when multiple earlier plugins are unavailable', () {
      final availablePlugins = [
        FlutterFirePlugins.core,
        FlutterFirePlugins.messaging,
        FlutterFirePlugins.storage,
      ];

      expect(pluginsFromSelectionIndexes(availablePlugins, [1, 2]), [
        FlutterFirePlugins.messaging,
        FlutterFirePlugins.storage,
      ]);
    });

    test('allows an empty selection', () {
      expect(
        pluginsFromSelectionIndexes([FlutterFirePlugins.core], []),
        isEmpty,
      );
    });

    test('ignores installed plugins unavailable in the selected BoM', () {
      expect(
        defaultPluginSelection(
          [FlutterFirePlugins.core, FlutterFirePlugins.messaging],
          ['firebase_dynamic_links', 'firebase_messaging', 'other_package'],
        ),
        [true, true],
      );
    });

    test('preselects core without selecting other uninstalled plugins', () {
      expect(
        defaultPluginSelection(
          [FlutterFirePlugins.core, FlutterFirePlugins.messaging],
          [],
        ),
        [true, false],
      );
    });
  });

  group('install version arguments', () {
    final parser = InstallCommand(null).argParser;

    test('accepts a positional version with options', () {
      final results = parser.parse(['4.17.1', '--only-pubspec-plugins']);

      expect(bomVersionFromArguments(results), '4.17.1');
    });

    test('accepts the command version option', () {
      final results = parser.parse(['--version', '4.17.1']);

      expect(bomVersionFromArguments(results), '4.17.1');
    });

    test('accepts the equals form of the command version option', () {
      expect(
        bomVersionFromArguments(parser.parse(['--version=4.17.1'])),
        '4.17.1',
      );
    });

    test('accepts a positional version alongside explicit plugins', () {
      expect(
        bomVersionFromArguments(
          parser
              .parse(['4.17.1', '--plugins=firebase_core,firebase_messaging']),
        ),
        '4.17.1',
      );
    });

    test('returns null when no version is supplied', () {
      expect(bomVersionFromArguments(parser.parse([])), isNull);
      expect(
        bomVersionFromArguments(parser.parse(['--only-pubspec-plugins'])),
        isNull,
      );
    });

    test(
      'distinguishes the global version flag from the install version option',
      () {
        expect(isCliVersionRequest(['--version']), isTrue);
        expect(isCliVersionRequest(['-v']), isTrue);
        expect(isCliVersionRequest(['--verbose', '--version']), isTrue);
        expect(isCliVersionRequest(['--version', '--verbose']), isTrue);
        expect(isCliVersionRequest([]), isFalse);
        expect(
          isCliVersionRequest(['install', '--version', '4.17.1']),
          isFalse,
        );
        expect(isCliVersionRequest(['install', '--version=4.17.1']), isFalse);
        expect(isCliVersionRequest(['i', '--version', '4.17.1']), isFalse);
        expect(isCliVersionRequest(['install', '4.17.1']), isFalse);
        expect(isCliVersionRequest(['install', '--unknown']), isFalse);
      },
    );
  });
}

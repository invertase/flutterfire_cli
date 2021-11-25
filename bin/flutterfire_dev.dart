import '../packages/flutterfire_cli/bin/flutterfire.dart' as flutterfire;

// This allows us to use FlutterFire CLI during development.
void main(List<String> arguments) {
  if (arguments.contains('--help')) {
    // ignore_for_file: avoid_print
    print('------------------------------------------------------------------');
    print(
      '| You are running a local development version of FlutterFire CLI. |',
    );
    print('------------------------------------------------------------------');
    print('');
  }
  flutterfire.main(arguments);
}

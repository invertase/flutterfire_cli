import 'package:cli_util/cli_logging.dart';

bool _debugMode = false;

bool get debugMode => _debugMode;

void updateDebugMode(bool value) {
  _debugMode = value;
}

Logger get logger => debugMode ? Logger.verbose() : Logger.standard();

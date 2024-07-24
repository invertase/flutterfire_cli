import 'package:cli_util/cli_logging.dart';

bool debugMode = false;

void updateDebugMode(bool value) {
  debugMode = value;
}

Logger get logger => debugMode ? Logger.verbose() : Logger.standard();
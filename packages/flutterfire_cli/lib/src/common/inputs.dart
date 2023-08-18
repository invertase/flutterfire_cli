import 'utils.dart';

class DartConfigurationFileInputs {
  DartConfigurationFileInputs({
    required this.configurationFilePath,
    required this.writeConfigurationFile,
  });
  final String configurationFilePath;
  final bool writeConfigurationFile;
}

class AndroidInputs {
  AndroidInputs({
    this.serviceFilePath,
    required this.projectConfiguration,
  });
  final String? serviceFilePath;
  ProjectConfiguration projectConfiguration;
}

class AppleInputs {
  AppleInputs({
    this.buildConfiguration,
    this.target,
    required this.serviceFilePath,
    required this.projectConfiguration,
  });
  final String? buildConfiguration;
  final String? target;
  final String serviceFilePath;
  ProjectConfiguration projectConfiguration;
}

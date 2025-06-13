class FirebasePubSpecModel {
  const FirebasePubSpecModel({
    required this.googleServicesGradlePluginVersion,
    required this.crashlyticsGradlePluginVersion,
    required this.performanceGradlePluginVersion,
  });

  factory FirebasePubSpecModel.fromJson(Map<String, dynamic> json) {
    return FirebasePubSpecModel(
      googleServicesGradlePluginVersion: json['google_services_gradle_plugin_version'],
      crashlyticsGradlePluginVersion: json['crashlytics_gradle_plugin_version'],
      performanceGradlePluginVersion: json['performance_gradle_plugin_version'],
    );
  }

  final String googleServicesGradlePluginVersion;
  final String crashlyticsGradlePluginVersion;
  final String performanceGradlePluginVersion;
}
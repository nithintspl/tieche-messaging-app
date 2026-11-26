/// Map / geocoding API keys — pass at build/run time, never commit secrets.
///
/// Example:
/// `flutter run --dart-define=GEOAPIFY_API_KEY=... --dart-define=TOMTOM_API_KEY=...`
class MapsApiConfig {
  MapsApiConfig._();

  static const String geoapifyApiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: '',
  );

  static const String tomtomApiKey = String.fromEnvironment(
    'TOMTOM_API_KEY',
    defaultValue: '',
  );

  static bool get hasGeoapify => geoapifyApiKey.trim().isNotEmpty;

  static bool get hasTomtom => tomtomApiKey.trim().isNotEmpty;
}
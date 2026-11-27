/// Map / geocoding API keys — pass at build/run time, never commit secrets.
///
/// Example:
/// `flutter run --dart-define=GEOAPIFY_API_KEY=... --dart-define=TOMTOM_API_KEY=...`
class MapsApiConfig {
  MapsApiConfig._();

  static const String geoapifyApiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: 'e0a77673e3b144f1be9c94a9fe2d264e',
  );

  static const String tomtomApiKey = String.fromEnvironment(
    'TOMTOM_API_KEY',
    defaultValue: 'esUAEEEuOstCHl8Z7LUOrz3braPzywdN',
  );

  static bool get hasGeoapify => geoapifyApiKey.trim().isNotEmpty;

  static bool get hasTomtom => tomtomApiKey.trim().isNotEmpty;
}
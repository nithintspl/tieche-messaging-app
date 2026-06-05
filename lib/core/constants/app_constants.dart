class AppConstants {
  static const String appName = 'Masjid Omar Muhammad Moorpark';
  static const String appIconAsset = 'assets/icons/app_icon.png';

  // API Configuration
  // Use only apex host because some mobile DNS networks fail on `www`.
  static const List<String> apiBaseUrls = [
    'https://masjidomarmoorpark.com',
  ];
  static const String baseApiUrl = 'https://masjidomarmoorpark.com';

  // Organization Information
  static const String orgName = 'Masjid Omar Muhammad Moorpark';
  static const String orgAddress = '702 Walnut Street, Moorpark, CA 93021';
  static const String orgPhone = '(805) 304 5940 WhatsApp';
  static const String orgPhoneRaw = '+18053045940';
  static const String orgEmail = '8053045940@tmobile.com';

  // Map Coordinates
  static const double orgLatitude = 34.2818;
  static const double orgLongitude = -118.8741;

  // External URLs
  static const String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$orgLatitude,$orgLongitude';
  static const String telUrl = 'tel:$orgPhoneRaw';
  static const String emailUrl = 'mailto:$orgEmail?subject=Inquiry%20from%20Masjid Omar Muhammad Moorpark%20App';
}

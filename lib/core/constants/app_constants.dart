class AppConstants {
  static const String appName = 'Community Hub';

  // Organization Information
  static const String orgName = 'Green Community Organization';
  static const String orgAddress = '123 Faith & Community Blvd, Green Hills, GH 94025';
  static const String orgPhone = '+1 (234) 567-890';
  static const String orgPhoneRaw = '+1234567890';
  static const String orgEmail = 'info@greencommunity.org';

  // Map Coordinates (Googleplex for demonstration)
  static const double orgLatitude = 37.4220;
  static const double orgLongitude = -122.0841;

  // External URLs
  static const String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$orgLatitude,$orgLongitude';
  static const String telUrl = 'tel:$orgPhoneRaw';
  static const String emailUrl = 'mailto:$orgEmail?subject=Inquiry%20from%20Community%20App';
}

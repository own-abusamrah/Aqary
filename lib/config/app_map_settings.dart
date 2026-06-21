enum AppMapProvider {
  openStreetMap,
  googleMaps,
}

class AppMapSettings {
  AppMapSettings._();

  // Change this single value to switch all shared map widgets globally.
  static const AppMapProvider provider = AppMapProvider.googleMaps;

  static bool get useGoogleMaps => provider == AppMapProvider.googleMaps;
  static bool get useOpenStreetMap => provider == AppMapProvider.openStreetMap;
}

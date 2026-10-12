import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Adds the app's own notices to Flutter's licence page (Settings → Legal
/// notices): the bundled fonts and the Google Maps terms. Package licences
/// are listed automatically.
void registerAppLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const <String>[
      'Poppins',
      'Hind',
      'Hind Vadodara',
    ], await rootBundle.loadString('assets/fonts/LICENSE-OFL.txt'));
    yield const LicenseEntryWithLineBreaks(
      <String>['Google Maps'],
      '''
Maps, Street View and directions are provided by Google. Use of Google Maps
features is subject to the Google Maps/Google Earth Additional Terms of
Service (https://maps.google.com/help/terms_maps/) and the Google Privacy
Policy (https://policies.google.com/privacy).''',
    );
  });
}

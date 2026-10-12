// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jetalpur Dham';

  @override
  String get templeName => 'Shree Swaminarayan Mandir, Jetalpur Dham';

  @override
  String get templeShortName => 'Jetalpur Dham';

  @override
  String get deityName => 'Shree Revati Baldevji Harikrushna Maharaj';

  @override
  String get jaySwaminarayan => 'Jay Shree Swaminarayan';

  @override
  String get navHome => 'Home';

  @override
  String get navKirtan => 'Kirtan';

  @override
  String get navPlaces => 'Prasadi';

  @override
  String get navLibrary => 'Shastra';

  @override
  String get navEvents => 'Utsav';

  @override
  String get menu => 'Menu';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get downloading => 'Downloading…';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get search => 'Search';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get seeAll => 'See all';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get submit => 'Submit';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get readMore => 'Read more';

  @override
  String get showLess => 'Show less';

  @override
  String get all => 'All';

  @override
  String get loading => 'Loading…';

  @override
  String get back => 'Back';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'No internet connection. Please check your network.';

  @override
  String get errorOpenLink => 'Couldn\'t open the link';

  @override
  String get offlineBanner => 'You\'re offline. Showing saved content.';

  @override
  String get emptyGeneric => 'Nothing here yet';

  @override
  String get homeGreeting => 'Jay Shree Swaminarayan';

  @override
  String get homeHeroSubtitle => 'Shree Revati Baldevji Harikrushna Maharaj';

  @override
  String get homeExplore => 'Explore';

  @override
  String get featureKirtan => 'Kirtan';

  @override
  String get featureKirtanDesc => 'Listen & download';

  @override
  String get featurePlaces => 'Prasadi Places';

  @override
  String get featurePlacesDesc => 'Sacred places & mahima';

  @override
  String get featureGallery => 'Avsar 200';

  @override
  String get featureGalleryDesc => 'Utsav photos';

  @override
  String get featureLibrary => 'Shastra';

  @override
  String get featureLibraryDesc => 'Read holy scriptures';

  @override
  String get featureEvents => 'Utsav & Katha';

  @override
  String get featureEventsDesc => 'Upcoming & past events';

  @override
  String get featureDonate => 'Donate';

  @override
  String get featureDonateDesc => 'Offer seva to the temple';

  @override
  String get homeUpcomingTitle => 'Upcoming Utsav';

  @override
  String get homeFeaturedKirtans => 'Featured Kirtans';

  @override
  String get homeGalleryTitle => 'Avsar 200 Photos';

  @override
  String get homePlacesTitle => 'Prasadi Places';

  @override
  String get homeDonateTitle => 'Offer your seva';

  @override
  String get homeDonateBody =>
      'Support the daily seva, utsav and upkeep of Shree Jetalpur Dham.';

  @override
  String get homeDonateCta => 'Donate now';

  @override
  String get homeDarshanTimings => 'Darshan Timings';

  @override
  String get drawerDownloads => 'My Downloads';

  @override
  String get drawerGallery => 'Photo Gallery';

  @override
  String get drawerAbout => 'About Temple';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerShareApp => 'Share App';

  @override
  String get drawerContact => 'Contact Us';

  @override
  String get kirtanTitle => 'Kirtan';

  @override
  String get kirtanSearchHint => 'Search kirtan, poet or singer';

  @override
  String kirtanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kirtans',
      one: '1 kirtan',
      zero: 'No kirtans',
    );
    return '$_temp0';
  }

  @override
  String get kirtanNoResults => 'No kirtan found';

  @override
  String get kirtanEmpty => 'Kirtans will be added soon.';

  @override
  String get kirtanNowPlaying => 'Now Playing';

  @override
  String get kirtanLyrics => 'Lyrics';

  @override
  String get kirtanNoLyrics => 'Lyrics are not available for this kirtan.';

  @override
  String get kirtanPoet => 'Poet';

  @override
  String get kirtanSinger => 'Singer';

  @override
  String get kirtanDownloads => 'Downloaded Kirtans';

  @override
  String get kirtanDownloadsEmpty =>
      'Tap the download icon on any kirtan to listen offline, without internet.';

  @override
  String get kirtanPlayAll => 'Play all';

  @override
  String get kirtanShuffle => 'Shuffle';

  @override
  String get kirtanRepeat => 'Repeat';

  @override
  String get kirtanRepeatOne => 'Repeat one';

  @override
  String get kirtanRepeatOff => 'Repeat off';

  @override
  String get kirtanQueue => 'Up next';

  @override
  String get kirtanRemoveDownload => 'Remove download';

  @override
  String get kirtanDownloadFailed => 'Download failed. Please try again.';

  @override
  String get kirtanDownloadComplete => 'Saved for offline listening';

  @override
  String get kirtanPlaybackError => 'Unable to play this kirtan right now.';

  @override
  String get kirtanAvailableOffline => 'Available offline';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepTimerOff => 'Off';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get sleepTimerEndOfTrack => 'End of kirtan';

  @override
  String get playbackSpeed => 'Speed';

  @override
  String get kirtanCancelDownload => 'Cancel download';

  @override
  String get kirtanRemoveDownloadConfirm =>
      'Remove this kirtan from your phone? You can download it again anytime.';

  @override
  String kirtanSleepTimerRemaining(String time) {
    return 'Stops in $time';
  }

  @override
  String get kirtanSpeedNormal => 'Normal';

  @override
  String get kirtanOfflineUnavailable =>
      'You\'re offline. Downloaded kirtans play without internet.';

  @override
  String get kirtanBrowse => 'Browse kirtans';

  @override
  String get placesTitle => 'Prasadi Places';

  @override
  String get placesSubtitle => 'Places blessed by Shree Swaminarayan Bhagwan';

  @override
  String get placesMapView => 'Map';

  @override
  String get placesListView => 'List';

  @override
  String get placeMahima => 'Mahima';

  @override
  String get placeDirections => 'Directions';

  @override
  String get placeStreetView => 'Street View';

  @override
  String get placeView360 => '360° Darshan';

  @override
  String get placePhotos => 'Photos';

  @override
  String get placeAddress => 'Address';

  @override
  String get placesEmpty => 'Prasadi places will be added soon.';

  @override
  String get place360Hint => 'Drag or move your phone to look around';

  @override
  String get placeOpenInMaps => 'Open in Google Maps';

  @override
  String get placeNotFound => 'This place is no longer available.';

  @override
  String get placeCategoryTemple => 'Temple';

  @override
  String get placeCategoryYagna => 'Yagna';

  @override
  String get placeCategoryWater => 'Vav / Talav';

  @override
  String get placeCategoryTree => 'Prasadi Tree';

  @override
  String get placeCategoryResidence => 'Residence';

  @override
  String get placeCategoryOther => 'Sacred Place';

  @override
  String get placesShowAll => 'Show all places';

  @override
  String get placesSatellite => 'Satellite';

  @override
  String get placesTapForMahima => 'Tap to read the mahima';

  @override
  String get places360Badge => '360°';

  @override
  String get places360Loading => 'Preparing 360° darshan…';

  @override
  String get placesMotionControl => 'Move phone to look around';

  @override
  String placesPanoramaNumber(int number) {
    return 'View $number';
  }

  @override
  String placesShareMessage(String name) {
    return 'Jay Shree Swaminarayan! Prasadi place of Shree Jetalpur Dham – $name';
  }

  @override
  String get galleryTitle => 'Photo Gallery';

  @override
  String get galleryAlbums => 'Albums';

  @override
  String galleryPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
      zero: 'No photos',
    );
    return '$_temp0';
  }

  @override
  String get gallerySave => 'Save to Gallery';

  @override
  String get gallerySaved => 'Saved to your gallery';

  @override
  String gallerySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos saved',
      one: '1 photo saved',
    );
    return '$_temp0';
  }

  @override
  String get gallerySaveFailed => 'Couldn\'t save the photo. Please try again.';

  @override
  String get galleryPermissionDenied =>
      'Please allow photo access in Settings to save images.';

  @override
  String get gallerySelect => 'Select';

  @override
  String get gallerySelectAll => 'Select all';

  @override
  String gallerySelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get gallerySaving => 'Saving…';

  @override
  String get galleryEmpty => 'Photos will be added soon.';

  @override
  String get galleryAlbumNotFound => 'This album is no longer available.';

  @override
  String gallerySaveSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $count photos',
      one: 'Save 1 photo',
    );
    return '$_temp0';
  }

  @override
  String gallerySavingProgress(int done, int total) {
    return 'Saving $done of $total…';
  }

  @override
  String galleryNotSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos couldn\'t be saved',
      one: '1 photo couldn\'t be saved',
    );
    return '$_temp0';
  }

  @override
  String get galleryClearSelection => 'Clear selection';

  @override
  String get gallerySelectHint => 'Tap photos to select them';

  @override
  String galleryShareText(String album) {
    return 'Jay Shree Swaminarayan! $album – Shree Swaminarayan Mandir, Jetalpur Dham';
  }

  @override
  String galleryPhotoLabel(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String get galleryPhotoLoadFailed => 'Couldn\'t load this photo';

  @override
  String get libraryTitle => 'Shastra Library';

  @override
  String get librarySearchHint => 'Search scriptures';

  @override
  String get libraryRead => 'Read';

  @override
  String get libraryDownloadForOffline => 'Download for offline';

  @override
  String get libraryRemoveDownload => 'Remove download';

  @override
  String libraryPages(int count) {
    return '$count pages';
  }

  @override
  String get libraryAuthor => 'Author';

  @override
  String get libraryLanguage => 'Language';

  @override
  String get libraryEmpty => 'Scriptures will be added soon.';

  @override
  String get libraryNoResults => 'No scripture found';

  @override
  String get libraryContinueReading => 'Continue reading';

  @override
  String get libraryBookNotFound => 'This book is no longer available.';

  @override
  String get readerGoToPage => 'Go to page';

  @override
  String readerPageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get readerOpenFailed => 'Couldn\'t open this book. Please try again.';

  @override
  String get readerPreparing => 'Preparing book…';

  @override
  String readerInvalidPage(int total) {
    return 'Enter a page between 1 and $total';
  }

  @override
  String get langGujarati => 'Gujarati';

  @override
  String get langHindi => 'Hindi';

  @override
  String get langEnglish => 'English';

  @override
  String get langSanskrit => 'Sanskrit';

  @override
  String libraryContinueFromPage(int page) {
    return 'Continue reading · Page $page';
  }

  @override
  String libraryPageNumber(int page) {
    return 'Page $page';
  }

  @override
  String libraryDownloadWithSize(String size) {
    return 'Download for offline · $size';
  }

  @override
  String libraryDownloadingProgress(String percent) {
    return 'Downloading… $percent';
  }

  @override
  String get libraryAvailableOffline => 'Available offline';

  @override
  String get libraryRemoveDownloadConfirm =>
      'Remove this book from your phone? You can download it again anytime.';

  @override
  String get libraryDownloadComplete => 'Saved for offline reading';

  @override
  String get libraryDownloadFailed => 'Download failed. Please try again.';

  @override
  String get libraryCancelDownload => 'Cancel download';

  @override
  String get libraryDownloadedEmpty =>
      'Books you download will appear here, ready to read without internet.';

  @override
  String get libraryAboutBook => 'About this scripture';

  @override
  String libraryReaderPageInputLabel(int total) {
    return 'Page number (1 – $total)';
  }

  @override
  String get libraryReaderGo => 'Go';

  @override
  String get libraryReaderNeedsInternet =>
      'This book isn\'t downloaded yet. Please connect to the internet to read it.';

  @override
  String get eventsTitle => 'Utsav & Events';

  @override
  String get eventsUpcoming => 'Upcoming';

  @override
  String get eventsPast => 'Past';

  @override
  String get eventsEmptyUpcoming =>
      'No upcoming utsav right now. We\'ll notify you!';

  @override
  String get eventsEmptyPast => 'No past events yet.';

  @override
  String get eventDate => 'Date';

  @override
  String get eventTime => 'Time';

  @override
  String get eventLocation => 'Venue';

  @override
  String get eventViewPhotos => 'View Photos';

  @override
  String get eventWatchLive => 'Watch Live';

  @override
  String get eventToday => 'Today';

  @override
  String get eventTomorrow => 'Tomorrow';

  @override
  String get eventOngoing => 'Ongoing';

  @override
  String eventInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String get eventTypeUtsav => 'Utsav';

  @override
  String get eventTypeKatha => 'Katha';

  @override
  String get eventTypeAnnouncement => 'Announcement';

  @override
  String get eventTypeOther => 'Event';

  @override
  String get eventNotFound => 'This event is no longer available.';

  @override
  String get notificationPermissionTitle => 'Stay updated';

  @override
  String get notificationPermissionBody =>
      'Get notified about upcoming utsav, katha and temple updates.';

  @override
  String get notificationAllow => 'Continue';

  @override
  String get notificationLater => 'Not now';

  @override
  String get notificationChannelName => 'Utsav & Katha updates';

  @override
  String get notificationChannelDesc =>
      'Notifications about upcoming utsav, katha and temple news';

  @override
  String get eventsBrowseAll => 'See all utsav';

  @override
  String get eventsDetails => 'Details';

  @override
  String eventsIndiaTime(String time) {
    return '$time (India time)';
  }

  @override
  String get donateTitle => 'Donate';

  @override
  String get donateHeadline => 'Offer Your Seva';

  @override
  String get donateSubtitle =>
      'Your offering supports the daily seva, utsav and upkeep of Shree Jetalpur Dham.';

  @override
  String get donateScanQr => 'Scan & Pay';

  @override
  String get donateScanQrHint =>
      'Scan with any UPI app — Google Pay, PhonePe, Paytm or BHIM';

  @override
  String get donatePayWithUpi => 'Pay with UPI app';

  @override
  String get donateUpiId => 'UPI ID';

  @override
  String get donateBankDetails => 'Bank Transfer';

  @override
  String get donateAccountName => 'Account name';

  @override
  String get donateAccountNumber => 'Account number';

  @override
  String get donateIfsc => 'IFSC code';

  @override
  String get donateBankName => 'Bank';

  @override
  String get donateBranch => 'Branch';

  @override
  String get donateAccountType => 'Account type';

  @override
  String get donateCopyAll => 'Copy all details';

  @override
  String get donateContactNow => 'Contact Now';

  @override
  String get donateContactSubtitle =>
      'Made an offering? Share the details so the temple can confirm it and send you a receipt.';

  @override
  String get donateFormTitle => 'Share Donation Details';

  @override
  String get donateName => 'Full name';

  @override
  String get donatePhone => 'Mobile number';

  @override
  String get donateEmail => 'Email (optional)';

  @override
  String get donateAmount => 'Amount (₹)';

  @override
  String get donatePurpose => 'Purpose';

  @override
  String get donateMethod => 'Payment method';

  @override
  String get donateMethodUpi => 'UPI';

  @override
  String get donateMethodBank => 'Bank transfer';

  @override
  String get donateMethodCash => 'Cash';

  @override
  String get donateMethodCheque => 'Cheque';

  @override
  String get donateMethodOther => 'Other';

  @override
  String get donateTxnRef => 'Transaction / UTR no. (optional)';

  @override
  String get donateMessage => 'Message (optional)';

  @override
  String get donateSubmit => 'Submit details';

  @override
  String get donateSubmitting => 'Submitting…';

  @override
  String get donateSuccessTitle => 'Thank you!';

  @override
  String get donateSuccessBody =>
      'Your details have been received. The temple office will contact you soon. Jay Shree Swaminarayan!';

  @override
  String get donateRequired => 'This field is required';

  @override
  String get donateInvalidPhone => 'Enter a valid 10-digit mobile number';

  @override
  String get donateInvalidAmount => 'Enter a valid amount';

  @override
  String get donateInvalidEmail => 'Enter a valid email address';

  @override
  String get donateCall => 'Call';

  @override
  String get donateWhatsApp => 'WhatsApp';

  @override
  String get donateUnavailable => 'Donation details will be available soon.';

  @override
  String get donateSaveQr => 'Save QR';

  @override
  String get donateNoUpiApp =>
      'No UPI app found on this device. Please scan the QR code instead.';

  @override
  String get donateWebsiteMessage =>
      'Seva offerings are made on the temple website.';

  @override
  String get donateWebsiteButton => 'Donate on the temple website';

  @override
  String get donateContactOffice =>
      'To offer seva, please contact the temple office.';

  @override
  String get donatePurposeGeneral => 'General seva';

  @override
  String get donateInvalidName => 'Please enter your full name';

  @override
  String get donateQrLabel => 'Donation QR code';

  @override
  String get donateQrSaved => 'QR code saved to your photos';

  @override
  String get donateQrPermissionDenied =>
      'Please allow photo access in Settings to save the QR code.';

  @override
  String donateCopyLabel(String label) {
    return 'Copy $label';
  }

  @override
  String get donateEmailButton => 'Email';

  @override
  String get donateWhatsAppMessage =>
      'Jay Shree Swaminarayan! I would like to know about offering seva (donation) at Shree Jetalpur Dham.';

  @override
  String get donateSuccessQueued =>
      'Your details are saved on this phone and will reach the temple automatically as soon as the internet is available. The temple office will then contact you. Jay Shree Swaminarayan!';

  @override
  String get donateRememberHint =>
      'Your name and number are remembered on this phone for next time.';

  @override
  String get aboutTitle => 'About Temple';

  @override
  String get aboutHistory => 'History';

  @override
  String get aboutDarshanTimings => 'Darshan Timings';

  @override
  String get aboutAddress => 'Address';

  @override
  String get aboutContact => 'Contact';

  @override
  String get aboutCall => 'Call';

  @override
  String get aboutEmail => 'Email';

  @override
  String get aboutWebsite => 'Website';

  @override
  String get aboutWhatsApp => 'WhatsApp';

  @override
  String get aboutFollowUs => 'Follow us';

  @override
  String get aboutGetDirections => 'Get directions';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsNotifications => 'Utsav notifications';

  @override
  String get settingsNotificationsDesc =>
      'Get alerts for upcoming utsav & katha';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsDownloadedKirtans => 'Downloaded kirtans';

  @override
  String get settingsDownloadedBooks => 'Downloaded books';

  @override
  String get settingsStreamCache => 'Kirtan listening cache';

  @override
  String get settingsStreamCacheDesc =>
      'Kirtans you have heard, kept for instant replay';

  @override
  String get settingsClearCache => 'Clear image cache';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsRemoveAll => 'Remove all';

  @override
  String get settingsConfirmDelete =>
      'Remove all downloaded files? You can download them again anytime.';

  @override
  String settingsAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsLegalNotices => 'Legal notices & licences';

  @override
  String get settingsCrashReports => 'Share crash reports';

  @override
  String get settingsCrashReportsDesc =>
      'Helps fix problems in the app. Never includes your name, phone or e-mail.';

  @override
  String get donatePrivacyNotice =>
      'Your details go only to the temple office, to confirm your offering and send a receipt.';

  @override
  String get donateClearSaved => 'Clear saved details';

  @override
  String get donateSavedCleared => 'Saved details removed from this phone';

  @override
  String get demoBadge => 'Demo';

  @override
  String get demoIntroTitle => 'Welcome to the demo';

  @override
  String get demoIntroBody =>
      'This is a preview of the Jetalpur Dham app. The temple history, the prasadi places and their mahima are real; the photos, kirtan audio, shastra PDF and most utsavs are only samples.';

  @override
  String get demoIntroDisabled =>
      'Notifications and the map are turned off in this demo. The donation details are samples too, so please do not send money to them.';

  @override
  String get demoIntroStart => 'Start exploring';

  @override
  String get settingsAboutApp => 'About app';

  @override
  String get settingsSendFeedback => 'Send feedback';

  @override
  String get settingsSendFeedbackDesc => 'Report a problem or share an idea';

  @override
  String get settingsFeedbackSubject => 'Feedback on the Jetalpur Dham app';

  @override
  String shareAppMessage(String link) {
    return 'Jay Shree Swaminarayan! Experience Shree Jetalpur Dham — kirtan, prasadi places, shastra and utsav updates in one app. $link';
  }
}

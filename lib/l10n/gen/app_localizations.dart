import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Jetalpur Dham'**
  String get appTitle;

  /// No description provided for @templeName.
  ///
  /// In en, this message translates to:
  /// **'Shree Swaminarayan Mandir, Jetalpur Dham'**
  String get templeName;

  /// No description provided for @templeShortName.
  ///
  /// In en, this message translates to:
  /// **'Jetalpur Dham'**
  String get templeShortName;

  /// No description provided for @deityName.
  ///
  /// In en, this message translates to:
  /// **'Shree Revati Baldevji Harikrushna Maharaj'**
  String get deityName;

  /// No description provided for @jaySwaminarayan.
  ///
  /// In en, this message translates to:
  /// **'Jay Shree Swaminarayan'**
  String get jaySwaminarayan;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navKirtan.
  ///
  /// In en, this message translates to:
  /// **'Kirtan'**
  String get navKirtan;

  /// No description provided for @navPlaces.
  ///
  /// In en, this message translates to:
  /// **'Prasadi'**
  String get navPlaces;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Shastra'**
  String get navLibrary;

  /// No description provided for @navEvents.
  ///
  /// In en, this message translates to:
  /// **'Utsav'**
  String get navEvents;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloading;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network.'**
  String get errorNetwork;

  /// No description provided for @errorOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get errorOpenLink;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing saved content.'**
  String get offlineBanner;

  /// No description provided for @emptyGeneric.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyGeneric;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Jay Shree Swaminarayan'**
  String get homeGreeting;

  /// No description provided for @homeHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shree Revati Baldevji Harikrushna Maharaj'**
  String get homeHeroSubtitle;

  /// No description provided for @homeExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get homeExplore;

  /// No description provided for @featureKirtan.
  ///
  /// In en, this message translates to:
  /// **'Kirtan'**
  String get featureKirtan;

  /// No description provided for @featureKirtanDesc.
  ///
  /// In en, this message translates to:
  /// **'Listen & download'**
  String get featureKirtanDesc;

  /// No description provided for @featurePlaces.
  ///
  /// In en, this message translates to:
  /// **'Prasadi Places'**
  String get featurePlaces;

  /// No description provided for @featurePlacesDesc.
  ///
  /// In en, this message translates to:
  /// **'Sacred places & mahima'**
  String get featurePlacesDesc;

  /// No description provided for @featureGallery.
  ///
  /// In en, this message translates to:
  /// **'Avsar 200'**
  String get featureGallery;

  /// No description provided for @featureGalleryDesc.
  ///
  /// In en, this message translates to:
  /// **'Utsav photos'**
  String get featureGalleryDesc;

  /// No description provided for @featureLibrary.
  ///
  /// In en, this message translates to:
  /// **'Shastra'**
  String get featureLibrary;

  /// No description provided for @featureLibraryDesc.
  ///
  /// In en, this message translates to:
  /// **'Read holy scriptures'**
  String get featureLibraryDesc;

  /// No description provided for @featureEvents.
  ///
  /// In en, this message translates to:
  /// **'Utsav & Katha'**
  String get featureEvents;

  /// No description provided for @featureEventsDesc.
  ///
  /// In en, this message translates to:
  /// **'Upcoming & past events'**
  String get featureEventsDesc;

  /// No description provided for @featureDonate.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get featureDonate;

  /// No description provided for @featureDonateDesc.
  ///
  /// In en, this message translates to:
  /// **'Offer seva to the temple'**
  String get featureDonateDesc;

  /// No description provided for @homeUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Utsav'**
  String get homeUpcomingTitle;

  /// No description provided for @homeFeaturedKirtans.
  ///
  /// In en, this message translates to:
  /// **'Featured Kirtans'**
  String get homeFeaturedKirtans;

  /// No description provided for @homeGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Avsar 200 Photos'**
  String get homeGalleryTitle;

  /// No description provided for @homePlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prasadi Places'**
  String get homePlacesTitle;

  /// No description provided for @homeDonateTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer your seva'**
  String get homeDonateTitle;

  /// No description provided for @homeDonateBody.
  ///
  /// In en, this message translates to:
  /// **'Support the daily seva, utsav and upkeep of Shree Jetalpur Dham.'**
  String get homeDonateBody;

  /// No description provided for @homeDonateCta.
  ///
  /// In en, this message translates to:
  /// **'Donate now'**
  String get homeDonateCta;

  /// No description provided for @homeDarshanTimings.
  ///
  /// In en, this message translates to:
  /// **'Darshan Timings'**
  String get homeDarshanTimings;

  /// No description provided for @drawerDownloads.
  ///
  /// In en, this message translates to:
  /// **'My Downloads'**
  String get drawerDownloads;

  /// No description provided for @drawerGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo Gallery'**
  String get drawerGallery;

  /// No description provided for @drawerAbout.
  ///
  /// In en, this message translates to:
  /// **'About Temple'**
  String get drawerAbout;

  /// No description provided for @drawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettings;

  /// No description provided for @drawerShareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get drawerShareApp;

  /// No description provided for @drawerContact.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get drawerContact;

  /// No description provided for @kirtanTitle.
  ///
  /// In en, this message translates to:
  /// **'Kirtan'**
  String get kirtanTitle;

  /// No description provided for @kirtanSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search kirtan, poet or singer'**
  String get kirtanSearchHint;

  /// No description provided for @kirtanCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No kirtans} =1{1 kirtan} other{{count} kirtans}}'**
  String kirtanCount(int count);

  /// No description provided for @kirtanNoResults.
  ///
  /// In en, this message translates to:
  /// **'No kirtan found'**
  String get kirtanNoResults;

  /// No description provided for @kirtanEmpty.
  ///
  /// In en, this message translates to:
  /// **'Kirtans will be added soon.'**
  String get kirtanEmpty;

  /// No description provided for @kirtanNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get kirtanNowPlaying;

  /// No description provided for @kirtanLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get kirtanLyrics;

  /// No description provided for @kirtanNoLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are not available for this kirtan.'**
  String get kirtanNoLyrics;

  /// No description provided for @kirtanPoet.
  ///
  /// In en, this message translates to:
  /// **'Poet'**
  String get kirtanPoet;

  /// No description provided for @kirtanSinger.
  ///
  /// In en, this message translates to:
  /// **'Singer'**
  String get kirtanSinger;

  /// No description provided for @kirtanDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloaded Kirtans'**
  String get kirtanDownloads;

  /// No description provided for @kirtanDownloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap the download icon on any kirtan to listen offline, without internet.'**
  String get kirtanDownloadsEmpty;

  /// No description provided for @kirtanPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get kirtanPlayAll;

  /// No description provided for @kirtanShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get kirtanShuffle;

  /// No description provided for @kirtanRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get kirtanRepeat;

  /// No description provided for @kirtanRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get kirtanRepeatOne;

  /// No description provided for @kirtanRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get kirtanRepeatOff;

  /// No description provided for @kirtanQueue.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get kirtanQueue;

  /// No description provided for @kirtanRemoveDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get kirtanRemoveDownload;

  /// No description provided for @kirtanDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again.'**
  String get kirtanDownloadFailed;

  /// No description provided for @kirtanDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline listening'**
  String get kirtanDownloadComplete;

  /// No description provided for @kirtanPlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Unable to play this kirtan right now.'**
  String get kirtanPlaybackError;

  /// No description provided for @kirtanAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get kirtanAvailableOffline;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @sleepTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sleepTimerOff;

  /// No description provided for @sleepTimerMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sleepTimerMinutes(int minutes);

  /// No description provided for @sleepTimerEndOfTrack.
  ///
  /// In en, this message translates to:
  /// **'End of kirtan'**
  String get sleepTimerEndOfTrack;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get playbackSpeed;

  /// No description provided for @kirtanCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get kirtanCancelDownload;

  /// No description provided for @kirtanRemoveDownloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this kirtan from your phone? You can download it again anytime.'**
  String get kirtanRemoveDownloadConfirm;

  /// No description provided for @kirtanSleepTimerRemaining.
  ///
  /// In en, this message translates to:
  /// **'Stops in {time}'**
  String kirtanSleepTimerRemaining(String time);

  /// No description provided for @kirtanSpeedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get kirtanSpeedNormal;

  /// No description provided for @kirtanOfflineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Downloaded kirtans play without internet.'**
  String get kirtanOfflineUnavailable;

  /// No description provided for @kirtanBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse kirtans'**
  String get kirtanBrowse;

  /// No description provided for @placesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prasadi Places'**
  String get placesTitle;

  /// No description provided for @placesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Places blessed by Shree Swaminarayan Bhagwan'**
  String get placesSubtitle;

  /// No description provided for @placesMapView.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get placesMapView;

  /// No description provided for @placesListView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get placesListView;

  /// No description provided for @placeMahima.
  ///
  /// In en, this message translates to:
  /// **'Mahima'**
  String get placeMahima;

  /// No description provided for @placeDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get placeDirections;

  /// No description provided for @placeStreetView.
  ///
  /// In en, this message translates to:
  /// **'Street View'**
  String get placeStreetView;

  /// No description provided for @placeView360.
  ///
  /// In en, this message translates to:
  /// **'360° Darshan'**
  String get placeView360;

  /// No description provided for @placePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get placePhotos;

  /// No description provided for @placeAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get placeAddress;

  /// No description provided for @placesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Prasadi places will be added soon.'**
  String get placesEmpty;

  /// No description provided for @place360Hint.
  ///
  /// In en, this message translates to:
  /// **'Drag or move your phone to look around'**
  String get place360Hint;

  /// No description provided for @placeOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get placeOpenInMaps;

  /// No description provided for @placeNotFound.
  ///
  /// In en, this message translates to:
  /// **'This place is no longer available.'**
  String get placeNotFound;

  /// No description provided for @placeCategoryTemple.
  ///
  /// In en, this message translates to:
  /// **'Temple'**
  String get placeCategoryTemple;

  /// No description provided for @placeCategoryYagna.
  ///
  /// In en, this message translates to:
  /// **'Yagna'**
  String get placeCategoryYagna;

  /// No description provided for @placeCategoryWater.
  ///
  /// In en, this message translates to:
  /// **'Vav / Talav'**
  String get placeCategoryWater;

  /// No description provided for @placeCategoryTree.
  ///
  /// In en, this message translates to:
  /// **'Prasadi Tree'**
  String get placeCategoryTree;

  /// No description provided for @placeCategoryResidence.
  ///
  /// In en, this message translates to:
  /// **'Residence'**
  String get placeCategoryResidence;

  /// No description provided for @placeCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Sacred Place'**
  String get placeCategoryOther;

  /// No description provided for @placesShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all places'**
  String get placesShowAll;

  /// No description provided for @placesSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get placesSatellite;

  /// No description provided for @placesTapForMahima.
  ///
  /// In en, this message translates to:
  /// **'Tap to read the mahima'**
  String get placesTapForMahima;

  /// No description provided for @places360Badge.
  ///
  /// In en, this message translates to:
  /// **'360°'**
  String get places360Badge;

  /// No description provided for @places360Loading.
  ///
  /// In en, this message translates to:
  /// **'Preparing 360° darshan…'**
  String get places360Loading;

  /// No description provided for @placesMotionControl.
  ///
  /// In en, this message translates to:
  /// **'Move phone to look around'**
  String get placesMotionControl;

  /// No description provided for @placesPanoramaNumber.
  ///
  /// In en, this message translates to:
  /// **'View {number}'**
  String placesPanoramaNumber(int number);

  /// No description provided for @placesShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Jay Shree Swaminarayan! Prasadi place of Shree Jetalpur Dham – {name}'**
  String placesShareMessage(String name);

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo Gallery'**
  String get galleryTitle;

  /// No description provided for @galleryAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get galleryAlbums;

  /// No description provided for @galleryPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos} =1{1 photo} other{{count} photos}}'**
  String galleryPhotoCount(int count);

  /// No description provided for @gallerySave.
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get gallerySave;

  /// No description provided for @gallerySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery'**
  String get gallerySaved;

  /// No description provided for @gallerySavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo saved} other{{count} photos saved}}'**
  String gallerySavedCount(int count);

  /// No description provided for @gallerySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the photo. Please try again.'**
  String get gallerySaveFailed;

  /// No description provided for @galleryPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Please allow photo access in Settings to save images.'**
  String get galleryPermissionDenied;

  /// No description provided for @gallerySelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get gallerySelect;

  /// No description provided for @gallerySelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get gallerySelectAll;

  /// No description provided for @gallerySelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String gallerySelectedCount(int count);

  /// No description provided for @gallerySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get gallerySaving;

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Photos will be added soon.'**
  String get galleryEmpty;

  /// No description provided for @galleryAlbumNotFound.
  ///
  /// In en, this message translates to:
  /// **'This album is no longer available.'**
  String get galleryAlbumNotFound;

  /// No description provided for @gallerySaveSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Save 1 photo} other{Save {count} photos}}'**
  String gallerySaveSelected(int count);

  /// No description provided for @gallerySavingProgress.
  ///
  /// In en, this message translates to:
  /// **'Saving {done} of {total}…'**
  String gallerySavingProgress(int done, int total);

  /// No description provided for @galleryNotSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo couldn\'t be saved} other{{count} photos couldn\'t be saved}}'**
  String galleryNotSavedCount(int count);

  /// No description provided for @galleryClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get galleryClearSelection;

  /// No description provided for @gallerySelectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap photos to select them'**
  String get gallerySelectHint;

  /// No description provided for @galleryShareText.
  ///
  /// In en, this message translates to:
  /// **'Jay Shree Swaminarayan! {album} – Shree Swaminarayan Mandir, Jetalpur Dham'**
  String galleryShareText(String album);

  /// No description provided for @galleryPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {total}'**
  String galleryPhotoLabel(int index, int total);

  /// No description provided for @galleryPhotoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this photo'**
  String get galleryPhotoLoadFailed;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Shastra Library'**
  String get libraryTitle;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search scriptures'**
  String get librarySearchHint;

  /// No description provided for @libraryRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get libraryRead;

  /// No description provided for @libraryDownloadForOffline.
  ///
  /// In en, this message translates to:
  /// **'Download for offline'**
  String get libraryDownloadForOffline;

  /// No description provided for @libraryRemoveDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get libraryRemoveDownload;

  /// No description provided for @libraryPages.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String libraryPages(int count);

  /// No description provided for @libraryAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get libraryAuthor;

  /// No description provided for @libraryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get libraryLanguage;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Scriptures will be added soon.'**
  String get libraryEmpty;

  /// No description provided for @libraryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No scripture found'**
  String get libraryNoResults;

  /// No description provided for @libraryContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get libraryContinueReading;

  /// No description provided for @libraryBookNotFound.
  ///
  /// In en, this message translates to:
  /// **'This book is no longer available.'**
  String get libraryBookNotFound;

  /// No description provided for @readerGoToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get readerGoToPage;

  /// No description provided for @readerPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String readerPageOf(int current, int total);

  /// No description provided for @readerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this book. Please try again.'**
  String get readerOpenFailed;

  /// No description provided for @readerPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing book…'**
  String get readerPreparing;

  /// No description provided for @readerInvalidPage.
  ///
  /// In en, this message translates to:
  /// **'Enter a page between 1 and {total}'**
  String readerInvalidPage(int total);

  /// No description provided for @langGujarati.
  ///
  /// In en, this message translates to:
  /// **'Gujarati'**
  String get langGujarati;

  /// No description provided for @langHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get langHindi;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langSanskrit.
  ///
  /// In en, this message translates to:
  /// **'Sanskrit'**
  String get langSanskrit;

  /// No description provided for @libraryContinueFromPage.
  ///
  /// In en, this message translates to:
  /// **'Continue reading · Page {page}'**
  String libraryContinueFromPage(int page);

  /// No description provided for @libraryPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String libraryPageNumber(int page);

  /// No description provided for @libraryDownloadWithSize.
  ///
  /// In en, this message translates to:
  /// **'Download for offline · {size}'**
  String libraryDownloadWithSize(String size);

  /// No description provided for @libraryDownloadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}'**
  String libraryDownloadingProgress(String percent);

  /// No description provided for @libraryAvailableOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get libraryAvailableOffline;

  /// No description provided for @libraryRemoveDownloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this book from your phone? You can download it again anytime.'**
  String get libraryRemoveDownloadConfirm;

  /// No description provided for @libraryDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline reading'**
  String get libraryDownloadComplete;

  /// No description provided for @libraryDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again.'**
  String get libraryDownloadFailed;

  /// No description provided for @libraryCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get libraryCancelDownload;

  /// No description provided for @libraryDownloadedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Books you download will appear here, ready to read without internet.'**
  String get libraryDownloadedEmpty;

  /// No description provided for @libraryAboutBook.
  ///
  /// In en, this message translates to:
  /// **'About this scripture'**
  String get libraryAboutBook;

  /// No description provided for @libraryReaderPageInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Page number (1 – {total})'**
  String libraryReaderPageInputLabel(int total);

  /// No description provided for @libraryReaderGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get libraryReaderGo;

  /// No description provided for @libraryReaderNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'This book isn\'t downloaded yet. Please connect to the internet to read it.'**
  String get libraryReaderNeedsInternet;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Utsav & Events'**
  String get eventsTitle;

  /// No description provided for @eventsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get eventsUpcoming;

  /// No description provided for @eventsPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get eventsPast;

  /// No description provided for @eventsEmptyUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming utsav right now. We\'ll notify you!'**
  String get eventsEmptyUpcoming;

  /// No description provided for @eventsEmptyPast.
  ///
  /// In en, this message translates to:
  /// **'No past events yet.'**
  String get eventsEmptyPast;

  /// No description provided for @eventDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get eventDate;

  /// No description provided for @eventTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get eventTime;

  /// No description provided for @eventLocation.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get eventLocation;

  /// No description provided for @eventViewPhotos.
  ///
  /// In en, this message translates to:
  /// **'View Photos'**
  String get eventViewPhotos;

  /// No description provided for @eventWatchLive.
  ///
  /// In en, this message translates to:
  /// **'Watch Live'**
  String get eventWatchLive;

  /// No description provided for @eventToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get eventToday;

  /// No description provided for @eventTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get eventTomorrow;

  /// No description provided for @eventOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get eventOngoing;

  /// No description provided for @eventInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{In 1 day} other{In {days} days}}'**
  String eventInDays(int days);

  /// No description provided for @eventTypeUtsav.
  ///
  /// In en, this message translates to:
  /// **'Utsav'**
  String get eventTypeUtsav;

  /// No description provided for @eventTypeKatha.
  ///
  /// In en, this message translates to:
  /// **'Katha'**
  String get eventTypeKatha;

  /// No description provided for @eventTypeAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get eventTypeAnnouncement;

  /// No description provided for @eventTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventTypeOther;

  /// No description provided for @eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'This event is no longer available.'**
  String get eventNotFound;

  /// No description provided for @notificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay updated'**
  String get notificationPermissionTitle;

  /// No description provided for @notificationPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Get notified about upcoming utsav, katha and temple updates.'**
  String get notificationPermissionBody;

  /// No description provided for @notificationAllow.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get notificationAllow;

  /// No description provided for @notificationLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notificationLater;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Utsav & Katha updates'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Notifications about upcoming utsav, katha and temple news'**
  String get notificationChannelDesc;

  /// No description provided for @eventsBrowseAll.
  ///
  /// In en, this message translates to:
  /// **'See all utsav'**
  String get eventsBrowseAll;

  /// No description provided for @eventsDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get eventsDetails;

  /// No description provided for @eventsIndiaTime.
  ///
  /// In en, this message translates to:
  /// **'{time} (India time)'**
  String eventsIndiaTime(String time);

  /// No description provided for @donateTitle.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donateTitle;

  /// No description provided for @donateHeadline.
  ///
  /// In en, this message translates to:
  /// **'Offer Your Seva'**
  String get donateHeadline;

  /// No description provided for @donateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your offering supports the daily seva, utsav and upkeep of Shree Jetalpur Dham.'**
  String get donateSubtitle;

  /// No description provided for @donateScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan & Pay'**
  String get donateScanQr;

  /// No description provided for @donateScanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan with any UPI app — Google Pay, PhonePe, Paytm or BHIM'**
  String get donateScanQrHint;

  /// No description provided for @donatePayWithUpi.
  ///
  /// In en, this message translates to:
  /// **'Pay with UPI app'**
  String get donatePayWithUpi;

  /// No description provided for @donateUpiId.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get donateUpiId;

  /// No description provided for @donateBankDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get donateBankDetails;

  /// No description provided for @donateAccountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get donateAccountName;

  /// No description provided for @donateAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get donateAccountNumber;

  /// No description provided for @donateIfsc.
  ///
  /// In en, this message translates to:
  /// **'IFSC code'**
  String get donateIfsc;

  /// No description provided for @donateBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get donateBankName;

  /// No description provided for @donateBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get donateBranch;

  /// No description provided for @donateAccountType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get donateAccountType;

  /// No description provided for @donateCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all details'**
  String get donateCopyAll;

  /// No description provided for @donateContactNow.
  ///
  /// In en, this message translates to:
  /// **'Contact Now'**
  String get donateContactNow;

  /// No description provided for @donateContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Made an offering? Share the details so the temple can confirm it and send you a receipt.'**
  String get donateContactSubtitle;

  /// No description provided for @donateFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Donation Details'**
  String get donateFormTitle;

  /// No description provided for @donateName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get donateName;

  /// No description provided for @donatePhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get donatePhone;

  /// No description provided for @donateEmail.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get donateEmail;

  /// No description provided for @donateAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (₹)'**
  String get donateAmount;

  /// No description provided for @donatePurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get donatePurpose;

  /// No description provided for @donateMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get donateMethod;

  /// No description provided for @donateMethodUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get donateMethodUpi;

  /// No description provided for @donateMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get donateMethodBank;

  /// No description provided for @donateMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get donateMethodCash;

  /// No description provided for @donateMethodCheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get donateMethodCheque;

  /// No description provided for @donateMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get donateMethodOther;

  /// No description provided for @donateTxnRef.
  ///
  /// In en, this message translates to:
  /// **'Transaction / UTR no. (optional)'**
  String get donateTxnRef;

  /// No description provided for @donateMessage.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get donateMessage;

  /// No description provided for @donateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit details'**
  String get donateSubmit;

  /// No description provided for @donateSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get donateSubmitting;

  /// No description provided for @donateSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get donateSuccessTitle;

  /// No description provided for @donateSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your details have been received. The temple office will contact you soon. Jay Shree Swaminarayan!'**
  String get donateSuccessBody;

  /// No description provided for @donateRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get donateRequired;

  /// No description provided for @donateInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get donateInvalidPhone;

  /// No description provided for @donateInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get donateInvalidAmount;

  /// No description provided for @donateInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get donateInvalidEmail;

  /// No description provided for @donateCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get donateCall;

  /// No description provided for @donateWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get donateWhatsApp;

  /// No description provided for @donateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Donation details will be available soon.'**
  String get donateUnavailable;

  /// No description provided for @donateSaveQr.
  ///
  /// In en, this message translates to:
  /// **'Save QR'**
  String get donateSaveQr;

  /// No description provided for @donateNoUpiApp.
  ///
  /// In en, this message translates to:
  /// **'No UPI app found on this device. Please scan the QR code instead.'**
  String get donateNoUpiApp;

  /// No description provided for @donateWebsiteMessage.
  ///
  /// In en, this message translates to:
  /// **'Seva offerings are made on the temple website.'**
  String get donateWebsiteMessage;

  /// No description provided for @donateWebsiteButton.
  ///
  /// In en, this message translates to:
  /// **'Donate on the temple website'**
  String get donateWebsiteButton;

  /// No description provided for @donateContactOffice.
  ///
  /// In en, this message translates to:
  /// **'To offer seva, please contact the temple office.'**
  String get donateContactOffice;

  /// No description provided for @donatePurposeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General seva'**
  String get donatePurposeGeneral;

  /// No description provided for @donateInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get donateInvalidName;

  /// No description provided for @donateQrLabel.
  ///
  /// In en, this message translates to:
  /// **'Donation QR code'**
  String get donateQrLabel;

  /// No description provided for @donateQrSaved.
  ///
  /// In en, this message translates to:
  /// **'QR code saved to your photos'**
  String get donateQrSaved;

  /// No description provided for @donateQrPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Please allow photo access in Settings to save the QR code.'**
  String get donateQrPermissionDenied;

  /// No description provided for @donateCopyLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy {label}'**
  String donateCopyLabel(String label);

  /// No description provided for @donateEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get donateEmailButton;

  /// No description provided for @donateWhatsAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Jay Shree Swaminarayan! I would like to know about offering seva (donation) at Shree Jetalpur Dham.'**
  String get donateWhatsAppMessage;

  /// No description provided for @donateSuccessQueued.
  ///
  /// In en, this message translates to:
  /// **'Your details are saved on this phone and will reach the temple automatically as soon as the internet is available. The temple office will then contact you. Jay Shree Swaminarayan!'**
  String get donateSuccessQueued;

  /// No description provided for @donateRememberHint.
  ///
  /// In en, this message translates to:
  /// **'Your name and number are remembered on this phone for next time.'**
  String get donateRememberHint;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Temple'**
  String get aboutTitle;

  /// No description provided for @aboutHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get aboutHistory;

  /// No description provided for @aboutDarshanTimings.
  ///
  /// In en, this message translates to:
  /// **'Darshan Timings'**
  String get aboutDarshanTimings;

  /// No description provided for @aboutAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get aboutAddress;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get aboutContact;

  /// No description provided for @aboutCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get aboutCall;

  /// No description provided for @aboutEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get aboutEmail;

  /// No description provided for @aboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutWebsite;

  /// No description provided for @aboutWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get aboutWhatsApp;

  /// No description provided for @aboutFollowUs.
  ///
  /// In en, this message translates to:
  /// **'Follow us'**
  String get aboutFollowUs;

  /// No description provided for @aboutGetDirections.
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get aboutGetDirections;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Utsav notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get alerts for upcoming utsav & katha'**
  String get settingsNotificationsDesc;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsDownloadedKirtans.
  ///
  /// In en, this message translates to:
  /// **'Downloaded kirtans'**
  String get settingsDownloadedKirtans;

  /// No description provided for @settingsDownloadedBooks.
  ///
  /// In en, this message translates to:
  /// **'Downloaded books'**
  String get settingsDownloadedBooks;

  /// No description provided for @settingsStreamCache.
  ///
  /// In en, this message translates to:
  /// **'Kirtan listening cache'**
  String get settingsStreamCache;

  /// No description provided for @settingsStreamCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Kirtans you have heard, kept for instant replay'**
  String get settingsStreamCacheDesc;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear image cache'**
  String get settingsClearCache;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsCacheCleared;

  /// No description provided for @settingsRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get settingsRemoveAll;

  /// No description provided for @settingsConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove all downloaded files? You can download them again anytime.'**
  String get settingsConfirmDelete;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAppVersion(String version);

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsLegalNotices.
  ///
  /// In en, this message translates to:
  /// **'Legal notices & licences'**
  String get settingsLegalNotices;

  /// No description provided for @settingsCrashReports.
  ///
  /// In en, this message translates to:
  /// **'Share crash reports'**
  String get settingsCrashReports;

  /// No description provided for @settingsCrashReportsDesc.
  ///
  /// In en, this message translates to:
  /// **'Helps fix problems in the app. Never includes your name, phone or e-mail.'**
  String get settingsCrashReportsDesc;

  /// No description provided for @donatePrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Your details go only to the temple office, to confirm your offering and send a receipt.'**
  String get donatePrivacyNotice;

  /// No description provided for @donateClearSaved.
  ///
  /// In en, this message translates to:
  /// **'Clear saved details'**
  String get donateClearSaved;

  /// No description provided for @donateSavedCleared.
  ///
  /// In en, this message translates to:
  /// **'Saved details removed from this phone'**
  String get donateSavedCleared;

  /// Demo build only (preview/main_preview.dart): label on the first-launch demo sheet.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demoBadge;

  /// Demo build only: title of the sheet shown once on first launch.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the demo'**
  String get demoIntroTitle;

  /// Demo build only: explains which content is real and which is sample.
  ///
  /// In en, this message translates to:
  /// **'This is a preview of the Jetalpur Dham app. The temple history, the prasadi places and their mahima are real; the photos, kirtan audio, shastra PDF and most utsavs are only samples.'**
  String get demoIntroBody;

  /// Demo build only: features that do not work in the demo, and a reminder that the donation details shown are samples.
  ///
  /// In en, this message translates to:
  /// **'Notifications and the map are turned off in this demo. The donation details are samples too, so please do not send money to them.'**
  String get demoIntroDisabled;

  /// Demo build only: button that closes the demo sheet.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get demoIntroStart;

  /// No description provided for @settingsAboutApp.
  ///
  /// In en, this message translates to:
  /// **'About app'**
  String get settingsAboutApp;

  /// No description provided for @settingsSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get settingsSendFeedback;

  /// No description provided for @settingsSendFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Report a problem or share an idea'**
  String get settingsSendFeedbackDesc;

  /// No description provided for @settingsFeedbackSubject.
  ///
  /// In en, this message translates to:
  /// **'Feedback on the Jetalpur Dham app'**
  String get settingsFeedbackSubject;

  /// No description provided for @shareAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Jay Shree Swaminarayan! Experience Shree Jetalpur Dham — kirtan, prasadi places, shastra and utsav updates in one app. {link}'**
  String shareAppMessage(String link);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

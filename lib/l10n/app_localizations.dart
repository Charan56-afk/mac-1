import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('te'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'CineSocial'**
  String get appName;

  /// Home screen tab label
  ///
  /// In en, this message translates to:
  /// **'CINEMA HUB'**
  String get cinemaHub;

  /// Section header for industry news
  ///
  /// In en, this message translates to:
  /// **'INDUSTRY BUZZ'**
  String get industryBuzz;

  /// Section header for reviews
  ///
  /// In en, this message translates to:
  /// **'NEW MOVIE REVIEWS'**
  String get newMovieReviews;

  /// Button to view all reviews
  ///
  /// In en, this message translates to:
  /// **'View All Reviews'**
  String get viewAllReviews;

  /// CineFeed tab
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get forYou;

  /// CineFeed following tab
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// Feed screen title
  ///
  /// In en, this message translates to:
  /// **'CineFeed'**
  String get cineFeed;

  /// Nav tab label
  ///
  /// In en, this message translates to:
  /// **'Cinema Hub'**
  String get cinemaHub2;

  /// Nav tab label
  ///
  /// In en, this message translates to:
  /// **'CineVerse'**
  String get cineVerse;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No content available right now.'**
  String get noContentAvailable;

  /// Generic loading text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Statistics menu item
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Account settings section
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Privacy settings section
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety'**
  String get privacySafety;

  /// Notifications settings section
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Display settings section
  ///
  /// In en, this message translates to:
  /// **'Content & Display'**
  String get contentDisplay;

  /// Help section
  ///
  /// In en, this message translates to:
  /// **'Help & About'**
  String get helpAbout;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// Account sub-item
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// Account sub-item
  ///
  /// In en, this message translates to:
  /// **'Password & Security'**
  String get passwordSecurity;

  /// Account sub-item
  ///
  /// In en, this message translates to:
  /// **'Verification Request'**
  String get verificationRequest;

  /// Account sub-item
  ///
  /// In en, this message translates to:
  /// **'Deactivation & Deletion'**
  String get deactivationDeletion;

  /// Privacy toggle
  ///
  /// In en, this message translates to:
  /// **'Private Account'**
  String get privateAccount;

  /// Private account description
  ///
  /// In en, this message translates to:
  /// **'Only approved followers can see your posts'**
  String get privateAccountDesc;

  /// Privacy sub-item
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// Privacy sub-item
  ///
  /// In en, this message translates to:
  /// **'Story Privacy'**
  String get storyPrivacy;

  /// Privacy sub-item
  ///
  /// In en, this message translates to:
  /// **'Mentions & Tags'**
  String get mentionsTags;

  /// Notifications toggle
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// Push notifications description
  ///
  /// In en, this message translates to:
  /// **'Alerts for likes, comments & followers'**
  String get pushNotificationsDesc;

  /// Notifications toggle
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// Email notifications description
  ///
  /// In en, this message translates to:
  /// **'Weekly digest & security alerts'**
  String get emailNotificationsDesc;

  /// Quiet mode toggle
  ///
  /// In en, this message translates to:
  /// **'Quiet Mode'**
  String get quietMode;

  /// Quiet mode description
  ///
  /// In en, this message translates to:
  /// **'Mute all notifications during set hours'**
  String get quietModeDesc;

  /// Theme toggle
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Dark mode description
  ///
  /// In en, this message translates to:
  /// **'Switch between light and dark theme'**
  String get darkModeDesc;

  /// Autoplay toggle
  ///
  /// In en, this message translates to:
  /// **'Auto-play Videos'**
  String get autoPlayVideos;

  /// Autoplay description
  ///
  /// In en, this message translates to:
  /// **'Automatically play trailers in feed'**
  String get autoPlayVideosDesc;

  /// Data saver toggle
  ///
  /// In en, this message translates to:
  /// **'Data Saver'**
  String get dataSaver;

  /// Data saver description
  ///
  /// In en, this message translates to:
  /// **'Reduce data usage on cellular networks'**
  String get dataSaverDesc;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// 2FA toggle
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get twoFactorAuth;

  /// 2FA description
  ///
  /// In en, this message translates to:
  /// **'Add an extra layer of security to your account'**
  String get twoFactorAuthDesc;

  /// Change password item
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// Change password description
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get changePasswordDesc;

  /// Delete account item
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Delete account description
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account & data'**
  String get deleteAccountDesc;

  /// Delete account confirmation message
  ///
  /// In en, this message translates to:
  /// **'This is irreversible. All your posts, reviews and data will be permanently deleted.'**
  String get deleteAccountConfirm;

  /// Empty blocked users message
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// Button to update password
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get passwordUpdated;

  /// Quiet hours label
  ///
  /// In en, this message translates to:
  /// **'Quiet Hours'**
  String get quietHours;

  /// Start time label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// End time label
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// Privacy option
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// Privacy option
  ///
  /// In en, this message translates to:
  /// **'Followers Only'**
  String get followersOnly;

  /// Privacy option
  ///
  /// In en, this message translates to:
  /// **'Close Friends'**
  String get closeFriends;

  /// Privacy option
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get nobody;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'Account & Security'**
  String get accountSecurity;

  /// Help sub-item
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// Help sub-item
  ///
  /// In en, this message translates to:
  /// **'Report a Problem'**
  String get reportProblem;

  /// Help sub-item
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Help sub-item
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// User tier badge
  ///
  /// In en, this message translates to:
  /// **'PLATINUM'**
  String get platinum;

  /// User rank label
  ///
  /// In en, this message translates to:
  /// **'CineCinephile'**
  String get cineCinephile;

  /// Profile stat label
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// Profile stat label
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Morning greeting in hero section
  ///
  /// In en, this message translates to:
  /// **'Good Morning, Cine Fan'**
  String get greetingMorning;

  /// Afternoon greeting in hero section
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon, Cine Fan'**
  String get greetingAfternoon;

  /// Evening greeting in hero section
  ///
  /// In en, this message translates to:
  /// **'Good Evening, Cine Fan'**
  String get greetingEvening;

  /// Night greeting in hero section
  ///
  /// In en, this message translates to:
  /// **'Good Night, Cine Fan'**
  String get greetingNight;

  /// Live badge label
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// Button to watch trailer
  ///
  /// In en, this message translates to:
  /// **'Watch Trailer'**
  String get watchTrailer;

  /// Section header for box office
  ///
  /// In en, this message translates to:
  /// **'BOX OFFICE COLLECTIONS'**
  String get boxOfficeCollections;

  /// Error message when backend is offline
  ///
  /// In en, this message translates to:
  /// **'Backend Not Connected'**
  String get backendNotConnected;

  /// Subtext for backend offline error
  ///
  /// In en, this message translates to:
  /// **'Start local server to view featured movies'**
  String get startLocalServer;
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
      <String>['en', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

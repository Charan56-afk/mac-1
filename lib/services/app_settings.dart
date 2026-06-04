import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maps display language names to BCP-47 locale codes.
const Map<String, Locale> _languageLocales = {
  'English':   Locale('en', 'US'),
  'Telugu':    Locale('te', 'IN'),
  'Hindi':     Locale('hi', 'IN'),
  'Tamil':     Locale('ta', 'IN'),
  'Kannada':   Locale('kn', 'IN'),
  'Malayalam': Locale('ml', 'IN'),
};

/// Broadcasts locale changes to [MaterialApp].
class LocaleController {
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier(const Locale('en', 'US'));

  static void setLanguage(String languageName) {
    final locale = _languageLocales[languageName] ?? const Locale('en', 'US');
    localeNotifier.value = locale;
  }
}

/// Central settings singleton — read/write all user preferences here.
/// All changes are persisted immediately via SharedPreferences.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // ─── Keys ─────────────────────────────────────────────────────────────────
  static const String _kDarkMode = 'isDarkMode';
  static const String _kAutoPlay = 'autoPlay';
  static const String _kDataSaver = 'dataSaver';
  static const String _kPushNotifications = 'pushNotifications';
  static const String _kEmailNotifications = 'emailNotifications';
  static const String _kQuietMode = 'quietMode';
  static const String _kQuietStart = 'quietStart';
  static const String _kQuietEnd = 'quietEnd';
  static const String _kPrivateAccount = 'privateAccount';
  static const String _kStoryPrivacy = 'storyPrivacy'; // 'everyone' | 'followers' | 'closeFriends'
  static const String _kMentionsPrivacy = 'mentionsPrivacy'; // 'everyone' | 'followers' | 'nobody'
  static const String _kLanguage = 'language';
  static const String _kTwoFactor = 'twoFactor';

  // ─── Values ───────────────────────────────────────────────────────────────
  bool _darkMode = true;
  bool _autoPlay = true;
  bool _dataSaver = false;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _quietMode = false;
  int _quietStartHour = 22; // 10 PM
  int _quietEndHour = 8;   // 8 AM
  bool _privateAccount = false;
  String _storyPrivacy = 'everyone';
  String _mentionsPrivacy = 'everyone';
  String _language = 'English';
  bool _twoFactor = false;

  // ─── Getters ──────────────────────────────────────────────────────────────
  bool get darkMode => _darkMode;
  bool get autoPlay => _autoPlay;
  bool get dataSaver => _dataSaver;
  bool get pushNotifications => _pushNotifications;
  bool get emailNotifications => _emailNotifications;
  bool get quietMode => _quietMode;
  int get quietStartHour => _quietStartHour;
  int get quietEndHour => _quietEndHour;
  bool get privateAccount => _privateAccount;
  String get storyPrivacy => _storyPrivacy;
  String get mentionsPrivacy => _mentionsPrivacy;
  String get language => _language;
  bool get twoFactor => _twoFactor;

  SharedPreferences? _prefs;

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _darkMode = _prefs!.getBool(_kDarkMode) ?? true;
    _autoPlay = _prefs!.getBool(_kAutoPlay) ?? true;
    _dataSaver = _prefs!.getBool(_kDataSaver) ?? false;
    _pushNotifications = _prefs!.getBool(_kPushNotifications) ?? true;
    _emailNotifications = _prefs!.getBool(_kEmailNotifications) ?? false;
    _quietMode = _prefs!.getBool(_kQuietMode) ?? false;
    _quietStartHour = _prefs!.getInt(_kQuietStart) ?? 22;
    _quietEndHour = _prefs!.getInt(_kQuietEnd) ?? 8;
    _privateAccount = _prefs!.getBool(_kPrivateAccount) ?? false;
    _storyPrivacy = _prefs!.getString(_kStoryPrivacy) ?? 'everyone';
    _mentionsPrivacy = _prefs!.getString(_kMentionsPrivacy) ?? 'everyone';
    _language = _prefs!.getString(_kLanguage) ?? 'English';
    _twoFactor = _prefs!.getBool(_kTwoFactor) ?? false;
    LocaleController.setLanguage(_language); // Restore locale on startup
    notifyListeners();
  }

  // ─── Setters (each saves immediately & broadcasts) ────────────────────────
  Future<void> setDarkMode(bool val) async {
    _darkMode = val;
    await _prefs?.setBool(_kDarkMode, val);
    notifyListeners();
  }

  Future<void> setAutoPlay(bool val) async {
    _autoPlay = val;
    await _prefs?.setBool(_kAutoPlay, val);
    notifyListeners();
  }

  Future<void> setDataSaver(bool val) async {
    _dataSaver = val;
    await _prefs?.setBool(_kDataSaver, val);
    notifyListeners();
  }

  Future<void> setPushNotifications(bool val) async {
    _pushNotifications = val;
    await _prefs?.setBool(_kPushNotifications, val);
    notifyListeners();
  }

  Future<void> setEmailNotifications(bool val) async {
    _emailNotifications = val;
    await _prefs?.setBool(_kEmailNotifications, val);
    notifyListeners();
  }

  Future<void> setQuietMode(bool val) async {
    _quietMode = val;
    await _prefs?.setBool(_kQuietMode, val);
    notifyListeners();
  }

  Future<void> setQuietHours(int startHour, int endHour) async {
    _quietStartHour = startHour;
    _quietEndHour = endHour;
    await _prefs?.setInt(_kQuietStart, startHour);
    await _prefs?.setInt(_kQuietEnd, endHour);
    notifyListeners();
  }

  Future<void> setPrivateAccount(bool val) async {
    _privateAccount = val;
    await _prefs?.setBool(_kPrivateAccount, val);
    notifyListeners();
  }

  Future<void> setStoryPrivacy(String val) async {
    _storyPrivacy = val;
    await _prefs?.setString(_kStoryPrivacy, val);
    notifyListeners();
  }

  Future<void> setMentionsPrivacy(String val) async {
    _mentionsPrivacy = val;
    await _prefs?.setString(_kMentionsPrivacy, val);
    notifyListeners();
  }

  Future<void> setLanguage(String val) async {
    _language = val;
    await _prefs?.setString(_kLanguage, val);
    LocaleController.setLanguage(val); // Live locale switch
    notifyListeners();
  }

  Future<void> setTwoFactor(bool val) async {
    _twoFactor = val;
    await _prefs?.setBool(_kTwoFactor, val);
    notifyListeners();
  }
}

import 'package:flutter/material.dart' hide Locale;
import 'package:flutter/material.dart' as material show Locale;
import 'package:shared_preferences/shared_preferences.dart';

// Use Flutter's Locale explicitly
typedef FlutterLocale = material.Locale;

class LanguageProvider extends ChangeNotifier {
  // ignore: constant_identifier_names
  static const String LANGUAGE_CODE = 'languageCode';
  
  FlutterLocale _currentLocale = FlutterLocale('en');
  
  FlutterLocale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLanguage();
  }

  void changeLanguage(String languageCode) async {
    if (languageCode == _currentLocale.languageCode) return;
    
    _currentLocale = FlutterLocale(languageCode);
    notifyListeners();
    await _saveLanguage(languageCode);
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(LANGUAGE_CODE);
    if (languageCode != null) {
      _currentLocale = FlutterLocale(languageCode);
      notifyListeners();
    }
  }

  Future<void> _saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LANGUAGE_CODE, languageCode);
  }
}

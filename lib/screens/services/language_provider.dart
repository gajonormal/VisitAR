import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider responsável por gerir o idioma da aplicação.
/// Persiste a escolha do utilizador em SharedPreferences e notifica os listeners.
class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('pt');

  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLanguage();
  }

  /// Altera o idioma da aplicação e persiste a escolha localmente.
  void changeLanguage(String languageCode) async {
    _currentLocale = Locale(languageCode);
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
  }

  /// Carrega o idioma guardado em SharedPreferences ao iniciar o provider.
  void _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lang = prefs.getString('language');
    if (lang != null) {
      _currentLocale = Locale(lang);
      notifyListeners();
    }
  }
}

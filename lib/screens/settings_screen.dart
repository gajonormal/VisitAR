import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'services/language_provider.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  bool _isDarkMode = false;
  bool _isLoading = false;

  User? user = FirebaseAuth.instance.currentUser;

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simula atraso na limpeza de cache
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cacheClearedSuccess), backgroundColor: kPrimaryGreen),
      );
    }
  }

  Future<void> _deleteAccount() async {
    if (user == null) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAccountWarningTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppLocalizations.of(context)!.deleteAccountWarningBody),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      setState(() => _isLoading = true);
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
      await user!.delete();
      if (mounted) Navigator.pop(context); 
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: ${e.message}"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLang = languageProvider.currentLocale.languageCode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(AppLocalizations.of(context)!.general),
                
                _buildListOption(
                  icon: Icons.security_rounded,
                  text: AppLocalizations.of(context)!.managePermissions,
                  onTap: () {
                    Geolocator.openAppSettings();
                  },
                ),

                _buildListOption(
                  icon: Icons.translate_rounded,
                  text: AppLocalizations.of(context)!.language,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentLang == 'pt' ? 'Português' : 'English',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14.5, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _showLanguageDialog(context, currentLang, user?.uid),
                ),

                // Alterna entre modo claro e escuro (funcionalidade futura)
                _buildListOption(
                  icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  text: AppLocalizations.of(context)!.darkMode,
                  onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isDarkMode,
                      activeThumbColor: kPrimaryGreen,
                      onChanged: (val) => setState(() => _isDarkMode = val),
                    ),
                  ),
                ),

                _buildListOption(
                  icon: Icons.cleaning_services_rounded,
                  text: AppLocalizations.of(context)!.clearCache,
                  iconColor: Colors.orange,
                  iconBgColor: Colors.orange.withOpacity(0.1),
                  onTap: _clearCache,
                ),

                SizedBox(height: 20),

                // Apresenta opções de conta apenas se o utilizador estiver autenticado
                if (user != null) ...[
                  _buildSectionTitle(AppLocalizations.of(context)!.account),
                  
                  // Ação destrutiva para eliminar a conta
                  _buildListOption(
                    icon: Icons.delete_forever_rounded,
                    text: AppLocalizations.of(context)!.deleteAccount,
                    iconColor: Colors.red,
                    iconBgColor: Colors.red.withOpacity(0.1),
                    textColor: Colors.red,
                    onTap: _deleteAccount,
                  ),
                ],

                SizedBox(height: 30),
                Center(
                  child: Text(
                    "Versão 1.0.0",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  /// Constrói o título de uma secção de definições
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5, top: 10),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
      ),
    );
  }

  /// Constrói um item de lista para as definições
  Widget _buildListOption({
    required IconData icon, 
    required String text, 
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor, 
    Color? iconBgColor,
    Color? textColor,
  }) {
    final Color finalIconColor = iconColor ?? kPrimaryGreen;
    final Color finalBgColor = iconBgColor ?? kPrimaryGreen.withOpacity(0.1);
    final Color finalTextColor = textColor ?? Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ListTile(
        dense: true, 
        visualDensity: const VisualDensity(vertical: -0.5), 
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
        horizontalTitleGap: 10,

        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: finalBgColor, shape: BoxShape.circle),
          child: Icon(icon, color: finalIconColor, size: 20),
        ),
        
        title: Text(
          text, 
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: finalTextColor) 
        ),
        
        trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey),
        
        onTap: onTap,
      ),
    );
  }

  /// Exibe o diálogo de seleção de idioma
  void _showLanguageDialog(BuildContext context, String currentLang, String? userId) {
    final Map<String, String> languages = {
      'Português': 'pt',
      'English': 'en',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.chooseLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.entries.map((entry) {
            bool isSelected = entry.value == currentLang;
            return ListTile(
              leading: Radio<String>(
                value: entry.value,
                groupValue: currentLang,
                onChanged: (val) {
                  Navigator.pop(context);
                  _changeLanguage(context, val!, userId);
                },
              ),
              title: Text(entry.key),
              trailing: isSelected ? Icon(Icons.check, color: kPrimaryGreen) : null,
              onTap: () {
                Navigator.pop(context);
                _changeLanguage(context, entry.value, userId);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Aplica a mudança de idioma no provider e persiste no Firestore (se autenticado)
  void _changeLanguage(BuildContext context, String newLang, String? userId) async {
    Provider.of<LanguageProvider>(context, listen: false).changeLanguage(newLang);

    if (userId != null) {
      // Atualiza a preferência de idioma no Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'linguagem': newLang,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.languageChanged(newLang.toUpperCase())))
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.languageChangedLocal(newLang.toUpperCase())))
        );
      }
    }
  }
}

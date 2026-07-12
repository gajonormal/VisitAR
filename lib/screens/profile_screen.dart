import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visitar_teste/screens/services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'offline_content_screen.dart';
import 'passport_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import 'services/language_provider.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';
import 'services/roteiros_service.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../models/roteiro.dart';
import 'roteiro_details_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  final Color kPrimaryGreen = const Color(0xFF0F9D58);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Utilizador autenticado: perfil completo
        if (snapshot.hasData) {
          final User user = snapshot.data!;
          return _buildProfileWithData(context, user);
        }

        // Visitante: perfil restrito
        return _buildGuestProfile(context);
      },
    );
  }

  /// Constrói o ecrã de perfil para utilizadores autenticados
  Widget _buildProfileWithData(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>?;

        String nome = userData?['nome'] ?? "Sem nome";
        String email = userData?['email'] ?? user.email ?? "";
        String langCode = userData?['linguagem'] ?? "pt";
        String foto = userData?['urlFoto'] ?? "";

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 100,
            leading: TextButton.icon(
              icon: Icon(Icons.logout, color: Colors.grey[700], size: 20),
              label: Text(AppLocalizations.of(context)!.logout, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
              onPressed: () async {
                await AuthService().signOut();
              },
              style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 15)),
            ),
            actions: [

              Padding(
                padding: const EdgeInsets.only(right: 7.0),
                child: TextButton.icon(
                  icon: Icon(Icons.translate, color: Colors.grey[700], size: 20),
                  label: Text(langCode.toUpperCase(), style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                  onPressed: () => _showLanguageDialog(context, langCode, user.uid),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: IconButton(
                  icon: Icon(Icons.settings_outlined, color: Colors.grey[700], size: 24),
                  tooltip: AppLocalizations.of(context)!.settings,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                  },
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
            child: Column(
              children: [
                // Foto de perfil
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kPrimaryGreen, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: foto.isNotEmpty ? CachedNetworkImageProvider(foto) : null,
                        child: foto.isEmpty
                            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                            : null,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),
                Text(nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),

                SizedBox(height: 15),

                // Botão de editar perfil
                SizedBox(
                  height: 35,
                  width: 140,
                  child: ElevatedButton(
                    onPressed: () {
                      if (userData != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(userData: userData)));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(AppLocalizations.of(context)!.editProfile, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

                SizedBox(height: 25),

                // Secção de conquistas (badges)
                _buildBadgesSection(context, user.uid),

                SizedBox(height: 25),

                // Secção de roteiros criados
                _buildMyRoteirosSection(context, user.uid),

                SizedBox(height: 20),
                

                _buildListOption(
                  icon: Icons.book_outlined,
                  text: AppLocalizations.of(context)!.myPassport,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportScreen()));
                  },
                ),
                
                _buildListOption(
                  icon: Icons.download_done_rounded,
                  text: AppLocalizations.of(context)!.offlineDownloads,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const OfflineContentScreen()));
                  },
                ),


                SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Constrói o ecrã de perfil para visitantes não autenticados
  Widget _buildGuestProfile(BuildContext context) {
    // Lê o idioma atual do provider
    String guestLangCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 160,
        leading: TextButton.icon(
          icon: Icon(Icons.login, color: kPrimaryGreen, size: 20),
          label: Text(AppLocalizations.of(context)!.loginRegister, style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          },
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 15)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 7.0),
            child: TextButton.icon(
              icon: Icon(Icons.translate, color: Colors.grey[700], size: 20),
              label: Text(
                guestLangCode.toUpperCase(),
                style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)
              ),
              onPressed: () => _showLanguageDialog(context, guestLangCode, null),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: IconButton(
              icon: Icon(Icons.settings_outlined, color: Colors.grey[700], size: 24),
              tooltip: AppLocalizations.of(context)!.settings,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
        child: Column(
          children: [
            // Avatar genérico para visitantes
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                child: Icon(Icons.person_outline, size: 50, color: Colors.grey[400]),
              ),
            ),

            SizedBox(height: 10),
            Text(AppLocalizations.of(context)!.guest, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(AppLocalizations.of(context)!.guestMode, style: TextStyle(color: Colors.grey[600], fontSize: 14)),

            SizedBox(height: 40),

            // Aviso sobre funcionalidades restritas
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[700]),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.guestLimitedAccess,
                      style: TextStyle(color: Colors.grey[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Opções disponíveis para visitantes
            _buildListOption(
              icon: Icons.download_done_rounded,
              text: AppLocalizations.of(context)!.offlineDownloads,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OfflineContentScreen()));
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói a secção de badges recentes do utilizador
  Widget _buildBadgesSection(BuildContext context, String uid) {
    // Ícones dos badges
    const Map<String, IconData> badgeIcons = {
      'primeiro_carimbo': Icons.pin_drop_outlined,
      'conhecedor': Icons.account_balance_outlined,
      'colecionador': Icons.flag_circle_outlined,
      'grande_explorador': Icons.public_outlined,
      'primeiro_roteiro': Icons.map_outlined,
      'aventureiro': Icons.emoji_events_outlined,
      'viajante': Icons.flight_takeoff_outlined,
      'criador': Icons.edit_outlined,
      'guia_local': Icons.military_tech_outlined,
    };

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('badges')
          .orderBy('unlockedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final earnedDocs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.latestAchievements, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  // Mostra as últimas 4 conquistas
                  ...earnedDocs.take(4).map((doc) {
                    final icon = badgeIcons[doc.id] ?? Icons.star_border;
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                      ),
                      child: Center(child: Icon(icon, color: const Color(0xFFD4AF37), size: 26)),
                    );
                  }),
                  // Slots para os badges por desbloquear
                  ...List.generate(earnedDocs.length < 4 ? 4 - earnedDocs.length : 0, (_) => Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Icon(Icons.lock_outline_rounded, color: Colors.grey[400], size: 22)),
                  )),
                  const Spacer(),
                  // Botão para ver todas as conquistas
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportScreen())),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.add, color: Colors.grey, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyRoteirosSection(BuildContext context, String uid) {
    return StreamBuilder<List<Roteiro>>(
      stream: RoteirosService().getUserRoteiros(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0F9D58)));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Sem roteiros: mostra um placeholder
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.myItineraries, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, color: Colors.grey[400], size: 30),
                    SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.noPersonalItineraries,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        
        final roteiros = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.myItineraries, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: roteiros.length,
                itemBuilder: (context, index) {
                  final roteiro = roteiros[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoteiroDetailsScreen(roteiro: roteiro))),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F9D58), // Fundo verde por omissão
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (roteiro.imagemCapa.trim().isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: roteiro.imagemCapa,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => const SizedBox.shrink(),
                              ),
                            // Overlay para destacar o título
                            Container(color: Colors.black.withValues(alpha: 0.3)),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  roteiro.titulo,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Constrói uma opção de lista reutilizável (ícone + texto + seta)
  Widget _buildListOption({required IconData icon, required String text, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ListTile(
        dense: true, 
        
        visualDensity: const VisualDensity(vertical: -0.5), 
        
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
        
        horizontalTitleGap: 10,

        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: kPrimaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: kPrimaryGreen, size: 20),
        ),
        title: Text(
          text, 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5) 
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey),
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
        // Guarda o idioma no Firestore
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
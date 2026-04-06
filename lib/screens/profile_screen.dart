import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visitar_teste/screens/services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'offline_content_screen.dart';
import 'admin_add_poi.dart'; 
import 'settings_screen.dart';

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

        // SE TEM USER LOGADO
        if (snapshot.hasData) {
          final User user = snapshot.data!;
          return _buildProfileWithData(context, user);
        }

        // SE NÃO TEM USER (VISITANTE)
        return _buildGuestProfile(context);
      },
    );
  }

  // PERFIL PARA UTILIZADOR AUTENTICADO
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
              label: Text("Sair", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
              onPressed: () async {
                await AuthService().signOut();
              },
              style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 15)),
            ),
            actions: [
              // ... (Os teus botões de linguagem e definições mantêm-se iguais)
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
                  tooltip: "Definições",
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
                // FOTO DE PERFIL
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
                        backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                        child: foto.isEmpty
                            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Text(nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),

                const SizedBox(height: 15), // Espaço antes do botão

                // --- NOVO BOTÃO EDITAR PERFIL (MAIS PEQUENO E POR BAIXO DO NOME) ---
                SizedBox(
                  height: 35, // Altura reduzida (era padrão ~45-50)
                  width: 140, // Largura controlada para não ocupar o ecrã todo
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Mais arredondado
                      padding: EdgeInsets.zero, // Remove padding interno para o texto caber bem na altura pequena
                    ),
                    child: const Text("Editar Perfil", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 30), // Espaço antes da lista
                
                // LISTA DE OPÇÕES
                _buildListOption(
                  icon: Icons.flag_circle_rounded,
                  text: "Os meus roteiros",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A abrir...")));
                  },
                ),
                
                _buildListOption(
                  icon: Icons.favorite_outlined,
                  text: "Os meus favoritos",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A abrir...")));
                  },
                ),

                _buildListOption(
                  icon: Icons.star_rate_rounded,
                  text: "As minhas avaliações",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A abrir...")));
                  },
                ),

                _buildListOption(
                  icon: Icons.download_done_rounded,
                  text: "Downloads Offline",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const OfflineContentScreen()));
                  },
                ),

                // --- PAINEL DE ADMIN (Movido para aqui como opção de lista) ---
                // Fica mais limpo do que ter um botão solto
                _buildListOption(
                  icon: Icons.admin_panel_settings,
                  text: "Painel de Admin",
                  onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAddPoiScreen()));
                  },
                ),
              ],
            ),
          ),
          // REMOVIDO O BOTTOM NAVIGATION BAR
        );
      },
    );
  }

  // PERFIL PARA VISITANTE (NÃO AUTENTICADO)
  Widget _buildGuestProfile(BuildContext context) {
    // Linguagem padrão para visitante (pode ser guardada em SharedPreferences)
    String guestLangCode = "pt";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 160,
        leading: TextButton.icon(
          icon: Icon(Icons.login, color: kPrimaryGreen, size: 20),
          label: Text("Login/Registo", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold)),
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
              tooltip: "Definições",
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
            // ÍCONE DE VISITANTE
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

            const SizedBox(height: 10),
            const Text("Visitante", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("Modo sem conta", style: TextStyle(color: Colors.grey[600], fontSize: 14)),

            const SizedBox(height: 40),

            // INFO: Visitantes têm acesso limitado
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Como visitante, tens acesso limitado. Cria uma conta para mais funcionalidades!",
                      style: TextStyle(color: Colors.grey[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Opções disponíveis para visitante
            _buildListOption(
              icon: Icons.download_done_rounded,
              text: "Downloads Offline",
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

Widget _buildListOption({required IconData icon, required String text, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11), // Margem externa ligeiramente maior (era 10)
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
        
        // Ajuste fino: -0.5 (antes era -1). Dá um pouquinho mais de altura natural.
        visualDensity: const VisualDensity(vertical: -0.5), 
        
        // Padding vertical: 2 (antes era 0). Dá um pequeno respiro nas bordas.
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
        
        horizontalTitleGap: 10,

        leading: Container(
          padding: const EdgeInsets.all(7), // Aumentei de 6 para 7 (o original era 8)
          decoration: BoxDecoration(color: kPrimaryGreen.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: kPrimaryGreen, size: 20),
        ),
        title: Text(
          text, 
          // Aumentei de 14 para 14.5 para encher melhor o espaço
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5) 
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // Dialog para escolher idioma
  void _showLanguageDialog(BuildContext context, String currentLang, String? userId) {
    final Map<String, String> languages = {
      'Português': 'pt',
      'English': 'en',
      'Español': 'es',
      'Français': 'fr',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Escolher Idioma"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.entries.map((entry) {
            bool isSelected = entry.value == currentLang;
            return ListTile(
              leading: Radio<String>(
                value: entry.value,
                groupValue: currentLang,
                activeColor: kPrimaryGreen,
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

  // Função para alterar idioma
  void _changeLanguage(BuildContext context, String newLang, String? userId) async {
    if (userId != null) {
      // Utilizador autenticado: guarda no Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'linguagem': newLang,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Idioma alterado para ${newLang.toUpperCase()}"))
      );
    } else {
      // Visitante: guarda em SharedPreferences (implementar depois)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Idioma alterado para ${newLang.toUpperCase()} (local)"))
      );
      // TODO: Implementar SharedPreferences para guardar preferência do visitante
    }
  }
}
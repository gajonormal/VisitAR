import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          final User user = snapshot.data!;
          return _buildProfileWithData(context, user);
        }

        return const LoginScreen();
      },
    );
  }

  Widget _buildProfileWithData(BuildContext context, User user) {
    // Estilo comum para as caixas de texto (Leitura apenas)
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black),
      ),
      enabledBorder: OutlineInputBorder( // Borda preta mesmo quando não focado
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
    );

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>?;

        // Dados
        String nome = userData?['nome'] ?? "Sem nome";
        String email = userData?['email'] ?? user.email ?? "";
        String genero = userData?['genero'] ?? "Não definido";
        String langCode = userData?['linguagem'] ?? "pt";
        String nacionalidade = _getNacionalidadeLabel(langCode); // Converte 'pt' para 'Portuguesa'
        String foto = userData?['urlFoto'] ?? "";

        return Scaffold(
          backgroundColor: Colors.white, // Fundo branco/limpo
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            // 1. LOGOUT NO TOPO ESQUERDO (Como no desenho)
            leadingWidth: 100,
            leading: TextButton.icon(
              icon: const Icon(Icons.logout, color: Colors.black, size: 20),
              label: const Text("Logout", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await AuthService().signOut();
              },
              style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 10)),
            ),
            // Ícone de Tradução à direita
            actions: [
              IconButton(
                icon: const Icon(Icons.translate, color: Colors.black),
                onPressed: () {}, // Futuro: Mudar língua da app
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // 2. FOTO DE PERFIL
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2), // Borda preta no avatar
                          ),
                          child: foto.isEmpty 
                            ? const Center(child: Icon(Icons.person, size: 60, color: Colors.black)) 
                            : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 3. CAMPOS DE LEITURA (Visual de caixas como no desenho)
                  TextFormField(
                    initialValue: nome,
                    readOnly: true, // Não deixa escrever aqui
                    decoration: inputDecoration.copyWith(labelText: "Nome"),
                  ),
                  const SizedBox(height: 15),
                  
                  TextFormField(
                    initialValue: email,
                    readOnly: true,
                    decoration: inputDecoration.copyWith(labelText: "E-mail"),
                  ),
                  const SizedBox(height: 15),
                  
                  // Simulamos dropdowns com TextFields que têm um ícone de seta (apenas visual)
                  TextFormField(
                    initialValue: genero,
                    readOnly: true,
                    decoration: inputDecoration.copyWith(
                      labelText: "Género",
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  TextFormField(
                    initialValue: nacionalidade,
                    readOnly: true,
                    decoration: inputDecoration.copyWith(
                      labelText: "Nacionalidade",
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 4. BOTÃO "EDITAR PERFIL" (Pequeno e centrado)
                  ElevatedButton(
                    onPressed: () {
                       if (userData != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(userData: userData!),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      side: const BorderSide(color: Colors.black, width: 2), // Borda preta
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: const Text("Editar perfil", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 40),

                  // 5. BOTÕES DE AÇÃO (Largos e retangulares)
                  _buildActionButton("Gerir downloads offline", () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A abrir downloads...")));
                  }),
                  const SizedBox(height: 15),
                  _buildActionButton("As minhas avaliações", () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A abrir avaliações...")));
                  }),

                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Função auxiliar para criar os botões retangulares do fundo
  Widget _buildActionButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)), // Quase quadrado
          side: const BorderSide(color: Colors.black, width: 2), // Borda preta grossa
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  // Helper para mostrar "Portuguesa" em vez de "pt"
  String _getNacionalidadeLabel(String code) {
    switch (code) {
      case 'pt': return 'Portuguesa';
      case 'en': return 'Inglesa';
      case 'es': return 'Espanhola';
      case 'fr': return 'Francesa';
      default: return 'Outra';
    }
  }
}
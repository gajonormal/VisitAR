import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../screens/services/auth_service.dart'; // Descomenta se precisares

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

  // --- AÇÕES ---

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulação
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Cache limpa com sucesso!"), backgroundColor: kPrimaryGreen),
      );
    }
  }

  Future<void> _deleteAccount() async {
    if (user == null) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Conta?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Esta ação é irreversível. Todos os teus dados serão apagados."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: Colors.white, // Fundo branco como no Perfil
      appBar: AppBar(
        title: const Text("Definições", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                _buildSectionTitle("Geral"),
                
                // 1. Gerir Permissões
                _buildListOption(
                  icon: Icons.security_rounded,
                  text: "Gerir Permissões",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A abrir definições...")));
                  },
                ),

                // 2. Modo Escuro (Com Switch)
                _buildListOption(
                  icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  text: "Modo Escuro",
                  onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                  // Aqui passamos o Switch como widget "trailing"
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isDarkMode,
                      activeThumbColor: kPrimaryGreen,
                      onChanged: (val) => setState(() => _isDarkMode = val),
                    ),
                  ),
                ),

                // 3. Limpar Cache
                _buildListOption(
                  icon: Icons.cleaning_services_rounded,
                  text: "Limpar Cache",
                  iconColor: Colors.orange, // Cor personalizada
                  iconBgColor: Colors.orange.withOpacity(0.1),
                  onTap: _clearCache,
                ),

                const SizedBox(height: 20),

                // SECÇÃO CONTA (Se tiver login)
                if (user != null) ...[
                  _buildSectionTitle("Conta"),
                  
                  // 4. Excluir Conta (Vermelho)
                  _buildListOption(
                    icon: Icons.delete_forever_rounded,
                    text: "Excluir Conta",
                    iconColor: Colors.red,
                    iconBgColor: Colors.red.withOpacity(0.1),
                    textColor: Colors.red, // Texto vermelho para destaque
                    onTap: _deleteAccount,
                  ),
                ],

                const SizedBox(height: 30),
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
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // Título da Secção (Pequeno e cinza)
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5, top: 10),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
      ),
    );
  }

  // --- O WIDGET MÁGICO (IGUAL AO PERFIL) ---
  // Adicionei parâmetros opcionais para cores e widget final (trailing)
  Widget _buildListOption({
    required IconData icon, 
    required String text, 
    required VoidCallback onTap,
    Widget? trailing, // Para pôr o Switch
    Color? iconColor, 
    Color? iconBgColor,
    Color? textColor,
  }) {
    // Cores padrão (Verde) se não forem especificadas
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

        // Ícone à esquerda (Bola colorida)
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: finalBgColor, shape: BoxShape.circle),
          child: Icon(icon, color: finalIconColor, size: 20),
        ),
        
        // Texto
        title: Text(
          text, 
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: finalTextColor) 
        ),
        
        // Ícone à direita (Seta ou Switch)
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey),
        
        onTap: onTap,
      ),
    );
  }
}
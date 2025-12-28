import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  // Recebemos os dados atuais para preencher o formulário
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  
  // Controladores
  late TextEditingController _nameController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  
  // Valores para os Dropdowns
  late String _selectedGender;
  late String _selectedLanguage;

  // Listas
  final List<String> _genders = ['Masculino', 'Feminino', 'Outro', 'Prefiro não dizer'];
  final Map<String, String> _languageMap = {
    'Portuguesa': 'pt',
    'Inglesa': 'en',
    'Espanhola': 'es',
    'Francesa': 'fr',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['nome'] ?? '');
    _emailController.text = widget.userData['email'] ?? '';
    
    String dbGender = widget.userData['genero'] ?? _genders.first;
    _selectedGender = _genders.contains(dbGender) ? dbGender : _genders.first;
        
    String dbLangCode = widget.userData['linguagem'] ?? 'pt';
    _selectedLanguage = _languageMap.keys.firstWhere(
      (k) => _languageMap[k] == dbLangCode, 
      orElse: () => 'Portuguesa'
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String langCode = _languageMap[_selectedLanguage] ?? 'pt';

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nome': _nameController.text.trim(),
        'genero': _selectedGender,
        'linguagem': langCode, 
      });

      if (_newPassController.text.isNotEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A alteração de password requer passos adicionais (não implementado).")),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Perfil atualizado com sucesso!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao atualizar: $e")),
      );
    } finally {
       if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- ESTILO VISUAL IGUAL AO WIREFRAME ---
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Menos altura (estilo compacto)
      // Borda Preta Definida (Estilo Desenho)
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4), // Cantos pouco arredondados
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      // Borda quando clicas
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.black, width: 2.0),
      ),
      // Borda de erro
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(4),
         borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    );

    return Scaffold(
      backgroundColor: Colors.white, // Fundo branco limpo
      appBar: AppBar(
        title: const Text("Editar Perfil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Botão de voltar preto
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Avatar com borda preta
                Container(
                  padding: const EdgeInsets.all(2), // Espaço para a borda
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 60, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 30),

                // 1. Campo Nome
                TextFormField(
                  controller: _nameController,
                  decoration: inputDecoration.copyWith(labelText: "Nome"),
                  validator: (val) => val!.isEmpty ? "O nome não pode ser vazio" : null,
                ),
                const SizedBox(height: 15),

                // 2. Campo Email
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  // Fundo ligeiramente cinza para indicar que não dá para mudar
                  decoration: inputDecoration.copyWith(labelText: "E-mail", fillColor: Colors.grey[100]),
                ),
                const SizedBox(height: 15),

                // 3. Campo Género (Dropdown com estilo de caixa)
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: inputDecoration.copyWith(labelText: "Género"),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  dropdownColor: Colors.white,
                  items: _genders.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedGender = val!),
                ),
                const SizedBox(height: 15),

                // 4. Campo Nacionalidade
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: inputDecoration.copyWith(labelText: "Nacionalidade"),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  dropdownColor: Colors.white,
                  items: _languageMap.keys.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedLanguage = val!),
                ),
                const SizedBox(height: 30),
                
                // 5. Passwords
                TextFormField(
                  controller: _newPassController,
                  obscureText: true,
                  decoration: inputDecoration.copyWith(labelText: "Nova password"),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _confirmPassController,
                  obscureText: true,
                  decoration: inputDecoration.copyWith(labelText: "Confirmar nova password"),
                  validator: (val) {
                    if (_newPassController.text.isNotEmpty && val != _newPassController.text) {
                      return "As passwords não coincidem";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // BOTÃO ESTILO WIREFRAME (Branco com borda preta)
                isLoading 
                ? const CircularProgressIndicator(color: Colors.black)
                : SizedBox(
                  width: double.infinity, // Largura total
                  height: 50, // Altura fixa para ficar robusto
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // Fundo Branco
                      foregroundColor: Colors.black, // Texto Preto
                      elevation: 0,
                      // Borda Preta com espessura 2
                      side: const BorderSide(color: Colors.black, width: 2), 
                      // Cantos pouco arredondados (quase retangulares)
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    child: const Text("Confirmar alterações"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../screens/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(); 
  
  // Variável para guardar o género selecionado
  String _selectedGender = 'Masculino'; 
  final List<String> _genders = ['Masculino', 'Feminino', 'Outro', 'Prefiro não dizer'];

  bool isLogin = true; 
  bool isLoading = false;
  String? errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { isLoading = true; errorMessage = null; });

    try {
      if (isLogin) {
        // Login normal
        await AuthService().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Registo COMPLETO
        await AuthService().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          nome: _nameController.text.trim(),
          genero: _selectedGender, // <--- Envia o género escolhido
        );
      }
    } catch (e) {
      setState(() { errorMessage = e.toString(); });
    } finally {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? "Bem-vindo" : "Criar Conta")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
            
                // --- CAMPOS DE REGISTO ---
                if (!isLogin) ...[
                  // Nome
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Nome", border: OutlineInputBorder()),
                    validator: (val) => val!.isEmpty ? "Insere o teu nome" : null,
                  ),
                  const SizedBox(height: 15),

                  // Seletor de Género (Dropdown)
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(labelText: "Género", border: OutlineInputBorder()),
                    items: _genders.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedGender = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                ],

                // --- CAMPOS COMUNS ---
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                  validator: (val) => val!.contains('@') ? null : "Email inválido",
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (val) => val!.length < 6 ? "Mínimo 6 caracteres" : null,
                ),
                const SizedBox(height: 25),
                
                isLoading 
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(15),
                          backgroundColor: Colors.black,
                        ),
                        child: Text(isLogin ? "ENTRAR" : "REGISTAR", style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(isLogin ? "Não tens conta? Regista-te" : "Já tens conta? Entra"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
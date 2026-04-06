import 'package:flutter/material.dart';
import '../screens/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(); 
  
  String _selectedGender = 'Masculino'; 
  final List<String> _genders = ['Masculino', 'Feminino', 'Outro', 'Prefiro não dizer'];

  bool isLogin = true; 
  bool isLoading = false;
  String? errorMessage;
  
  final Color kPrimaryGreen = const Color(0xFF0F9D58);

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
      errorMessage = null; 
      if (!isLogin) {
        _animationController.forward(); 
      } else {
        _animationController.reverse(); 
      }
    });
  }

Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus(); // Fecha o teclado

    setState(() { isLoading = true; errorMessage = null; });

    try {
      if (isLogin) {
        // LOGIN
        await AuthService().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // REGISTO
        await AuthService().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          nome: _nameController.text.trim(),
          genero: _selectedGender,
        );
      }

      // --- CORREÇÃO AQUI ---
      // Se chegou aqui, é porque não houve erro (catch não foi ativado).
      // Então fechamos o ecrã de Login e voltamos ao Perfil (que já vai estar atualizado).
      if (mounted) {
        Navigator.pop(context); 
      }

    } catch (e) {
      // Se houver erro, ficamos no ecrã e mostramos a mensagem
      if (mounted) {
        setState(() { 
          errorMessage = e.toString().replaceAll("Exception:", "").trim(); 
        });
      }
    } finally {
      // Paramos o loading (importante se houve erro, se não houve o pop já tratou de tudo)
      if (mounted) setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      // ResizeToAvoidBottomInset ajuda quando o teclado abre
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          // 1. FUNDO VERDE (Topo - Mais pequeno agora, 35%)
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.35, // Reduzi de 0.4 para 0.35
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPrimaryGreen, kPrimaryGreen.withOpacity(0.8)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40), // Curva mais pequena
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 60, color: Colors.white), // Ícone menor
                  const SizedBox(height: 5),
                  Text(
                    isLogin ? "Bem-vindo!" : "Criar Conta",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  // Removi o texto extra para poupar espaço
                  const SizedBox(height: 30), 
                ],
              ),
            ),
          ),

          // 2. BOTÃO VOLTAR (NOVO)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context), // Volta para trás
              ),
            ),
          ),

          // 3. CONTEÚDO SCROLLÁVEL
          // Usamos Positioned.fill com SingleChildScrollView para garantir que tudo cabe
          Positioned.fill(
            top: size.height * 0.25, // Começa mais acima
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // CARD DO FORMULÁRIO
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20), // Padding menor
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // ERRO
                          if (errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: Colors.red[50], borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!)
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(errorMessage!, style: TextStyle(color: Colors.red[800], fontSize: 12))),
                                ],
                              ),
                            ),

                          // CAMPOS EXTRAS (Registo)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: !isLogin 
                            ? Column(
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    label: "Nome",
                                    icon: Icons.person_outline,
                                    validator: (val) => val!.isEmpty ? "Obrigatório" : null,
                                  ),
                                  const SizedBox(height: 15), // Espaço reduzido
                                  _buildGenderDropdown(),
                                  const SizedBox(height: 15),
                                ],
                              ) 
                            : const SizedBox.shrink(),
                          ),

                          // EMAIL & PASS
                          _buildTextField(
                            controller: _emailController,
                            label: "Email",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) => val!.contains('@') ? null : "Email inválido",
                          ),
                          
                          const SizedBox(height: 15),
                          
                          _buildTextField(
                            controller: _passwordController,
                            label: "Password",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            validator: (val) => val!.length < 6 ? "Mín. 6 carateres" : null,
                          ),

                          const SizedBox(height: 25),

                          // BOTÃO AÇÃO
                          SizedBox(
                            width: double.infinity,
                            height: 48, // Altura reduzida (era 55)
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
                              child: isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isLogin ? "ENTRAR" : "CRIAR CONTA", 
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // RODAPÉ (Links)
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin ? "Não tens conta?" : "Já tens conta?",
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      TextButton(
                        onPressed: _toggleAuthMode,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5)),
                        child: Text(
                          isLogin ? "Regista-te" : "Entra aqui",
                          style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  // Margem extra em baixo para garantir que o scroll funciona bem com teclado
                  const SizedBox(height: 50), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS MAIS COMPACTOS ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14), // Fonte menor
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon, color: kPrimaryGreen, size: 20), // Ícone menor
        filled: true,
        fillColor: Colors.grey[50],
        // Padding interno reduzido
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15), 
        isDense: true, // Faz o campo ocupar menos espaço vertical
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPrimaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      icon: Icon(Icons.arrow_drop_down, color: kPrimaryGreen, size: 20),
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: "Género",
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(Icons.people_outline, color: kPrimaryGreen, size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPrimaryGreen, width: 1.5),
        ),
      ),
      items: _genders.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() { _selectedGender = newValue!; });
      },
    );
  }
}
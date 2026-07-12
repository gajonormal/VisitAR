import 'package:flutter/material.dart';
import '../screens/services/auth_service.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

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
    
    FocusScope.of(context).unfocus();

    setState(() { isLoading = true; errorMessage = null; });

    try {
      if (isLogin) {
        // Autentica utilizador existente
        await AuthService().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Cria nova conta e regista o utilizador no Firestore
        await AuthService().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          nome: _nameController.text.trim(),
          genero: _selectedGender,
        );
      }

      // Sucesso: regressa ao ecrã anterior
      if (mounted) {
        Navigator.pop(context); 
      }

    } catch (e) {
      // Mapeia o erro do Firebase para uma mensagem localizada
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        final errStr = e.toString().toLowerCase();

        String localizedError;
        if (errStr.contains('invalid-credential') || errStr.contains('invalid_credential') || errStr.contains('wrong-password') || errStr.contains('user-not-found')) {
          localizedError = l.invalidCredentialError;
        } else if (errStr.contains('email-already-in-use') || errStr.contains('email_already_in_use')) {
          localizedError = l.emailAlreadyInUseError;
        } else if (errStr.contains('weak-password') || errStr.contains('weak_password')) {
          localizedError = l.weakPasswordError;
        } else if (errStr.contains('network-request-failed') || errStr.contains('network_request_failed')) {
          localizedError = l.networkRequestFailed;
        } else if (errStr.contains('too-many-requests') || errStr.contains('too_many_requests')) {
          localizedError = l.tooManyRequestsError;
        } else if (errStr.contains('user-disabled') || errStr.contains('user_disabled')) {
          localizedError = l.userDisabledError;
        } else if (errStr.contains('operation-not-allowed') || errStr.contains('operation_not_allowed')) {
          localizedError = l.operationNotAllowedError;
        } else {
          localizedError = l.genericAuthError;
        }

        setState(() { errorMessage = localizedError; });
      }
    } finally {
      // Garante o fecho do estado de carregamento após a operação
      if (mounted) setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          // Fundo de destaque gradiente no topo do ecrã
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.35,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPrimaryGreen, kPrimaryGreen.withValues(alpha: 0.8)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, size: 60, color: Colors.white),
                  SizedBox(height: 5),
                  Text(
                    isLogin ? AppLocalizations.of(context)!.welcomeTitle : AppLocalizations.of(context)!.createAccountTitle,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 30), 
                ],
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Formulário principal em cartão com scroll
          Positioned.fill(
            top: size.height * 0.25,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Apresenta mensagem de erro caso a autenticação falhe
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
                                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(child: Text(errorMessage!, style: TextStyle(color: Colors.red[800], fontSize: 12))),
                                ],
                              ),
                            ),

                          // Campos adicionais visíveis apenas no modo de registo
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: !isLogin 
                            ? Column(
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    label: AppLocalizations.of(context)!.name,
                                    icon: Icons.person_outline,
                                    validator: (val) => val!.isEmpty ? AppLocalizations.of(context)!.fieldRequired : null,
                                  ),
                                  SizedBox(height: 15),
                                  _buildGenderDropdown(),
                                  SizedBox(height: 15),
                                ],
                              ) 
                            : const SizedBox.shrink(),
                          ),

                          _buildTextField(
                            controller: _emailController,
                            label: AppLocalizations.of(context)!.email,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) => val!.contains('@') ? null : AppLocalizations.of(context)!.emailInvalid,
                          ),
                          
                          SizedBox(height: 15),
                          
                          _buildTextField(
                            controller: _passwordController,
                            label: "Password",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            validator: (val) => val!.length < 6 ? AppLocalizations.of(context)!.minPasswordLength : null,
                          ),

                          SizedBox(height: 25),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
                              child: isLoading 
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isLogin ? AppLocalizations.of(context)!.loginButton : AppLocalizations.of(context)!.signUpButton, 
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Alterna entre os modos de login e registo
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin ? AppLocalizations.of(context)!.dontHaveAccount : AppLocalizations.of(context)!.alreadyHaveAccount,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      TextButton(
                        onPressed: _toggleAuthMode,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5)),
                        child: Text(
                          isLogin ? AppLocalizations.of(context)!.registerNow : AppLocalizations.of(context)!.loginHere,
                          style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  // Margem extra na base para evitar sobreposição do teclado
                  SizedBox(height: 50), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói um campo de texto formatado

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
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon, color: kPrimaryGreen, size: 20),
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

  String _getGenderTranslation(BuildContext context, String gender) {
    switch (gender) {
      case 'Masculino': return AppLocalizations.of(context)!.genderMale;
      case 'Feminino': return AppLocalizations.of(context)!.genderFemale;
      case 'Outro': return AppLocalizations.of(context)!.genderOther;
      case 'Prefiro não dizer': return AppLocalizations.of(context)!.genderPreferNotToSay;
      default: return gender;
    }
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      icon: Icon(Icons.arrow_drop_down, color: kPrimaryGreen, size: 20),
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.gender,
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
          child: Text(_getGenderTranslation(context, value)),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() { _selectedGender = newValue!; });
      },
    );
  }
}
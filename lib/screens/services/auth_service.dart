import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Autentica o utilizador com email e password.
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Regista um novo utilizador e cria o documento de perfil no Firestore.
  Future<void> signUp({
    required String email,
    required String password,
    required String nome,
    required String genero,
  }) async {
    // Cria a conta no Firebase Authentication
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: password
    );
    
    User? user = result.user;

    if (user != null) {
      // Cria o documento de perfil do utilizador no Firestore
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'nome': nome,
        'email': email,
        'genero': genero,
        'urlFoto': '',               // Foto de perfil — preenchida após upload
        'linguagem': 'pt',           // Idioma padrão
        // Listas inicializadas a vazio
        'favoritosPois': [],
        'favoritosRoteiros': [],
        'roteirosOffline': [],
        'poisOffline': [],
      });
    }
  }

  /// Termina a sessão do utilizador atual.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // --- REGISTO COMPLETO (Com todos os campos do relatório) ---
  Future<void> signUp({
    required String email, 
    required String password,
    required String nome,
    required String genero, // <--- Novo Campo: Género
  }) async {
    // 1. Criar conta de Autenticação
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: password
    );
    
    User? user = result.user;

    if (user != null) {
      // 2. Criar o documento na BD com a TUA estrutura exata
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'nome': nome,
        'email': email,
        'genero': genero,            // Guarda o género escolhido
        'urlFoto': '',               // Começa vazio (fará upload depois)
        'linguagem': 'pt',           // Defeito
        
        // As tuas listas (Arrays) começam vazias
        'favoritosPois': [],         
        'favoritosRoteiros': [],     
        'roteirosOffline': [],       
        'poisOffline': [],           // Adicionei este também como pediste
      });
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
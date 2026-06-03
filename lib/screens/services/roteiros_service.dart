import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/roteiro.dart';

class RoteirosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Retorna um stream com todos os roteiros
  Stream<List<Roteiro>> getRoteiros() {
    return _firestore
        .collection('roteiros')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Roteiro.fromFirestore(doc)).toList();
          list.sort((a, b) => (b.dataCriacao ?? DateTime.now()).compareTo(a.dataCriacao ?? DateTime.now()));
          return list;
        });
  }

  /// Retorna apenas os roteiros criados por um utilizador específico (Os meus roteiros)
  Stream<List<Roteiro>> getUserRoteiros() {
    if (_uid == null) return Stream.value([]);
    
    return _firestore
        .collection('roteiros')
        .where('criadorId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Roteiro.fromFirestore(doc)).toList();
          list.sort((a, b) => (b.dataCriacao ?? DateTime.now()).compareTo(a.dataCriacao ?? DateTime.now()));
          return list;
        });
  }

  /// Retorna apenas os roteiros sugeridos (criados pelo admin)
  Stream<List<Roteiro>> getSuggestedRoteiros() {
    return _firestore
        .collection('roteiros')
        .where('criadorId', isEqualTo: 'admin')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Roteiro.fromFirestore(doc)).toList();
          list.sort((a, b) => (b.dataCriacao ?? DateTime.now()).compareTo(a.dataCriacao ?? DateTime.now()));
          return list;
        });
  }

  /// Criar um novo roteiro
  Future<void> createRoteiro(Roteiro roteiro) async {
    if (_uid == null) throw Exception("Utilizador não autenticado");
    
    // Garantir que o criador é o utilizador atual (a não ser que seja admin a usar outro fluxo, mas para users normais é assim)
    final newRoteiro = Roteiro(
      id: '', // Firebase gera isto
      titulo: roteiro.titulo,
      descricao: roteiro.descricao,
      imagemCapa: roteiro.imagemCapa,
      poiIds: roteiro.poiIds,
      dificuldade: roteiro.dificuldade,
      duracao: roteiro.duracao,
      distancia: roteiro.distancia,
      avaliacao: roteiro.avaliacao,
      criadorId: _uid!,
      dataCriacao: DateTime.now(),
    );

    await _firestore.collection('roteiros').add(newRoteiro.toMap());
  }

  // --- ROTEIROS CONCLUÍDOS ---

  /// Marca um roteiro como concluído para o utilizador atual
  Future<void> markRoteiroAsCompleted(String roteiroId) async {
    if (_uid == null) return;

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('concluidos')
        .doc(roteiroId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Verifica se um roteiro já foi concluído
  Future<bool> isCompleted(String roteiroId) async {
    if (_uid == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('concluidos')
        .doc(roteiroId)
        .get();

    return doc.exists;
  }

  /// Retorna um stream com os IDs dos roteiros concluídos
  Stream<List<String>> getCompletedRoteirosIds() {
    if (_uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('concluidos')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}

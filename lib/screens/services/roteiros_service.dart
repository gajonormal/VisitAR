import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/roteiro.dart';

class RoteirosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<Roteiro?> getRoteiroStream(String roteiroId) {
    return _firestore.collection('roteiros').doc(roteiroId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Roteiro.fromFirestore(doc);
    });
  }

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

  /// Retorna os roteiros do Explorar (criados pelo utilizador atual + admin)
  Stream<List<Roteiro>> getExploreRoteiros() {
    if (_uid == null) return getSuggestedRoteiros();

    return _firestore
        .collection('roteiros')
        .where('criadorId', whereIn: ['admin', _uid])
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Roteiro.fromFirestore(doc)).toList();
          list.sort((a, b) => (b.dataCriacao ?? DateTime.now()).compareTo(a.dataCriacao ?? DateTime.now()));
          return list;
        });
  }

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
      criadorId: _uid!,
      dataCriacao: DateTime.now(),
    );

    await _firestore.collection('roteiros').add(newRoteiro.toMap());
  }

  /// Atualizar um roteiro existente
  Future<void> updateRoteiro(Roteiro roteiro) async {
    if (_uid == null) throw Exception("Utilizador não autenticado");
    // Verify if the current user is the creator (or admin)
    final doc = await _firestore.collection('roteiros').doc(roteiro.id).get();
    if (doc.exists && doc.data()?['criadorId'] != _uid && _uid != 'admin') {
      throw Exception("Não tens permissão para editar este roteiro");
    }

    await _firestore.collection('roteiros').doc(roteiro.id).update(roteiro.toMap());
  }

  /// Apagar um roteiro existente
  Future<void> deleteRoteiro(String id) async {
    if (_uid == null) throw Exception("Utilizador não autenticado");
    final doc = await _firestore.collection('roteiros').doc(id).get();
    if (doc.exists && doc.data()?['criadorId'] != _uid && _uid != 'admin') {
      throw Exception("Não tens permissão para apagar este roteiro");
    }

    await _firestore.collection('roteiros').doc(id).delete();
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

  /// Retorna um stream com os roteiros concluídos pelo utilizador atual
  Stream<List<Roteiro>> getCompletedRoteiros() {
    if (_uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('concluidos')
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((doc) => doc.id).toList();
          if (ids.isEmpty) return [];

          // Buscar os roteiros correspondentes (em lotes de 10 por limitação do Firestore)
          List<Roteiro> result = [];
          for (int i = 0; i < ids.length; i += 10) {
            final batch = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
            final snap = await _firestore
                .collection('roteiros')
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            result.addAll(snap.docs.map((doc) => Roteiro.fromFirestore(doc)));
          }
          return result;
        });
  }
}

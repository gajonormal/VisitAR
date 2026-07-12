import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/poi.dart';
import '../../models/roteiro.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Retorna o UID do utilizador autenticado, ou null se não houver sessão
  String? get _uid => _auth.currentUser?.uid;

  /// Adiciona um POI aos favoritos do utilizador no Firestore
  Future<void> addFavorite(POI poi) async {
    if (_uid == null) throw Exception('Utilizador não autenticado');

    // Guarda apenas os campos necessários para exibir o POI nas listagens de favoritos
    final data = {
      'id': poi.id,
      'name': poi.nome,
      'category': poi.categoria,
      'latitude': poi.localizacao.latitude,
      'longitude': poi.localizacao.longitude,
      'images': poi.imagens,
      'descriptionMap': poi.mapaDescricao,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(poi.id)
        .set(data);
  }

  /// Remove um POI dos favoritos
  Future<void> removeFavorite(String poiId) async {
    if (_uid == null) return;
    
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(poiId)
        .delete();
  }

  /// Verifica se um dado POI é favorito do utilizador.
  Future<bool> isFavorite(String poiId) async {
    if (_uid == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(poiId)
        .get();

    return doc.exists;
  }

  /// Stream em tempo real com os POIs favoritos do utilizador, ordenados do mais recente.
  Stream<QuerySnapshot<Map<String, dynamic>>> getFavoritePoisStream() {
    if (_uid == null) return const Stream.empty();
    return _firestore.collection('users').doc(_uid).collection('favorites').orderBy('timestamp', descending: true).snapshots();
  }

  /// Converte um snapshot do Firestore numa lista de objetos POI.
  List<POI> mapPoisFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return POI(
        id: data['id'] ?? doc.id,
        nome: data['name'] ?? 'Desconhecido',
        categoria: data['category'] ?? 'Outro',
        localizacao: LatLng(data['latitude'] ?? 0.0, data['longitude'] ?? 0.0),
        imagens: List<String>.from(data['images'] ?? []),
        mapaAudio: {},
        mapaDescricao: Map<String, dynamic>.from(data['descriptionMap'] ?? {}),
      );
    }).toList();
  }

  // --- FAVORITOS: ROTEIROS ---

  /// Adiciona um roteiro aos favoritos do utilizador no Firestore.
  Future<void> addFavoriteRoteiro(Roteiro roteiro) async {
    if (_uid == null) throw Exception('Utilizador não autenticado');

    final data = roteiro.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorite_roteiros')
        .doc(roteiro.id)
        .set(data);
  }

  /// Remove um roteiro dos favoritos do utilizador.
  Future<void> removeFavoriteRoteiro(String roteiroId) async {
    if (_uid == null) return;
    
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorite_roteiros')
        .doc(roteiroId)
        .delete();
  }

  /// Verifica se um roteiro é favorito do utilizador.
  Future<bool> isFavoriteRoteiro(String roteiroId) async {
    if (_uid == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorite_roteiros')
        .doc(roteiroId)
        .get();

    return doc.exists;
  }

  /// Stream em tempo real com os roteiros favoritos do utilizador, ordenados do mais recente.
  Stream<QuerySnapshot<Map<String, dynamic>>> getFavoriteRoteirosStream() {
    if (_uid == null) return const Stream.empty();
    return _firestore.collection('users').doc(_uid).collection('favorite_roteiros').orderBy('timestamp', descending: true).snapshots();
  }

  /// Converte um snapshot do Firestore numa lista de objetos Roteiro.
  List<Roteiro> mapRoteirosFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Roteiro(
        id: data['id'] ?? doc.id,
        titulo: data['titulo'] ?? 'Desconhecido',
        descricao: data['descricao'] ?? '',
        imagemCapa: data['imagemCapa'] ?? '',
        poiIds: List<String>.from(data['poiIds'] ?? []),
        categoria: data['categoria'] ?? 'Histórico',
        duracao: data['duracao'] ?? '0h',
        distancia: (data['distancia'] ?? 0.0).toDouble(),
        criadorId: data['criadorId'] ?? '',
      );
    }).toList();
  }
}



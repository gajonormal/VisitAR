import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/poi.dart';
import '../../models/roteiro.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Verifica se o utilizador está autenticado
  String? get _uid => _auth.currentUser?.uid;

  /// Adiciona um POI aos favoritos do utilizador no Firestore
  Future<void> addFavorite(POI poi) async {
    if (_uid == null) throw Exception("Utilizador não autenticado");

    // Guardamos um subconjunto dos dados do POI nos favoritos para facilitar a listagem
    final data = {
      'id': poi.id,
      'name': poi.name,
      'category': poi.category,
      'latitude': poi.location.latitude,
      'longitude': poi.location.longitude,
      'images': poi.images,
      'descriptionMap': poi.descriptionMap,
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

  /// Verifica se um dado POI é favorito
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getFavoritePoisStream() {
    if (_uid == null) return const Stream.empty();
    return _firestore.collection('users').doc(_uid).collection('favorites').orderBy('timestamp', descending: true).snapshots();
  }

  List<POI> mapPoisFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return POI(
        id: data['id'] ?? doc.id,
        name: data['name'] ?? 'Desconhecido',
        category: data['category'] ?? 'Outro',
        location: LatLng(data['latitude'] ?? 0.0, data['longitude'] ?? 0.0),
        images: List<String>.from(data['images'] ?? []),
        audioMap: {},
        descriptionMap: Map<String, dynamic>.from(data['descriptionMap'] ?? {}),
        arModelUrl: '', 
        arScale: 1.0,
      );
    }).toList();
  }

  // --- FAVORITOS ROTEIROS ---

  Future<void> addFavoriteRoteiro(Roteiro roteiro) async {
    if (_uid == null) throw Exception("Utilizador não autenticado");

    final data = roteiro.toMap();
    data['timestamp'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorite_roteiros')
        .doc(roteiro.id)
        .set(data);
  }

  Future<void> removeFavoriteRoteiro(String roteiroId) async {
    if (_uid == null) return;
    
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('favorite_roteiros')
        .doc(roteiroId)
        .delete();
  }

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

  Stream<QuerySnapshot<Map<String, dynamic>>> getFavoriteRoteirosStream() {
    if (_uid == null) return const Stream.empty();
    return _firestore.collection('users').doc(_uid).collection('favorite_roteiros').orderBy('timestamp', descending: true).snapshots();
  }

  List<Roteiro> mapRoteirosFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Roteiro(
        id: data['id'] ?? doc.id,
        titulo: data['titulo'] ?? 'Desconhecido',
        descricao: data['descricao'] ?? '',
        imagemCapa: data['imagemCapa'] ?? '',
        poiIds: List<String>.from(data['poiIds'] ?? []),
        dificuldade: data['dificuldade'] ?? 'FÁCIL',
        duracao: data['duracao'] ?? '0h',
        distancia: (data['distancia'] ?? 0.0).toDouble(),
        criadorId: data['criadorId'] ?? '',
      );
    }).toList();
  }
}

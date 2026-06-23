import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/badge_model.dart';
import '../../models/poi.dart';
import '../../models/roteiro.dart';

class PassportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  static const double kVisitRadiusMeters = 50.0;

  // ─────────────────────────────────────────────
  // VISITAS
  // ─────────────────────────────────────────────

  /// Verifica se o utilizador já visitou este POI
  Future<bool> hasVisited(String poiId) async {
    if (_uid == null) return false;
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('visits')
        .doc(poiId)
        .get();
    return doc.exists;
  }

  /// Stream das visitas do utilizador
  Stream<QuerySnapshot<Map<String, dynamic>>> getVisitsStream() {
    if (_uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('visits')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Calcula a distância ao POI (em metros). Retorna null se não conseguir localização.
  Future<double?> getDistanceToPoi(POI poi) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));

      return Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        poi.localizacao.latitude,
        poi.localizacao.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  /// Regista a visita e verifica novas badges. Retorna as badges desbloqueadas.
  Future<List<BadgeModel>> registerVisit(POI poi) async {
    if (_uid == null) throw Exception('Não autenticado');

    final visitRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('visits')
        .doc(poi.id);

    // Idempotente: não regista duas vezes
    if ((await visitRef.get()).exists) return [];

    await visitRef.set({
      'poiId': poi.id,
      'poiName': poi.nome,
      'poiCategory': poi.categoria,
      'poiImage': poi.imagens.isNotEmpty ? poi.imagens.first : '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return await _checkAndAwardBadges();
  }

  // ─────────────────────────────────────────────
  // ROTEIROS CONCLUÍDOS
  // ─────────────────────────────────────────────

  /// Verifica se o roteiro está concluído (todos os POIs visitados)
  Future<RoteiroProgress> getRoteiroProgress(Roteiro roteiro) async {
    if (_uid == null) return RoteiroProgress(visitedCount: 0, total: roteiro.poiIds.length);

    final visitsSnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('visits')
        .get();

    final visitedIds = visitsSnap.docs.map((d) => d.id).toSet();
    final count = roteiro.poiIds.where((id) => visitedIds.contains(id)).length;

    return RoteiroProgress(visitedCount: count, total: roteiro.poiIds.length);
  }

  Stream<RoteiroProgress> getRoteiroProgressStream(Roteiro roteiro) {
    if (_uid == null) {
      return Stream.value(RoteiroProgress(visitedCount: 0, total: roteiro.poiIds.length));
    }
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('visits')
        .snapshots()
        .map((snap) {
          final visitedIds = snap.docs.map((d) => d.id).toSet();
          final count = roteiro.poiIds.where((id) => visitedIds.contains(id)).length;
          return RoteiroProgress(visitedCount: count, total: roteiro.poiIds.length);
        });
  }

  /// Regista roteiro como concluído e verifica badges. Retorna badges desbloqueadas.
  Future<List<BadgeModel>> registerRoteiroCompletion(String roteiroId) async {
    if (_uid == null) return [];

    final ref = _firestore
        .collection('users')
        .doc(_uid)
        .collection('concluidos')
        .doc(roteiroId);

    if ((await ref.get()).exists) return [];

    await ref.set({
      'roteiroId': roteiroId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return await _checkAndAwardBadges();
  }

  // ─────────────────────────────────────────────
  // ROTEIROS CRIADOS
  // ─────────────────────────────────────────────

  /// Deve ser chamado quando o utilizador cria um roteiro.
  Future<List<BadgeModel>> onRoteiroCreated() async {
    return await _checkAndAwardBadges();
  }

  // ─────────────────────────────────────────────
  // BADGES
  // ─────────────────────────────────────────────

  /// Stream dos badges do utilizador
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserBadgesStream() {
    if (_uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('badges')
        .orderBy('unlockedAt', descending: true)
        .snapshots();
  }

  /// Seed de badges no Firestore (executar apenas uma vez via admin)
  Future<void> seedBadges() async {
    final batch = _firestore.batch();
    for (final badge in kDefaultBadges) {
      final ref = _firestore.collection('badges').doc(badge['id'] as String);
      batch.set(ref, badge, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Verifica todas as condições e atribui as badges que ainda não foram ganhas
  Future<List<BadgeModel>> _checkAndAwardBadges() async {
    if (_uid == null) return [];

    // Buscar todos os badges disponíveis
    final allBadgesSnap = await _firestore.collection('badges').get();
    final allBadges = allBadgesSnap.docs.map(BadgeModel.fromFirestore).toList();

    // Badges que o utilizador já tem
    final userBadgesSnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('badges')
        .get();
    final earnedIds = userBadgesSnap.docs.map((d) => d.id).toSet();

    // Contadores actuais
    final visitsSnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('visits')
        .get();
    final visitCount = visitsSnap.docs.length;

    final completedSnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('concluidos')
        .get();
    final completedCount = completedSnap.docs.length;

    final createdSnap = await _firestore
        .collection('roteiros')
        .where('criadorId', isEqualTo: _uid)
        .get();
    final createdCount = createdSnap.docs.length;

    // Categorias visitadas
    final Map<String, int> categoryCount = {};
    for (final doc in visitsSnap.docs) {
      final cat = (doc.data()['poiCategory'] ?? '') as String;
      if (cat.isNotEmpty) categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
    }

    final List<BadgeModel> newlyEarned = [];

    for (final badge in allBadges) {
      if (earnedIds.contains(badge.id)) continue;

      bool unlocked = false;

      switch (badge.condicaoTipo) {
        case 'visitar_poi':
          unlocked = visitCount >= badge.quantidadeAlvo;
          break;
        case 'concluir_roteiro':
          unlocked = completedCount >= badge.quantidadeAlvo;
          break;
        case 'criar_roteiro':
          unlocked = createdCount >= badge.quantidadeAlvo;
          break;
        case 'visitar_categoria':
          final count = categoryCount[badge.condicaoAlvo] ?? 0;
          unlocked = count >= badge.quantidadeAlvo;
          break;
      }

      if (unlocked) {
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('badges')
            .doc(badge.id)
            .set({
          'badgeId': badge.id,
          'titulo': badge.titulo,
          'descricao': badge.descricao,
          'categoria': badge.categoria,
          'urlIcone': badge.urlIcone,
          'unlockedAt': FieldValue.serverTimestamp(),
        });
        newlyEarned.add(badge);
      }
    }

    return newlyEarned;
  }
}

class RoteiroProgress {
  final int visitedCount;
  final int total;

  const RoteiroProgress({required this.visitedCount, required this.total});

  bool get isCompleted => total > 0 && visitedCount >= total;
  double get percentage => total > 0 ? visitedCount / total : 0.0;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
class Roteiro {
  final String id;
  final String titulo;
  final String descricao;
  final String imagemCapa;
  final List<String> poiIds; // Lista de IDs dos POIs neste roteiro
  final String dificuldade; // "FÁCIL", "MODERADO", "DIFÍCIL"
  final String duracao; // ex: "2h 30m"
  final double distancia; // em km
  final String criadorId; // 'admin' ou ID do utilizador autenticado
  final DateTime? dataCriacao;
  final List<LatLng>? routePoints; // Rota offline em cache

  Roteiro({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.imagemCapa,
    required this.poiIds,
    required this.dificuldade,
    required this.duracao,
    required this.distancia,
    required this.criadorId,
    this.dataCriacao,
    this.routePoints,
  });

  factory Roteiro.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Roteiro(
      id: doc.id,
      titulo: data['titulo'] ?? 'Sem Título',
      descricao: data['descricao'] ?? 'Sem descrição.',
      imagemCapa: data['imagemCapa'] ?? '',
      poiIds: List<String>.from(data['poiIds'] ?? []),
      dificuldade: data['dificuldade'] ?? 'FÁCIL',
      duracao: data['duracao'] ?? '0h 0m',
      distancia: (data['distancia'] ?? 0.0).toDouble(),
      criadorId: data['criadorId'] ?? 'admin',
      dataCriacao: data['dataCriacao'] != null 
          ? (data['dataCriacao'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'imagemCapa': imagemCapa,
      'poiIds': poiIds,
      'dificuldade': dificuldade,
      'duracao': duracao,
      'distancia': distancia,
      'criadorId': criadorId,
      'dataCriacao': dataCriacao != null ? Timestamp.fromDate(dataCriacao!) : FieldValue.serverTimestamp(),
      'routePoints': routePoints?.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    };
  }

  factory Roteiro.fromMap(Map<String, dynamic> data) {
    return Roteiro(
      id: data['id'] ?? '',
      titulo: data['titulo'] ?? 'Sem Título',
      descricao: data['descricao'] ?? 'Sem descrição.',
      imagemCapa: data['imagemCapa'] ?? '',
      poiIds: List<String>.from(data['poiIds'] ?? []),
      dificuldade: data['dificuldade'] ?? 'FÁCIL',
      duracao: data['duracao'] ?? '0h 0m',
      distancia: (data['distancia'] ?? 0.0).toDouble(),
      criadorId: data['criadorId'] ?? 'admin',
      dataCriacao: null, // Ignoramos dataCriacao offline para simplicidade
      routePoints: data['routePoints'] != null
          ? (data['routePoints'] as List).map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble())).toList()
          : null,
    );
  }

  // Utilizado especificamente para guardar offline através de jsonEncode
  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'imagemCapa': imagemCapa,
      'poiIds': poiIds,
      'dificuldade': dificuldade,
      'duracao': duracao,
      'distancia': distancia,
      'criadorId': criadorId,
      'dataCriacao': dataCriacao?.toIso8601String(),
      'routePoints': routePoints?.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    };
  }
}

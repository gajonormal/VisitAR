import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Roteiro {
  final String id;
  final String titulo;
  final String descricao; // Mantido para compatibilidade — usa mapaDescricao para multilíngue
  final Map<String, String> mapaDescricao; // {'pt': '...', 'en': '...'}
  final String imagemCapa;
  final List<String> poiIds; // Lista de IDs dos POIs neste roteiro
  final String categoria; // "Histórico", "Natureza", "Geológico", "Trilho"
  final String duracao; // ex: "2h 30m"
  final double distancia; // em km
  final String criadorId; // 'admin' ou ID do utilizador autenticado
  final DateTime? dataCriacao;
  final List<LatLng>? routePoints; // Rota offline em cache
  final String? trailAsset; // Caminho do asset GeoJSON para trilhos pré-feitos

  Roteiro({
    required this.id,
    required this.titulo,
    required this.imagemCapa,
    required this.poiIds,
    required this.categoria,
    required this.duracao,
    required this.distancia,
    required this.criadorId,
    Map<String, String>? mapaDescricao,
    String? descricao,
    this.dataCriacao,
    this.routePoints,
    this.trailAsset,
  })  : mapaDescricao = mapaDescricao ??
            (descricao != null ? {'pt': descricao, 'en': descricao} : {}),
        descricao = descricao ?? mapaDescricao?['pt'] ?? '';

  /// Retorna a descrição no idioma pedido, com fallback para 'pt' e depois string vazia.
  String getDescricao(String languageCode) {
    if (mapaDescricao.containsKey(languageCode)) {
      return mapaDescricao[languageCode]!;
    }
    return mapaDescricao['pt'] ?? descricao;
  }

  factory Roteiro.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Suporte a ambos os formatos: mapaDescricao (novo) e descricao (legado)
    Map<String, String> mapa = {};
    if (data['mapaDescricao'] != null) {
      mapa = Map<String, String>.from(data['mapaDescricao']);
    } else if (data['descricao'] != null) {
      final d = data['descricao'] as String;
      mapa = {'pt': d, 'en': d};
    }

    return Roteiro(
      id: doc.id,
      titulo: data['titulo'] ?? 'Sem Título',
      mapaDescricao: mapa,
      imagemCapa: data['imagemCapa'] ?? '',
      poiIds: List<String>.from(data['poiIds'] ?? []),
      categoria: data['categoria'] ?? 'Histórico',
      duracao: data['duracao'] ?? '0h 0m',
      distancia: (data['distancia'] ?? 0.0).toDouble(),
      criadorId: data['criadorId'] ?? 'admin',
      dataCriacao: data['dataCriacao'] != null
          ? (data['dataCriacao'] as dynamic).toDate()
          : null,
      trailAsset: data['trailAsset'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'mapaDescricao': mapaDescricao,
      'imagemCapa': imagemCapa,
      'poiIds': poiIds,
      'categoria': categoria,
      'duracao': duracao,
      'distancia': distancia,
      'criadorId': criadorId,
      'dataCriacao': dataCriacao != null
          ? dataCriacao
          : FieldValue.serverTimestamp(),
      'routePoints': routePoints
          ?.map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      if (trailAsset != null) 'trailAsset': trailAsset,
    };
  }

  factory Roteiro.fromMap(Map<String, dynamic> data) {
    Map<String, String> mapa = {};
    if (data['mapaDescricao'] != null) {
      mapa = Map<String, String>.from(data['mapaDescricao']);
    } else if (data['descricao'] != null) {
      final d = data['descricao'] as String;
      mapa = {'pt': d, 'en': d};
    }

    return Roteiro(
      id: data['id'] ?? '',
      titulo: data['titulo'] ?? 'Sem Título',
      mapaDescricao: mapa,
      imagemCapa: data['imagemCapa'] ?? '',
      poiIds: List<String>.from(data['poiIds'] ?? []),
      categoria: data['categoria'] ?? 'Histórico',
      duracao: data['duracao'] ?? '0h 0m',
      distancia: (data['distancia'] ?? 0.0).toDouble(),
      criadorId: data['criadorId'] ?? 'admin',
      dataCriacao: null,
      routePoints: data['routePoints'] != null
          ? (data['routePoints'] as List)
              .map((p) => LatLng(
                    (p['lat'] as num).toDouble(),
                    (p['lng'] as num).toDouble(),
                  ))
              .toList()
          : null,
      trailAsset: data['trailAsset'] as String?,
    );
  }

  // Utilizado especificamente para guardar offline através de jsonEncode
  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'titulo': titulo,
      'mapaDescricao': mapaDescricao,
      'imagemCapa': imagemCapa,
      'poiIds': poiIds,
      'categoria': categoria,
      'duracao': duracao,
      'distancia': distancia,
      'criadorId': criadorId,
      'dataCriacao': dataCriacao?.toIso8601String(),
      'routePoints': routePoints
          ?.map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      if (trailAsset != null) 'trailAsset': trailAsset,
    };
  }
}

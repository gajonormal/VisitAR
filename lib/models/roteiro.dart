import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Roteiro {
  final String id;
  final String titulo;
  /// Mantido para compatibilidade — usar [mapaDescricao] para suporte multilíngue.
  final String descricao;
  /// Descrições traduzidas, com o código do idioma como chave (ex: {'pt': '...', 'en': '...'}).
  final Map<String, String> mapaDescricao;
  final String imagemCapa;
  /// Lista de IDs dos POIs incluídos neste roteiro.
  final List<String> poiIds;
  /// Categoria do roteiro (ex: "Histórico", "Natureza", "Geológico", "Trilho").
  final String categoria;
  /// Duração estimada do roteiro (ex: "2h 30m").
  final String duracao;
  /// Distância total do roteiro, em quilómetros.
  final double distancia;
  /// ID do criador — pode ser 'admin' ou o ID de um utilizador autenticado.
  final String criadorId;
  final DateTime? dataCriacao;
  /// Pontos da rota em cache para uso offline.
  final List<LatLng>? routePoints;
  /// Caminho para o asset GeoJSON de trilhos pré-definidos.
  final String? trailAsset;

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

    // Suporta tanto o novo formato (mapaDescricao) como o formato legado (descricao como string simples).
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

  /// Serializa o roteiro para um mapa compatível com jsonEncode, para persistência offline.
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

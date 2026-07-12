import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa uma imagem panorâmica 360° associada a um POI,
/// incluindo os marcadores interativos que apontam para outros POIs.
class Panorama {
  final String id;
  final String urlImagem;
  final List<PanoramaMarker> marcadores;

  Panorama({
    required this.id,
    required this.urlImagem,
    required this.marcadores,
  });

  /// Constrói um [Panorama] a partir de um documento do Firestore.
  factory Panorama.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Panorama(
      id: doc.id,
      urlImagem: data['imageUrl'] ?? '',
      marcadores: (data['markers'] as List<dynamic>? ?? [])
          .map((m) => PanoramaMarker.fromMap(m as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializa o panorama para um mapa, para envio ao Firestore.
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': urlImagem,
      'markers': marcadores.map((m) => m.toMap()).toList(),
    };
  }
}

/// Marcador interativo dentro de uma imagem panorâmica 360°,
/// que aponta para um POI numa direção específica.
class PanoramaMarker {
  final String idPoi;
  /// Ângulo horizontal (yaw) do marcador, em graus.
  final double rotacaoHorizontal;
  /// Ângulo vertical (pitch) do marcador, em graus.
  final double rotacaoVertical;

  PanoramaMarker({
    required this.idPoi,
    required this.rotacaoHorizontal,
    required this.rotacaoVertical,
  });

  /// Constrói um [PanoramaMarker] a partir de um mapa de dados.
  factory PanoramaMarker.fromMap(Map<String, dynamic> map) {
    return PanoramaMarker(
      idPoi: map['poiId'] ?? '',
      rotacaoHorizontal: (map['yaw'] ?? 0.0).toDouble(),
      rotacaoVertical: (map['pitch'] ?? 0.0).toDouble(),
    );
  }

  /// Serializa o marcador para um mapa, para envio ao Firestore.
  Map<String, dynamic> toMap() {
    return {
      'poiId': idPoi,
      'yaw': rotacaoHorizontal,
      'pitch': rotacaoVertical,
    };
  }
}

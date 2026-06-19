import 'package:cloud_firestore/cloud_firestore.dart';

class Panorama {
  final String id;
  final String urlImagem;
  final List<PanoramaMarker> marcadores;

  Panorama({
    required this.id,
    required this.urlImagem,
    required this.marcadores,
  });

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

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': urlImagem,
      'markers': marcadores.map((m) => m.toMap()).toList(),
    };
  }
}

class PanoramaMarker {
  final String idPoi;
  final double rotacaoHorizontal;
  final double rotacaoVertical;

  PanoramaMarker({
    required this.idPoi,
    required this.rotacaoHorizontal,
    required this.rotacaoVertical,
  });

  factory PanoramaMarker.fromMap(Map<String, dynamic> map) {
    return PanoramaMarker(
      idPoi: map['poiId'] ?? '',
      rotacaoHorizontal: (map['yaw'] ?? 0.0).toDouble(),
      rotacaoVertical: (map['pitch'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'poiId': idPoi,
      'yaw': rotacaoHorizontal,
      'pitch': rotacaoVertical,
    };
  }
}

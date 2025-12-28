import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class POI {
  final String id;
  final String name;
  final String category;
  final LatLng location;
  final List<String> images;
  final String audioUrl;
  final double rating;
  
  // Campos processados
  final String description;
  final String arModelUrl;
  final double arScale;

  POI({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.images,
    required this.audioUrl,
    required this.rating,
    required this.description,
    required this.arModelUrl,
    this.arScale = 1.0,
  });

  factory POI.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // 1. Tratar Localização
    GeoPoint geo = data['localizacao'] ?? const GeoPoint(0, 0);

    // 2. Tratar Imagens (Proteção contra links vazios)
    List<dynamic> rawImages = data['imagens'] ?? [];
    List<String> listaImagens = rawImages
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty) // Remove strings vazias ""
        .toList();
    
    if (listaImagens.isEmpty) {
      listaImagens.add('https://via.placeholder.com/300'); // Imagem de segurança
    }

    // 3. Tratar Descrição (Map -> String)
    Map<String, dynamic> descMap = data['descricao'] ?? {};
    String textoDescricao = descMap['pt'] ?? descMap['en'] ?? 'Sem descrição.';

    // 4. Tratar AR (Map -> Campos)
    Map<String, dynamic> arMap = data['conteudoAr'] ?? {};
    
    return POI(
      id: doc.id,
      name: data['nome'] ?? 'Sem nome',
      category: data['categoria'] ?? 'Geral',
      location: LatLng(geo.latitude, geo.longitude),
      images: listaImagens,
      audioUrl: data['urlAudio'] ?? '',
      rating: (data['medAvaliacao'] ?? 0.0).toDouble(),
      description: textoDescricao,
      arModelUrl: arMap['modelUrl'] ?? '',
      arScale: (arMap['scale'] ?? 1.0).toDouble(),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class POI {
  final String id;
  final String name;
  final String category;
  final LatLng location;
  final List<String> images;
  final double rating;
  
  // Guardamos o mapa de descrições e o mapa de audios
  final Map<String, dynamic> descriptionMap; 
  final Map<String, dynamic> audioMap; 
  
  final String arModelUrl;
  final double arScale;

  POI({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.images,
    required this.rating,
    required this.descriptionMap,
    required this.audioMap,
    required this.arModelUrl,
    this.arScale = 1.0,
  });

  // --- 1. LER DO FIREBASE (Já tinhas isto) ---
  factory POI.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    GeoPoint geo = data['localizacao'] ?? const GeoPoint(0, 0);

    List<dynamic> rawImages = data['imagens'] ?? [];
    List<String> listaImagens = rawImages
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    
    if (listaImagens.isEmpty) {
      listaImagens.add('https://via.placeholder.com/300');
    }

    Map<String, dynamic> descMap;
    if (data['descricao'] is Map) {
      descMap = data['descricao'];
    } else if (data['descricao'] is String) {
      descMap = {'pt': data['descricao']};
    } else {
      descMap = {'pt': 'Sem descrição.'};
    }

    Map<String, dynamic> audMap = {};
    if (data['audioMap'] is Map) {
      audMap = data['audioMap'];
    } else if (data['urlAudio'] != null && data['urlAudio'].toString().isNotEmpty) {
      audMap = {'pt': data['urlAudio']};
    }

    Map<String, dynamic> arMap = data['conteudoAr'] ?? {};
    
    return POI(
      id: doc.id,
      name: data['nome'] ?? 'Sem nome',
      category: data['categoria'] ?? 'Geral',
      location: LatLng(geo.latitude, geo.longitude),
      images: listaImagens,
      rating: (data['medAvaliacao'] ?? 0.0).toDouble(),
      descriptionMap: descMap,
      audioMap: audMap,
      arModelUrl: arMap['modelUrl'] ?? '',
      arScale: (arMap['scale'] ?? 1.0).toDouble(),
    );
  }

  // --- 2. NOVO: CONVERTER PARA MAPA (Para o DownloadService guardar offline) ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'lat': location.latitude,
      'lng': location.longitude,
      'images': images,
      'rating': rating,
      'descriptionMap': descriptionMap,
      'audioMap': audioMap,
      'arModelUrl': arModelUrl,
      'arScale': arScale,
    };
  }

  // --- 3. NOVO: LER DO MAPA (Para o DownloadService ler do offline) ---
  factory POI.fromMap(Map<String, dynamic> map) {
    return POI(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      location: LatLng(map['lat'], map['lng']),
      images: List<String>.from(map['images']),
      rating: (map['rating'] ?? 0.0).toDouble(),
      descriptionMap: Map<String, dynamic>.from(map['descriptionMap'] ?? {}),
      audioMap: Map<String, dynamic>.from(map['audioMap'] ?? {}),
      arModelUrl: map['arModelUrl'] ?? '',
      arScale: (map['arScale'] ?? 1.0).toDouble(),
    );
  }

  // --- Helpers ---
  String getDescription(String langCode) {
    return descriptionMap[langCode] ?? descriptionMap['pt'] ?? descriptionMap['en'] ?? 'Sem descrição disponível.';
  }

  String get description => getDescription('pt');

  String getAudioUrl(String langCode) {
    return audioMap[langCode] ?? audioMap['pt'] ?? audioMap['en'] ?? '';
  }
}
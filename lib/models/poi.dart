import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class POI {
  final String id;
  final String nome;
  final String categoria;
  final LatLng localizacao;
  final List<String> imagens;
  
  final Map<String, dynamic> mapaDescricao; 
  final Map<String, dynamic> mapaAudio; 
  bool tem360;

  POI({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.localizacao,
    required this.imagens,
    required this.mapaDescricao,
    required this.mapaAudio,
    this.tem360 = false,
  });

  /// Constrói um [POI] a partir de um documento do Firestore.
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
      nome: data['nome'] ?? 'Sem nome',
      categoria: data['categoria'] ?? 'Geral',
      localizacao: LatLng(geo.latitude, geo.longitude),
      imagens: listaImagens,
      mapaDescricao: descMap,
      mapaAudio: audMap,
    );
  }

  /// Serializa o [POI] para um mapa, usado pelo DownloadService ao guardar dados offline.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'categoria': categoria,
      'lat': localizacao.latitude,
      'lng': localizacao.longitude,
      'imagens': imagens,
      'mapaDescricao': mapaDescricao,
      'mapaAudio': mapaAudio,
    };
  }

  /// Constrói um [POI] a partir de um mapa JSON, usado pelo DownloadService ao ler dados offline.
  factory POI.fromMap(Map<String, dynamic> map) {
    return POI(
      id: map['id'],
      nome: map['nome'],
      categoria: map['categoria'],
      localizacao: LatLng(map['lat'], map['lng']),
      imagens: List<String>.from(map['imagens']),
      mapaDescricao: Map<String, dynamic>.from(map['mapaDescricao'] ?? {}),
      mapaAudio: Map<String, dynamic>.from(map['mapaAudio'] ?? {}),
    );
  }

  /// Devolve a descrição no idioma indicado por [langCode].
  /// Usa português como fallback e, se não existir, devolve o primeiro idioma disponível.
  String getDescription(String langCode) {
    if (mapaDescricao.containsKey(langCode)) return mapaDescricao[langCode];
    if (mapaDescricao.containsKey('pt')) return mapaDescricao['pt'];
    if (mapaDescricao.isNotEmpty) return mapaDescricao.values.first;
    return 'Descrição indisponível.';
  }

  String get description => getDescription('pt');

  /// Devolve o URL do áudio no idioma indicado por [langCode].
  /// Usa português como fallback; devolve string vazia se não houver áudio disponível.
  String getAudioUrl(String langCode) {
    if (mapaAudio.containsKey(langCode)) return mapaAudio[langCode];
    if (mapaAudio.containsKey('pt')) return mapaAudio['pt'];
    if (mapaAudio.isNotEmpty) return mapaAudio.values.first;
    return '';
  }
}
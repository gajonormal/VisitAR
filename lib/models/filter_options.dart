class POIFilter {
  final String categoria;
  final bool temModelo3D;
  final bool temAudio;

  POIFilter({
    this.categoria = 'Tudo',
    this.temModelo3D = false,
    this.temAudio = false,
  });

  bool get isActive => categoria != 'Tudo' || temModelo3D || temAudio;

  POIFilter copyWith({
    String? categoria,
    bool? temModelo3D,
    bool? temAudio,
  }) {
    return POIFilter(
      categoria: categoria ?? this.categoria,
      temModelo3D: temModelo3D ?? this.temModelo3D,
      temAudio: temAudio ?? this.temAudio,
    );
  }

  // Novo método para verificar se um POI passa no filtro
  bool apply(dynamic poi) {
    if (!isActive) return true;
    if (categoria != 'Tudo' && poi.category.toLowerCase() != categoria.toLowerCase()) return false;
    if (temModelo3D && (poi.arModelUrl == null || poi.arModelUrl.isEmpty)) return false;
    if (temAudio && (poi.audioMap == null || poi.audioMap.isEmpty)) return false;
    return true;
  }
}

class RoteiroFilter {
  final String dificuldade;

  RoteiroFilter({
    this.dificuldade = 'Qualquer',
  });

  bool get isActive => dificuldade != 'Qualquer';

  RoteiroFilter copyWith({
    String? dificuldade,
  }) {
    return RoteiroFilter(
      dificuldade: dificuldade ?? this.dificuldade,
    );
  }

  // Novo método para verificar se um Roteiro passa no filtro
  bool apply(dynamic roteiro) {
    if (!isActive) return true;
    if (dificuldade != 'Qualquer' && roteiro.dificuldade.toLowerCase() != dificuldade.toLowerCase()) return false;
    return true;
  }
}

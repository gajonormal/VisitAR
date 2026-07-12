import 'package:visitar_teste/models/roteiro.dart';

/// Opções de filtragem aplicadas à lista de POIs.
class POIFilter {
  final String categoria;
  final bool tem360;

  POIFilter({
    this.categoria = 'Tudo',
    this.tem360 = false,
  });

  bool get isActive => categoria != 'Tudo' || tem360;

  POIFilter copyWith({
    String? categoria,
    bool? tem360,
  }) {
    return POIFilter(
      categoria: categoria ?? this.categoria,
      tem360: tem360 ?? this.tem360,
    );
  }

  /// Verifica se um [poi] passa nos filtros ativos.
  /// Devolve verdadeiro se não houver filtros ativos ou se o POI cumprir todas as condições.
  bool apply(dynamic poi) {
    if (!isActive) return true;
    if (categoria != 'Tudo' && poi.categoria.toLowerCase() != categoria.toLowerCase()) return false;
    if (tem360 && !poi.tem360) return false;
    return true;
  }
}

/// Opções de filtragem aplicadas à lista de roteiros.
class RoteiroFilter {
  final String categoria;
  final bool offlineOnly;

  RoteiroFilter({
    this.categoria = 'Qualquer',
    this.offlineOnly = false,
  });

  bool get isActive => categoria != 'Qualquer' || offlineOnly;

  RoteiroFilter copyWith({
    String? categoria,
    bool? offlineOnly,
  }) {
    return RoteiroFilter(
      categoria: categoria ?? this.categoria,
      offlineOnly: offlineOnly ?? this.offlineOnly,
    );
  }

  /// Verifica se um [roteiro] passa nos filtros ativos.
  bool apply(Roteiro roteiro) {
    if (categoria != 'Qualquer' && roteiro.categoria.toLowerCase() != categoria.toLowerCase()) return false;
    return true;
  }
}

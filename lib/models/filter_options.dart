import 'package:visitar_teste/models/roteiro.dart';

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

  // Novo mÃ©todo para verificar se um POI passa no filtro
  bool apply(dynamic poi) {
    if (!isActive) return true;
    if (categoria != 'Tudo' && poi.categoria.toLowerCase() != categoria.toLowerCase()) return false;
    if (tem360 && !poi.tem360) return false;
    return true;
  }
}

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

  bool apply(Roteiro roteiro) {
    if (categoria != 'Qualquer' && roteiro.categoria.toLowerCase() != categoria.toLowerCase()) return false;
    return true;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/poi.dart';

class DatabaseService {
  // Vai buscar à coleção 'pois' que criaste na imagem
  final CollectionReference poiCollection = 
      FirebaseFirestore.instance.collection('pois');

  // Função para obter a lista de POIs
  Future<List<POI>> getPOIs() async {
    try {
      QuerySnapshot snapshot = await poiCollection.get();
      return snapshot.docs.map((doc) {
        return POI.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print("Erro ao buscar POIs: $e");
      return [];
    }
  }

  // Função para buscar múltiplos POIs através dos seus IDs (Para os Roteiros)
  Future<List<POI>> getPOIsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    try {
      // O Firestore 'whereIn' suporta até 10 valores por query. 
      // Para roteiros curtos (<=10 POIs), funciona bem numa só query.
      if (ids.length <= 10) {
        QuerySnapshot snapshot = await poiCollection.where(FieldPath.documentId, whereIn: ids).get();
        List<POI> pois = snapshot.docs.map((doc) => POI.fromFirestore(doc)).toList();
        // Ordenar conforme a ordem original dos IDs
        pois.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
        return pois;
      } else {
        // Se houver mais de 10, buscar todos e filtrar localmente
        List<POI> all = await getPOIs();
        List<POI> filtered = all.where((poi) => ids.contains(poi.id)).toList();
        filtered.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
        return filtered;
      }
    } catch (e) {
      print("Erro ao buscar POIs por ID: $e");
      return [];
    }
  }
}
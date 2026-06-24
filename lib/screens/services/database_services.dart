import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '/models/poi.dart';
import '../../models/panorama.dart';

class DatabaseService {
  final CollectionReference poiCollection = 
      FirebaseFirestore.instance.collection('pois');

  // POIs mock removidos da app.
  // Função para obter a lista de POIs
  Future<List<POI>> getPOIs() async {
    List<POI> pois = [];
    try {
      // Timeout de 4 segundos para evitar que a app congele caso não haja ligação
      QuerySnapshot snapshot = await poiCollection.get().timeout(const Duration(seconds: 4));
      for (var doc in snapshot.docs) {
        try {
          POI p = POI.fromFirestore(doc);
          // Adiciona se não for duplicado
          if (!pois.any((existing) => existing.id == p.id)) {
            pois.add(p);
          }
        } catch (e) {
          print("Erro ao converter POI individual do Firestore: $e");
        }
      }
    } catch (e) {
      print("Erro ao buscar POIs do Firestore: $e");
    }

    try {
      QuerySnapshot panSnapshot = await FirebaseFirestore.instance.collection('panoramas').get().timeout(const Duration(seconds: 4));
      Set<String> panIds = panSnapshot.docs.map((d) => d.id).toSet();
      for (var poi in pois) {
        poi.tem360 = panIds.contains(poi.id);
      }
    } catch (e) {
      print("Erro ao buscar panoramas: $e");
    }

    return pois;
  }

  // Função para buscar múltiplos POIs através dos seus IDs (Para os Roteiros)
  Future<List<POI>> getPOIsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    // Filtramos apenas os IDs reais (ignorando qualquer ID 'mock_' que possa ter ficado em cache nalgum roteiro antigo)
    List<String> firestoreIds = ids.where((id) => !id.startsWith('mock_')).toList();
    List<POI> foundPois = [];

    if (firestoreIds.isNotEmpty) {
      try {
        if (firestoreIds.length <= 10) {
          QuerySnapshot snapshot = await poiCollection
              .where(FieldPath.documentId, whereIn: firestoreIds)
              .get()
              .timeout(const Duration(seconds: 4));
          for (var doc in snapshot.docs) {
            try {
              POI p = POI.fromFirestore(doc);
              foundPois.add(p);
            } catch (e) {
              print("Erro ao converter POI individual por ID: $e");
            }
          }
        } else {
          List<POI> all = await getPOIs();
          List<POI> filtered = all.where((poi) => firestoreIds.contains(poi.id)).toList();
          foundPois.addAll(filtered);
        }
      } catch (e) {
        print("Erro ao buscar POIs do Firestore por ID: $e");
      }
    }

    // Ordenar conforme a ordem original dos IDs
    foundPois.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));

    try {
      QuerySnapshot panSnapshot = await FirebaseFirestore.instance.collection('panoramas').get().timeout(const Duration(seconds: 4));
      Set<String> panIds = panSnapshot.docs.map((d) => d.id).toSet();
      for (var poi in foundPois) {
        poi.tem360 = panIds.contains(poi.id);
      }
    } catch (e) {
      print("Erro ao buscar panoramas: $e");
    }

    return foundPois;
  }

  // --- PANORAMAS ---

  Future<Panorama?> getPanoramaForPoi(String poiId) async {
    try {
      var doc = await FirebaseFirestore.instance.collection('panoramas').doc(poiId).get();
      if (doc.exists) {
        return Panorama.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print("Erro ao obter panorama: $e");
      return null;
    }
  }
}
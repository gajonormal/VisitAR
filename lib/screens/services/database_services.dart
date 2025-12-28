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
}
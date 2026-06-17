import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '/models/poi.dart';

class DatabaseService {
  final CollectionReference poiCollection = 
      FirebaseFirestore.instance.collection('pois');

  // POIs locais de teste — criados via método para evitar problemas de inicialização estática.
  static List<POI> _getMockPois() {
    return [
      POI(
        id: 'mock_poi_castelo_cb',
        name: 'Castelo de Castelo Branco',
        category: 'Monumento',
        location: LatLng(39.822180, -7.491095),
        images: ['https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600&q=80'],
        audioMap: {},
        rating: 4.8,
        descriptionMap: {'pt': 'Castelo templário em Castelo Branco, com vistas incríveis sobre a cidade.'},
        arModelUrl: '',
        arScale: 1.0,
      ),
      POI(
        id: 'mock_poi_jardim_cb',
        name: 'Jardim do Paço Episcopal',
        category: 'Jardim',
        location: LatLng(39.8235, -7.4925),
        images: ['https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=600&q=80'],
        audioMap: {},
        rating: 4.7,
        descriptionMap: {'pt': 'Lindo jardim barroco em Castelo Branco, famoso pelas suas estátuas de reis.'},
        arModelUrl: '',
        arScale: 1.0,
      ),
      POI(
        id: 'mock_poi_castelo_guimaraes',
        name: 'Castelo de Guimarães',
        category: 'Monumento',
        location: LatLng(41.4478, -8.2891),
        images: ['https://images.unsplash.com/photo-1533154683836-84ea7a0bc310?w=600&q=80'],
        audioMap: {
          'pt': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          'en': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        },
        rating: 4.9,
        descriptionMap: {
          'pt': 'O berço de Portugal, o imponente Castelo de Guimarães.',
          'en': 'The cradle of Portugal, the imposing Guimarães Castle.',
        },
        arModelUrl: '',
        arScale: 1.0,
      ),
      POI(
        id: 'mock_poi_paco_duques',
        name: 'Paço dos Duques de Bragança',
        category: 'Palácio',
        location: LatLng(41.4460, -8.2900),
        images: ['https://images.unsplash.com/photo-1520637836993-a8c4b4c04c72?w=600&q=80'],
        audioMap: {},
        rating: 4.6,
        descriptionMap: {'pt': 'Palácio medieval majestoso em Guimarães.'},
        arModelUrl: '',
        arScale: 1.0,
      ),
      POI(
        id: 'mock_poi_oliveira',
        name: 'Praça da Oliveira',
        category: 'Praça',
        location: LatLng(41.4420, -8.2940),
        images: ['https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=600&q=80'],
        audioMap: {},
        rating: 4.7,
        descriptionMap: {'pt': 'A praça mais charmosa e animada no centro histórico de Guimarães.'},
        arModelUrl: '',
        arScale: 1.0,
      ),
    ];
  }

  // Função para obter a lista de POIs
  Future<List<POI>> getPOIs() async {
    // Começa logo com os mock POIs garantidos
    List<POI> pois = _getMockPois();
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
    return pois;
  }

  // Função para buscar múltiplos POIs através dos seus IDs (Para os Roteiros)
  Future<List<POI>> getPOIsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    // Separar IDs locais dos do Firestore
    List<String> firestoreIds = ids.where((id) => !id.startsWith('mock_')).toList();
    List<POI> foundPois = [];

    // Adicionar os mocks correspondentes aos IDs solicitados
    final mockPois = _getMockPois();
    for (var id in ids) {
      if (id.startsWith('mock_')) {
        var mock = mockPois.firstWhere(
          (p) => p.id == id,
          orElse: () => mockPois.first,
        );
        foundPois.add(mock);
      }
    }

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
    return foundPois;
  }
}
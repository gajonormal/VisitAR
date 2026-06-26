import 'dart:io';
import 'dart:convert'; // Para JSON
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/poi.dart';
import '../../models/roteiro.dart';
import '../../models/panorama.dart';
import 'database_services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'routing_service.dart';

class DownloadService {
  final Dio _dio = Dio();

  /// Faz o download de um ficheiro e devolve o caminho local.
  Future<String?> downloadFile(String url, String fileName) async {
    try {
      if (url.isEmpty) return null; // ProteÃ§Ã£o contra URLs vazias

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // 2. Verificar se jÃ¡ existe
      if (await file.exists()) {
        print("Ficheiro jÃ¡ existe localmente: $filePath");
        return filePath; 
      }

      // 3. Se nÃ£o existe, faz o download
      print("A iniciar download de: $url");
      await _dio.download(
        url, 
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Podes descomentar para debug, mas pode poluir a consola
            // print("Download: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      print("Download concluÃ­do: $filePath");
      return filePath;

    } catch (e) {
      print("Erro no download: $e");
      return null;
    }
  }

  /// Verifica se um ficheiro existe
  Future<bool> checkFileExists(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    return await file.exists();
  }

  /// Retorna o caminho completo do ficheiro
  Future<String> getFullPath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  // --- NOVAS FUNÃ‡Ã•ES PARA O MODO OFFLINE COMPLETO ---

  /// 1. Apagar um ficheiro fÃ­sico
  Future<bool> deleteFile(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Verifica se o fileName jÃ¡ Ã© um caminho completo ou sÃ³ o nome
      final path = fileName.contains('/') ? fileName : '${directory.path}/$fileName';
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
        print("Ficheiro apagado: $path");
        return true;
      }
      return false;
    } catch (e) {
      print("Erro ao apagar ficheiro: $e");
      return false;
    }
  }

  /// 2. Guardar os dados do POI (JSON) para uso offline
  Future<void> saveOfflinePoiData(POI poi, {bool isStandalone = false}) async {
    final prefs = await SharedPreferences.getInstance();
    // Converte o objeto POI (que jÃ¡ tem caminhos locais nas imagens) para texto
    String jsonString = jsonEncode(poi.toMap());
    
    await prefs.setString('offline_poi_${poi.id}', jsonString);
    
    // Adiciona Ã  lista de IDs offline (para listagens futuras)
    List<String> offlineIds = prefs.getStringList('offline_poi_ids') ?? [];
    if (!offlineIds.contains(poi.id)) {
      offlineIds.add(poi.id);
      await prefs.setStringList('offline_poi_ids', offlineIds);
    }

    if (isStandalone) {
      List<String> standaloneIds = prefs.getStringList('standalone_offline_poi_ids') ?? [];
      if (!standaloneIds.contains(poi.id)) {
        standaloneIds.add(poi.id);
        await prefs.setStringList('standalone_offline_poi_ids', standaloneIds);
      }
    }
  }

  /// 3. Ler o POI Offline (Recuperar o objeto ao abrir a app)
  Future<POI?> getOfflinePoi(String poiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonString = prefs.getString('offline_poi_$poiId');
      
      if (jsonString != null) {
        Map<String, dynamic> map = jsonDecode(jsonString);
        POI poi = POI.fromMap(map);
        // Check if there is an offline panorama for this POI
        String? panoJson = prefs.getString('offline_panorama_${poi.id}');
        poi.tem360 = panoJson != null;
        return poi;
      }
      return null;
    } catch (e) {
      print("Erro ao ler offline POI: $e");
      return null;
    }
  }

  /// 4. Remover os dados do POI (JSON) da memÃ³ria
  Future<void> removeOfflinePoiData(String poiId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_poi_$poiId');

    List<String> offlineIds = prefs.getStringList('offline_poi_ids') ?? [];
    offlineIds.remove(poiId);
    await prefs.setStringList('offline_poi_ids', offlineIds);

    List<String> standaloneIds = prefs.getStringList('standalone_offline_poi_ids') ?? [];
    standaloneIds.remove(poiId);
    await prefs.setStringList('standalone_offline_poi_ids', standaloneIds);
  }

  // --- PANORAMAS OFFLINE ---
  Future<void> saveOfflinePanorama(Panorama panorama) async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(panorama.toMap());
    await prefs.setString('offline_panorama_${panorama.id}', jsonString);
  }

  Future<Panorama?> getOfflinePanorama(String poiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonString = prefs.getString('offline_panorama_$poiId');
      if (jsonString != null) {
        Map<String, dynamic> map = jsonDecode(jsonString);
        return Panorama(
          id: poiId,
          urlImagem: map['imageUrl'] ?? '',
          marcadores: (map['markers'] as List<dynamic>? ?? [])
              .map((m) => PanoramaMarker.fromMap(m as Map<String, dynamic>))
              .toList(),
        );
      }
      return null;
    } catch (e) {
      print("Erro ao ler panorama offline: $e");
      return null;
    }
  }

  // --- ROTEIROS OFFLINE ---

  /// Faz download de todos os recursos necessÃ¡rios para um Roteiro
  Future<bool> downloadRoteiroCompleto(Roteiro roteiro, List<POI> pois) async {
    try {
      // 1. PrÃ©-calcular a rota entre todos os POIs
      List<LatLng> waypoints = pois.map((p) => p.localizacao).toList();
      List<LatLng> fullRoute = await RoutingService.getFullRoteiroRoute(waypoints);
      
      String localCapa = roteiro.imagemCapa;

      // 2. Fazer download da capa do roteiro se existir
      if (roteiro.imagemCapa.startsWith('http')) {
        String fileName = 'roteiro_${roteiro.id}_capa.jpg';
        String? localPath = await downloadFile(roteiro.imagemCapa, fileName);
        if (localPath != null) {
          localCapa = localPath;
        } else {
          // Se falhou o download (ex: Modo Avião), abortamos o Roteiro inteiro!
          throw Exception("Falha de Rede (SocketException) no download da capa");
        }
      }

      // 3. Guardar o Roteiro offline com a imagem local e a rota pre-calculada
      final localRoteiro = Roteiro(
        id: roteiro.id,
        titulo: roteiro.titulo,
        mapaDescricao: roteiro.mapaDescricao,
        imagemCapa: localCapa,
        poiIds: roteiro.poiIds,
        categoria: roteiro.categoria,
        duracao: roteiro.duracao,
        distancia: roteiro.distancia,
        criadorId: roteiro.criadorId,
        dataCriacao: roteiro.dataCriacao,
        routePoints: fullRoute.isNotEmpty ? fullRoute : null,
        trailAsset: roteiro.trailAsset,
      );
      await saveOfflineRoteiroData(localRoteiro);

      // 3. Fazer download de TODOS os POIs (Modelos 3D, imagens, etc.)
      for (var poi in pois) {

        // Download Images
        List<String> localImages = [];
        for (int i = 0; i < poi.imagens.length; i++) {
          String url = poi.imagens[i];
          if (url.startsWith('http')) {
            String imgName = 'poi_${poi.id}_img_$i.jpg';
            String? localImg = await downloadFile(url, imgName);
            if (localImg != null) localImages.add(localImg);
          } else {
            localImages.add(url);
          }
        }

        // Download Audios
        Map<String, dynamic> localAudioMap = {};
        for (String lang in poi.mapaAudio.keys) {
          String aUrl = poi.mapaAudio[lang];
          if (aUrl.isNotEmpty && aUrl.startsWith('http')) {
            String audioName = 'poi_${poi.id}_audio_$lang.mp3';
            String? lAudio = await downloadFile(aUrl, audioName);
            if (lAudio != null) {
              localAudioMap[lang] = lAudio;
            } else {
              localAudioMap[lang] = aUrl; // fallback
            }
          } else {
            localAudioMap[lang] = aUrl;
          }
        }

        // Download Panorama (se existir)
        var panorama = await DatabaseService().getPanoramaForPoi(poi.id);
        if (panorama != null && panorama.urlImagem.isNotEmpty) {
          String panoName = "poi_${poi.id}_panorama.jpg";
          String? localPanoPath = await downloadFile(panorama.urlImagem, panoName);
          if (localPanoPath != null) {
            Panorama offlinePano = Panorama(
              id: panorama.id,
              urlImagem: localPanoPath,
              marcadores: panorama.marcadores,
            );
            await saveOfflinePanorama(offlinePano);
          }
        }

        // Save local POI copy
        final offlinePoi = POI(
          id: poi.id,
          nome: poi.nome,
          categoria: poi.categoria,
          localizacao: poi.localizacao,
          imagens: localImages,
          mapaDescricao: poi.mapaDescricao,
          mapaAudio: localAudioMap,
        );
        await saveOfflinePoiData(offlinePoi);
      }
      return true;
    } catch (e) {
      print("Erro ao baixar roteiro completo: $e");
      return false;
    }
  }

  Future<void> saveOfflineRoteiroData(Roteiro roteiro) async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(roteiro.toJsonMap());
    
    await prefs.setString('offline_roteiro_${roteiro.id}', jsonString);
    
    List<String> offlineIds = prefs.getStringList('offline_roteiro_ids') ?? [];
    if (!offlineIds.contains(roteiro.id)) {
      offlineIds.add(roteiro.id);
      await prefs.setStringList('offline_roteiro_ids', offlineIds);
    }
  }

  Future<Roteiro?> getOfflineRoteiro(String roteiroId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonString = prefs.getString('offline_roteiro_$roteiroId');
      
      if (jsonString != null) {
        Map<String, dynamic> map = jsonDecode(jsonString);
        return Roteiro.fromMap(map);
      }
      return null;
    } catch (e) {
      print("Erro ao ler offline Roteiro: $e");
      return null;
    }
  }

  Future<void> removeOfflineRoteiroData(String roteiroId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_roteiro_$roteiroId');

    List<String> offlineIds = prefs.getStringList('offline_roteiro_ids') ?? [];
    offlineIds.remove(roteiroId);
    await prefs.setStringList('offline_roteiro_ids', offlineIds);
  }

  /// Remove um roteiro e todos os seus POIs que nÃ£o estejam a ser usados noutro lado
  Future<void> deleteRoteiroCompletoSmart(Roteiro roteiro) async {
    // 1. Apagar capa do roteiro
    if (roteiro.imagemCapa.isNotEmpty) {
      await deleteFile("roteiro_${roteiro.id}_capa.jpg");
    }
    // 2. Apagar Roteiro JSON
    await removeOfflineRoteiroData(roteiro.id);

    // 3. Obter todos os roteiros offline RESTANTES
    final prefs = await SharedPreferences.getInstance();
    List<String> remainingRoteiroIds = prefs.getStringList('offline_roteiro_ids') ?? [];
    
    Set<String> poisInOtherRoteiros = {};
    for (String rId in remainingRoteiroIds) {
      Roteiro? r = await getOfflineRoteiro(rId);
      if (r != null) {
        poisInOtherRoteiros.addAll(r.poiIds);
      }
    }

    List<String> standaloneIds = prefs.getStringList('standalone_offline_poi_ids') ?? [];

    // 4. Verificar POIs do roteiro que foi apagado
    for (String poiId in roteiro.poiIds) {
      bool isStandalone = standaloneIds.contains(poiId);
      bool isUsedElsewhere = poisInOtherRoteiros.contains(poiId);

      if (!isStandalone && !isUsedElsewhere) {
        // Pode ser apagado em seguranÃ§a!
        POI? poi = await getOfflinePoi(poiId);
        if (poi != null) {
          // Apagar Modelo 3D
          await deleteFile("poi_${poi.id}.glb");
          // Apagar Imagens
          for (int i = 0; i < poi.imagens.length; i++) {
            await deleteFile("poi_${poi.id}_img_$i.jpg");
          }
          // Apagar Ã¡udios
          for (String lang in poi.mapaAudio.keys) {
            await deleteFile("poi_${poi.id}_audio_$lang.mp3");
          }
          await deleteFile("poi_${poi.id}_audio.mp3");
          
          // Apagar Panorama (Correção do Bug do Modo Offline)
          await deleteFile("poi_${poi.id}_panorama.jpg");
          await prefs.remove('offline_panorama_${poi.id}');

          // Remover dados offline
          await removeOfflinePoiData(poi.id);
          await prefs.remove('nome_$poiId'); // remove nome guardado localmente
        }
      }
    }
  }
}

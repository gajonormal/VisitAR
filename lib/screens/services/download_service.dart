import 'dart:io';
import 'dart:convert';
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
      if (url.isEmpty) return null; // Proteção contra URLs vazias

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Verifica se o ficheiro já foi descarregado anteriormente
      if (await file.exists()) {
        return filePath;
      }

      // Ficheiro não existe localmente — inicia o download
      await _dio.download(
        url, 
        filePath,
        onReceiveProgress: (received, total) {},
      );

      return filePath;

    } catch (e) {
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

  // --- FUNÇÕES PARA O MODO OFFLINE COMPLETO ---

  /// Apaga um ficheiro físico do armazenamento local.
  Future<bool> deleteFile(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Suporta tanto o nome do ficheiro como um caminho absoluto
      final path = fileName.contains('/') ? fileName : '${directory.path}/$fileName';
      final file = File(path);

      if (await file.exists()) {
        await file.delete();

        return true;
      }
      return false;
    } catch (e) {

      return false;
    }
  }

  /// Serializa e guarda os dados de um POI em JSON para uso offline.
  Future<void> saveOfflinePoiData(POI poi, {bool isStandalone = false}) async {
    final prefs = await SharedPreferences.getInstance();
    // O objeto POI já deve ter os caminhos locais nas imagens antes de ser guardado
    String jsonString = jsonEncode(poi.toMap());
    
    await prefs.setString('offline_poi_${poi.id}', jsonString);
    
    // Mantém a lista de IDs offline atualizada para consultas futuras
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

  /// Recupera um POI guardado offline a partir do armazenamento local.
  Future<POI?> getOfflinePoi(String poiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonString = prefs.getString('offline_poi_$poiId');
      
      if (jsonString != null) {
        Map<String, dynamic> map = jsonDecode(jsonString);
        POI poi = POI.fromMap(map);
        // Verifica se existe um panorama 360° guardado offline para este POI
        String? panoJson = prefs.getString('offline_panorama_${poi.id}');
        poi.tem360 = panoJson != null;
        return poi;
      }
      return null;
    } catch (e) {

      return null;
    }
  }

  /// Remove os dados JSON de um POI do armazenamento offline.
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

      return null;
    }
  }

  // --- ROTEIROS OFFLINE ---

  /// Faz o download de todos os recursos necessários para um roteiro funcionar offline.
  Future<bool> downloadRoteiroCompleto(Roteiro roteiro, List<POI> pois) async {
    try {
      // Pré-calcula a rota pedestre entre todos os POIs do roteiro
      List<LatLng> waypoints = pois.map((p) => p.localizacao).toList();
      List<LatLng> fullRoute = await RoutingService.getFullRoteiroRoute(waypoints);
      
      String localCapa = roteiro.imagemCapa;

      // Descarrega a imagem de capa do roteiro, se for uma URL remota
      if (roteiro.imagemCapa.startsWith('http')) {
        String fileName = 'roteiro_${roteiro.id}_capa.jpg';
        String? localPath = await downloadFile(roteiro.imagemCapa, fileName);
        if (localPath != null) {
          localCapa = localPath;
        } else {
          // Falha no download da capa (ex: modo avião) — aborta o processo inteiro
          throw Exception("Falha de Rede (SocketException) no download da capa");
        }
      }

      // Guarda o roteiro offline com a imagem local e a rota pré-calculada
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

      // Descarrega todos os recursos de cada POI (imagens, áudios, panoramas)
      for (var poi in pois) {

        // Descarrega as imagens do POI
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

        // Descarrega os ficheiros de áudio em cada língua disponível
        Map<String, dynamic> localAudioMap = {};
        for (String lang in poi.mapaAudio.keys) {
          String aUrl = poi.mapaAudio[lang];
          if (aUrl.isNotEmpty && aUrl.startsWith('http')) {
            String audioName = 'poi_${poi.id}_audio_$lang.mp3';
            String? lAudio = await downloadFile(aUrl, audioName);
            if (lAudio != null) {
              localAudioMap[lang] = lAudio;
            } else {
              localAudioMap[lang] = aUrl; // fallback: mantém URL remota se o download falhar
            }
          } else {
            localAudioMap[lang] = aUrl;
          }
        }

        // Descarrega o panorama 360°, se existir para este POI
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

        // Guarda a cópia local do POI com todos os caminhos atualizados
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

  /// Remove um roteiro offline e os seus POIs, preservando os que estão noutros roteiros ou são standalone.
  Future<void> deleteRoteiroCompletoSmart(Roteiro roteiro) async {
    // Apaga a imagem de capa do roteiro
    if (roteiro.imagemCapa.isNotEmpty) {
      await deleteFile("roteiro_${roteiro.id}_capa.jpg");
    }
    // Remove os metadados JSON do roteiro
    await removeOfflineRoteiroData(roteiro.id);

    // Recolhe os IDs de todos os roteiros offline que ainda existem
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

    // Para cada POI do roteiro removido, verifica se pode ser apagado com segurança
    for (String poiId in roteiro.poiIds) {
      bool isStandalone = standaloneIds.contains(poiId);
      bool isUsedElsewhere = poisInOtherRoteiros.contains(poiId);

      if (!isStandalone && !isUsedElsewhere) {
        // POI não é utilizado em mais nenhum lado — pode ser apagado com segurança
        POI? poi = await getOfflinePoi(poiId);
        if (poi != null) {
          // Apaga o modelo 3D
          await deleteFile("poi_${poi.id}.glb");
          // Apaga as imagens
          for (int i = 0; i < poi.imagens.length; i++) {
            await deleteFile("poi_${poi.id}_img_$i.jpg");
          }
          // Apaga os ficheiros de áudio
          for (String lang in poi.mapaAudio.keys) {
            await deleteFile("poi_${poi.id}_audio_$lang.mp3");
          }
          await deleteFile("poi_${poi.id}_audio.mp3");
          
          // Apagar Panorama (Correção do Bug do Modo Offline)
          await deleteFile("poi_${poi.id}_panorama.jpg");
          await prefs.remove('offline_panorama_${poi.id}');

          // Remover dados offline
          await removeOfflinePoiData(poi.id);
          await prefs.remove('nome_$poiId'); // remove o nome guardado localmente
        }
      }
    }
  }
}

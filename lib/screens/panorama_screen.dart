import 'dart:io';
import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/panorama.dart';
import '../models/poi.dart';
import 'services/database_services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'details_screen.dart';
import 'package:provider/provider.dart';
import 'services/language_provider.dart';
import 'services/download_service.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';
class PanoramaScreen extends StatefulWidget {
  final Panorama panorama;
  final String initialPoiId;

  const PanoramaScreen({
    super.key, 
    required this.panorama,
    required this.initialPoiId,
  });

  @override
  State<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends State<PanoramaScreen> {
  final Map<String, POI> _poiCache = {};
  late Panorama _currentPanorama;
  
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  bool _isGyroEnabled = false;
  bool _isAutoRotateEnabled = true;
  bool _isAdminMode = false; // MODO DE EDICAO DE MARCADORES
  final PanoramaController _panoramaController = PanoramaController();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StateSetter? _bottomSheetState;

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void initState() {
    super.initState();
    _currentPanorama = widget.panorama;
    _loadPois();

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
      _bottomSheetState?.call(() {});
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
      _bottomSheetState?.call(() {});
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlayingAudio = state == PlayerState.playing);
      _bottomSheetState?.call(() {});
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _position = Duration.zero;
        });
      }
      _bottomSheetState?.call(() {});
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _loadPois() async {
    final ids = _currentPanorama.marcadores.map((m) => m.idPoi).toList();
    if (ids.isEmpty) return;
    
    final downloadService = DownloadService();
    List<String> onlineIdsToFetch = [];
    List<POI> finalPois = [];

    // Tentar ler offline primeiro
    for (String id in ids) {
      POI? offlinePoi = await downloadService.getOfflinePoi(id);
      if (offlinePoi != null) {
        finalPois.add(offlinePoi);
      } else {
        onlineIdsToFetch.add(id);
      }
    }

    if (onlineIdsToFetch.isNotEmpty) {
      try {
        final onlinePois = await DatabaseService().getPOIsByIds(onlineIdsToFetch);
        finalPois.addAll(onlinePois);
      } catch (e) {
        print("Erro ao carregar POIs online no Panorama: $e");
      }
    }

    if (mounted) {
      setState(() {
        for (var poi in finalPois) {
          _poiCache[poi.id] = poi;
        }
      });
    }
  }

  void _onPanoramaTap(double longitude, double latitude, double tilt) async {
    if (!_isAdminMode) return;
    
    // Obter todos os pontos para poder escolher
    final allPois = await DatabaseService().getPOIs();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Adicionar Marcador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Long: ${longitude.toStringAsFixed(2)} | Lat: ${latitude.toStringAsFixed(2)}'),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: allPois.length,
                itemBuilder: (context, index) {
                  final poi = allPois[index];
                  return ListTile(
                    title: Text(poi.nome),
                    subtitle: Text(poi.categoria),
                    onTap: () async {
                      Navigator.pop(ctx);
                      _saveNewMarker(longitude, latitude, poi.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewMarker(double lon, double lat, String poiId) async {
    final newMarker = PanoramaMarker(idPoi: poiId, rotacaoHorizontal: lon, rotacaoVertical: lat);
    
    // Atualizar no Firebase
    final docRef = FirebaseFirestore.instance.collection('panoramas').doc(_currentPanorama.id);
    await docRef.update({
      'markers': FieldValue.arrayUnion([
        {'poiId': poiId, 'yaw': lon, 'pitch': lat}
      ])
    });

    // Atualizar localmente
    setState(() {
      _currentPanorama.marcadores.add(newMarker);
    });
    // Carregar os dados deste novo POI caso nao esteja na cache
    _loadPois();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marcador adicionado ao panorama!')));
    }
  }

  void _onHotspotTap(PanoramaMarker marker) {
    if (_isAdminMode) {
      // No modo admin, perguntar se quer apagar o marcador
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remover Marcador?'),
          content: Text('Tem a certeza que deseja apagar este marcador do 360?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final docRef = FirebaseFirestore.instance.collection('panoramas').doc(_currentPanorama.id);
                await docRef.update({
                  'markers': FieldValue.arrayRemove([
                    {'poiId': marker.idPoi, 'yaw': marker.rotacaoHorizontal, 'pitch': marker.rotacaoVertical}
                  ])
                });
                setState(() {
                  _currentPanorama.marcadores.remove(marker);
                });
              }, 
              child: Text('Apagar', style: TextStyle(color: Colors.red))
            ),
          ],
        )
      );
      return;
    }

    final poi = _poiCache[marker.idPoi];
    if (poi == null) return;

    final langCode = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateModal) {
          _bottomSheetState = setStateModal;
          return Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (poi.mapaAudio[langCode] != null && poi.mapaAudio[langCode]!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                                child: Icon(Icons.volume_up_rounded, size: 20),
                              ),
                              SizedBox(width: 15),
                              Text(AppLocalizations.of(context)!.listenAudioGuide, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () async {
                                  if (_isPlayingAudio) {
                                    await _audioPlayer.pause();
                                  } else {
                                    final audioUrl = poi.mapaAudio[langCode]!;
                                    if (_position == Duration.zero) {
                                      if (audioUrl.startsWith('http')) {
                                        await _audioPlayer.play(UrlSource(audioUrl));
                                      } else {
                                        await _audioPlayer.play(DeviceFileSource(audioUrl));
                                      }
                                    } else {
                                      await _audioPlayer.resume();
                                    }
                                  }
                              },
                              child: Icon(
                                _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: kPrimaryGreen,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                        if (_duration != Duration.zero) ...[
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Text(_formatDuration(_position), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    trackHeight: 4,
                                    activeTrackColor: kPrimaryGreen,
                                    inactiveTrackColor: Colors.grey[300],
                                    thumbColor: kPrimaryGreen,
                                  ),
                                  child: Slider(
                                    value: _position.inSeconds.toDouble(),
                                    max: _duration.inSeconds.toDouble(),
                                    onChanged: (val) {
                                      _audioPlayer.seek(Duration(seconds: val.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              Text(_formatDuration(_duration), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.nome,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: kPrimaryGreen, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                poi.categoria,
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Fechar bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsScreen(poi: poi),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(AppLocalizations.of(context)!.readMore),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  poi.getDescription(langCode),
                  style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _bottomSheetState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    PanoramaMarker? initialMarker;
    try {
      initialMarker = _currentPanorama.marcadores.firstWhere((m) => m.idPoi == widget.initialPoiId);
    } catch (e) {
      // Se não houver marcador para o POI inicial, inicializamos um genérico a olhar em frente (0,0)
      initialMarker = PanoramaMarker(idPoi: '', rotacaoHorizontal: 0, rotacaoVertical: 0);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PanoramaViewer(
            panoramaController: _panoramaController,
            animSpeed: _isAutoRotateEnabled ? 1.0 : 0.0,
            sensorControl: _isGyroEnabled ? SensorControl.orientation : SensorControl.none,
            longitude: initialMarker.rotacaoHorizontal,
            latitude: initialMarker.rotacaoVertical,
            onTap: _isAdminMode ? _onPanoramaTap : null,
            hotspots: _currentPanorama.marcadores.map((marker) {
              return Hotspot(
                longitude: marker.rotacaoHorizontal,
                latitude: marker.rotacaoVertical,
                width: 32,
                height: 32,
                widget: GestureDetector(
                  onTap: () => _onHotspotTap(marker),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isAdminMode ? Colors.red : const Color(0xFF0F9D58),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Icon(
                      _isAdminMode ? Icons.delete_forever : Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            }).toList(),
            child: _currentPanorama.urlImagem.startsWith('http')
                ? Image(
                    image: CachedNetworkImageProvider(_currentPanorama.urlImagem),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  )
                : Image.file(
                    File(_currentPanorama.urlImagem),
                  ),
          ),
          
          // Controles no topo (Voltar e Modo Admin)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                    child: Icon(Icons.arrow_back, color: Colors.black, size: 22),
                  ),
                ),
              ],
            ),
          ),
          
          // Controles na base
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => setState(() => _isGyroEnabled = !_isGyroEnabled),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                    child: Icon(_isGyroEnabled ? Icons.explore : Icons.explore_off, color: _isGyroEnabled ? kPrimaryGreen : Colors.black, size: 22),
                  ),
                ),
                const SizedBox(width: 20),
                InkWell(
                  onTap: () {
                    setState(() => _isAutoRotateEnabled = !_isAutoRotateEnabled);
                    _panoramaController.setAnimSpeed(_isAutoRotateEnabled ? 1.0 : 0.0);
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                    child: Icon(_isAutoRotateEnabled ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



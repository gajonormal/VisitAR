import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/panorama.dart';
import '../models/poi.dart';
import 'services/database_services.dart';
import 'details_screen.dart';
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
  
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  bool _isGyroEnabled = false;
  bool _isAutoRotateEnabled = true;
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
    final ids = widget.panorama.marcadores.map((m) => m.idPoi).toList();
    if (ids.isEmpty) return;
    
    final pois = await DatabaseService().getPOIsByIds(ids);
    if (mounted) {
      setState(() {
        for (var poi in pois) {
          _poiCache[poi.id] = poi;
        }
      });
    }
  }

  void _onHotspotTap(PanoramaMarker marker) {
    final poi = _poiCache[marker.idPoi];
    if (poi == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateModal) {
          _bottomSheetState = setStateModal;
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (poi.mapaAudio['pt'] != null && poi.mapaAudio['pt']!.isNotEmpty)
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
                                  final audioUrl = poi.mapaAudio['pt']!;
                                  if (_duration == Duration.zero) {
                                    if (audioUrl.startsWith('http')) {
                                      await _audioPlayer.setSourceUrl(audioUrl);
                                    } else {
                                      await _audioPlayer.setSourceDeviceFile(audioUrl);
                                    }
                                  }
                                  await _audioPlayer.resume();
                                }
                              },
                              child: Icon(
                                _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                size: 44,
                                color: kPrimaryGreen,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: kPrimaryGreen,
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: kPrimaryGreen,
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            min: 0,
                            max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                            value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
                            onChanged: (v) async {
                              final position = Duration(milliseconds: v.toInt());
                              await _audioPlayer.seek(position);
                            },
                          ),
                        ),
                        SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_position), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Text(_formatDuration(_duration), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                  ),
                Text(poi.nome, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.1)),
                SizedBox(height: 5),
                Text(poi.categoria, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                SizedBox(height: 15),
                Text(
                  poi.mapaDescricao['pt'] ?? 'Sem descrição',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
                ),
                if (widget.initialPoiId != poi.id) ...[
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _audioPlayer.stop();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(poi: poi)));
                      },
                      child: Text("Explorar Local", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]
              ],
            ),
          );
        }
      ),
    ).then((_) {
      _bottomSheetState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // A rotação inicial para focar no POI que abriu o panorama
    final initialMarker = widget.panorama.marcadores.firstWhere(
      (m) => m.idPoi == widget.initialPoiId, 
      orElse: () => widget.panorama.marcadores.isNotEmpty ? widget.panorama.marcadores.first : PanoramaMarker(idPoi: '', rotacaoHorizontal: 0, rotacaoVertical: 0)
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.arrow_back, color: Colors.black, size: 22),
            ),
          ),
        ),
        actions: [
          if (_isPlayingAudio)
            Center(
              child: InkWell(
                onTap: () async {
                  await _audioPlayer.stop();
                  setState(() => _isPlayingAudio = false);
                },
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                  child: Icon(Icons.stop, color: Colors.red, size: 22),
                ),
              ),
            ),
          if (_isPlayingAudio) SizedBox(width: 10),
          Center(
            child: InkWell(
              onTap: () => setState(() => _isGyroEnabled = !_isGyroEnabled),
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: Icon(_isGyroEnabled ? Icons.explore : Icons.explore_off, color: _isGyroEnabled ? kPrimaryGreen : Colors.black, size: 22),
              ),
            ),
          ),
          SizedBox(width: 10),
          Center(
            child: InkWell(
              onTap: () {
                setState(() => _isAutoRotateEnabled = !_isAutoRotateEnabled);
                _panoramaController.setAnimSpeed(_isAutoRotateEnabled ? 1.0 : 0.0);
              },
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: Icon(_isAutoRotateEnabled ? Icons.threesixty : Icons.pause, color: _isAutoRotateEnabled ? kPrimaryGreen : Colors.black, size: 22),
              ),
            ),
          ),
          SizedBox(width: 12),
        ],
      ),
      body: PanoramaViewer(
        panoramaController: _panoramaController,
        animSpeed: _isAutoRotateEnabled ? 1.0 : 0.0,
        sensorControl: _isGyroEnabled ? SensorControl.orientation : SensorControl.none,
        longitude: initialMarker.rotacaoHorizontal,
        latitude: initialMarker.rotacaoVertical,
        child: Image.network(widget.panorama.urlImagem),
        hotspots: widget.panorama.marcadores.map((marker) {
          return Hotspot(
            longitude: marker.rotacaoHorizontal,
            latitude: marker.rotacaoVertical,
            width: 60,
            height: 60,
            widget: GestureDetector(
              onTap: () => _onHotspotTap(marker),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D58),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: Icon(Icons.location_on, color: Colors.white, size: 35),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

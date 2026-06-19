import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ar_flutter_plugin_updated/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_updated/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_updated/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_updated/models/ar_node.dart';
import 'package:ar_flutter_plugin_updated/widgets/ar_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

import 'package:visitar_teste/screens/services/database_services.dart';
import '../models/poi.dart';
import 'details_screen.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> with WidgetsBindingObserver {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);

  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;

  final Map<String, ARNode> _activeNodes = {};
  final Map<String, POI> _activePois = {};
  final Set<String> _poisLoading = {};

  POI? poiSelecionado;

  bool showInfoCard = false;
  String statusMessage = "A aguardar sensores...";
  bool _canRenderArWidget = false;
  bool _isSessionReady = false;
  double? _currentHeading; 

  List<POI> _poisDoFirebase = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregarDadosDoFirebase();
    _iniciarBussola();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _canRenderArWidget = true);
    });
  }

  void _iniciarBussola() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted) {
        setState(() { _currentHeading = event.heading; });
      }
    });
  }

  Future<void> _carregarDadosDoFirebase() async {
    try {
      var lista = await DatabaseService().getPOIs();
      if (mounted) setState(() => _poisDoFirebase = lista);
    } catch (e) {
      print("Erro DB: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSubscription?.cancel();
    _limparSessaoAr();
    super.dispose();
  }

  void _limparSessaoAr() {
    _positionStreamSubscription?.cancel();
    if (arObjectManager != null) {
      for (var node in _activeNodes.values) {
        try { arObjectManager!.removeNode(node); } catch (e) {}
      }
    }
    try { arSessionManager?.dispose(); } catch (e) {}
    _activeNodes.clear();
    _activePois.clear();
    _poisLoading.clear();
    _isSessionReady = false;
  }

  vector.Vector3? _calcularPosicaoAr(Position userPos, POI targetPoi) {
    if (_currentHeading == null) return null;

    double distanciaReal = Geolocator.distanceBetween(
      userPos.latitude, userPos.longitude,
      targetPoi.localizacao.latitude, targetPoi.localizacao.longitude
    );

    if (distanciaReal > 100) return null; 

    double bearing = Geolocator.bearingBetween(
      userPos.latitude, userPos.longitude,
      targetPoi.localizacao.latitude, targetPoi.localizacao.longitude
    );

    double angleFinal = (bearing - _currentHeading!);
    double angleRad = angleFinal * (pi / 180.0);

    double distanciaVisual = distanciaReal;
    if (distanciaVisual > 20) distanciaVisual = 20 + (distanciaReal * 0.1); 

    double x = distanciaVisual * sin(angleRad);
    double z = -distanciaVisual * cos(angleRad);

    return vector.Vector3(x, -1.5, z);
  }

  vector.Vector4 _calcularRotacaoParaCamara(vector.Vector3 posicaoObjeto) {
    double x = -posicaoObjeto.x;
    double z = -posicaoObjeto.z;
    double angleY = atan2(x, z);
    angleY += pi; 
    final rotation = vector.Quaternion.axisAngle(vector.Vector3(0, 1, 0), angleY);
    return vector.Vector4(rotation.x, rotation.y, rotation.z, rotation.w);
  }

  Future<void> _iniciarRastreioGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2)
    ).listen((Position position) {
      if (!mounted || !_isSessionReady || arObjectManager == null || _currentHeading == null) return;

      int encontradosAgora = 0;
      
      for (var poi in _poisDoFirebase) {
        String id = poi.nome;
        vector.Vector3? posicaoCalculada = _calcularPosicaoAr(position, poi);

        if (posicaoCalculada != null) {
          encontradosAgora++;
          if (!_activeNodes.containsKey(id) && !_poisLoading.contains(id)) {
            _adicionarObjetoNaCena(poi, posicaoCalculada, id);
          }
        } else {
          if (_activeNodes.containsKey(id)) {
            arObjectManager!.removeNode(_activeNodes[id]!);
            _activeNodes.remove(id);
          }
        }
      }

      if (mounted) {
        setState(() {
          if (_currentHeading == null) {
            statusMessage = "A calibrar sensores...";
          } else if (encontradosAgora > 0) {
            statusMessage = "Existem pontos de interesse próximos";
          } else {
            statusMessage = "Sem pontos de interesse próximos";
          }
        });
      }
    });
  }

  Future<void> _adicionarObjetoNaCena(POI poi, vector.Vector3 posicao, String id) async {
    _poisLoading.add(id);
    try {
      String nomeFicheiro = "marker.glb";
      await _copiarAssetParaFicheiro(nomeFicheiro);

      vector.Vector4 rotacao = _calcularRotacaoParaCamara(posicao);

      var newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: nomeFicheiro,
        scale: vector.Vector3(25.0, 25.0, 25.0),
        position: posicao,
        rotation: rotacao,
        name: id,
      );

      if (arObjectManager != null) {
        bool? didAdd = await arObjectManager!.addNode(newNode);
        if (didAdd == true && mounted) {
          setState(() {
            _activeNodes[id] = newNode;
            _activePois[id] = poi;
          });
        }
      }
    } catch (e) {
      print("Erro AR: $e");
    } finally {
      _poisLoading.remove(id);
    }
  }

  Future<void> _copiarAssetParaFicheiro(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File("${directory.path}/$filename");
    if (!await file.exists()) {
      try {
        final data = await rootBundle.load("assets/models/$filename");
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      } catch (e) { print(e); }
    }
  }

  void _onNodeTapped(List<String> nodes) {
    if (nodes.isEmpty) return;
    for (var nodeName in nodes) {
      if (_activePois.containsKey(nodeName)) {
        setState(() {
          poiSelecionado = _activePois[nodeName];
          showInfoCard = true;
        });
        break;
      }
    }
  }

  void onARViewCreated(ARSessionManager sessionManager, ARObjectManager objectManager, ARAnchorManager anchorManager, ARLocationManager locationManager) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;

    arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      handleRotation: false, 
      handlePans: false,
    );
    arObjectManager!.onInitialize();
    arObjectManager!.onNodeTap = _onNodeTapped;

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isSessionReady = true);
        _iniciarRastreioGPS();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          if (_canRenderArWidget)
            ARView(
              onARViewCreated: onARViewCreated,
              planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          
          SafeArea(
            child: Stack(
              children: [
                // --- TOPO DA PÁGINA (Seta + Pílula na mesma linha) ---
                Positioned(
                  top: 20, 
                  left: 20, 
                  right: 20, // Ocupa a largura disponível
                  child: Row(
                    children: [
                      // 1. Botão Voltar
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))]
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.black),
                        ),
                      ),
                      
                      const SizedBox(width: 12), // Espaço entre a seta e a pílula

                      // 2. Pílula de Status (Expanded para ocupar o resto da linha)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.2))
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min, // Não estica a pílula desnecessariamente
                            children: [
                              if (_poisLoading.isNotEmpty)
                                 const Padding(padding: EdgeInsets.only(right: 10), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                              else
                                 Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
                              const SizedBox(width: 8),
                              
                              // Texto da pílula
                              Flexible(
                                child: Text(
                                  statusMessage, 
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- CARTÃO DE INFORMAÇÃO ---
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            bottom: showInfoCard && poiSelecionado != null ? 40 : -300,
            left: 20, right: 20,
            child: _buildPoiInfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiInfoCard() {
    if (poiSelecionado == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Verde
          Container(
            height: 50,
            decoration: BoxDecoration(color: kPrimaryGreen.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
                const SizedBox(width: 10),
                Text(
                  poiSelecionado!.categoria.toUpperCase(), 
                  style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryGreen, fontSize: 12, letterSpacing: 1.0)
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => setState(() => showInfoCard = false)),
              ],
            ),
          ),
          // Conteúdo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poiSelecionado!.nome, 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.1), 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis
                ),
                const SizedBox(height: 8),
                Text(
                  poiSelecionado!.description, 
                  style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(poi: poiSelecionado!))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryGreen, 
                      foregroundColor: Colors.white, 
                      elevation: 0, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: const Text("Ver Detalhes", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
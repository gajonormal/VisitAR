import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_updated/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_updated/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_updated/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_updated/models/ar_node.dart';
import 'package:ar_flutter_plugin_updated/widgets/ar_view.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:geolocator/geolocator.dart';
import 'package:visitar_teste/screens/services/database_services.dart';

import '../models/poi.dart'; 
import 'details_screen.dart';
import 'dart:io'; // Para usar o File
import '../screens/services/download_service.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  
  ARNode? webObjectNode;
  POI? poiEncontrado;

  bool showInfoCard = false;
  String poiName = "A carregar dados...";

  List<POI> _poisDoFirebase = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosDoFirebase();
    _iniciarRastreioGPS();
  }

  Future<void> _carregarDadosDoFirebase() async {
    var lista = await DatabaseService().getPOIs();
    if (mounted) {
      setState(() {
        _poisDoFirebase = lista;
        poiName = "À procura de locais...";
      });
    }
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  Future<void> _iniciarRastreioGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, 
      )
    ).listen((Position position) {
      
      // Se já temos um objeto carregado, verificamos se nos afastámos demasiado
      if (webObjectNode != null && poiEncontrado != null) {
         double distanciaAtual = Geolocator.distanceBetween(
            position.latitude, position.longitude, 
            poiEncontrado!.location.latitude, poiEncontrado!.location.longitude
         );
         
         // Se te afastares mais de 100m, aí sim removemos tudo
         if (distanciaAtual > 100) {
           _removerObjeto();
         }
         return; // Não procura novos se já tem um
      }

      for (var poi in _poisDoFirebase) {
        double distancia = Geolocator.distanceBetween(
          position.latitude, position.longitude, 
          poi.location.latitude, poi.location.longitude
        );

        if (distancia < 50 && webObjectNode == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${poi.name} encontrado a ${distancia.toInt()}m!"))
            );
          }
          _adicionarObjetoOnline(poi);
          break; 
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VisitAR - Modo AR")),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // CARD DE INFORMAÇÃO
          if (showInfoCard && poiEncontrado != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                   if (poiEncontrado != null) {
                     Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => DetailsScreen(poi: poiEncontrado!)
                      )
                     );
                   }
                },
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                poiName, 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                // --- AQUI ESTÁ A CORREÇÃO ---
                                setState(() {
                                  // Apenas escondemos o card.
                                  // NÃO removemos o objeto nem o nó.
                                  showInfoCard = false;
                                });
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text("Toque para ver a história completa."),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.blue),
                            SizedBox(width: 5),
                            Text("Estás no local!", style: TextStyle(color: Colors.green)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void onARViewCreated(ARSessionManager sessionManager, ARObjectManager objectManager, ARAnchorManager anchorManager, ARLocationManager locationManager) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;

    arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handlePans: true,
      handleRotation: true,
    );
    arObjectManager!.onInitialize();
    
    // Isto ativa o clique no objeto 3D
    arObjectManager!.onNodeTap = _onNodeTapped;
  }

Future<void> _adicionarObjetoOnline(POI poi) async {
    if (webObjectNode != null) return;

    String uriFinal = poi.arModelUrl; 
    NodeType tipoDeNo = NodeType.webGLB;

    // --- LÓGICA OFFLINE ---
    String fileName = "poi_${poi.id}.glb";
    
    // Verificamos se o ficheiro existe
    bool existeOffline = await DownloadService().checkFileExists(fileName);

    if (existeOffline) {
// O DownloadService garante que o ficheiro lá está
      // Mas aqui NÃO precisamos do caminho completo para o AR Node
      await DownloadService().downloadFile(poi.arModelUrl, fileName);
      
      print("A usar modelo OFFLINE (apenas nome): $fileName");
      
      uriFinal = fileName; // <--- CORREÇÃO: Passa SÓ o nome (ex: "poi_abc.glb")
      tipoDeNo = NodeType.fileSystemAppFolderGLB; 

    } else {
      print("A usar modelo ONLINE (Streaming)");
    }
    // ----------------------

    var newNode = ARNode(
      type: tipoDeNo,
      uri: uriFinal,
      scale: vector.Vector3(poi.arScale, poi.arScale, poi.arScale),
      position: vector.Vector3(0.0, -1.0, -3.0),
      rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
    );

    if (arObjectManager != null) {
      bool? didAdd = await arObjectManager!.addNode(newNode);

      if (didAdd == true) {
        setState(() {
          webObjectNode = newNode;
          poiEncontrado = poi;
          poiName = poi.name;
          showInfoCard = true;
        });
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro ao carregar objeto (Tenta aproximar-te mais).")),
          );
        }
      }
    }
  }

  // --- FUNÇÃO DE TOQUE NO OBJETO ---
  void _onNodeTapped(List<String> nodes) {
    // Se tocámos no nosso objeto e o card estava escondido...
    if (webObjectNode != null && nodes.contains(webObjectNode!.name)) {
      setState(() {
        showInfoCard = true; // ... voltamos a mostrar o card!
      });
    }
  }

  // Função auxiliar para limpar tudo (só usada se te afastares muito)
  void _removerObjeto() {
    if (webObjectNode != null) {
      arObjectManager!.removeNode(webObjectNode!);
      webObjectNode = null;
    }
    setState(() {
      poiEncontrado = null;
      showInfoCard = false;
      poiName = "À procura...";
    });
  }
}
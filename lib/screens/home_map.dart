import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui; // Necessário para renderizar os marcadores personalizados no mapa
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para ByteData (conversão de imagens dos marcadores)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/services/database_services.dart';
import '../screens/services/download_service.dart';
import '../screens/services/roteiro_state.dart';
import '../models/poi.dart';
import '../models/roteiro.dart';
import '../models/panorama.dart';
import 'panorama_screen.dart';
import '../models/filter_options.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../screens/services/routing_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/services/favorites_service.dart';
import 'details_screen.dart';

import 'profile_screen.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'roteiros_screen.dart';
import 'login_screen.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

class HomeMap extends StatefulWidget {
  const HomeMap({super.key});

  @override
  State<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  final LatLng _initialPosition = const LatLng(39.822180, -7.491095);
  
  // --- DADOS ---
  List<POI> _allPois = [];
  List<POI> _visiblePois = [];
  Set<Marker> _markers = {}; 
  Set<Polyline> _polylines = {}; // Linhas de rota desenhadas no mapa
  BitmapDescriptor? _markerIconNormal;
  BitmapDescriptor? _markerIconSelected;
  Map<int, BitmapDescriptor> _numberedMarkersNormal = {};
  Map<int, BitmapDescriptor> _numberedMarkersSelected = {};

  // --- ESTADO UI ---
  int _selectedIndex = 0;
  int _selectedPoiIndex = -1; 

  late PageController _pageController;
  GoogleMapController? _mapController;
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final double _filterRadiusMeters = 5000.0; // Raio de 5 km — equilíbrio entre turismo e caminhadas

  // --- NAVEGAÇÃO ROTEIRO ---
  Timer? _roteiroTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isRoteiroPaused = false;
  int _roteiroElapsedSeconds = 0;
  double _roteiroDistanceCovered = 0.0;
  Position? _lastRoteiroPosition;
  double _distanceToNextPoi = 0.0;
  List<POI> _currentRoteiroPois = [];
  int _nextPoiIndex = 0;
  
  // Controlo de frequência das requisições ao OSRM para a linha de navegação dinâmica
  DateTime? _lastRouteFetch;
  List<LatLng> _currentDynamicRoute = [];
  
  // POI selecionado no mini cartão de topo (durante navegação ativa)
  POI? _selectedTopPoi;

  // --- PESQUISA ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<POI> _searchResults = [];
  bool _isSearching = false;
  
  // --- FILTROS ---
  POIFilter _poiFilter = POIFilter();
  // --- AR ---
  bool _isSearchFocused = false;

  // --- PANORAMA CACHE ---
  Panorama? _selectedPanorama;
  final Map<String, Panorama?> _panoramasCache = {};
  bool _isSatellite = false;

  final String _mapStyle = '''
    [
      {
        "featureType": "poi",
        "stylers": [
          { "visibility": "off" }
        ]
      },
      {
        "featureType": "transit",
        "stylers": [
          { "visibility": "off" }
        ]
      }
    ]
  ''';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);

    // Limpa a cache local para evitar POIs "fantasma" de sessões anteriores
    SharedPreferences.getInstance().then((prefs) {
      prefs.clear();
    });

    _loadCustomMarkerIcons().then((_) => _initData());
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() { _isSearchFocused = _searchFocusNode.hasFocus; });
    });

    // Reage a mudanças no roteiro ativo (inicia/termina navegação)
    activeRoteiroNotifier.addListener(_onActiveRoteiroChanged);
  }

  @override
  void dispose() {
    activeRoteiroNotifier.removeListener(_onActiveRoteiroChanged);
    _pageController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<POI> _optimizeRouteOrder(List<POI> pois, Position startPosition) {
    List<POI> unvisited = List.from(pois);
    List<POI> optimized = [];
    LatLng currentLoc = LatLng(startPosition.latitude, startPosition.longitude);

    while (unvisited.isNotEmpty) {
      POI closest = unvisited.first;
      double minDistance = Geolocator.distanceBetween(
        currentLoc.latitude, currentLoc.longitude,
        closest.localizacao.latitude, closest.localizacao.longitude,
      );

      for (int i = 1; i < unvisited.length; i++) {
        double dist = Geolocator.distanceBetween(
          currentLoc.latitude, currentLoc.longitude,
          unvisited[i].localizacao.latitude, unvisited[i].localizacao.longitude,
        );
        if (dist < minDistance) {
          closest = unvisited[i];
          minDistance = dist;
        }
      }

      optimized.add(closest);
      unvisited.remove(closest);
      currentLoc = closest.localizacao;
    }
    return optimized;
  }

  Future<void> _onActiveRoteiroChanged() async {
    Roteiro? roteiro = activeRoteiroNotifier.value;
    if (roteiro == null) {
      _stopRoteiroTracking();
      setState(() {
        _polylines.clear();
        _updateMarkers();
      });
      return;
    }

    // Muda para o separador do mapa
    setState(() => _selectedIndex = 1);

    // Fecha qualquer cartão de POI aberto para focar no roteiro
    setState(() {
      _selectedPoiIndex = -1;
      _visiblePois.clear();
    });

    // Carrega os POIs associados ao roteiro
    List<POI> roteiroPois = await DatabaseService().getPOIsByIds(roteiro.poiIds);
    if (roteiroPois.isEmpty) return;

    // Obtém a localização atual para otimizar a ordem de visita
    Position? currentPos;
    try {
      currentPos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (e) {
      debugPrint('Erro ao obter posição para ordenar roteiro: $e');
    }

    // Verifica conectividade para calcular a rota pela nova ordem
    bool hasNet = await _hasInternet();

    List<LatLng> points = [];

    // Trilho pré-definido em GeoJSON: carrega diretamente do asset, ignorando o OSRM
    if (roteiro.trailAsset != null && roteiro.trailAsset!.isNotEmpty) {
      points = await RoutingService.loadTrailFromAsset(roteiro.trailAsset!);
      if (points.isEmpty) {
        // GeoJSON inválido ou vazio — fallback para o OSRM
        debugPrint('trailAsset definido mas GeoJSON vazio. A usar OSRM como alternativa.');
        List<LatLng> waypoints = roteiroPois.map((p) => p.localizacao).toList();
        points = await RoutingService.getFullRoteiroRoute(waypoints);
      }
    } else if (hasNet && currentPos != null) {
      // Com internet e GPS: reordena os POIs pelo vizinho mais próximo
      roteiroPois = _optimizeRouteOrder(roteiroPois, currentPos);
      List<LatLng> waypoints = roteiroPois.map((p) => p.localizacao).toList();
      points = await RoutingService.getFullRoteiroRoute(waypoints);
    } else {
      // Sem internet ou GPS: usa a ordem original e a rota em cache, se disponível
      List<LatLng> waypoints = roteiroPois.map((p) => p.localizacao).toList();
      if (roteiro.routePoints != null && roteiro.routePoints!.isNotEmpty) {
        points = roteiro.routePoints!;
      } else {
        points = await RoutingService.getFullRoteiroRoute(waypoints);
      }
    }

    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId(roteiro.id),
          points: points,
          color: kPrimaryGreen,
          width: 5,
          geodesic: true,
        )
      };
    });

    // Centra a câmara no primeiro ponto da rota
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
    }

    // Inicia o tracking ativo do roteiro
    _startRoteiroTracking(roteiroPois);
  }

  void _startRoteiroTracking(List<POI> roteiroPois) {
    WakelockPlus.enable(); // Mantém o ecrã sempre ligado durante a navegação
    _isRoteiroPaused = false;
    _roteiroElapsedSeconds = 0;
    _roteiroDistanceCovered = 0.0;
    _currentRoteiroPois = roteiroPois;
    _nextPoiIndex = 0;
    _lastRoteiroPosition = null;
    _lastRouteFetch = null;
    _currentDynamicRoute = [];
    _selectedTopPoi = null;

    _updateMarkers(); // Atualiza os marcadores para mostrar os números de ordem do roteiro
    _updateDistanceToNextPoi();

    _roteiroTimer?.cancel();
    _roteiroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRoteiroPaused) {
        setState(() {
          _roteiroElapsedSeconds++;
        });
      }
    });

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      if (_isRoteiroPaused) return;

      if (_lastRoteiroPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastRoteiroPosition!.latitude, _lastRoteiroPosition!.longitude,
          position.latitude, position.longitude,
        );
        setState(() {
          _roteiroDistanceCovered += distance;
        });
      }
      _lastRoteiroPosition = position;
      _updateDistanceToNextPoi();
    });
  }

  void _updateDistanceToNextPoi() async {
    if (_nextPoiIndex >= _currentRoteiroPois.length) return;
    try {
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      POI nextPoi = _currentRoteiroPois[_nextPoiIndex];
      double dist = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        nextPoi.localizacao.latitude, nextPoi.localizacao.longitude,
      );
      
      // Se o utilizador estiver a menos de 20 metros, considera o POI como visitado e avança
      if (dist < 20.0) {
        _nextPoiIndex++;
        if (_nextPoiIndex < _currentRoteiroPois.length) {
          nextPoi = _currentRoteiroPois[_nextPoiIndex];
          dist = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            nextPoi.localizacao.latitude, nextPoi.localizacao.longitude,
          );
        } else {
          dist = 0.0; // Roteiro concluído
        }
      }
      
      setState(() {
        _distanceToNextPoi = dist;
        
        // Atualiza a linha de navegação entre a posição atual e o próximo POI
        _polylines.removeWhere((p) => p.polylineId.value == 'user_to_next');
        if (_nextPoiIndex < _currentRoteiroPois.length) {
          
          // Só busca nova rota se passaram mais de 10 segundos desde a última requisição
          bool shouldFetch = _lastRouteFetch == null || DateTime.now().difference(_lastRouteFetch!).inSeconds > 10;
          
          if (shouldFetch || _currentDynamicRoute.isEmpty) {
            _lastRouteFetch = DateTime.now();
            RoutingService.getPedestrianRoute(
              LatLng(position.latitude, position.longitude), 
              nextPoi.localizacao
            ).then((route) {
              if (mounted) {
                setState(() {
                  _currentDynamicRoute = route;
                  // Atualizar polyline com a nova rota
                  // Substitui a polyline dinâmica com a rota atualizada
                  _polylines.removeWhere((p) => p.polylineId.value == 'user_to_next');
                  _polylines.add(
                    Polyline(
                      polylineId: const PolylineId('user_to_next'),
                      points: _currentDynamicRoute,
                      color: Colors.blueAccent,
                      width: 4,
                      patterns: [PatternItem.dash(20), PatternItem.gap(15)],
                    ),
                  );
                });
              }
            });
          } else {
            // Sem nova requisição: atualiza apenas o ponto de partida da rota existente
            if (_currentDynamicRoute.isNotEmpty) {
              _currentDynamicRoute[0] = LatLng(position.latitude, position.longitude);
            }
          }

          _polylines.add(
            Polyline(
              polylineId: const PolylineId('user_to_next'),
              points: _currentDynamicRoute.isNotEmpty ? _currentDynamicRoute : [
                LatLng(position.latitude, position.longitude),
                nextPoi.localizacao,
              ],
              color: Colors.blueAccent,
              width: 4,
              patterns: [PatternItem.dash(20), PatternItem.gap(15)],
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Erro ao calcular distância para o próximo POI: $e');
    }
  }

  void _stopRoteiroTracking() {
    WakelockPlus.disable();
    _roteiroTimer?.cancel();
    _positionStreamSubscription?.cancel();
    setState(() {
      _currentRoteiroPois = [];
      _nextPoiIndex = 0;
      _roteiroElapsedSeconds = 0;
      _roteiroDistanceCovered = 0.0;
      _distanceToNextPoi = 0.0;
      _lastRouteFetch = null;
      _currentDynamicRoute = [];
      _selectedTopPoi = null;
    });
  }



  Future<void> _loadCustomMarkerIcons() async {
    final normal = await getCustomMarker(color: Colors.white, iconColor: kPrimaryGreen, isSelected: false);
    final selected = await getCustomMarker(color: kPrimaryGreen, iconColor: Colors.white, isSelected: true);
    
    // Pré-gera marcadores numerados de 1 a 20 para os POIs dos roteiros
    Map<int, BitmapDescriptor> numNormals = {};
    Map<int, BitmapDescriptor> numSelected = {};
    for (int i = 1; i <= 20; i++) {
      numNormals[i] = await getCustomMarker(color: Colors.white, iconColor: kPrimaryGreen, isSelected: false, text: i.toString());
      numSelected[i] = await getCustomMarker(color: kPrimaryGreen, iconColor: Colors.white, isSelected: true, text: i.toString());
    }

    if (mounted) {
      setState(() { 
        _markerIconNormal = normal; 
        _markerIconSelected = selected; 
        _numberedMarkersNormal = numNormals;
        _numberedMarkersSelected = numSelected;
      });
      _updateMarkers(); // Garante que os marcadores são desenhados mesmo que os dados já estivessem carregados
    }
  }

  Future<void> _initData() async {
    List<POI> rawPois = await DatabaseService().getPOIs();
    final downloadService = DownloadService();
    List<POI> processedPois = [];
    for (var onlinePoi in rawPois) {
      POI? offlinePoi = await downloadService.getOfflinePoi(onlinePoi.id);
      processedPois.add(offlinePoi ?? onlinePoi);
    }
    setState(() { _allPois = processedPois; });
    Position? userPos = await _getUserLocation();
    if (userPos != null) {
      if (_mapController != null) _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(userPos.latitude, userPos.longitude)));
      _updateCardsContext(LatLng(userPos.latitude, userPos.longitude));
    } else {
      _updateCardsContext(_initialPosition);
    }
  }

  /// Atualiza a lista de POIs visíveis e os cartões com base num ponto central.
  void _updateCardsContext(LatLng centerPoint) {
    List<POI> nearby = _allPois.where((poi) {
      if (!_poiFilter.apply(poi)) return false;
      double dist = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, poi.localizacao.latitude, poi.localizacao.longitude);
      return dist <= _filterRadiusMeters;
    }).toList();

    nearby.sort((a, b) {
      double distA = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, a.localizacao.latitude, a.localizacao.longitude);
      double distB = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, b.localizacao.latitude, b.localizacao.longitude);
      return distA.compareTo(distB);
    });
    setState(() {
      _visiblePois = nearby;
      if (_visiblePois.isNotEmpty) {
        _selectedPoiIndex = 0;
        if (_pageController.hasClients) _pageController.jumpToPage(0);
        _checkPanoramaForPoi(_visiblePois[0]);
      } else {
        _selectedPoiIndex = -1;
        _selectedPanorama = null;
      }
      _updateMarkers(); 
    });
  }

  void _updateMarkers() {
    if (_markerIconNormal == null || _markerIconSelected == null) return;
    Set<Marker> newMarkers = {};
    
    bool isRoteiroActive = activeRoteiroNotifier.value != null;

    if (isRoteiroActive) {
      for (int i = 0; i < _currentRoteiroPois.length; i++) {
        var poi = _currentRoteiroPois[i];
        newMarkers.add(Marker(
          markerId: MarkerId(poi.id),
          position: poi.localizacao,
          icon: _numberedMarkersNormal[i + 1] ?? _markerIconNormal!,
          zIndexInt: 1,
          anchor: const Offset(0.5, 0.5),
          onTap: () {
            setState(() {
              _selectedTopPoi = poi;
            });
            if (_mapController != null) {
               _mapController!.animateCamera(CameraUpdate.newLatLng(poi.localizacao));
            }
          }
        ));
      }
    } else {
      for (var poi in _allPois) {
        if (!_poiFilter.apply(poi)) continue;
        
        bool isSelected = false;
        if (_selectedPoiIndex != -1 && _selectedPoiIndex < _visiblePois.length) {
          isSelected = _visiblePois[_selectedPoiIndex].id == poi.id;
        }

        newMarkers.add(Marker(
          markerId: MarkerId(poi.id),
          position: poi.localizacao,
          icon: isSelected ? _markerIconSelected! : _markerIconNormal!,
          zIndexInt: isSelected ? 2 : 1,
          anchor: const Offset(0.5, 0.5),
          onTap: () { 
            if (activeRoteiroNotifier.value == null) {
              _updateCardsContext(poi.localizacao); 
            }
          },
        ));
      }
    }
    setState(() { _markers = newMarkers; });
  }

  Future<void> _checkPanoramaForPoi(POI poi) async {
    if (_panoramasCache.containsKey(poi.id)) {
      setState(() {
        _selectedPanorama = _panoramasCache[poi.id];
      });
      return;
    }
    
    try {
      var pano = await DatabaseService().getPanoramaForPoi(poi.id);
      _panoramasCache[poi.id] = pano;
      if (_selectedPoiIndex != -1 && _selectedPoiIndex < _visiblePois.length && _visiblePois[_selectedPoiIndex].id == poi.id) {
        if (mounted) {
          setState(() {
            _selectedPanorama = pano;
          });
        }
      }
    } catch (e) {
      _panoramasCache[poi.id] = null;
    }
  }

  void _onPageChanged(int index) {
    setState(() { _selectedPoiIndex = index; });
    _updateMarkers();
    if (_mapController != null && index < _visiblePois.length) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_visiblePois[index].localizacao));
      _checkPanoramaForPoi(_visiblePois[index]);
    }
  }

  Future<Position?> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (e) { return null; }
  }

  Future<void> _locateUser() async {
    Position? pos = await _getUserLocation();
    if (pos != null) {
      if (_mapController != null) _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 18)));
      if (activeRoteiroNotifier.value == null) {
        _updateCardsContext(LatLng(pos.latitude, pos.longitude));
      }
    }
  }

  void _onItemTapped(int index) { setState(() { _selectedIndex = index; }); }

  /// Inicia a navegação para um POI individual, criando um roteiro temporário.
  void _startNavigation(POI poi) {
    // Limpa o estado visual do mapa antes de iniciar
    setState(() {
      _selectedPoiIndex = -1;
      _selectedTopPoi = null;
      _visiblePois.clear();
      _polylines.clear();
    });

    // Cria um roteiro temporário com um único destino para ativar o tracking
    final tempRoteiro = Roteiro(
      id: 'single_poi_${poi.id}',
      titulo: 'Destino: ${poi.nome}',
      descricao: poi.description,
      imagemCapa: poi.imagens.isNotEmpty ? poi.imagens.first : '',
      poiIds: [poi.id],
      categoria: 'Geral',
      duracao: 'N/A',
      distancia: 0.0,
      criadorId: 'app_navigation',
    );

    // Publica o roteiro no notifier global para ativar a navegação
    activeRoteiroNotifier.value = tempRoteiro;
  }

  // --- PESQUISA ---
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    final results = _allPois.where((poi) {
      if (!_poiFilter.apply(poi)) return false;
      return poi.nome.toLowerCase().contains(query) ||
             poi.categoria.toLowerCase().contains(query);
    }).toList();
    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
  }

  /// Seleciona um resultado de pesquisa, centra o mapa nele e mostra os cartões próximos.
  void _selectSearchResult(POI poi) {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: poi.localizacao, zoom: 18),
        ),
      );
    }
    _updateCardsContext(poi.localizacao);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    const double cardHeight = 220.0;
    const double visibleBottom = 100.0;
    const double hiddenBottom = -300.0;

    // Os cartões só são visíveis quando o teclado está fechado e há um POI selecionado
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    bool areCardsVisible = _selectedPoiIndex != -1 && _visiblePois.isNotEmpty && !isKeyboardOpen;

    return Focus(
      autofocus: true,
      child: Scaffold(
        extendBody: true,
        // Impede que o layout suba quando o teclado abre
        resizeToAvoidBottomInset: false, 
      
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // 0. EXPLORAR (novo ecrã principal)
          ExploreScreen(onTabChange: _onItemTapped),

          // 1. MAPA
          Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 17.5),
                markers: _markers,
                polylines: _polylines,
                mapType: _isSatellite ? MapType.satellite : MapType.normal,
                style: _isSatellite ? null : _mapStyle,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                mapToolbarEnabled: false,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                padding: EdgeInsets.only(bottom: areCardsVisible ? 300 : 100, top: 100),
                onTap: (_) {
                  // Fechar teclado e desselecionar o POI ativo ao tocar no mapa
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _selectedPoiIndex = -1;
                    _selectedTopPoi = null;
                  });
                  _updateMarkers();
                },
              ),
              
              // Barra de pesquisa (só visível fora da navegação)
              if (activeRoteiroNotifier.value == null)
                _buildSearchBar(),
              
              // Botão GPS — esconde durante pesquisa e desce quando o mini cartão está visível
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
                top: (_selectedTopPoi != null && activeRoteiroNotifier.value != null) ? 160 : 110,
                right: (_isSearchFocused || _isSearching) ? -80 : 20,
                child: FloatingActionButton.small(
                  heroTag: "gps_btn", backgroundColor: Colors.white, onPressed: _locateUser,
                  child: Icon(Icons.my_location, color: Colors.black54),
                ),
              ),

              // Botão de alternância entre mapa normal e vista de satélite
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
                top: (_selectedTopPoi != null && activeRoteiroNotifier.value != null) ? 210 : 160,
                right: (_isSearchFocused || _isSearching) ? -80 : 20,
                child: FloatingActionButton.small(
                  heroTag: "map_type_btn", backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _isSatellite = !_isSatellite;
                    });
                  },
                  child: Icon(_isSatellite ? Icons.map_outlined : Icons.satellite_outlined, color: Colors.black54),
                ),
              ),


              // Botões de ação (360° e Navegar) — surgem quando há um POI selecionado
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                bottom: areCardsVisible ? (visibleBottom + cardHeight + 15) : 100,
                left: (areCardsVisible && !isKeyboardOpen) ? 20 : -200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedPanorama != null && _selectedPoiIndex != -1 && _selectedPoiIndex < _visiblePois.length) ...[
                      SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: kPrimaryGreen,
                            elevation: 3,
                            shadowColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
                          ),
                          onPressed: () async {
                            // Recarrega o panorama antes de abrir para garantir marcadores atualizados
                            var freshPano = await DatabaseService().getPanoramaForPoi(_visiblePois[_selectedPoiIndex].id);
                            if (!mounted) return;
                            
                            var panoToPass = _selectedPanorama!;
                            if (freshPano != null) {
                              panoToPass = freshPano;
                              setState(() {
                                _selectedPanorama = freshPano;
                                _panoramasCache[_visiblePois[_selectedPoiIndex].id] = freshPano;
                              });
                            }
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PanoramaScreen(
                                  panorama: panoToPass,
                                  initialPoiId: _visiblePois[_selectedPoiIndex].id,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) {
                                FocusScope.of(context).unfocus();
                                _searchFocusNode.unfocus();
                                setState(() { _isSearchFocused = false; });
                              }
                            });
                          },
                          icon: Icon(Icons.threesixty, size: 18),
                          label: Text(AppLocalizations.of(context)!.view360, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kPrimaryGreen,
                          elevation: 3,
                          shadowColor: Colors.black26,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
                        ),
                        onPressed: () {
                          if (_selectedPoiIndex != -1 && _selectedPoiIndex < _visiblePois.length) {
                            _startNavigation(_visiblePois[_selectedPoiIndex]);
                          }
                        },
                        icon: Icon(Icons.navigation_rounded, size: 18),
                        label: Text(AppLocalizations.of(context)!.navigate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),

              // Painel inferior de navegação ativa (cronómetro, distância, pausar/terminar)
              if (activeRoteiroNotifier.value != null)
                _buildActiveNavigationPanel(),

              // Mini cartão de topo: sempre presente na árvore, desliza para fora do ecrã quando vazio
              _buildTopMiniCard(),

              // Carrossel de cartões dos POIs próximos
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic,
                left: 0, right: 0,
                height: cardHeight,
                // Quando o teclado está aberto, empurra os cartões para fora do ecrã
                bottom: areCardsVisible ? visibleBottom : hiddenBottom, 
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _visiblePois.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = _pageController.page! - index;
                          value = (1 - (value.abs() * 0.1)).clamp(0.0, 1.0);
                        }
                        return Transform.scale(scale: Curves.easeOut.transform(value), child: child);
                      },
                      child: PoiMapCard(poi: _visiblePois[index]), 
                    );
                  },
                ),
              ),
            ],
          ),
          // Ecrãs dos restantes separadores da barra de navegação
          const RoteirosScreen(),
          const FavoritesScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: activeRoteiroNotifier.value != null ? null : _buildBottomNav(),
    ),
    );
  }

  /// Constrói o painel inferior com as estatísticas e controlos da navegação ativa.
  Widget _buildActiveNavigationPanel() {
    String formatTime(int seconds) {
      int m = seconds ~/ 60;
      int s = seconds % 60;
      int h = m ~/ 60;
      m = m % 60;
      if (h > 0) {
        return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
      return '${m.toString()}:${s.toString().padLeft(2, '0')}';
    }

    String formatDistance(double meters) {
      if (meters >= 1000) {
        return '${(meters / 1000).toStringAsFixed(2)}km';
      }
      return '${meters.toStringAsFixed(0)}m';
    }

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, -5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatTime(_roteiroElapsedSeconds), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(AppLocalizations.of(context)!.time, style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(activeRoteiroNotifier.value!.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (_nextPoiIndex < _currentRoteiroPois.length)
                          Text("A ${formatDistance(_distanceToNextPoi)} de ${_currentRoteiroPois[_nextPoiIndex].nome}", style: TextStyle(color: kPrimaryGreen, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDistance(_roteiroDistanceCovered), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(AppLocalizations.of(context)!.distance, style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isRoteiroPaused = !_isRoteiroPaused;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRoteiroPaused ? kPrimaryGreen.withValues(alpha: 0.7) : kPrimaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(_isRoteiroPaused ? AppLocalizations.of(context)!.resume : AppLocalizations.of(context)!.pause, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showEndRoteiroDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(AppLocalizations.of(context)!.stop, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra o diálogo de confirmação para terminar o roteiro, com o resumo da sessão.
  void _showEndRoteiroDialog() {
    // Pausa o tracking enquanto o utilizador confirma a ação
    setState(() => _isRoteiroPaused = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)!.stopNavigation, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.stopNavigationConfirm, textAlign: TextAlign.center),
            SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Icon(Icons.timer, color: kPrimaryGreen),
                      SizedBox(height: 5),
                      Text("${(_roteiroElapsedSeconds / 60).toStringAsFixed(1)} min", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.directions_walk, color: kPrimaryGreen),
                      SizedBox(height: 5),
                      Text("${(_roteiroDistanceCovered / 1000).toStringAsFixed(2)} km", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _isRoteiroPaused = false); // Retoma o tracking
                  },
                  child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: Colors.grey)),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _finishRoteiro();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
                  child: Text(AppLocalizations.of(context)!.finish),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Termina o roteiro ativo, limpando a UI e parando o tracking via [_onActiveRoteiroChanged].
  void _finishRoteiro() {
    activeRoteiroNotifier.value = null;
  }

  /// Constrói a barra de pesquisa com sugestões e lista de resultados.
  Widget _buildSearchBar() {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    // Espaço disponível para a lista de resultados (desconta teclado, barra e margens)
    final double availableDropdownHeight =
        screenHeight - keyboardHeight - 50 - 50 - 12 - 16;

    return Positioned(
      top: 50, left: 20, right: 20,
      // Limita a altura da coluna ao espaço disponível acima do teclado
      bottom: keyboardHeight > 0 ? keyboardHeight + 8 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de pesquisa principal
          Container(
            padding: const EdgeInsets.only(left: 15, right: 5),
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ícone de lupa (fica verde quando há pesquisa ativa)
                Icon(Icons.search, color: _isSearching ? kPrimaryGreen : Colors.grey),
                SizedBox(width: 10),
                // Campo de entrada de texto
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchLocation,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 15),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (_searchResults.isNotEmpty) {
                        _selectSearchResult(_searchResults.first);
                      }
                    },
                  ),
                ),
                // Botão para limpar (só aparece durante pesquisa ativa)
                if (_isSearching)
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    splashRadius: 20,
                    onPressed: _clearSearch,
                  )
                else ...([
                  Container(width: 1, height: 24, color: Colors.grey[300]),
                  SizedBox(width: 5),
                  IconButton(
                    icon: Icon(Icons.tune, color: _poiFilter.isActive ? kPrimaryGreen : Colors.grey),
                    splashRadius: 24,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => FilterBottomSheet(
                          initialPoiFilter: _poiFilter,
                          showPoiFilters: true,
                          showRoteiroFilters: false,
                          availablePoiCategories: _allPois.map((e) => e.categoria).where((e) => e.isNotEmpty).toSet().toList().cast<String>()..sort(),
                          onApply: (poiF, rotF) {
                            if (poiF != null) {
                              setState(() {
                                _poiFilter = poiF;
                              });
                              // Se tivermos um POI selecionado, o centro é ele. Senão procuramos na zona atual ou inicial.
                              LatLng center = _selectedPoiIndex != -1 && _visiblePois.isNotEmpty && _selectedPoiIndex < _visiblePois.length 
                                  ? _visiblePois[_selectedPoiIndex].localizacao 
                                  : _initialPosition;
                              
                              _updateCardsContext(center);
                              if (_searchController.text.isNotEmpty) _onSearchChanged();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ]),
              ],
            ),
          ),
          // Sugestões de locais próximos (quando o campo está focado mas sem texto)
          if (_isSearchFocused && !_isSearching && _visiblePois.isNotEmpty)
            _buildNearbyRecommendations(maxHeight: availableDropdownHeight.clamp(100, 300)),

          // -- Lista de resultados de pesquisa --
          if (_isSearching && _searchResults.isNotEmpty)
            _buildResultsList(_searchResults, maxHeight: availableDropdownHeight.clamp(100, 260)),

          // Mensagem de "sem resultados"
          if (_isSearching && _searchResults.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Colors.grey[400], size: 20),
                  SizedBox(width: 10),
                  Text(AppLocalizations.of(context)!.noLocationFound, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
  /// Constrói a lista de sugestões de locais próximos (máximo 5, ordenados por distância).
  Widget _buildNearbyRecommendations({double maxHeight = 300}) {
    final nearby = _visiblePois.take(5).toList(); // Limita a 5 POIs
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da lista de sugestões
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.near_me, size: 15, color: kPrimaryGreen),
                  SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.nearbyPlaces,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[200]),
            // Lista com scroll para caber no espaço disponível acima do teclado
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: nearby.length,
                separatorBuilder: (_, i) => Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final poi = nearby[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kPrimaryGreen.withValues(alpha: 0.12),
                      child: Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
                    ),
                    title: Text(
                      poi.nome,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      poi.categoria,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey[400]),
                    onTap: () => _selectSearchResult(poi),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a lista de resultados de pesquisa com altura máxima configurável.
  Widget _buildResultsList(List<POI> pois, {double maxHeight = 260}) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: pois.length,
          separatorBuilder: (_, i) => Divider(height: 1, color: Colors.grey[200]),
          itemBuilder: (context, index) {
            final poi = pois[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: kPrimaryGreen.withValues(alpha: 0.12),
                child: Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
              ),
              title: Text(
                poi.nome,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                poi.categoria,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey[400]),
              onTap: () => _selectSearchResult(poi),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 90, 
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))]),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex, onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, backgroundColor: Colors.transparent, elevation: 0,
        selectedItemColor: kPrimaryGreen, unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: [
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.explore_outlined)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.explore)), label: AppLocalizations.of(context)!.tabExplore),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.map_outlined)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.map)), label: AppLocalizations.of(context)!.tabMap),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.tour_outlined)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.tour)), label: AppLocalizations.of(context)!.tabItineraries),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite_outline)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite)), label: AppLocalizations.of(context)!.tabFavorites),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_outline)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person)), label: AppLocalizations.of(context)!.tabProfile),
        ],
      ),
    );
  }

  /// Constrói o mini cartão animado de topo que mostra o POI selecionado durante a navegação.
  Widget _buildTopMiniCard() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 60.0,
      left: 20, 
      right: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: (activeRoteiroNotifier.value != null && _selectedTopPoi != null)
            ? GestureDetector(
                key: ValueKey(_selectedTopPoi!.id),
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(poi: _selectedTopPoi!)));
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                       ClipRRect(
                         borderRadius: BorderRadius.circular(10),
                         child: CachedNetworkImage(
                           imageUrl: _selectedTopPoi!.imagens.isNotEmpty ? _selectedTopPoi!.imagens.first : '', 
                           width: 50, 
                           height: 50, 
                           fit: BoxFit.cover, 
                           errorWidget: (_,__,___) => Container(
                             width: 50, height: 50, color: Colors.grey.shade200,
                             child: Icon(Icons.image_not_supported, color: Colors.grey),
                           )
                         ),
                       ),
                       SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(_selectedTopPoi!.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                             Text(_selectedTopPoi!.categoria, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                           ],
                         ),
                       ),
                       Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ) 
            : const SizedBox.shrink(key: ValueKey('empty_card')),
      ),
    );
  }
}
// Widget do cartão de POI exibido no carrossel do mapa

class PoiMapCard extends StatefulWidget {
  final POI poi;
  const PoiMapCard({super.key, required this.poi});

  @override
  State<PoiMapCard> createState() => _PoiMapCardState();
}

class _PoiMapCardState extends State<PoiMapCard> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final FavoritesService _favoritesService = FavoritesService();
  
  bool isFavorite = false;
  bool isInItinerary = false;
  bool _isLoadingFavorite = false;
  
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _getUserLocation();
  }

  @override
  void didUpdateWidget(PoiMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poi.id != widget.poi.id) {
      _checkFavoriteStatus();
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    bool isFav = await _favoritesService.isFavorite(widget.poi.id);
    if (mounted) setState(() => isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }
    setState(() => _isLoadingFavorite = true);
    try {
      if (isFavorite) {
        await _favoritesService.removeFavorite(widget.poi.id);
        if (mounted) setState(() => isFavorite = false);
      } else {
        await _favoritesService.addFavorite(widget.poi);
        if (mounted) setState(() => isFavorite = true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingFavorites), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  void _showLoginRequiredDialog() {
    const Color kGreen = Color(0xFF0F9D58);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline_rounded, color: kGreen, size: 32),
            ),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.loginRequiredTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Para guardar nos favoritos, precisas de ter uma conta e iniciar sessão.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLocalizations.of(context)!.notNow)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLocalizations.of(context)!.login)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        if (mounted) setState(() => _userPosition = pos);
      }
    } catch (_) {}
  }

  String _formatDistance() {
    if (_userPosition == null) return '— km';
    double dist = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        widget.poi.localizacao.latitude, widget.poi.localizacao.longitude);
    if (dist < 1000) return '${dist.toStringAsFixed(0)} m';
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    String? imagePath = widget.poi.imagens.isNotEmpty ? widget.poi.imagens.first : null;

    if (imagePath == null || imagePath.isEmpty) {
      imageWidget = Container(
        color: Colors.grey[200],
      );
    } else if (imagePath.startsWith('http')) {
      imageWidget = CachedNetworkImage(imageUrl: imagePath, fit: BoxFit.cover, errorWidget: (c,e,s) => Container(color: Colors.grey[200]));
    } else {
      imageWidget = Image.file(File(imagePath), fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[200]));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                // Imagem de capa do POI (40% da altura do cartão)
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(width: double.infinity, child: imageWidget),
                  ),
                ),
                // Conteúdo textual e botões (60% da altura do cartão)
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(widget.poi.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        Text("${widget.poi.categoria} • Aprox. ${_formatDistance()}", style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            // Botão principal de acesso aos detalhes do POI
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(poi: widget.poi))),
                                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white, elevation: 0, shape: const StadiumBorder(), padding: EdgeInsets.zero),
                                  child: Text(AppLocalizations.of(context)!.viewDetails, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            // Botão de favorito
                            _isLoadingFavorite
                                ? SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                                : _buildIconButton(icon: isFavorite ? Icons.favorite : Icons.favorite_border, activeColor: Colors.red, isActive: isFavorite, onTap: _toggleFavorite),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required Color activeColor, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
        child: Icon(icon, color: isActive ? activeColor : Colors.grey[600], size: 20),
      ),
    );
  }
}

/// Gera um [BitmapDescriptor] com um marcador circular personalizado,
/// podendo exibir um número (para roteiros) ou o ícone de localização.
Future<BitmapDescriptor> getCustomMarker({required Color color, required Color iconColor, required bool isSelected, String? text}) async {
  final double size = isSelected ? 120.0 : 90.0;
  final double iconSize = isSelected ? 70.0 : 50.0;
  final double borderSize = isSelected ? 8.0 : 6.0;

  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final Paint paint = Paint()..color = color;

  // Borda branca quando selecionado, verde (cor da app) quando não selecionado
  final Paint borderPaint = Paint()
    ..color = isSelected ? Colors.white : const Color(0xFF0F9D58); 

  final double radius = size / 2;

  // Círculo exterior (borda) e círculo interior (fundo)
  canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
  canvas.drawCircle(Offset(radius, radius), radius - borderSize, paint); 

  TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
  if (text != null) {
    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: iconSize * 0.8, 
        fontWeight: FontWeight.bold,
        color: iconColor
      ),
    );
  } else {
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: iconSize, 
        fontFamily: Icons.location_on.fontFamily, 
        color: iconColor
      ),
    );
  }
  textPainter.layout();
  textPainter.paint(canvas, Offset(radius - textPainter.width / 2, radius - textPainter.height / 2));

  final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), (size + 10).toInt());
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: 2.5);
}

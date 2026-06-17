import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui; // Necessário para desenhar os marcadores
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para ByteData
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/services/database_services.dart';
import '../screens/services/download_service.dart';
import '../screens/services/roteiro_state.dart';
import '../models/poi.dart';
import '../models/roteiro.dart';
import '../screens/services/roteiros_service.dart';
import '../screens/services/routing_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/services/favorites_service.dart';
import 'details_screen.dart';
import 'ar_screen.dart';
import 'profile_screen.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'roteiros_screen.dart';
import 'login_screen.dart';

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
  Set<Polyline> _polylines = {}; // <-- Novo: Polylines para  // Ícones do mapa
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
  final double _filterRadiusMeters = 5000.0; // 5km — alcance equilibrado para turismo e caminhadas

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
  
  // Throttle para requisições do OSRM da linha dinâmica
  DateTime? _lastRouteFetch;
  List<LatLng> _currentDynamicRoute = [];
  
  // Cartão de topo na navegação
  POI? _selectedTopPoi;

  // --- PESQUISA ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<POI> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchFocused = false;

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
    _loadCustomMarkerIcons().then((_) => _initData());
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() { _isSearchFocused = _searchFocusNode.hasFocus; });
    });

    // Escutar Roteiro Ativo
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

    // Mudar para a tab do mapa
    setState(() => _selectedIndex = 1);

    // Fechar qualquer cartão de POI aberto
    setState(() {
      _selectedPoiIndex = -1;
      _visiblePois.clear(); // Opcional: limpar cartões para focar no roteiro
    });

    // Obter os POIs do roteiro
    List<POI> roteiroPois = await DatabaseService().getPOIsByIds(roteiro.poiIds);
    if (roteiroPois.isEmpty) return;

    List<LatLng> waypoints = roteiroPois.map((p) => p.location).toList();
    List<LatLng> points = await RoutingService.getFullRoteiroRoute(waypoints);

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

    // Mover câmara para o início do roteiro
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
    }
    
    // Iniciar Navegação Ativa
    _startRoteiroTracking(roteiroPois);
  }

  void _startRoteiroTracking(List<POI> roteiroPois) {
    WakelockPlus.enable(); // Manter ecrã ligado
    _isRoteiroPaused = false;
    _roteiroElapsedSeconds = 0;
    _roteiroDistanceCovered = 0.0;
    _currentRoteiroPois = roteiroPois;
    _nextPoiIndex = 0;
    _lastRoteiroPosition = null;
    _lastRouteFetch = null;
    _currentDynamicRoute = [];
    _selectedTopPoi = null;

    _updateMarkers(); // <-- CRUCIAL PARA MOSTRAR OS NÚMEROS!
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
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      POI nextPoi = _currentRoteiroPois[_nextPoiIndex];
      double dist = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        nextPoi.location.latitude, nextPoi.location.longitude,
      );
      
      // Se estiver muito perto (ex: 20 metros), avança para o próximo POI
      if (dist < 20.0) {
        _nextPoiIndex++;
        if (_nextPoiIndex < _currentRoteiroPois.length) {
          nextPoi = _currentRoteiroPois[_nextPoiIndex];
          dist = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            nextPoi.location.latitude, nextPoi.location.longitude,
          );
        } else {
          dist = 0.0; // Chegou ao fim
        }
      }
      
      setState(() {
        _distanceToNextPoi = dist;
        
        // Atualizar a linha entre o utilizador e o próximo POI
        _polylines.removeWhere((p) => p.polylineId.value == 'user_to_next');
        if (_nextPoiIndex < _currentRoteiroPois.length) {
          
          bool shouldFetch = _lastRouteFetch == null || DateTime.now().difference(_lastRouteFetch!).inSeconds > 10;
          
          if (shouldFetch || _currentDynamicRoute.isEmpty) {
            _lastRouteFetch = DateTime.now();
            RoutingService.getPedestrianRoute(
              LatLng(position.latitude, position.longitude), 
              nextPoi.location
            ).then((route) {
              if (mounted) {
                setState(() {
                  _currentDynamicRoute = route;
                  // Atualizar polyline com a nova rota
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
            // Se não formos buscar à net, apenas atualizamos o ponto de partida da rota existente
            if (_currentDynamicRoute.isNotEmpty) {
              _currentDynamicRoute[0] = LatLng(position.latitude, position.longitude);
            }
          }

          _polylines.add(
            Polyline(
              polylineId: const PolylineId('user_to_next'),
              points: _currentDynamicRoute.isNotEmpty ? _currentDynamicRoute : [
                LatLng(position.latitude, position.longitude),
                nextPoi.location,
              ],
              color: Colors.blueAccent,
              width: 4,
              patterns: [PatternItem.dash(20), PatternItem.gap(15)],
            ),
          );
        }
      });
    } catch (e) {
      print("Erro ao atualizar distância do POI: $e");
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

  // ... (MANTÉM AS FUNÇÕES DE DADOS IGUAIS: _loadCustomMarkerIcons, _initData, _updateCardsContext, _updateMarkers, _onPageChanged, _getUserLocation, _locateUser, _onItemTapped) ...
  // (Omiti para poupar espaço, já que não mudaram)

  Future<void> _loadCustomMarkerIcons() async {
    final normal = await getCustomMarker(color: Colors.white, iconColor: kPrimaryGreen, isSelected: false);
    final selected = await getCustomMarker(color: kPrimaryGreen, iconColor: Colors.white, isSelected: true);
    
    // Gerar marcadores de 1 a 20 para os roteiros
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

  void _updateCardsContext(LatLng centerPoint) {
    List<POI> nearby = _allPois.where((poi) {
      double dist = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, poi.location.latitude, poi.location.longitude);
      return dist <= _filterRadiusMeters;
    }).toList();

    nearby.sort((a, b) {
      double distA = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, a.location.latitude, a.location.longitude);
      double distB = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, b.location.latitude, b.location.longitude);
      return distA.compareTo(distB);
    });
    setState(() {
      _visiblePois = nearby;
      if (_visiblePois.isNotEmpty) {
        _selectedPoiIndex = 0;
        if (_pageController.hasClients) _pageController.jumpToPage(0);
      } else {
        _selectedPoiIndex = -1;
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
          position: poi.location,
          icon: _numberedMarkersNormal[i + 1] ?? _markerIconNormal!,
          zIndex: 1,
          anchor: const Offset(0.5, 0.5),
          onTap: () {
            setState(() {
              _selectedTopPoi = poi;
            });
            if (_mapController != null) {
               _mapController!.animateCamera(CameraUpdate.newLatLng(poi.location));
            }
          }
        ));
      }
    } else {
      for (var poi in _allPois) {
        bool isSelected = false;
        if (_selectedPoiIndex != -1 && _selectedPoiIndex < _visiblePois.length) {
          isSelected = _visiblePois[_selectedPoiIndex].id == poi.id;
        }
        newMarkers.add(Marker(
          markerId: MarkerId(poi.id),
          position: poi.location,
          icon: isSelected ? _markerIconSelected! : _markerIconNormal!,
          zIndex: isSelected ? 2 : 1,
          anchor: const Offset(0.5, 0.5),
          onTap: () { 
            if (activeRoteiroNotifier.value == null) {
              _updateCardsContext(poi.location); 
            }
          },
        ));
      }
    }
    setState(() { _markers = newMarkers; });
  }

  void _onPageChanged(int index) {
    setState(() { _selectedPoiIndex = index; });
    _updateMarkers();
    if (_mapController != null && index < _visiblePois.length) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_visiblePois[index].location));
    }
  }

  Future<Position?> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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

  // --- NAVEGAR: Abre Google Maps com seleção de modo de transporte ---
  void _startNavigation(POI poi) {
    final lat = poi.location.latitude;
    final lng = poi.location.longitude;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: kPrimaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.navigation_rounded, color: kPrimaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Navegar para', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(poi.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Escolhe o modo de transporte', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTransportOption(ctx, icon: Icons.directions_walk, label: 'A Pé', mode: 'w', lat: lat, lng: lng),
                const SizedBox(width: 10),
                _buildTransportOption(ctx, icon: Icons.directions_car, label: 'Carro', mode: 'd', lat: lat, lng: lng),
                const SizedBox(width: 10),
                _buildTransportOption(ctx, icon: Icons.directions_bike, label: 'Bicicleta', mode: 'b', lat: lat, lng: lng),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportOption(BuildContext ctx, {required IconData icon, required String label, required String mode, required double lat, required double lng}) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          Navigator.pop(ctx);
          final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=$mode');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            // Fallback para browser
            final fallback = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=${mode == 'w' ? 'walking' : mode == 'b' ? 'bicycling' : 'driving'}');
            await launchUrl(fallback, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: kPrimaryGreen, size: 26),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // --- LÓGICA DE PESQUISA ---
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
      return poi.name.toLowerCase().contains(query) ||
             poi.category.toLowerCase().contains(query);
    }).toList();
    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
  }

  void _selectSearchResult(POI poi) {
    // Fechar teclado e limpar pesquisa
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    // Navegar o mapa para o POI selecionado
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: poi.location, zoom: 18),
        ),
      );
    }
    // Mostrar os cartões em torno desse POI
    _updateCardsContext(poi.location);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  // ---------------------------------------------------------------
  // --- BUILD ATUALIZADO ---
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const double cardHeight = 220.0;
    const double visibleBottom = 100.0;
    const double hiddenBottom = -300.0;

    // 1. Verificar se o teclado está aberto
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // 2. Os cartões só aparecem se o teclado estiver FECHADO
    bool areCardsVisible = _selectedPoiIndex != -1 && _visiblePois.isNotEmpty && !isKeyboardOpen;

    return Scaffold(
      extendBody: true,
      // 3. Isto impede que o layout suba quando o teclado abre
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
                initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 16),
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Aplica o estilo para limpar o mapa
                  controller.setMapStyle(_mapStyle);
                },
                mapToolbarEnabled: false,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                padding: EdgeInsets.only(bottom: areCardsVisible ? 300 : 100, top: 100),
                onTap: (_) { 
                  // 4. Fechar o teclado ao clicar no mapa
                  FocusScope.of(context).unfocus();
                  setState(() { 
                    _selectedPoiIndex = -1; 
                    _selectedTopPoi = null;
                  }); 
                  _updateMarkers(); 
                },
              ),
              
              // BARRA DE PESQUISA ATUALIZADA
              if (activeRoteiroNotifier.value == null)
                _buildSearchBar(),
              
              // BOTÃO GPS — esconde quando a pesquisa está ativa
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
                top: 110,
                right: (_isSearchFocused || _isSearching) ? -80 : 20,
                child: FloatingActionButton.small(
                  heroTag: "gps_btn", backgroundColor: Colors.white, onPressed: _locateUser,
                  child: const Icon(Icons.my_location, color: Colors.black54),
                ),
              ),

              // BOTÃO AR
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                bottom: activeRoteiroNotifier.value != null ? 220 : 100, 
                // Se teclado aberto OU cartões visíveis, esconde botão AR
                right: (areCardsVisible || isKeyboardOpen) ? -200 : 20, 
                child: FloatingActionButton.extended(
                  heroTag: "ar_btn", backgroundColor: kPrimaryGreen,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ArScreen())),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("Modo AR", style: TextStyle(color: Colors.white)),
                ),
              ),

              // BOTÃO NAVEGAR — aparece quando há POI selecionado
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                bottom: 100,
                left: (areCardsVisible && !isKeyboardOpen) ? 20 : -200,
                child: FloatingActionButton.extended(
                  heroTag: "nav_btn",
                  backgroundColor: Colors.white,
                  onPressed: () {
                    if (_selectedPoiIndex != -1 && _selectedPoiIndex < _visiblePois.length) {
                      _startNavigation(_visiblePois[_selectedPoiIndex]);
                    }
                  },
                  icon: Icon(Icons.navigation_rounded, color: kPrimaryGreen),
                  label: Text("Navegar", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w700)),
                  elevation: 2,
                ),
              ),

              // PAINEL DE NAVEGAÇÃO ATIVA
              if (activeRoteiroNotifier.value != null)
                _buildActiveNavigationPanel(),

              // MINI CARTÃO DE TOPO (Apenas na Navegação Ativa)
              if (activeRoteiroNotifier.value != null && _selectedTopPoi != null)
                _buildTopMiniCard(),

              // CARROSSEL
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic,
                left: 0, right: 0, 
                height: cardHeight,
                // Se teclado aberto, manda para baixo
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
          // 2. ROTEIROS
          const RoteirosScreen(),
          const FavoritesScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: activeRoteiroNotifier.value != null ? null : _buildBottomNav(),
    );
  }

  // --- PAINEL DE NAVEGAÇÃO ATIVA ---
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -5))],
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
                    const Text("Tempo", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                          Text("A ${formatDistance(_distanceToNextPoi)} de ${_currentRoteiroPois[_nextPoiIndex].name}", style: TextStyle(color: kPrimaryGreen, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDistance(_roteiroDistanceCovered), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text("Distância", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                      backgroundColor: _isRoteiroPaused ? Colors.orange : kPrimaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(_isRoteiroPaused ? "Continuar" : "Pausar", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showEndRoteiroDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("Terminar", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- ECRÃ DE RESUMO DO ROTEIRO ---
  void _showEndRoteiroDialog() {
    // Pausar tracking temporariamente
    setState(() => _isRoteiroPaused = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Terminar Roteiro", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Tens a certeza que queres terminar este roteiro?", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Icon(Icons.timer, color: kPrimaryGreen),
                      const SizedBox(height: 5),
                      Text("${(_roteiroElapsedSeconds / 60).toStringAsFixed(1)} min", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.directions_walk, color: kPrimaryGreen),
                      const SizedBox(height: 5),
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
                    setState(() => _isRoteiroPaused = false); // Continuar
                  },
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _finishRoteiro();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
                  child: const Text("Concluir"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _finishRoteiro() {
    final roteiroId = activeRoteiroNotifier.value!.id;
    // Marcar como concluído
    RoteirosService().markRoteiroAsCompleted(roteiroId); 
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kPrimaryGreen,
        content: const Text("Parabéns! Roteiro concluído com sucesso."),
      )
    );
    activeRoteiroNotifier.value = null; // Isto chama o _onActiveRoteiroChanged que limpa a UI
  }

  // --- BARRA DE PESQUISA FUNCIONAL ---
  Widget _buildSearchBar() {
    // Altura do teclado (0 se estiver fechado)
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // Altura total do ecrã
    final double screenHeight = MediaQuery.of(context).size.height;
    // Espaço disponível para a lista de resultados:
    // ecrã - teclado - top da barra (50) - altura da barra (50) - margem (12) - padding de segurança extra (16)
    final double availableDropdownHeight =
        screenHeight - keyboardHeight - 50 - 50 - 12 - 16;

    return Positioned(
      top: 50, left: 20, right: 20,
      // Limitar a altura total ao espaço disponível acima do teclado
      bottom: keyboardHeight > 0 ? keyboardHeight + 8 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Barra principal --
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
                // Ícone de pesquisa
                Icon(Icons.search, color: _isSearching ? kPrimaryGreen : Colors.grey),
                const SizedBox(width: 10),
                // Campo de texto
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Pesquisar local...',
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
                // Botão X para limpar (só aparece enquanto pesquisa)
                if (_isSearching)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    splashRadius: 20,
                    onPressed: _clearSearch,
                  )
                else ...([
                  // Divisória e botão filtros quando não está a pesquisar
                  Container(width: 1, height: 24, color: Colors.grey[300]),
                  const SizedBox(width: 5),
                  IconButton(
                    icon: Icon(Icons.tune, color: kPrimaryGreen),
                    splashRadius: 24,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Filtros em breve!")),
                      );
                    },
                  ),
                ]),
              ],
            ),
          ),
          // -- Recomendações de locais próximos (quando focado e sem texto) --
          if (_isSearchFocused && !_isSearching && _visiblePois.isNotEmpty)
            _buildNearbyRecommendations(maxHeight: availableDropdownHeight.clamp(100, 300)),

          // -- Lista de resultados de pesquisa --
          if (_isSearching && _searchResults.isNotEmpty)
            _buildResultsList(_searchResults, maxHeight: availableDropdownHeight.clamp(100, 260)),

          // -- Mensagem quando não há resultados --
          if (_isSearching && _searchResults.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Text('Nenhum local encontrado', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
  // --- RECOMENDAÇÕES DE LOCAIS PRÓXIMOS ---
  Widget _buildNearbyRecommendations({double maxHeight = 300}) {
    // Mostra até 5 POIs próximos (já ordenados por distância em _visiblePois)
    final nearby = _visiblePois.take(5).toList();
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
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.near_me, size: 15, color: kPrimaryGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Locais Próximos',
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
            // Lista scrollable para caber no espaço disponível
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: nearby.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final poi = nearby[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kPrimaryGreen.withValues(alpha: 0.12),
                      child: Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
                    ),
                    title: Text(
                      poi.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      poi.category,
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

  // --- LISTA DE RESULTADOS (PESQUISA) ---
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
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
          itemBuilder: (context, index) {
            final poi = pois[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: kPrimaryGreen.withValues(alpha: 0.12),
                child: Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
              ),
              title: Text(
                poi.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                poi.category,
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
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex, onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, backgroundColor: Colors.transparent, elevation: 0,
        selectedItemColor: kPrimaryGreen, unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.explore_outlined)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.explore)), label: 'Explorar'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.map_outlined)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.map)), label: 'Mapa'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.tour_outlined)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.tour)), label: 'Roteiros'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite_outline)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite)), label: 'Favoritos'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_outline)), activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person)), label: 'Perfil'),
        ],
      ),
    );
  }
// -----------------------------------------------------------
// --- HELPER: MINI CARTÃO DE TOPO (Navegação Ativa) ---
// -----------------------------------------------------------
  Widget _buildTopMiniCard() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 60.0,
      left: 20, 
      right: 20,
      child: GestureDetector(
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
                 child: Image.network(
                   _selectedTopPoi!.images.isNotEmpty ? _selectedTopPoi!.images.first : '', 
                   width: 50, 
                   height: 50, 
                   fit: BoxFit.cover, 
                   errorBuilder: (_,__,___) => Container(
                     width: 50, height: 50, color: Colors.grey.shade200,
                     child: const Icon(Icons.image_not_supported, color: Colors.grey),
                   )
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(_selectedTopPoi!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                     Text(_selectedTopPoi!.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                   ],
                 ),
               ),
               const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
// -----------------------------------------------------------
// --- NOVO WIDGET DO CARTÃO (CARD) ---
// -----------------------------------------------------------

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao atualizar favoritos."), backgroundColor: Colors.red));
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
                color: kGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, color: kGreen, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sessão necessária',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Para guardar nos favoritos, precisas de ter uma conta e iniciar sessão.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Agora não'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Iniciar sessão'),
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
        pos ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        if (mounted) setState(() => _userPosition = pos);
      }
    } catch (_) {}
  }

  String _formatDistance() {
    if (_userPosition == null) return '— km';
    double dist = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        widget.poi.location.latitude, widget.poi.location.longitude);
    if (dist < 1000) return '${dist.toStringAsFixed(0)} m';
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    String? imagePath = widget.poi.images.isNotEmpty ? widget.poi.images.first : null;

    if (imagePath == null || imagePath.isEmpty) {
      imageWidget = Container(
        color: Colors.grey[200],
      );
    } else if (imagePath.startsWith('http')) {
      imageWidget = Image.network(imagePath, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[200]));
    } else {
      imageWidget = Image.file(File(imagePath), fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[200]));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                // IMAGEM (40% Altura)
                Expanded(
                  flex: 4, 
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(width: double.infinity, child: imageWidget),
                  ),
                ),
                // CONTEÚDO (60% Altura)
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
                            Expanded(child: Text(widget.poi.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [Text(widget.poi.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(width: 4), const Icon(Icons.star, size: 14, color: Colors.amber)]),
                            )
                          ],
                        ),
                        Text("${widget.poi.category} • Aprox. ${_formatDistance()}", style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            // Botão Detalhes (Stadium)
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(poi: widget.poi))),
                                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white, elevation: 0, shape: const StadiumBorder(), padding: EdgeInsets.zero),
                                  child: const Text("Ver Detalhes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Botões Ícone (Limpos)
                            _isLoadingFavorite
                                ? const SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                                : _buildIconButton(icon: isFavorite ? Icons.favorite : Icons.favorite_border, activeColor: Colors.red, isActive: isFavorite, onTap: _toggleFavorite),
                            const SizedBox(width: 8),
                            _buildIconButton(icon: isInItinerary ? Icons.playlist_add_check : Icons.playlist_add, activeColor: kPrimaryGreen, isActive: isInItinerary, onTap: () => setState(() => isInItinerary = !isInItinerary)),
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

// -----------------------------------------------------------
// --- HELPER: DESENHAR MARCADOR PERSONALIZADO ---
// -----------------------------------------------------------
Future<BitmapDescriptor> getCustomMarker({required Color color, required Color iconColor, required bool isSelected, String? text}) async {
  final double size = isSelected ? 120.0 : 90.0;
  final double iconSize = isSelected ? 70.0 : 50.0;
  final double borderSize = isSelected ? 8.0 : 6.0;

  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final Paint paint = Paint()..color = color;

  // --- ALTERAÇÃO AQUI ---
  // Se selecionado = Branco (destaque), Se não = Verde (marca da app)
  final Paint borderPaint = Paint()
    ..color = isSelected ? Colors.white : const Color(0xFF0F9D58); 

  final double radius = size / 2;

  // Desenha a Borda (Círculo exterior)
  canvas.drawCircle(Offset(radius, radius), radius, borderPaint); 
  
  // Desenha o Fundo (Círculo interior)
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

  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}
import 'dart:io';
import 'dart:ui' as ui; // Necessário para desenhar os marcadores
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para ByteData
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/services/database_services.dart';
import '../screens/services/download_service.dart';
import '../models/poi.dart';
import 'details_screen.dart';
import 'ar_screen.dart';
import 'profile_screen.dart';

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
  
  BitmapDescriptor? _markerIconNormal;
  BitmapDescriptor? _markerIconSelected;

  // --- ESTADO UI ---
  int _selectedIndex = 0;
  int _selectedPoiIndex = -1; 

  late PageController _pageController;
  GoogleMapController? _mapController;
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final double _filterRadiusMeters = 500.0;

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ... (MANTÉM AS FUNÇÕES DE DADOS IGUAIS: _loadCustomMarkerIcons, _initData, _updateCardsContext, _updateMarkers, _onPageChanged, _getUserLocation, _locateUser, _onItemTapped) ...
  // (Omiti para poupar espaço, já que não mudaram)

  Future<void> _loadCustomMarkerIcons() async {
    final normal = await getCustomMarker(color: Colors.white, iconColor: kPrimaryGreen, isSelected: false);
    final selected = await getCustomMarker(color: kPrimaryGreen, iconColor: Colors.white, isSelected: true);
    if (mounted) setState(() { _markerIconNormal = normal; _markerIconSelected = selected; });
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
        onTap: () { _updateCardsContext(poi.location); },
      ));
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
      _updateCardsContext(LatLng(pos.latitude, pos.longitude));
    }
  }

  void _onItemTapped(int index) { setState(() { _selectedIndex = index; }); }

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
          // 0. MAPA
          Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 16),
                markers: _markers,
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
                  setState(() { _selectedPoiIndex = -1; }); 
                  _updateMarkers(); 
                },
              ),
              
              // BARRA DE PESQUISA ATUALIZADA
              _buildSearchBar(),
              
              // BOTÃO GPS
              Positioned(
                top: 110, right: 20,
                child: FloatingActionButton.small(
                  heroTag: "gps_btn", backgroundColor: Colors.white, onPressed: _locateUser,
                  child: const Icon(Icons.my_location, color: Colors.black54),
                ),
              ),

              // BOTÃO AR
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                bottom: 100, 
                // Se teclado aberto OU cartões visíveis, esconde botão AR
                right: (areCardsVisible || isKeyboardOpen) ? -200 : 20, 
                child: FloatingActionButton.extended(
                  heroTag: "ar_btn", backgroundColor: kPrimaryGreen,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ArScreen())),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("Modo AR", style: TextStyle(color: Colors.white)),
                ),
              ),

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
          
          const Center(child: Text("Roteiros em breve...")),
          const Center(child: Text("Modo Navegação em breve...")),
          const Center(child: Text("Favoritos em breve...")),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- BARRA DE PESQUISA COM FILTROS ---
Widget _buildSearchBar() {
    return Positioned(
      top: 50, left: 20, right: 20,
      child: Container(
        padding: const EdgeInsets.only(left: 15, right: 5), // Ajustei o padding da direita para 5
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(30), 
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // Garante alinhamento vertical
          children: [
            // Ícone Pesquisa
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 10),
            
            // Campo de Texto
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Pesquisar local...', 
                  border: InputBorder.none, 
                  contentPadding: EdgeInsets.zero, // Remove padding interno extra
                  isDense: true,
                ),
                style: TextStyle(fontSize: 15),
              )
            ),
            
            // Divisória Vertical
            Container(
              width: 1, 
              height: 24, 
              color: Colors.grey[300]
            ),
            
            // Espaço entre a linha e o botão
            const SizedBox(width: 5), 
            
            // Botão Filtros
            IconButton(
              icon: Icon(Icons.tune, color: kPrimaryGreen),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Filtros em breve!")));
              },
              // Removemos constraints manuais para o ícone se centrar naturalmente
              splashRadius: 24, // O efeito de clique fica redondo e contido
            ),
          ],
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
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.map)), label: 'Explorar'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.tour)), label: 'Roteiros'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.near_me)), label: 'Navegar'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite_outlined)), label: 'Favoritos'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_outline)), label: 'Perfil'),
        ],
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
  bool isFavorite = false;
  bool isInItinerary = false;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    String? imagePath = widget.poi.images.isNotEmpty ? widget.poi.images.first : null;

    if (imagePath == null || imagePath.isEmpty) {
      imageWidget = Image.network('https://via.placeholder.com/300', fit: BoxFit.cover);
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
                        Text("${widget.poi.category} • Aprox. 20m", style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                            _buildIconButton(icon: isFavorite ? Icons.favorite : Icons.favorite_border, activeColor: Colors.red, isActive: isFavorite, onTap: () => setState(() => isFavorite = !isFavorite)),
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
Future<BitmapDescriptor> getCustomMarker({required Color color, required Color iconColor, required bool isSelected}) async {
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
  textPainter.text = TextSpan(
    text: String.fromCharCode(Icons.location_on.codePoint),
    style: TextStyle(
      fontSize: iconSize, 
      fontFamily: Icons.location_on.fontFamily, 
      color: iconColor
    ),
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(radius - textPainter.width / 2, radius - textPainter.height / 2));

  final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), (size + 10).toInt());
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}
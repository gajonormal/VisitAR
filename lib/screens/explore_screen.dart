import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi.dart';
import '../models/filter_options.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../screens/services/database_services.dart';
import '../screens/services/download_service.dart';
import '../screens/services/roteiros_service.dart';
import '../models/roteiro.dart';
import '../widgets/poi_card.dart';
import 'details_screen.dart';
import 'roteiro_details_screen.dart';
import 'ar_screen.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

class ExploreScreen extends StatefulWidget {
  /// Callback para mudar o tab ativo na navbar (e.g. ir para o Mapa)
  final Function(int) onTabChange;

  const ExploreScreen({super.key, required this.onTabChange});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // --- CORES ---
  final Color kPrimaryGreen = const Color(0xFF0F9D58);

  // --- DADOS ---
  List<POI> _allPois = [];
  List<POI> _nearbyPois = [];
  bool _isLoading = true;
  Position? _userPosition;

  // --- FILTROS ---
  final List<String> _categories = ['Tudo', 'Histórico', 'Natureza', 'Geológico', 'Trilho', 'Gastronomia'];
  POIFilter _poiFilter = POIFilter();

  // --- PESQUISA ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<POI> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchFocused = false;

  // --- ROTEIROS ---
  final RoteirosService _roteirosService = RoteirosService();

  // --- LAYOUT ---
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 220.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() { _isSearchFocused = _searchFocusNode.hasFocus; });
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _measureHeaderHeight() {
    final RenderBox? renderBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final newHeight = renderBox.size.height;
      if (newHeight != _headerHeight && newHeight > 0) {
        setState(() => _headerHeight = newHeight);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      List<POI> rawPois = await DatabaseService().getPOIs();
      final downloadService = DownloadService();
      List<POI> processedPois = [];
      for (var onlinePoi in rawPois) {
        POI? offlinePoi = await downloadService.getOfflinePoi(onlinePoi.id);
        processedPois.add(offlinePoi ?? onlinePoi);
      }
      Position? pos = await _getUserLocation();
      if (mounted) {
        setState(() {
          _allPois = processedPois;
          _userPosition = pos;
          _isLoading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position?> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Location timeout');
      });
    } catch (e) {
      return null;
    }
  }

  void _applyFilter() {
    List<POI> filtered = _allPois.where((p) => _poiFilter.apply(p)).toList();
    
    if (_userPosition != null) {
      // 1. Filter out POIs that are further than 50km (50,000 meters)
      filtered = filtered.where((poi) {
        double dist = Geolocator.distanceBetween(
            _userPosition!.latitude, _userPosition!.longitude, 
            poi.localizacao.latitude, poi.localizacao.longitude);
        return dist <= 50000;
      }).toList();

      // 2. Sort the remaining nearby POIs by distance
      filtered.sort((a, b) {
        double dA = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, a.localizacao.latitude, a.localizacao.longitude);
        double dB = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, b.localizacao.latitude, b.localizacao.longitude);
        return dA.compareTo(dB);
      });
    } else {
      // If we don't have the user's location, there's nothing "near" them
      filtered = [];
    }
    setState(() => _nearbyPois = filtered);
  }

  // --- LÓGICA DE PESQUISA (igual ao home_map) ---
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    final results = _allPois.where((poi) {
      if (!_poiFilter.apply(poi)) return false;
      return poi.nome.toLowerCase().contains(query) ||
             poi.categoria.toLowerCase().contains(query);
    }).toList();
    setState(() { _searchResults = results; _isSearching = true; });
  }

  void _selectSearchResult(POI poi) {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() { _searchResults = []; _isSearching = false; });
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(poi: poi)));
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() { _searchResults = []; _isSearching = false; });
  }



  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Fácil':    return const Color(0xFF27AE60);
      case 'Moderado': return const Color(0xFFE67E22);
      case 'Difícil':  return const Color(0xFFC0392B);
      default:         return Colors.grey;
    }
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = MediaQuery.of(context).padding.top;
    // Espaço disponível para o dropdown abaixo da barra de pesquisa
    final double headerH = topPadding + 16 + 60 + 12; // padding + header approx + search bar + margin
    final double availableDropdownHeight =
        (screenHeight - keyboardHeight - headerH - 12).clamp(100, 300);

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeaderHeight());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0), // Fundo principal
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: _clearSearch,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── CONTEÚDO SCROLLÁVEL (Por baixo) ──
            RefreshIndicator(
              color: kPrimaryGreen,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: _headerHeight + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildArBanner(),
                    _buildCategoryFilters(),
                    _buildNearbySection(),
                    _buildItinerariesSection(),
                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // ── CAIXA VERDE (Header + Pesquisa, Fixa no Topo) ──
            Positioned(
              top: 0, left: 0, right: 0,
              child: Material(
                key: _headerKey,
                elevation: 10,
                shadowColor: Colors.black.withOpacity(0.3),
                color: Colors.transparent,
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: kPrimaryGreen,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header saudão
                      _buildHeader(),

                // Barra de pesquisa + dropdown
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Barra principal — mesmo estilo do home_map mas com sombra mais suave sobre o verde
                      Container(
                        padding: const EdgeInsets.only(left: 15, right: 5),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.search, color: _isSearching ? kPrimaryGreen : Colors.grey),
                            SizedBox(width: 10),
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
                                  if (_searchResults.isNotEmpty) _selectSearchResult(_searchResults.first);
                                },
                              ),
                            ),
                            if (_isSearching)
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.grey),
                                splashRadius: 20,
                                onPressed: _clearSearch,
                              )
                            else ...[
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
                                      onApply: (poiF, rotF) {
                                        if (poiF != null) {
                                          setState(() => _poiFilter = poiF);
                                          _applyFilter();
                                          if (_searchController.text.isNotEmpty) _onSearchChanged();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Dropdown: locais próximos quando focado sem texto
                      if (_isSearchFocused && !_isSearching && _nearbyPois.isNotEmpty)
                        _buildDropdownContainer(
                          maxHeight: availableDropdownHeight,
                          child: _buildNearbyRecommendations(),
                        ),

                      // Dropdown: resultados de pesquisa
                      if (_isSearching && _searchResults.isNotEmpty)
                        _buildDropdownContainer(
                          maxHeight: availableDropdownHeight,
                          child: _buildResultsList(_searchResults),
                        ),

                      // Dropdown: sem resultados
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
                              SizedBox(width: 10),
                              Text(AppLocalizations.of(context)!.noLocationFound, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ), // fim Column
          ), // fim Container
        ), // fim Material
      ), // fim Positioned
    ], // fim Stack children
  ), // fim Stack
  ), // fim GestureDetector
); // fim Scaffold
}

  Widget _buildDropdownContainer({required Widget child, required double maxHeight}) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }

  Widget _buildNearbyRecommendations() {
    final nearby = _nearbyPois.take(5).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Icon(Icons.near_me, size: 15, color: kPrimaryGreen),
              SizedBox(width: 6),
              Text(AppLocalizations.of(context)!.nearbyPlaces, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimaryGreen, letterSpacing: 0.5)),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shrinkWrap: true,
            itemCount: nearby.length,
            itemBuilder: (context, index) {
              return PoiCard(poi: nearby[index], userPosition: _userPosition);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(List<POI> pois) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shrinkWrap: true,
      itemCount: pois.length,
      itemBuilder: (context, index) {
        return PoiCard(poi: pois[index], userPosition: _userPosition);
      },
    );
  }

  // ---------------------------------------------------------------
  // HEADER — Saudação
  // ---------------------------------------------------------------
  Widget _buildHeader() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.hasData) {
          final uid = authSnap.data!.uid;
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, userSnap) {
              final nome = (userSnap.data?.data() as Map<String, dynamic>?)?['nome'] ?? AppLocalizations.of(context)!.welcomeExplorer;
              return _headerContent(nome);
            },
          );
        }
        return _headerContent(AppLocalizations.of(context)!.welcomeExplorer);
      },
    );
  }

  Widget _headerContent(String nome) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 22, right: 22, bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.welcomeHeader,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              fontFamily: 'GoogleSans',
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 26, color: Colors.white, fontFamily: 'GoogleSans',
              ),
              children: [
                TextSpan(text: AppLocalizations.of(context)!.hello, style: TextStyle(fontWeight: FontWeight.w400)),
                TextSpan(text: nome, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // BANNER AR
  // ---------------------------------------------------------------
  Widget _buildArBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArScreen())),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              SizedBox(
                height: 180, width: double.infinity,
                child: Image.network(
                  'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1B4332),
                    child: Center(child: Icon(Icons.landscape, color: Colors.white54, size: 60)),
                  ),
                ),
              ),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.65)],
                  ),
                ),
              ),
              Positioned(
                left: 20, bottom: 20, right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text(AppLocalizations.of(context)!.arMode.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      AppLocalizations.of(context)!.arBannerTitle,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 15),
                    Text(AppLocalizations.of(context)!.arBannerSubtitle, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // FILTROS DE CATEGORIA
  // ---------------------------------------------------------------
  Widget _buildCategoryFilters() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final isSelected = cat == _poiFilter.categoria;
            return GestureDetector(
              onTap: () { setState(() => _poiFilter = _poiFilter.copyWith(categoria: cat)); _applyFilter(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? kPrimaryGreen : Colors.grey.shade300),
                  boxShadow: isSelected ? [BoxShadow(color: kPrimaryGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: Text(
                  _getCategoryTranslation(context, cat),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // SECÇÃO "PERTO DE TI"
  // ---------------------------------------------------------------
  Widget _buildNearbySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.nearYou, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              if (!_isLoading)
                Text(
                  '${_nearbyPois.length} ${_nearbyPois.length == 1 ? AppLocalizations.of(context)!.result : AppLocalizations.of(context)!.results}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
            ],
          ),
          SizedBox(height: 14),
          if (_isLoading)
            Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else if (_nearbyPois.isEmpty)
            _buildEmptyState()
          else
            ...List.generate(_nearbyPois.length, (i) => PoiCard(poi: _nearbyPois[i], userPosition: _userPosition)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.location_off_outlined, color: Colors.grey[300], size: 48),
            SizedBox(height: 12),
            Text(
              _userPosition == null ? AppLocalizations.of(context)!.locationNotFound : AppLocalizations.of(context)!.noPlacesNearYou, 
              style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)
            ),
            SizedBox(height: 4),
            Text(
              _userPosition == null ? AppLocalizations.of(context)!.turnOnGps : AppLocalizations.of(context)!.tryExploringOtherZones, 
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }



  // ---------------------------------------------------------------
  // SECÇÃO "ROTEIROS SUGERIDOS"
  // ---------------------------------------------------------------
  Widget _buildItinerariesSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppLocalizations.of(context)!.suggestedItineraries, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                GestureDetector(
                  onTap: () => widget.onTabChange(2), // Roteiros é o índice 2
                  child: Text(AppLocalizations.of(context)!.viewAll, style: TextStyle(color: kPrimaryGreen, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: StreamBuilder<List<Roteiro>>(
              stream: _roteirosService.getExploreRoteiros(), // Mostra apenas os do utilizador + admin
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final roteiros = snapshot.data ?? [];
                if (roteiros.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context)!.noItinerariesAvailable, style: TextStyle(color: Colors.grey)));
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  itemCount: roteiros.length > 5 ? 5 : roteiros.length,
                  separatorBuilder: (_, __) => SizedBox(width: 14),
                  itemBuilder: (context, i) => _buildItineraryCard(roteiros[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard(Roteiro roteiro) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RoteiroDetailsScreen(roteiro: roteiro)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (roteiro.imagemCapa.isNotEmpty)
                Image.network(roteiro.imagemCapa, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: kPrimaryGreen))
              else
                Container(color: kPrimaryGreen),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                  ),
                ),
              ),
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12)),
                  child: Text(_getDifficultyTranslation(context, roteiro.dificuldade), style: TextStyle(color: _difficultyColor(roteiro.dificuldade), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              Positioned(
                left: 12, right: 12, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roteiro.titulo, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.white.withOpacity(0.75), size: 12),
                        SizedBox(width: 4),
                        Text(roteiro.duracao, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                        SizedBox(width: 10),
                        Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                        SizedBox(width: 10),
                        Text('${roteiro.distancia.toStringAsFixed(1)} km', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryTranslation(BuildContext context, String category) {
    switch (category) {
      case 'Tudo':
        return AppLocalizations.of(context)!.catAll;
      case 'Histórico':
        return AppLocalizations.of(context)!.catHistoric;
      case 'Natureza':
        return AppLocalizations.of(context)!.catNature;
      case 'Geológico':
        return AppLocalizations.of(context)!.catGeologic;
      case 'Trilho':
        return AppLocalizations.of(context)!.catTrail;
      case 'Gastronomia':
        return AppLocalizations.of(context)!.catGastronomy;
      default:
        return category;
    }
  }

  String _getDifficultyTranslation(BuildContext context, String difficulty) {
    switch (difficulty) {
      case 'Qualquer':
        return AppLocalizations.of(context)!.difAny;
      case 'Fácil':
        return AppLocalizations.of(context)!.difEasy;
      case 'Moderado':
        return AppLocalizations.of(context)!.difMedium;
      case 'Difícil':
        return AppLocalizations.of(context)!.difHard;
      default:
        return difficulty;
    }
  }
}

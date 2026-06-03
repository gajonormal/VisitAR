import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi.dart';
import '../screens/services/database_services.dart';
import '../screens/services/download_service.dart';
import 'details_screen.dart';
import 'ar_screen.dart';

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
  String _selectedCategory = 'Tudo';

  // --- PESQUISA ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<POI> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchFocused = false;

  // --- ROTEIROS DE EXEMPLO ---
  final List<Map<String, String>> _sampleItineraries = [
    {
      'title': 'Trilho dos Gigantes de Granito',
      'difficulty': 'Moderado',
      'duration': '2h 30m',
      'distance': '4.2 km',
      'image': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600',
    },
    {
      'title': 'Rota Histórica do Barrocal',
      'difficulty': 'Fácil',
      'duration': '1h 45m',
      'distance': '2.8 km',
      'image': 'https://images.unsplash.com/photo-1518005020951-eccb494ad742?w=600',
    },
    {
      'title': 'Percurso da Serra da Gardunha',
      'difficulty': 'Difícil',
      'duration': '3h 15m',
      'distance': '6.1 km',
      'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600',
    },
  ];

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
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (e) {
      return null;
    }
  }

  void _applyFilter() {
    List<POI> filtered = _selectedCategory == 'Tudo'
        ? List.from(_allPois)
        : _allPois.where((p) => p.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    if (_userPosition != null) {
      filtered.sort((a, b) {
        double dA = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, a.location.latitude, a.location.longitude);
        double dB = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, b.location.latitude, b.location.longitude);
        return dA.compareTo(dB);
      });
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
      return poi.name.toLowerCase().contains(query) ||
             poi.category.toLowerCase().contains(query);
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

  String _formatDistance(POI poi) {
    if (_userPosition == null) return '— km';
    double dist = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        poi.location.latitude, poi.location.longitude);
    if (dist < 1000) return '${dist.toStringAsFixed(0)} m';
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'geológico':   return const Color(0xFFE67E22);
      case 'histórico':   return const Color(0xFF8B4513);
      case 'natureza':    return const Color(0xFF27AE60);
      case 'trilho':      return const Color(0xFF2980B9);
      case 'gastronomia': return const Color(0xFFC0392B);
      default:            return const Color(0xFF7F8C8D);
    }
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

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: _clearSearch,
        behavior: HitTestBehavior.translucent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

          // ── CAIXA VERDE (header + barra de pesquisa) ──
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kPrimaryGreen, kPrimaryGreen.withOpacity(0.82)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            const SizedBox(width: 10),
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
                                  if (_searchResults.isNotEmpty) _selectSearchResult(_searchResults.first);
                                },
                              ),
                            ),
                            if (_isSearching)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                splashRadius: 20,
                                onPressed: _clearSearch,
                              )
                            else ...[
                              Container(width: 1, height: 24, color: Colors.grey[300]),
                              const SizedBox(width: 5),
                              IconButton(
                                icon: Icon(Icons.tune, color: kPrimaryGreen),
                                splashRadius: 24,
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Filtros em breve!')),
                                ),
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
                              const SizedBox(width: 10),
                              Text('Nenhum local encontrado', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── CONTEÚDO SCROLLÁVEL ──
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F0),
              child: RefreshIndicator(
                color: kPrimaryGreen,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildArBanner(),
                      _buildCategoryFilters(),
                      _buildNearbySection(),
                      _buildItinerariesSection(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
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
              const SizedBox(width: 6),
              Text('Locais Próximos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimaryGreen, letterSpacing: 0.5)),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),
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
                  backgroundColor: kPrimaryGreen.withOpacity(0.12),
                  child: Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
                ),
                title: Text(poi.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(poi.category, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey[400]),
                onTap: () => _selectSearchResult(poi),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(List<POI> pois) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: pois.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final poi = pois[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: kPrimaryGreen.withOpacity(0.12),
            child: Icon(Icons.location_on, color: kPrimaryGreen, size: 20),
          ),
          title: Text(poi.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(poi.category, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          trailing: Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey[400]),
          onTap: () => _selectSearchResult(poi),
        );
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
              final nome = (userSnap.data?.data() as Map<String, dynamic>?)?['nome'] ?? 'Explorador';
              return _headerContent(nome);
            },
          );
        }
        return _headerContent('Explorador');
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
            'BEM-VINDO/A',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              fontFamily: 'GoogleSans',
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 26, color: Colors.white, fontFamily: 'GoogleSans',
              ),
              children: [
                const TextSpan(text: 'Olá, ', style: TextStyle(fontWeight: FontWeight.w400)),
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
                    child: const Center(child: Icon(Icons.landscape, color: Colors.white54, size: 60)),
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
                        children: const [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text('MODO AR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('O património\nvive à tua frente.', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 4),
                    Text('Aponta a câmara e descobre.', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
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
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final isSelected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () { setState(() => _selectedCategory = cat); _applyFilter(); },
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
                  cat,
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
              const Text('Perto de ti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              if (!_isLoading)
                Text(
                  '${_nearbyPois.length} resultado${_nearbyPois.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else if (_nearbyPois.isEmpty)
            _buildEmptyState()
          else
            ...List.generate(_nearbyPois.length, (i) => _buildPoiCard(_nearbyPois[i])),
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
            const SizedBox(height: 12),
            Text('Nenhum local encontrado', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Experimenta outro filtro', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPoiCard(POI poi) {
    final catColor = _categoryColor(poi.category);
    final distStr = _formatDistance(poi);
    final String? imagePath = poi.images.isNotEmpty ? poi.images.first : null;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(poi: poi))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80, height: 80,
                child: imagePath == null || imagePath.isEmpty
                    ? Container(color: Colors.grey[200], child: Icon(Icons.landscape, color: Colors.grey[400]))
                    : imagePath.startsWith('http')
                        ? Image.network(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]))
                        : Image.file(File(imagePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200])),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poi.category.toUpperCase(), style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  const SizedBox(height: 3),
                  Text(poi.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(poi.description, style: TextStyle(fontSize: 12.5, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(distStr, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber[600]),
                      const SizedBox(width: 3),
                      Text(poi.rating.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // SECÇÃO "ROTEIROS POPULARES"
  // ---------------------------------------------------------------
  Widget _buildItinerariesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Roteiros populares', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roteiros em breve!'))),
                  child: Text('Ver todos', style: TextStyle(color: kPrimaryGreen, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: _sampleItineraries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => _buildItineraryCard(_sampleItineraries[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard(Map<String, String> it) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roteiros em breve!'))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(it['image']!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2D6A4F))),
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
                  child: Text(it['difficulty']!, style: TextStyle(color: _difficultyColor(it['difficulty']!), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              Positioned(
                left: 12, right: 12, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it['title']!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.white.withOpacity(0.75), size: 12),
                        const SizedBox(width: 4),
                        Text(it['duration']!, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                        const SizedBox(width: 10),
                        Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text(it['distance']!, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
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
}

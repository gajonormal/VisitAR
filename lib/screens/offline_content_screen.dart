import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi.dart';
import '../models/roteiro.dart';
import '../models/filter_options.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'services/download_service.dart';
import 'details_screen.dart';
import 'roteiro_details_screen.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

class OfflineContentScreen extends StatefulWidget {
  const OfflineContentScreen({super.key});

  @override
  State<OfflineContentScreen> createState() => _OfflineContentScreenState();
}

class _OfflineContentScreenState extends State<OfflineContentScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final DownloadService _downloadService = DownloadService();
  
  // Controlador para a barra de pesquisa
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<POI> _offlinePois = [];
  List<Roteiro> _offlineRoteiros = [];
  bool _isLoading = true;
  
  POIFilter _poiFilter = POIFilter();
  RoteiroFilter _roteiroFilter = RoteiroFilter();

  @override
  void initState() {
    super.initState();
    _loadAllOfflineData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. LOAD
  Future<void> _loadAllOfflineData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    
    // Carregar POIs
    List<String> offlinePoiIds = prefs.getStringList('offline_poi_ids') ?? [];
    List<POI> loadedPois = [];
    for (String id in offlinePoiIds) {
      POI? poi = await _downloadService.getOfflinePoi(id);
      if (poi != null) loadedPois.add(poi);
    }
    
    // Carregar Roteiros
    List<String> offlineRoteiroIds = prefs.getStringList('offline_roteiro_ids') ?? [];
    List<Roteiro> loadedRoteiros = [];
    for (String id in offlineRoteiroIds) {
      Roteiro? roteiro = await _downloadService.getOfflineRoteiro(id);
      if (roteiro != null) loadedRoteiros.add(roteiro);
    }

    if (mounted) {
      setState(() {
        _offlinePois = loadedPois;
        _offlineRoteiros = loadedRoteiros;
        _isLoading = false;
      });
    }
  }

  // 2. DELETE POI
  Future<void> _deletePoi(POI poi) async {
    try {
      await _downloadService.deleteFile("poi_${poi.id}.glb");
      for (int i = 0; i < poi.imagens.length; i++) {
        String imgName = "poi_${poi.id}_img_$i.jpg";
        await _downloadService.deleteFile(imgName);
      }
      await _downloadService.removeOfflinePoiData(poi.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nome_${poi.id}');

      setState(() => _offlinePois.removeWhere((p) => p.id == poi.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: kPrimaryGreen, content: Text(AppLocalizations.of(context)!.poiRemoved(poi.nome))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(AppLocalizations.of(context)!.errorRemoving)));
    }
  }

  // 3. DELETE ROTEIRO
  Future<void> _deleteRoteiro(Roteiro roteiro) async {
    try {
      // Usa a nova versão inteligente que apaga o roteiro e os POIs não utilizados
      await _downloadService.deleteRoteiroCompletoSmart(roteiro);

      setState(() => _offlineRoteiros.removeWhere((r) => r.id == roteiro.id));
      
      // Recarrega todos os dados porque alguns POIs podem ter sido apagados
      await _loadAllOfflineData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: kPrimaryGreen, content: Text(AppLocalizations.of(context)!.roteiroRemoved(roteiro.titulo))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(AppLocalizations.of(context)!.errorRemovingRoteiro)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.offlineDownloads, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            labelColor: kPrimaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kPrimaryGreen,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(text: AppLocalizations.of(context)!.locationsPois),
              Tab(text: AppLocalizations.of(context)!.tabItineraries),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPoiList(),
                  _buildRoteirosList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BARRA DE PESQUISA (Estilo HomeMap Atualizado com Filtro) ---
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      // Ajustei o padding da direita para não ficar colado
      padding: const EdgeInsets.only(left: 15, right: 5), 
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(30), 
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey),
          SizedBox(width: 10),
          
          // Campo de Texto
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchDownloads, 
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),

          // Botão Limpar (X) - Só aparece se houver texto
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: kPrimaryGreen, size: 20),
              onPressed: () {
                setState(() {
                  _searchQuery = "";
                  _searchController.clear();
                });
              },
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),

          // --- NOVO: Divisória Vertical ---
          Container(
            width: 1,
            height: 24,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 10), // Espaçamento à volta da linha
          ),

          // --- NOVO: Botão Filtros ---
          IconButton(
            icon: Icon(Icons.tune, color: (_poiFilter.isActive || _roteiroFilter.isActive) ? kPrimaryGreen : Colors.grey),
            splashRadius: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => FilterBottomSheet(
                  initialPoiFilter: _poiFilter,
                  initialRoteiroFilter: _roteiroFilter,
                  showPoiFilters: true,
                  showRoteiroFilters: true,
                  onApply: (poiF, rotF) {
                    setState(() {
                      if (poiF != null) _poiFilter = poiF;
                      if (rotF != null) _roteiroFilter = rotF;
                    });
                  },
                ),
              );
            },
          ),
          
          SizedBox(width: 5), // Pequena margem final
        ],
      ),
    );
  }

  Widget _buildPoiList() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: kPrimaryGreen));
    
    if (_offlinePois.isEmpty && _searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 60, color: Colors.grey[300]),
            SizedBox(height: 15),
            Text(AppLocalizations.of(context)!.noDownloadsOffline, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    final filteredPois = _offlinePois.where((poi) {
      if (!_poiFilter.apply(poi)) return false;
      return poi.nome.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return filteredPois.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
                      SizedBox(height: 10),
                      Text(AppLocalizations.of(context)!.noLocationFoundFor(_searchQuery), 
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  itemCount: filteredPois.length,
                  itemBuilder: (context, index) {
                    final poi = filteredPois[index];
                    return _buildCard(
                      itemName: poi.nome,
                      coverImagePath: poi.imagens.isNotEmpty ? poi.imagens[0] : null,
                      title: poi.nome,
                      subtitle: AppLocalizations.of(context)!.availableOffline,
                      onDelete: () => _deletePoi(poi),
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => DetailsScreen(poi: poi))
                        ).then((_) => _loadAllOfflineData());
                      }
                    );
                  },
                );
  }

  Widget _buildRoteirosList() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: kPrimaryGreen));
    
    if (_offlineRoteiros.isEmpty && _searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 60, color: Colors.grey[300]),
            SizedBox(height: 15),
            Text(AppLocalizations.of(context)!.noRoteirosOffline, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    final filteredRoteiros = _offlineRoteiros.where((roteiro) {
      if (!_roteiroFilter.apply(roteiro)) return false;
      return roteiro.titulo.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredRoteiros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
            SizedBox(height: 10),
            Text(AppLocalizations.of(context)!.noRoteiroFoundFor(_searchQuery), style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      itemCount: filteredRoteiros.length,
      itemBuilder: (context, index) {
        final roteiro = filteredRoteiros[index];
        return _buildCard(
          itemName: roteiro.titulo,
          coverImagePath: roteiro.imagemCapa.isNotEmpty ? roteiro.imagemCapa : null,
          title: roteiro.titulo,
          subtitle: AppLocalizations.of(context)!.offlineStops(roteiro.poiIds.length),
          onDelete: () => _deleteRoteiro(roteiro),
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => RoteiroDetailsScreen(roteiro: roteiro))
            ).then((_) => _loadAllOfflineData());
          }
        );
      },
    );
  }

  Widget _buildCard({
    required String itemName,
    required String? coverImagePath,
    required String title, 
    required String subtitle, 
    required VoidCallback onDelete,
    required VoidCallback onTap,
  }) {
    File? coverFile;
    if (coverImagePath != null && coverImagePath.isNotEmpty) {
      coverFile = File(coverImagePath);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          
          leading: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kPrimaryGreen.withValues(alpha: 0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: coverFile != null && coverFile.existsSync()
                ? Image.file(coverFile, fit: BoxFit.cover)
                : Icon(Icons.place, color: kPrimaryGreen, size: 22),
            ),
          ),

          title: Text(
            title, 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          subtitle: Text(
            subtitle, 
            style: TextStyle(fontSize: 12, color: Colors.grey[600])
          ),

          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(AppLocalizations.of(context)!.deleteDownloadTitle),
                  content: Text(AppLocalizations.of(context)!.deleteDownloadConfirm(itemName)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      child: Text(AppLocalizations.of(context)!.deleteButton, style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
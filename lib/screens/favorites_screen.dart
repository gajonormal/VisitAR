import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../models/roteiro.dart';
import '../widgets/poi_card.dart';
import '../widgets/custom_button.dart';
import '../models/filter_options.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'services/favorites_service.dart';
import 'services/roteiros_service.dart';
import 'details_screen.dart';
import 'roteiro_details_screen.dart';
import 'login_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final FavoritesService _favoritesService = FavoritesService();
  final RoteirosService _roteirosService = RoteirosService();
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isLoading = false;
  
  POIFilter _poiFilter = POIFilter();
  RoteiroFilter _roteiroFilter = RoteiroFilter();

  @override
  void initState() {
    super.initState();
    _cleanupInvalidFavorites();
  }

  Future<void> _cleanupInvalidFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Limpar POIs
      final favPoisSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('favorites').get();
      if (favPoisSnap.docs.isNotEmpty) {
        final allPoisSnap = await FirebaseFirestore.instance.collection('pois').get();
        final validPoiIds = allPoisSnap.docs.map((d) => d.id).toSet();
        for (var doc in favPoisSnap.docs) {
          if (!validPoiIds.contains(doc.id)) await doc.reference.delete();
        }
      }

      // Limpar Roteiros
      final favRotSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('favorite_roteiros').get();
      if (favRotSnap.docs.isNotEmpty) {
        final allRotSnap = await FirebaseFirestore.instance.collection('roteiros').get();
        final validRotIds = allRotSnap.docs.map((d) => d.id).toSet();
        for (var doc in favRotSnap.docs) {
          if (!validRotIds.contains(doc.id)) await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint("Erro ao limpar favoritos inválidos: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 2. DELETE
  Future<void> _removeFavorite(POI poi) async {
    try {
      await _favoritesService.removeFavorite(poi.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: kPrimaryGreen, content: Text("${poi.name} removido dos favoritos.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text("Erro ao remover dos favoritos.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // SE NÃO ESTÁ AUTENTICADO → ecrã de sessão necessária (igual aos Roteiros)
        if (authSnapshot.connectionState != ConnectionState.waiting && user == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("Favoritos", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 56, color: Colors.grey[350]),
                    const SizedBox(height: 16),
                    const Text(
                      'Sessão necessária',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inicia sessão para guardares e veres os teus favoritos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      text: 'Iniciar sessão',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // SE ESTÁ AUTENTICADO → ecrã normal com tabs
        return DefaultTabController(
          length: 2, 
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("Favoritos", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              bottom: TabBar(
                labelColor: kPrimaryGreen,
                unselectedLabelColor: Colors.grey,
                indicatorColor: kPrimaryGreen,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [
                  Tab(text: "Locais (POIs)"),
                  Tab(text: "Roteiros"),
                ],
              ),
            ),
            body: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPoiTab(),
                      _buildRoteirosTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- BARRA DE PESQUISA (Estilo HomeMap/Offline) ---
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(25, 20, 25, 10),
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
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Pesquisar nos favoritos...', 
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
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
          Container(width: 1, height: 24, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 10)),
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
          const SizedBox(width: 5),
        ],
      ),
    );
  }

  Widget _buildPoiTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _favoritesService.getFavoritePoisStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return Center(child: CircularProgressIndicator(color: kPrimaryGreen));
        }
        if (snapshot.hasError) {
           print('ERRO favorites POIs: ${snapshot.error}');
           return Center(
             child: Padding(
               padding: const EdgeInsets.all(20),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                   const SizedBox(height: 12),
                   const Text("Erro ao carregar favoritos.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 6),
                   Text(snapshot.error.toString(), style: const TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
                 ],
               ),
             ),
           );
        }

        final allFavorites = snapshot.data != null ? _favoritesService.mapPoisFromSnapshot(snapshot.data!) : <POI>[];

        if (allFavorites.isEmpty && _searchQuery.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 15),
                Text("Sem favoritos", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        final filteredPois = allFavorites.where((poi) {
          if (!_poiFilter.apply(poi)) return false;
          return poi.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        if (filteredPois.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("Nenhum local encontrado para '$_searchQuery'", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: kPrimaryGreen,
          onRefresh: _cleanupInvalidFavorites,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            itemCount: filteredPois.length,
            itemBuilder: (context, index) {
              final poi = filteredPois[index];
              return Dismissible(
                key: Key('poi_${poi.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  await _favoritesService.removeFavorite(poi.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: kPrimaryGreen,
                      content: Text("${poi.name} removido dos favoritos.")
                    ));
                  }
                },
                child: PoiCard(poi: poi),
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildRoteirosTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _favoritesService.getFavoriteRoteirosStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: kPrimaryGreen));
        }
        if (snapshot.hasError) {
          print('ERRO favorites Roteiros: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  const Text("Erro ao carregar roteiros favoritos.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(snapshot.error.toString(), style: const TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final allFavorites = snapshot.data != null ? _favoritesService.mapRoteirosFromSnapshot(snapshot.data!) : <Roteiro>[];

        if (allFavorites.isEmpty && _searchQuery.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 15),
                Text("Sem roteiros favoritos", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        final filteredRoteiros = allFavorites.where((roteiro) {
          if (!_roteiroFilter.apply(roteiro)) return false;
          return roteiro.titulo.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        if (filteredRoteiros.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("Nenhum roteiro encontrado para '$_searchQuery'", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: kPrimaryGreen,
          onRefresh: _cleanupInvalidFavorites,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            itemCount: filteredRoteiros.length,
            itemBuilder: (context, index) {
              final favoriteRoteiro = filteredRoteiros[index];
              return StreamBuilder<Roteiro?>(
                stream: _roteirosService.getRoteiroStream(favoriteRoteiro.id),
                builder: (context, streamSnapshot) {
                  // Usa a versão atualizada se existir, senão usa a em cache
                  final roteiro = streamSnapshot.data ?? favoriteRoteiro;
                  
                  return _buildCard(
                    itemName: roteiro.titulo,
                    coverImage: roteiro.imagemCapa.isNotEmpty ? roteiro.imagemCapa : null,
                    title: roteiro.titulo,
                    subtitle: "${roteiro.poiIds.length} Paragens • ${roteiro.duracao}",
                    onDelete: () async {
                      await _favoritesService.removeFavoriteRoteiro(roteiro.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: kPrimaryGreen, content: Text("${roteiro.titulo} removido dos favoritos."))
                        );
                      }
                    },
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => RoteiroDetailsScreen(roteiro: roteiro))
                      );
                    }
                  );
                }
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildCard({
    required String itemName,
    required String? coverImage,
    required String title, 
    required String subtitle, 
    required VoidCallback onDelete,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          
          leading: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kPrimaryGreen.withOpacity(0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: coverImage != null && coverImage.isNotEmpty
                ? (coverImage.startsWith('http') 
                    ? Image.network(coverImage, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.place, color: kPrimaryGreen, size: 22))
                    : Image.file(File(coverImage), fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.place, color: kPrimaryGreen, size: 22)))
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
            icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Remover Favorito?"),
                  content: Text("Deseja remover '$itemName' dos favoritos?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      child: const Text("Remover", style: TextStyle(color: Colors.red)),
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

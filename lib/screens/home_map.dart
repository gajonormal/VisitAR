import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../screens/services/database_services.dart'; // <--- CORREÇÃO: Confirma se o nome do ficheiro é singular ou plural

// IMPORTS DOS NOSSOS FICHEIROS
import '../models/poi.dart';
import 'details_screen.dart';
import 'ar_screen.dart';
import 'profile_screen.dart'; // <--- IMPORT NOVO

class HomeMap extends StatefulWidget {
  const HomeMap({super.key});

  @override
  State<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends State<HomeMap> {
  // Posição inicial: Castelo Branco
  final LatLng _initialPosition = const LatLng(39.822180, -7.491095);
  final Set<Marker> _markers = {};
  int _selectedIndex = 0; 

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    List<POI> poisDoFirebase = await DatabaseService().getPOIs();

    if (mounted) {
      setState(() {
        _markers.clear(); 
        for (var poi in poisDoFirebase) {
          _markers.add(
            Marker(
              markerId: MarkerId(poi.id),
              position: poi.location,
              infoWindow: InfoWindow(
                title: poi.name,
                snippet: "Toque para ver detalhes",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DetailsScreen(poi: poi)),
                  );
                },
              ),
            ),
          );
        }
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos IndexedStack para manter o estado do Mapa (não recarregar)
      // quando mudamos para o Perfil e voltamos.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // --- PÁGINA 0: MAPA COMPLETO ---
          Stack(
            children: [
              // 1. O Mapa (Fundo)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _initialPosition,
                  zoom: 15,
                ),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false, 
                zoomControlsEnabled: false,
              ),

              // 2. Barra de Pesquisa (Topo)
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            hintText: 'Pesquisar locais...',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.filter_list),
                    ),
                  ],
                ),
              ),

              // 3. Botão Flutuante "Modo AR"
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ArScreen()),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      "Modo AR", 
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // --- PÁGINA 1: ROTEIROS ---
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions, size: 80, color: Colors.grey),
                Text("Roteiros em breve...", style: TextStyle(fontSize: 20, color: Colors.grey)),
              ],
            ),
          ),

          // --- PÁGINA 2: FAVORITOS ---
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, size: 80, color: Colors.grey),
                Text("Favoritos em breve...", style: TextStyle(fontSize: 20, color: Colors.grey)),
              ],
            ),
          ),

          // --- PÁGINA 3: PERFIL ---
          const ProfileScreen(),
        ],
      ),

      // 4. Barra de Navegação Inferior
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.directions), label: 'Roteiros'),
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: 'Favoritos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
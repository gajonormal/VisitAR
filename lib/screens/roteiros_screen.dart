import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/roteiro.dart';
import 'services/roteiros_service.dart';
import 'roteiro_details_screen.dart';
import 'create_roteiro_screen.dart';
import 'login_screen.dart';

class RoteirosScreen extends StatefulWidget {
  const RoteirosScreen({super.key});

  @override
  State<RoteirosScreen> createState() => _RoteirosScreenState();
}

class _RoteirosScreenState extends State<RoteirosScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final Color kBgColor = Colors.white; // Fundo branco padrão da app

  final RoteirosService _roteirosService = RoteirosService();

  int _selectedFilter = 0; // 0: Sugeridos, 1: Meus, 2: Concluídos
  late Stream<List<Roteiro>> _roteirosStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    if (_selectedFilter == 0) {
      _roteirosStream = _roteirosService.getSuggestedRoteiros();
    } else if (_selectedFilter == 1) {
      _roteirosStream = _roteirosService.getUserRoteiros();
    } else {
      _roteirosStream = _roteirosService.getCompletedRoteiros();
    }
  }

  void _showLoginRequiredDialog(String acao) {
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
                color: kPrimaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline_rounded, color: kPrimaryGreen, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sessão necessária',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Para $acao, precisas de ter uma conta e iniciar sessão.',
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
                    backgroundColor: kPrimaryGreen,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Roteiros",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (FirebaseAuth.instance.currentUser == null) {
                        _showLoginRequiredDialog('criar um roteiro');
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoteiroScreen()));
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kPrimaryGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // CHIPS DE FILTRO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildFilterChip("Sugeridos", 0),
                  const SizedBox(width: 10),
                  _buildFilterChip("Meus", 1),
                  const SizedBox(width: 10),
                  _buildFilterChip("Concluídos", 2),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // LISTA DE CARTÕES
            Expanded(
              child: StreamBuilder<List<Roteiro>>(
                stream: _roteirosStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: kPrimaryGreen));
                  }
                  
                  final roteiros = snapshot.data ?? [];
                  
                  if (roteiros.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    itemCount: roteiros.length,
                    itemBuilder: (context, index) {
                      return _buildRoteiroCard(roteiros[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    IconData icon;
    String title;
    String subtitle;

    if (_selectedFilter == 1) {
      if (!isLoggedIn) {
        icon = Icons.lock_outline_rounded;
        title = 'Sessão necessária';
        subtitle = 'Inicia sessão para criares e veres os teus roteiros.';
      } else {
        icon = Icons.route_outlined;
        title = 'Ainda sem roteiros';
        subtitle = 'Clica no botão + para criar o teu primeiro roteiro.';
      }
    } else if (_selectedFilter == 2) {
      if (!isLoggedIn) {
        icon = Icons.lock_outline_rounded;
        title = 'Sessão necessária';
        subtitle = 'Inicia sessão para veres os roteiros que já concluíste.';
      } else {
        icon = Icons.check_circle_outline_rounded;
        title = 'Nenhum roteiro concluído';
        subtitle = 'Quando completares um roteiro, aparece aqui.';
      }
    } else {
      icon = Icons.explore_outlined;
      title = 'Nenhum roteiro disponível';
      subtitle = 'De momento não há roteiros sugeridos.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (!isLoggedIn && _selectedFilter != 0) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                child: const Text('Iniciar sessão'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    bool isActive = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = index;
          _updateStream();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryGreen : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildRoteiroCard(Roteiro roteiro) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => RoteiroDetailsScreen(roteiro: roteiro)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            // IMAGEM COM BADGE E TÍTULO
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: roteiro.imagemCapa.isNotEmpty
                        ? (roteiro.imagemCapa.startsWith('http')
                            ? Image.network(
                                roteiro.imagemCapa, 
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40))),
                              )
                            : Image.file(
                                File(roteiro.imagemCapa), 
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40))),
                              ))
                        : Container(color: Colors.grey[200]),
                  ),
                ),
                // Gradiente escuro em baixo para o título ser legível
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // BADGE DIFICULDADE
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      roteiro.dificuldade.toUpperCase(),
                      style: TextStyle(
                        color: kPrimaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                // TÍTULO
                Positioned(
                  bottom: 15,
                  left: 15,
                  right: 15,
                  child: Text(
                    roteiro.titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // RODAPÉ (Duração, Distância, Rating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    roteiro.duracao,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  
                  const SizedBox(width: 15),
                  
                  Icon(Icons.route_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    "${roteiro.distancia.toStringAsFixed(1)} km",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  
                  const Spacer(),
                  
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    roteiro.avaliacao.toStringAsFixed(1),
                    style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

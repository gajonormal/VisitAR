import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/roteiro.dart';
import '../../models/poi.dart';
import 'services/database_services.dart';
import 'services/favorites_service.dart';
import 'services/download_service.dart';
import 'services/roteiro_state.dart';
import 'details_screen.dart';

class RoteiroDetailsScreen extends StatefulWidget {
  final Roteiro roteiro;
  
  const RoteiroDetailsScreen({super.key, required this.roteiro});

  @override
  State<RoteiroDetailsScreen> createState() => _RoteiroDetailsScreenState();
}

class _RoteiroDetailsScreenState extends State<RoteiroDetailsScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final DatabaseService _dbService = DatabaseService();
  final FavoritesService _favoritesService = FavoritesService();
  final DownloadService _downloadService = DownloadService();
  
  bool _isLoadingPois = true;
  List<POI> _poisDoRoteiro = [];
  
  bool _isFavorite = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadPois();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    bool fav = await _favoritesService.isFavoriteRoteiro(widget.roteiro.id);
    Roteiro? offline = await _downloadService.getOfflineRoteiro(widget.roteiro.id);
    if (mounted) {
      setState(() {
        _isFavorite = fav;
        _isDownloaded = offline != null;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        await _favoritesService.removeFavoriteRoteiro(widget.roteiro.id);
      } else {
        await _favoritesService.addFavoriteRoteiro(widget.roteiro);
      }
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isFavorite ? "Adicionado aos favoritos" : "Removido dos favoritos"),
          backgroundColor: kPrimaryGreen,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao atualizar favorito")));
    }
  }

  Future<void> _handleDownload() async {
    if (_isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Roteiro já está disponível offline.")));
      return;
    }
    setState(() => _isDownloading = true);
    
    bool success = await _downloadService.downloadRoteiroCompleto(widget.roteiro, _poisDoRoteiro);
    
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? "Download concluído com sucesso!" : "Erro ao transferir roteiro."),
        backgroundColor: success ? kPrimaryGreen : Colors.red,
      ));
    }
  }

  Future<void> _loadPois() async {
    List<POI> pois = await _dbService.getPOIsByIds(widget.roteiro.poiIds);
    if (mounted) {
      setState(() {
        _poisDoRoteiro = pois;
        _isLoadingPois = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.roteiro.titulo,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          _buildCircleButton(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.grey[600]!,
            onTap: _toggleFavorite,
          ),
          const SizedBox(width: 8),
          _isDownloading
              ? const SizedBox(
                  width: 35, 
                  height: 35, 
                  child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))
                )
              : _buildCircleButton(
                  _isDownloaded ? Icons.check : Icons.download_for_offline_outlined,
                  color: _isDownloaded ? kPrimaryGreen : Colors.grey[600]!,
                  onTap: _handleDownload,
                ),
          const SizedBox(width: 15),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categoria
            Text(
              "Categoria",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            
            // IMAGEM DE CAPA
            _buildCoverImage(),
            const SizedBox(height: 15),

            // ESTATÍSTICAS EM CHIPS VERDES (ESTILO FILTROS)
            Row(
              children: [
                Expanded(child: _buildStatChip("POIs - ${widget.roteiro.poiIds.length}")),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: _buildStatChip("Duração - ${widget.roteiro.duracao}")),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: _buildStatChip("Distância - ${widget.roteiro.distancia.toStringAsFixed(1)}km")),
              ],
            ),
            
            const SizedBox(height: 25),
            
            // DESCRIÇÃO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Descrição", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Text(
                    widget.roteiro.descricao.isEmpty ? "Sem descrição." : widget.roteiro.descricao,
                    style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // PONTOS DE INTERESSE ADICIONADOS (ESTILO FIGMA)
            _buildGreenSection(
              title: "Pontos de interesse adicionados",
              child: Column(
                children: [
                  // Lista
                  _isLoadingPois 
                      ? Padding(padding: const EdgeInsets.all(20.0), child: CircularProgressIndicator(color: kPrimaryGreen))
                      : _buildPoiTimeline(),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // AVALIAÇÕES
            const Text("Avaliações", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roteiro.avaliacao.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 24)),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 35,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("Avaliar", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 120,
                        height: 35,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("Avaliações", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // BOTÕES INFERIORES
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        activeRoteiroNotifier.value = widget.roteiro;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text("Iniciar Roteiro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edição de roteiros em breve.")));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text("Editar Roteiro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, {required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(6), 
        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22), 
      ),
    );
  }

  Widget _buildStatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: kPrimaryGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: widget.roteiro.imagemCapa.isNotEmpty
            ? (widget.roteiro.imagemCapa.startsWith('http')
                ? Image.network(widget.roteiro.imagemCapa, fit: BoxFit.cover)
                : Image.file(File(widget.roteiro.imagemCapa), fit: BoxFit.cover))
            : Container(
                color: Colors.grey[300], 
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 50)
              ),
      ),
    );
  }

  Widget _buildGreenSection({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      clipBehavior: Clip.antiAlias, // Ensures the grey banner doesn't spill over bottom corners
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Verde
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: kPrimaryGreen,
            ),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }

  Widget _buildPoiTimeline() {
    if (_poisDoRoteiro.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("Não foi possível carregar as paragens."),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      itemCount: _poisDoRoteiro.length,
      itemBuilder: (context, index) {
        final poi = _poisDoRoteiro[index];
        final isLast = index == _poisDoRoteiro.length - 1;
        String? img = poi.images.isNotEmpty ? poi.images.first : null;
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // COLUNA DA LINHA E ÍCONE
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: kPrimaryGreen, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(color: kPrimaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: kPrimaryGreen.withOpacity(0.3),
                        ),
                      ),
                  ],
                ),
              ),
              
              // COLUNA DO CONTEÚDO DO POI
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, left: 10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(poi: poi)));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 45, height: 45,
                            child: img != null 
                              ? (img.startsWith('http') ? Image.network(img, fit: BoxFit.cover) : Image.file(File(img), fit: BoxFit.cover))
                              : Container(color: Colors.grey[200]),
                          ),
                        ),
                        title: Text(poi.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(poi.category, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

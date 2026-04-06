import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi.dart';
import '../screens/services/download_service.dart';
import 'model_viewer_screen.dart'; 

class DetailsScreen extends StatefulWidget {
  final POI poi;

  const DetailsScreen({super.key, required this.poi});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 220.0;
  int _currentImageIndex = 0; 

  // --- NOVO: Variável para guardar o POI que está a ser mostrado ---
  // Começa com o do widget, mas pode ser substituído pelo offline
  late POI _displayPoi; 
  // ---------------------------------------------------------------

  bool isFavorite = false;
  bool isInItinerary = false;
  
  bool isDownloaded = false;
  bool isLoadingDownload = false;
  bool _hasInternet = true; 

  @override
  void initState() {
    super.initState();
    // Inicializa com os dados que vêm da lista anterior
    _displayPoi = widget.poi;

    _checkInternet();
    _checkDownloadStatus(); // <--- Isto agora vai carregar os dados offline se existirem
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureHeaderHeight();
    });
  }

  // --- NOVO: Função para Carregar Dados Offline ---
  Future<void> _checkDownloadStatus() async {
    final downloadService = DownloadService();
    String fileName = "poi_${widget.poi.id}.glb";
    
    // 1. Verifica se o ficheiro 3D ou registo existe
    bool exists = await downloadService.checkFileExists(fileName);
    
    // Tenta carregar o JSON completo do POI
    POI? offlinePoi = await downloadService.getOfflinePoi(widget.poi.id);

    if (exists || offlinePoi != null) {
      if (mounted) {
        setState(() {
          isDownloaded = true;
          // SE tivermos dados offline guardados (com caminhos locais), usamos esses!
          if (offlinePoi != null) {
            _displayPoi = offlinePoi;
          }
        });
      }
    }
  }
  // ------------------------------------------------

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (mounted) setState(() => _hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } on SocketException catch (_) {
      if (mounted) setState(() => _hasInternet = false);
    }
  }

  void _measureHeaderHeight() {
    final RenderBox? renderBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() => _headerHeight = renderBox.size.height + 20);
    }
  }

  // --- LÓGICA DE DOWNLOAD E APAGAR ATUALIZADA ---
  Future<void> _handleDownload() async {
    final downloadService = DownloadService();

    // MODO APAGAR
    if (isDownloaded) {
      setState(() => isLoadingDownload = true);
      
      // Apagar Modelo 3D
      await downloadService.deleteFile("poi_${widget.poi.id}.glb");
      
      // Apagar Imagens (baseado no índice)
      for (int i = 0; i < widget.poi.images.length; i++) {
        await downloadService.deleteFile("poi_${widget.poi.id}_img_$i.jpg");
      }
      
      // Apagar Dados JSON
      await downloadService.removeOfflinePoiData(widget.poi.id);
      await _removePoiNameLocally();

      if (mounted) {
        setState(() {
          isDownloaded = false;
          isLoadingDownload = false;
          _displayPoi = widget.poi; // Volta a usar os dados originais (online)
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conteúdo removido.")));
      }
      return;
    }

    // MODO BAIXAR
    if (widget.poi.arModelUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conteúdo indisponível.")));
      return;
    }
    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sem conexão para baixar.")));
      return;
    }

    setState(() => isLoadingDownload = true);
    
    try {
      // 1. Baixar Modelo 3D
      String modelFileName = "poi_${widget.poi.id}.glb";
      String? localModelPath = await downloadService.downloadFile(widget.poi.arModelUrl, modelFileName);

      // 2. Baixar Imagens
      List<String> localImagePaths = [];
      for (int i = 0; i < widget.poi.images.length; i++) {
        String imgUrl = widget.poi.images[i];
        String imgName = "poi_${widget.poi.id}_img_$i.jpg";
        String? localPath = await downloadService.downloadFile(imgUrl, imgName);
        if (localPath != null) localImagePaths.add(localPath);
      }

      // 3. Criar Objeto Offline (com caminhos locais)
      POI offlinePoi = POI(
        id: widget.poi.id,
        name: widget.poi.name,
        category: widget.poi.category,
        location: widget.poi.location,
        images: localImagePaths, // <--- Lista de caminhos no telemóvel
        audioUrl: widget.poi.audioUrl,
        rating: widget.poi.rating,
        descriptionMap: widget.poi.descriptionMap,
        arModelUrl: localModelPath ?? '', // <--- Caminho no telemóvel
        arScale: widget.poi.arScale,
      );

      // 4. Guardar JSON
      await downloadService.saveOfflinePoiData(offlinePoi);
      await _savePoiNameLocally();

      if (mounted) {
        setState(() {
          isLoadingDownload = false;
          isDownloaded = true;
          _displayPoi = offlinePoi; // <--- Atualiza a UI para usar os ficheiros locais IMEDIATAMENTE
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: kPrimaryGreen, content: const Text("Guardado offline"))
        );
      }
    } catch (e) {
      setState(() => isLoadingDownload = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Erro ao baixar.")));
    }
  }

  Future<void> _savePoiNameLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome_${widget.poi.id}', widget.poi.name);
  }
  
  Future<void> _removePoiNameLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nome_${widget.poi.id}');
  }

  void _open3DViewer() {
    String sourcePath;
    
    // Verifica se é caminho local (não começa por http) ou online
    bool isLocalFile = !_displayPoi.arModelUrl.startsWith('http');

    if (isDownloaded && isLocalFile) {
      sourcePath = _displayPoi.arModelUrl;
    } else if (_hasInternet && _displayPoi.arModelUrl.isNotEmpty) {
      sourcePath = _displayPoi.arModelUrl; 
    } else {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModelViewerScreen(
          filePath: sourcePath,
          title: _displayPoi.name,
        ),
      ),
    );
  }

  void _openFullDescriptionPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FullDescriptionSheet(poi: _displayPoi), // Usa _displayPoi
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeaderHeight());

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(top: _headerHeight), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // CARROSSEL (Usa _displayPoi)
                _buildFullWidthCarousel(),

                const SizedBox(height: 25),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Sobre este local", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
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
                            Text(
                              _displayPoi.getDescription('pt').isEmpty ? "Sem descrição." : _displayPoi.getDescription('pt'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 15),
                            Center(
                              child: InkWell(
                                onTap: _openFullDescriptionPage,
                                child: Text("Ler mais", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),
                      _build3DButton(),
                      const SizedBox(height: 25),
                      _buildReviewSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CABEÇALHO
          Positioned(
            top: 0, left: 0, right: 0,
            child: Material(
              key: _headerKey, 
              elevation: 15,
              shadowColor: Colors.black.withOpacity(0.4),
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              clipBehavior: Clip.antiAlias, 
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildHeaderContent(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
Widget _buildHeaderContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. NOME
              Text(
                _displayPoi.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.1),
              ),
              
              const SizedBox(height: 5),

              // 2. CATEGORIA (NOVO)
              Text(
                _displayPoi.category, 
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey[700], 
                  fontWeight: FontWeight.w500
                ),
              ),

              const SizedBox(height: 8),

              // 3. LOCALIZAÇÃO
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: kPrimaryGreen),
                  const SizedBox(width: 4),
                  Text("Aprox. 20m", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        
        // BOTÕES DO LADO DIREITO
        Row(
          children: [
            _buildCircleButton(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.grey,
              onTap: () => setState(() => isFavorite = !isFavorite),
            ),
            const SizedBox(width: 8),
            _buildCircleButton(
              icon: isInItinerary ? Icons.playlist_add_check : Icons.playlist_add,
              color: isInItinerary ? kPrimaryGreen : Colors.grey,
              onTap: () => setState(() => isInItinerary = !isInItinerary),
            ),
            const SizedBox(width: 8),
if (isLoadingDownload)
              SizedBox( // Removi o 'const' aqui
                width: 35, 
                height: 35, 
                child: Padding(
                  padding: const EdgeInsets.all(8.0), 
                  child: CircularProgressIndicator(
                    strokeWidth: 2, 
                    color: kPrimaryGreen, // <--- Define a cor verde aqui
                  )
                )
              )
            else
              _buildCircleButton(
                icon: isDownloaded ? Icons.check : Icons.download_for_offline_outlined,
                color: isDownloaded ? kPrimaryGreen : Colors.grey,
                onTap: _handleDownload,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, required Color color, required VoidCallback onTap}) {
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

  // --- CARROSSEL HÍBRIDO (LOCAL / NETWORK) ---
  Widget _buildFullWidthCarousel() {
    // Usa as imagens do _displayPoi (que podem ser locais ou online)
    final images = _displayPoi.images;
    
    if (images.isEmpty) {
      return Container(
        height: 250, color: Colors.grey[200],
        child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.95),
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index), 
            itemBuilder: (context, index) {
              String imgPath = images[index];
              // Verifica se é link online ou caminho local
              bool isNetwork = imgPath.startsWith('http');

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4), 
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: isNetwork 
                    // SE FOR ONLINE
                    ? Image.network(
                        imgPath, fit: BoxFit.cover,
                        loadingBuilder: (context, child, p) => p == null ? child : Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                      )
                    // SE FOR LOCAL (OFFLINE)
                    : Image.file(
                        File(imgPath), fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: _currentImageIndex == index ? 20 : 6, 
              decoration: BoxDecoration(
                color: _currentImageIndex == index ? kPrimaryGreen : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _build3DButton() {
    bool hasModelUrl = _displayPoi.arModelUrl.isNotEmpty;
    bool isButtonEnabled = hasModelUrl && (isDownloaded || _hasInternet);

    String buttonText;
    if (!hasModelUrl) {
      buttonText = "Sem modelo 3D";
    } else if (isButtonEnabled) {
      buttonText = "Visualizar Modelo 3D";
    } else {
      buttonText = "Sem modelo 3D";
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _open3DViewer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          disabledForegroundColor: Colors.grey, disabledBackgroundColor: Colors.grey[100], 
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_in_ar, color: isButtonEnabled ? kPrimaryGreen : Colors.grey),
            const SizedBox(width: 10),
            Text(buttonText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isButtonEnabled ? kPrimaryGreen : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${_displayPoi.rating}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Row(children: List.generate(5, (index) => Icon(index < _displayPoi.rating.round() ? Icons.star : Icons.star_border, color: Colors.amber, size: 20))),
            ],
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Avaliar"),
          ),
        ],
      ),
    );
  }
  
}
// --- COLA ISTO NO FINAL DO FICHEIRO, FORA DA CLASSE DETAILSSCREEN ---

class _FullDescriptionSheet extends StatefulWidget {
  final POI poi;
  const _FullDescriptionSheet({required this.poi});

  @override
  State<_FullDescriptionSheet> createState() => _FullDescriptionSheetState();
}

class _FullDescriptionSheetState extends State<_FullDescriptionSheet> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  bool isPlaying = false;
  double _sliderValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85, 
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Pega (Handle)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 15, bottom: 5),
              width: 50, height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Botão Fechar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          
          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player de Áudio
                  if (widget.poi.audioUrl.isNotEmpty || true) 
                    Container(
                      margin: const EdgeInsets.only(bottom: 25),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                                child: const Icon(Icons.volume_up_rounded, size: 20),
                              ),
                              const SizedBox(width: 15),
                              const Text("Ouvir áudio guia", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() => isPlaying = !isPlaying),
                                child: Icon(
                                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  size: 44,
                                  color: kPrimaryGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: kPrimaryGreen,
                              inactiveTrackColor: Colors.grey[300],
                              thumbColor: kPrimaryGreen,
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: _sliderValue,
                              onChanged: (v) => setState(() => _sliderValue = v),
                            ),
                          ),
                        ],
                      ),
                    ),
// --- ADICIONADO AQUI: Título Descrição ---
                  const Text(
                    "Descrição",
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black87
                    ),
                  ),
                  
                  const SizedBox(height: 10), // Espaçamento entre o título e o texto
                  // Texto da Descrição
                  Text(
                    widget.poi.getDescription('pt'),
                    style: const TextStyle(fontSize: 16, height: 1.7, color: Colors.black87),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/poi.dart';
import '../models/panorama.dart';
import 'services/database_services.dart';
import '../screens/services/download_service.dart';
import '../screens/services/favorites_service.dart';
import '../screens/services/passport_service.dart';
import '../../models/badge_model.dart';
import 'login_screen.dart';
import 'panorama_screen.dart';
import '../models/roteiro.dart';
import '../screens/services/roteiro_state.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

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

  // POI que está a ser mostrado — começa com os dados online mas pode ser substituído pela versão offline
  late POI _displayPoi;

  bool isFavorite = false;
  bool isInItinerary = false;
  
  bool isDownloaded = false;
  bool isLoadingDownload = false;
  bool _hasInternet = true; 

  // --- DISTÂNCIA ---
  Position? _userPosition;
  bool _isLoadingLocation = true;
  
  // --- FAVORITOS ---
  final FavoritesService _favoritesService = FavoritesService();
  final PassportService _passportService = PassportService();
  bool _isLoadingFavorite = false;

  // --- PASSAPORTE ---
  bool _isVisited = false;
  bool _isRegisteringVisit = false;
  double? _distanceToPoi;

  // --- PANORAMA ---
  Panorama? _panorama;

  @override
  void initState() {
    super.initState();
    _displayPoi = widget.poi;

    _checkInternet();
    _checkDownloadStatus(); 
    _getUserLocation();
    _checkFavoriteStatus();
    _checkItineraryStatus();
    _checkVisitStatus();
    _checkPanorama();

    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureHeaderHeight();
    });
  }

  Future<void> _checkVisitStatus() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final visited = await _passportService.hasVisited(widget.poi.id);
    if (mounted) setState(() => _isVisited = visited);
  }

  Future<void> _checkPanorama() async {
    try {
      Panorama? pano = await DownloadService().getOfflinePanorama(widget.poi.id);
      
      if (pano == null) {
        pano = await DatabaseService().getPanoramaForPoi(widget.poi.id);
      }
      
      if (mounted && pano != null) {
        setState(() => _panorama = pano);
      }
    } catch (e) {
      // Ignora erros de permissão do Firestore quando o utilizador não está autenticado
      final errStr = e.toString().toLowerCase();
      if (!errStr.contains('permission') && !errStr.contains('denied')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro 360: $e")));
        }
      }
    }
  }

  Future<void> _registerVisit() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog(AppLocalizations.of(context)!.actionRegisterVisit);
      return;
    }
    setState(() => _isRegisteringVisit = true);
    try {
      final distance = await _passportService.getDistanceToPoi(widget.poi);
      if (distance == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.locationError), backgroundColor: Colors.orange),
        );
        return;
      }
      setState(() => _distanceToPoi = distance);
      if (distance > PassportService.kVisitRadiusMeters) {
        final dist = distance < 1000
            ? '${distance.toStringAsFixed(0)} m'
            : '${(distance / 1000).toStringAsFixed(1)} km';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estás a $dist deste local. Aproxima-te para registar a visita.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Utilizador suficientemente perto — regista a visita
      final newBadges = await _passportService.registerVisit(widget.poi);
      if (mounted) {
        setState(() => _isVisited = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.visitRegistered),
            backgroundColor: kPrimaryGreen,
          ),
        );
        
        List<BadgeModel> allNewBadges = List.from(newBadges);

        // Verifica se o roteiro ativo fica concluído com esta visita
        if (activeRoteiroNotifier.value != null) {
          final roteiro = activeRoteiroNotifier.value!;
          if (roteiro.poiIds.contains(widget.poi.id)) {
            final progress = await _passportService.getRoteiroProgress(roteiro);
            if (progress.isCompleted) {
              final roteiroBadges = await _passportService.registerRoteiroCompletion(roteiro.id);
              allNewBadges.addAll(roteiroBadges);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Parabéns! Concluíste o roteiro "${roteiro.titulo}"!'),
                    backgroundColor: kPrimaryGreen,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              // Fecha o roteiro automaticamente ao concluir todos os POIs
              activeRoteiroNotifier.value = null; 
            }
          }
        }

        if (allNewBadges.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) _showBadgeUnlockedDialog(allNewBadges);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.registerVisitError), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isRegisteringVisit = false);
    }
  }

  void _showBadgeUnlockedDialog(List<BadgeModel> badges) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.military_tech_outlined, color: kPrimaryGreen, size: 54),
            SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.achievementUnlocked, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: badges.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Text(b.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                SizedBox(height: 4),
                Text(b.descricao, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )).toList(),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: kPrimaryGreen),
              child: Text(AppLocalizations.of(context)!.fantastic, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- ITINERÁRIO (cart de roteiro temporário) ---
  Future<void> _checkItineraryStatus() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cartIds = prefs.getStringList('roteiro_cart_poi_ids') ?? [];
    if (mounted) {
      setState(() {
        isInItinerary = cartIds.contains(widget.poi.id);
      });
    }
  }

  Future<void> _toggleItinerary() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cartIds = prefs.getStringList('roteiro_cart_poi_ids') ?? [];
    
    setState(() => isInItinerary = !isInItinerary);

    if (isInItinerary) {
      if (!cartIds.contains(widget.poi.id)) cartIds.add(widget.poi.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.addedToItinerary), duration: Duration(seconds: 2)));
    } else {
      cartIds.remove(widget.poi.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.removedFromItinerary), duration: Duration(seconds: 2)));
    }
    
    await prefs.setStringList('roteiro_cart_poi_ids', cartIds);
  }

  /// Verifica se o POI tem dados descarregados e carrega a versão offline, se disponível.
  Future<void> _checkDownloadStatus() async {
    final downloadService = DownloadService();
    String fileName = "poi_${widget.poi.id}.glb";

    // Verifica se existe ficheiro 3D ou registo offline
    bool exists = await downloadService.checkFileExists(fileName);
    POI? offlinePoi = await downloadService.getOfflinePoi(widget.poi.id);

    if (exists || offlinePoi != null) {
      if (mounted) {
        setState(() {
          isDownloaded = true;
          // Se houver dados offline com caminhos locais, usa-os diretamente
          if (offlinePoi != null) {
            _displayPoi = offlinePoi;
          }
        });
      }
    }
  }

  // --- LOCALIZAÇÃO E DISTÂNCIA ---
  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }
      Position pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        setState(() {
          _userPosition = pos;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  String _formatDistance() {
    if (_isLoadingLocation) return AppLocalizations.of(context)!.calculating;
    if (_userPosition == null) return '— km';
    double dist = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude,
        _displayPoi.localizacao.latitude, _displayPoi.localizacao.longitude);
    if (dist < 1000) return '${dist.toStringAsFixed(0)} m';
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  // --- FAVORITOS ---
  Future<void> _checkFavoriteStatus() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    bool isFav = await _favoritesService.isFavorite(widget.poi.id);
    if (mounted) {
      setState(() {
        isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog(AppLocalizations.of(context)!.actionSaveFavorites);
      return;
    }

    setState(() => _isLoadingFavorite = true);
    try {
      if (isFavorite) {
        await _favoritesService.removeFavorite(widget.poi.id);
        if (mounted) setState(() => isFavorite = false);
      } else {
        await _favoritesService.addFavorite(_displayPoi);
        if (mounted) setState(() => isFavorite = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingFavorites), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  void _showLoginRequiredDialog(String acao) {
    final Color kPrimaryGreen = const Color(0xFF0F9D58);
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
                color: kPrimaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline_rounded, color: kPrimaryGreen, size: 32),
            ),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.loginRequiredTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Para $acao, precisas de ter uma conta e iniciar sessão.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLocalizations.of(context)!.notNow)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLocalizations.of(context)!.login)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  /// Gera o download de todos os recursos do POI ou apaga-os, conforme o estado atual.
  Future<void> _handleDownload() async {
    final downloadService = DownloadService();

    // Modo apagar: remove todos os ficheiros e dados offline
    if (isDownloaded) {
      setState(() => isLoadingDownload = true);
      
      // Remove o modelo 3D
      await downloadService.deleteFile("poi_${widget.poi.id}.glb");
      
      // Remove o panorama 360° e a sua chave nas preferências
      await downloadService.deleteFile("poi_${widget.poi.id}_panorama.jpg");
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_panorama_${widget.poi.id}');

      // Remove as imagens descarregadas (por índice)
      for (int i = 0; i < widget.poi.imagens.length; i++) {
        await downloadService.deleteFile("poi_${widget.poi.id}_img_$i.jpg");
      }
      
      // Remove os dados JSON e o nome guardado localmente
      await downloadService.removeOfflinePoiData(widget.poi.id);
      await _removePoiNameLocally();

      if (mounted) {
          setState(() {
            isDownloaded = false;
            isLoadingDownload = false;
            _displayPoi = widget.poi; // Volta aos dados online após apagar o offline
          });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.contentRemoved)));
      }
      return;
    }

    // Modo descarregar: requer conexão à internet
    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.noConnectionToDownload)));
      return;
    }

    setState(() => isLoadingDownload = true);
    
    try {

      // Descarrega as imagens e guarda os caminhos locais
      List<String> localImagePaths = [];
      for (int i = 0; i < widget.poi.imagens.length; i++) {
        String imgUrl = widget.poi.imagens[i];
        String imgName = "poi_${widget.poi.id}_img_$i.jpg";
        String? localPath = await downloadService.downloadFile(imgUrl, imgName);
        if (localPath != null) localImagePaths.add(localPath);
      }

      // Descarrega os áudios para cada língua disponível
      Map<String, dynamic> localAudioMap = {};
      for (String lang in widget.poi.mapaAudio.keys) {
        String aUrl = widget.poi.mapaAudio[lang];
        if (aUrl.isNotEmpty && aUrl.startsWith('http')) {
          String audioName = "poi_${widget.poi.id}_audio_$lang.mp3";
          String? localAudioPath = await downloadService.downloadFile(aUrl, audioName);
          if (localAudioPath != null) {
            localAudioMap[lang] = localAudioPath;
          } else {
            localAudioMap[lang] = aUrl; // fallback
          }
        } else {
          localAudioMap[lang] = aUrl;
        }
      }

      // Descarrega o panorama 360°, se existir
      var panorama = await DatabaseService().getPanoramaForPoi(widget.poi.id);
      if (panorama != null && panorama.urlImagem.isNotEmpty) {
        String panoName = "poi_${widget.poi.id}_panorama.jpg";
        String? localPanoPath = await downloadService.downloadFile(panorama.urlImagem, panoName);
        if (localPanoPath != null) {
          Panorama offlinePano = Panorama(
            id: panorama.id,
            urlImagem: localPanoPath,
            marcadores: panorama.marcadores,
          );
          await downloadService.saveOfflinePanorama(offlinePano);
        }
      }

      // Cria o objeto POI com os caminhos locais para usar offline
      POI offlinePoi = POI(
        id: widget.poi.id,
        nome: widget.poi.nome,
        categoria: widget.poi.categoria,
        localizacao: widget.poi.localizacao,
        imagens: localImagePaths, // Caminhos das imagens no dispositivo
        mapaDescricao: widget.poi.mapaDescricao,
        mapaAudio: localAudioMap,
      );

      // Persiste os dados JSON e o nome do POI localmente
      await downloadService.saveOfflinePoiData(offlinePoi, isStandalone: true);
      await _savePoiNameLocally();

      if (mounted) {
          setState(() {
            isLoadingDownload = false;
            isDownloaded = true;
            _displayPoi = offlinePoi; // Atualiza imediatamente a UI para usar os ficheiros locais
          });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: kPrimaryGreen, content: Text(AppLocalizations.of(context)!.savedOffline))
        );
      }
    } catch (e) {
      setState(() => isLoadingDownload = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(AppLocalizations.of(context)!.errorDownloading)));
    }
  }

  Future<void> _savePoiNameLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome_${widget.poi.id}', widget.poi.nome);
  }
  
  Future<void> _removePoiNameLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nome_${widget.poi.id}');
  }
  /// Abre a folha modal com a descrição completa e o player de áudio.
  void _openFullDescriptionPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FullDescriptionSheet(poi: _displayPoi),
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
                
                // Carrossel de imagens do POI (usa _displayPoi para suportar offline)
                _buildFullWidthCarousel(),

                if (_panorama != null) ...[
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PanoramaScreen(
                                panorama: _panorama!,
                                initialPoiId: widget.poi.id,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.threesixty, color: kPrimaryGreen),
                            SizedBox(width: 10),
                            Text(AppLocalizations.of(context)!.explore360, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryGreen)),
                          ],
                        ),
                      ),
                    ),
                  )
                ],

                SizedBox(height: 25),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.aboutThisPlace, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      
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
                              () {
                                final lang = Localizations.localeOf(context).languageCode;
                                final desc = _displayPoi.getDescription(lang);
                                return desc.isEmpty ? AppLocalizations.of(context)!.noDescription : desc;
                              }(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
                            ),
                            SizedBox(height: 15),
                            Center(
                              child: InkWell(
                                onTap: _openFullDescriptionPage,
                                child: Text(AppLocalizations.of(context)!.readMore, style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 25),
                      _buildNavigationButton(),
                      SizedBox(height: 15),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cabeçalho fixo no topo com o nome, categoria, distância e botões de ação
          Positioned(
            top: 0, left: 0, right: 0,
            child: Material(
              key: _headerKey, 
              elevation: 15,
              shadowColor: Colors.black.withValues(alpha: 0.4),
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
                          icon: Icon(Icons.arrow_back, color: Colors.black, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      SizedBox(height: 15),
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
              // Nome do POI
              Text(
                _displayPoi.nome,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.1),
              ),
              
              SizedBox(height: 5),

              // Categoria do POI
              Text(
                _displayPoi.categoria, 
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey[700], 
                  fontWeight: FontWeight.w500
                ),
              ),

              SizedBox(height: 8),

              // Distância ao utilizador
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: kPrimaryGreen),
                  SizedBox(width: 4),
                  Text(_formatDistance(), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        
        // Botões de ação do lado direito (favorito, passaporte, download)
        Row(
          children: [
            _isLoadingFavorite
                ? SizedBox(width: 35, height: 35, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                : _buildCircleButton(
                    icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                    onTap: _toggleFavorite,
                  ),
            SizedBox(width: 8),
            // Botão de registo no passaporte
            _isRegisteringVisit
                ? SizedBox(width: 35, height: 35, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                : _buildCircleButton(
                    icon: _isVisited ? Icons.verified : Icons.approval,
                    color: _isVisited ? kPrimaryGreen : Colors.grey,
                    onTap: _isVisited ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.alreadyVisited), backgroundColor: Colors.green),
                      );
                    } : _registerVisit,
                  ),
            SizedBox(width: 8),
            if (isLoadingDownload)
              SizedBox(
                width: 35,
                height: 35,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kPrimaryGreen,
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

  /// Constrói o carrossel híbrido de imagens (suporta URLs online e caminhos locais offline).
  Widget _buildFullWidthCarousel() {
    final images = _displayPoi.imagens;
    
    if (images.isEmpty) {
      return Container(
        height: 250, color: Colors.grey[200],
        child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
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
              bool isNetwork = imgPath.startsWith('http'); // URL de rede ou ficheiro local?

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4), 
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: isNetwork
                    // Imagem de rede
                    ? CachedNetworkImage(
                        imageUrl: imgPath,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: Icon(Icons.broken_image)),
                      )
                    // Imagem local (modo offline)
                    : Image.file(
                        File(imgPath), fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12),
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

  void _startNavigation() {
    final tempRoteiro = Roteiro(
      id: 'single_poi_${_displayPoi.id}',
      titulo: 'Destino: ${_displayPoi.nome}',
      descricao: _displayPoi.description,
      imagemCapa: _displayPoi.imagens.isNotEmpty ? _displayPoi.imagens.first : '',
      poiIds: [_displayPoi.id],
      categoria: 'Geral',
      duracao: 'N/A',
      distancia: 0.0,
      criadorId: 'app_navigation',
    );
    
    // Publica o roteiro temporário no notifier global para iniciar a navegação
    activeRoteiroNotifier.value = tempRoteiro;

    // Volta ao mapa para mostrar a rota ativa
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildNavigationButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kPrimaryGreen,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: kPrimaryGreen.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton(
        onPressed: _startNavigation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.navigation_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.navigateToLocation, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }}
// Folha modal com a descrição completa e o player de áudio do POI

class _FullDescriptionSheet extends StatefulWidget {
  final POI poi;
  const _FullDescriptionSheet({required this.poi});

  @override
  State<_FullDescriptionSheet> createState() => _FullDescriptionSheetState();
}

class _FullDescriptionSheetState extends State<_FullDescriptionSheet> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  bool isPlaying = false;
  String _selectedLang = 'pt';
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lê a língua atual do contexto para carregar o áudio correto
    final locale = Localizations.localeOf(context);
    final newLang = locale.languageCode;
    if (newLang != _selectedLang) {
      _selectedLang = newLang;
      // Recarrega o áudio quando a língua muda
      _loadAudioForLang(_selectedLang);
    }
  }

  void _setupAudio() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        isPlaying = false;
        _position = Duration.zero;
      });
    });
    _loadAudioForLang(_selectedLang);
  }

  Future<void> _loadAudioForLang(String lang) async {
    await _audioPlayer.stop();
    if (mounted) setState(() {
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    String audioUrl = widget.poi.getAudioUrl(lang);
    if (audioUrl.isNotEmpty) {
      if (!audioUrl.startsWith('http')) {
        await _audioPlayer.setSourceDeviceFile(audioUrl);
      } else {
        await _audioPlayer.setSourceUrl(audioUrl);
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      String audioUrl = widget.poi.getAudioUrl(_selectedLang);
      if (audioUrl.isNotEmpty) {
        if (_position == Duration.zero) {
          if (audioUrl.startsWith('http')) {
            await _audioPlayer.play(UrlSource(audioUrl));
          } else {
            await _audioPlayer.play(DeviceFileSource(audioUrl));
          }
        } else {
          await _audioPlayer.resume();
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

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
          // Pega de arrasto para redimensionar a folha
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
                  icon: Icon(Icons.close_rounded, color: Colors.grey, size: 28),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          
          // Área de conteúdo scrollável
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Player de áudio (só visível se existir áudio para a língua selecionada)
                  if (widget.poi.getAudioUrl(_selectedLang).isNotEmpty) 
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
                                child: Icon(Icons.volume_up_rounded, size: 20),
                              ),
                              SizedBox(width: 15),
                              Text(AppLocalizations.of(context)!.listenAudioGuide, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const Spacer(),
                              GestureDetector(
                                onTap: _togglePlayPause,
                                child: Icon(
                                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  size: 44,
                                  color: kPrimaryGreen,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
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
                              min: 0,
                              max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                              value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
                              onChanged: (v) async {
                                final position = Duration(milliseconds: v.toInt());
                                await _audioPlayer.seek(position);
                              },
                            ),
                          ),
                          SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(_position), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              Text(_formatDuration(_duration), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Título da secção de descrição
                    Text(AppLocalizations.of(context)!.descriptionLabel,
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black87
                    ),
                  ),
                  
                  SizedBox(height: 10),
                  // Texto completo da descrição na língua ativa
                  Text(
                    widget.poi.getDescription(_selectedLang),
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


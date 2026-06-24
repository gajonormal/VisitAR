import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/roteiro.dart';
import '../../models/poi.dart';
import '../widgets/custom_button.dart';
import 'services/database_services.dart';
import 'services/favorites_service.dart';
import 'services/download_service.dart';
import 'services/roteiro_state.dart';
import 'details_screen.dart';
import 'login_screen.dart';
import 'create_roteiro_screen.dart';
import 'services/roteiros_service.dart';
import 'services/passport_service.dart';
import '../../models/badge_model.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

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
  
  late Roteiro _currentRoteiro;
  bool _isLoadingPois = true;
  List<POI> _poisDoRoteiro = [];
  
  bool _isFavorite = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentRoteiro = widget.roteiro;
    _checkAndFetchFullRoteiro();
    _loadPois();
    _checkStatus();
  }

  Future<void> _checkAndFetchFullRoteiro() async {
    // Se o Roteiro foi carregado a partir de favoritos antigos ou offline,
    // o criadorId pode estar vazio. Precisamos de ir buscar a versão completa.
    if (_currentRoteiro.criadorId.isEmpty || _currentRoteiro.criadorId == 'admin' && _currentRoteiro.mapaDescricao.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('roteiros').doc(_currentRoteiro.id).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentRoteiro = Roteiro.fromFirestore(doc);
          });
        }
      } catch (e) {
        debugPrint("Erro ao tentar buscar roteiro completo: $e");
      }
    }
  }

  Future<void> _checkStatus() async {
    bool fav = await _favoritesService.isFavoriteRoteiro(_currentRoteiro.id);
    Roteiro? offline = await _downloadService.getOfflineRoteiro(_currentRoteiro.id);
    if (mounted) {
      setState(() {
        _isFavorite = fav;
        _isDownloaded = offline != null;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog('guardar roteiros nos favoritos');
      return;
    }
    try {
      if (_isFavorite) {
        await _favoritesService.removeFavoriteRoteiro(_currentRoteiro.id);
      } else {
        await _favoritesService.addFavoriteRoteiro(_currentRoteiro);
      }
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isFavorite ? AppLocalizations.of(context)!.addedToFavorites : AppLocalizations.of(context)!.removedFromFavorites),
          backgroundColor: kPrimaryGreen,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingFavorite)));
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
              '${AppLocalizations.of(context)!.loginRequiredBody1}$acao${AppLocalizations.of(context)!.loginRequiredBody2}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomButton(
                  onPressed: () => Navigator.pop(ctx),
                  text: AppLocalizations.of(context)!.notNow,
                  backgroundColor: Colors.grey[200]!,
                  textColor: Colors.grey[700]!,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                SizedBox(width: 10),
                CustomButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  text: AppLocalizations.of(context)!.login,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDownload() async {
    if (_isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.roteiroAvailableOffline)));
      return;
    }
    setState(() => _isDownloading = true);
    
    bool success = await _downloadService.downloadRoteiroCompleto(_currentRoteiro, _poisDoRoteiro);
    
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? AppLocalizations.of(context)!.downloadSuccess : AppLocalizations.of(context)!.downloadError),
        backgroundColor: success ? kPrimaryGreen : Colors.red,
      ));
    }
  }

  Future<void> _loadPois() async {
    List<POI> pois = await _dbService.getPOIsByIds(_currentRoteiro.poiIds);
    if (mounted) {
      setState(() {
        _poisDoRoteiro = pois;
        _isLoadingPois = false;
      });
    }
  }

  Future<void> _showBadgeUnlockedDialog(List<BadgeModel> badges) async {
    await showDialog(
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
                Text(_getBadgeTitle(context, b.id, b.titulo), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text(_getBadgeDesc(context, b.id, b.descricao), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Center(
          child: Text(
            _currentRoteiro.titulo,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          _buildCircleButton(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.grey[600]!,
            onTap: _toggleFavorite,
          ),
          SizedBox(width: 8),
          _isDownloading
              ? SizedBox(
                  width: 35, 
                  height: 35, 
                  child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))
                )
              : _buildCircleButton(
                  _isDownloaded ? Icons.check : Icons.download_for_offline_outlined,
                  color: _isDownloaded ? kPrimaryGreen : Colors.grey[600]!,
                  onTap: _handleDownload,
                ),
          if (FirebaseAuth.instance.currentUser?.uid == _currentRoteiro.criadorId || FirebaseAuth.instance.currentUser?.uid == 'admin') ...[
            SizedBox(width: 8),
            _buildCircleButton(
              Icons.edit,
              color: Colors.grey[700]!,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoteiroScreen(roteiroToEdit: _currentRoteiro)));
                if (!mounted) return;
                
                try {
                  final doc = await FirebaseFirestore.instance.collection('roteiros').doc(_currentRoteiro.id).get();
                  if (doc.exists && mounted) {
                    setState(() {
                      // Fetch updated POI list from Firestore to refresh progress calculation
                      _currentRoteiro = Roteiro.fromFirestore(doc);
                    });
                  }
                } catch(e) {
                  debugPrint("Erro ao atualizar roteiro: $e");
                }
              },
            ),
            SizedBox(width: 8),
            _buildCircleButton(
              Icons.delete_outline,
              color: Colors.grey[700]!,
              onTap: () async {
                bool confirmar = await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(AppLocalizations.of(context)!.deleteRoteiro),
                    content: Text(AppLocalizations.of(context)!.deleteRoteiroConfirm),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.grey))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context)!.deleteButton, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ) ?? false;
                
                if (confirmar && mounted) {
                  try {
                    await RoteirosService().deleteRoteiro(_currentRoteiro.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.roteiroDeletedSuccess)));
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingRoteiro)));
                  }
                }
              },
            ),
          ],
          SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categoria
            Text(
              AppLocalizations.of(context)!.category,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 10),
            
            // IMAGEM DE CAPA
            _buildCoverImage(),
            SizedBox(height: 15),

            // ESTATÍSTICAS EM BLOCOS (ESTILO HEADER VERDE)
            Row(
              children: [
                Expanded(child: _buildStatBlock("POIs", "${_currentRoteiro.poiIds.length}")),
                SizedBox(width: 8),
                Expanded(child: _buildStatBlock(AppLocalizations.of(context)!.duration, _currentRoteiro.duracao)),
                SizedBox(width: 8),
                Expanded(child: _buildStatBlock(AppLocalizations.of(context)!.distance, "${_currentRoteiro.distancia.toStringAsFixed(1)} km")),
              ],
            ),
            
            SizedBox(height: 25),
            
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
                  Text(AppLocalizations.of(context)!.descriptionLabel, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  SizedBox(height: 10),
                  Text(
                    () {
                      final lang = Localizations.localeOf(context).languageCode;
                      final desc = _currentRoteiro.getDescricao(lang);
                      return desc.isEmpty ? AppLocalizations.of(context)!.noDescription : desc;
                    }(),
                    style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),

            // PROGRESSO DO ROTEIRO
            StreamBuilder<RoteiroProgress>(
              stream: PassportService().getRoteiroProgressStream(_currentRoteiro),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox();
                final progress = snapshot.data!;
                
                // Se o roteiro acabou de ser concluído, regista e possivelmente lança conquista
                if (progress.isCompleted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!mounted) return;
                    final novasBadges = await PassportService().registerRoteiroCompletion(_currentRoteiro.id);
                    if (novasBadges.isNotEmpty && mounted) {
                      _showBadgeUnlockedDialog(novasBadges);
                    }
                  });
                }

                return _buildGreenSection(
                  title: AppLocalizations.of(context)!.explorationProgress,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalizations.of(context)!.visitedProgress(progress.visitedCount, progress.total), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text('${(progress.percentage * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryGreen)),
                          ],
                        ),
                        SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress.percentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryGreen),
                            minHeight: 10,
                          ),
                        ),
                        if (progress.isCompleted) ...[
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified, color: kPrimaryGreen, size: 18),
                              SizedBox(width: 5),
                              Text(AppLocalizations.of(context)!.roteiroCompletedBadge, style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            
            // PONTOS DE INTERESSE ADICIONADOS (ESTILO FIGMA)
            _buildGreenSection(
              title: AppLocalizations.of(context)!.poisAdded,
              child: Column(
                children: [
                  // Lista
                  _isLoadingPois 
                      ? Padding(padding: const EdgeInsets.all(20.0), child: CircularProgressIndicator(color: kPrimaryGreen))
                      : _buildPoiTimeline(),
                ],
              ),
            ),
            
            SizedBox(height: 40),
            
            // BOTÕES INFERIORES
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  activeRoteiroNotifier.value = _currentRoteiro;
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text(AppLocalizations.of(context)!.startRoteiro, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            SizedBox(height: 30),
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

  Widget _buildStatBlock(String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(color: kPrimaryGreen),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              maxLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: _currentRoteiro.imagemCapa.isNotEmpty
            ? (_currentRoteiro.imagemCapa.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: _currentRoteiro.imagemCapa, 
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
                    errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40))),
                  )
                : Image.file(
                    File(_currentRoteiro.imagemCapa), 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40))),
                  ))
            : Container(
                color: Colors.grey[300], 
                child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 50)
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
      return Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(AppLocalizations.of(context)!.cannotLoadStops),
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
        String? img = poi.imagens.isNotEmpty ? poi.imagens.first : null;
        
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
                          color: kPrimaryGreen.withValues(alpha: 0.3),
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
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 45, height: 45,
                            child: img != null 
                              ? (img.startsWith('http') 
                                  ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_,__,___) => Container(color: Colors.grey[200], child: Icon(Icons.place, color: Colors.grey, size: 20)))
                                  : Image.file(File(img), fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[200], child: Icon(Icons.place, color: Colors.grey, size: 20))))
                              : Container(color: Colors.grey[200]),
                          ),
                        ),
                        title: Text(poi.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(_getCategoryTranslation(context, poi.categoria), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
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

  String _getCategoryTranslation(BuildContext context, String category) {
    switch (category) {
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

  String _getBadgeTitle(BuildContext context, String badgeId, String defaultVal) {
    switch (badgeId) {
      case 'primeiro_carimbo': return AppLocalizations.of(context)!.badgePrimeiroCarimboTitle;
      case 'conhecedor': return AppLocalizations.of(context)!.badgeConhecedorTitle;
      case 'colecionador': return AppLocalizations.of(context)!.badgeColecionadorTitle;
      case 'grande_explorador': return AppLocalizations.of(context)!.badgeGrandeExploradorTitle;
      case 'primeiro_roteiro': return AppLocalizations.of(context)!.badgePrimeiroRoteiroTitle;
      case 'aventureiro': return AppLocalizations.of(context)!.badgeAventureiroTitle;
      case 'viajante': return AppLocalizations.of(context)!.badgeViajanteTitle;
      case 'criador': return AppLocalizations.of(context)!.badgeCriadorTitle;
      case 'guia_local': return AppLocalizations.of(context)!.badgeGuiaLocalTitle;
      default: return defaultVal;
    }
  }

  String _getBadgeDesc(BuildContext context, String badgeId, String defaultVal) {
    switch (badgeId) {
      case 'primeiro_carimbo': return AppLocalizations.of(context)!.badgePrimeiroCarimboDesc;
      case 'conhecedor': return AppLocalizations.of(context)!.badgeConhecedorDesc;
      case 'colecionador': return AppLocalizations.of(context)!.badgeColecionadorDesc;
      case 'grande_explorador': return AppLocalizations.of(context)!.badgeGrandeExploradorDesc;
      case 'primeiro_roteiro': return AppLocalizations.of(context)!.badgePrimeiroRoteiroDesc;
      case 'aventureiro': return AppLocalizations.of(context)!.badgeAventureiroDesc;
      case 'viajante': return AppLocalizations.of(context)!.badgeViajanteDesc;
      case 'criador': return AppLocalizations.of(context)!.badgeCriadorDesc;
      case 'guia_local': return AppLocalizations.of(context)!.badgeGuiaLocalDesc;
      default: return defaultVal;
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/roteiro.dart';
import '../../models/poi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_services.dart';
import 'services/roteiros_service.dart';
import 'services/passport_service.dart';
import '../../models/badge_model.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

class CreateRoteiroScreen extends StatefulWidget {
  final Roteiro? roteiroToEdit;
  
  const CreateRoteiroScreen({super.key, this.roteiroToEdit});

  @override
  State<CreateRoteiroScreen> createState() => _CreateRoteiroScreenState();
}

class _CreateRoteiroScreenState extends State<CreateRoteiroScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);

  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoPtController = TextEditingController();
  final _descricaoEnController = TextEditingController();
  final _searchController = TextEditingController();
  
  String _categoria = 'Histórico';
  final List<String> _categorias = ['Histórico', 'Natureza', 'Geológico', 'Trilho'];

  bool _isLoadingPois = true;
  bool _isSaving = false;
  
  List<POI> _allPois = [];
  final List<POI> _selectedPois = []; 

  File? _imagemCapaFile;

  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    if (widget.roteiroToEdit != null) {
      _tituloController.text = widget.roteiroToEdit!.titulo;
      _descricaoPtController.text = widget.roteiroToEdit!.mapaDescricao['pt'] ?? '';
      _descricaoEnController.text = widget.roteiroToEdit!.mapaDescricao['en'] ?? '';
      _categoria = widget.roteiroToEdit!.categoria;
    }
    _loadPois();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoPtController.dispose();
    _descricaoEnController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPois() async {
    final pois = await DatabaseService().getPOIs();
    
    // Pré-seleciona POIs existentes no modo de edição
    List<POI> preSelected = [];
    if (widget.roteiroToEdit != null) {
      preSelected = pois.where((p) => widget.roteiroToEdit!.poiIds.contains(p.id)).toList();
    } else {
      // Pré-seleciona POIs guardados no carrinho temporário
      final prefs = await SharedPreferences.getInstance();
      List<String> cartIds = prefs.getStringList('roteiro_cart_poi_ids') ?? [];
      preSelected = pois.where((p) => cartIds.contains(p.id)).toList();
    }

    if (mounted) {
      setState(() {
        _allPois = pois;
        _selectedPois.addAll(preSelected);
        _isLoadingPois = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imagemCapaFile = File(pickedFile.path);
      });
    }
  }

  List<POI> get _availablePois {
    return _allPois.where((poi) {
      final matchesSearch = poi.nome.toLowerCase().contains(_searchQuery.toLowerCase());
      final isNotSelected = !_selectedPois.contains(poi);
      return matchesSearch && isNotSelected;
    }).toList();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _guardarRoteiro() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPois.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.routeMinLocations), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.routeTitleRequired), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    bool hasNet = await _hasInternet();
      if (!hasNet) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.routeInternetRequired), backgroundColor: Colors.red),
          );
        }
        return;
      }

    try {
      double distTotal = 0;
      for (int i = 0; i < _selectedPois.length - 1; i++) {
        double d = Geolocator.distanceBetween(
          _selectedPois[i].localizacao.latitude, _selectedPois[i].localizacao.longitude,
          _selectedPois[i+1].localizacao.latitude, _selectedPois[i+1].localizacao.longitude
        );
        distTotal += d;
      }
      double distKm = distTotal / 1000.0;
      
      double horasAndar = distKm / 4.0;
      double horasParagens = _selectedPois.length * 0.5;
      double horasTotais = horasAndar + horasParagens;
      
      int h = horasTotais.floor();
      int m = ((horasTotais - h) * 60).round();
      String duracaoFinal = "${h}h ${m}m";

      String capa = '';
      if (_imagemCapaFile != null) {
        // Envia a imagem de capa para o Firebase Storage
        final fileName = 'roteiros/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = await ref.putFile(_imagemCapaFile!);
        capa = await uploadTask.ref.getDownloadURL();
      } else if (widget.roteiroToEdit != null) {
        capa = widget.roteiroToEdit!.imagemCapa;
      } else {
        capa = _selectedPois.isNotEmpty && _selectedPois.first.imagens.isNotEmpty ? _selectedPois.first.imagens.first : '';
      }

      final novoRoteiro = Roteiro(
        id: widget.roteiroToEdit?.id ?? '',
        titulo: _tituloController.text.trim(),
        mapaDescricao: {
          'pt': _descricaoPtController.text.trim(),
          'en': _descricaoEnController.text.trim(),
        },
        imagemCapa: capa,
        poiIds: _selectedPois.map((e) => e.id).toList(),
        categoria: _categoria,
        duracao: duracaoFinal,
        distancia: distKm,
        criadorId: widget.roteiroToEdit?.criadorId ?? '',
      );
      
      if (widget.roteiroToEdit != null) {
        await RoteirosService().updateRoteiro(novoRoteiro);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.roteiroUpdatedSuccess), backgroundColor: Colors.green));
          // Regressa aos detalhes do roteiro após edição
        Navigator.pop(context);
        }
      } else {
        await RoteirosService().createRoteiro(novoRoteiro);
        
        // Limpa o carrinho após a criação do roteiro
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('roteiro_cart_poi_ids');
        
        // Valida desbloqueio de novas conquistas
        final novasBadges = await PassportService().onRoteiroCreated();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.roteiroCreatedSuccess), backgroundColor: Colors.green));
          
          if (novasBadges.isNotEmpty) {
            await _showBadgeUnlockedDialog(novasBadges);
          }
          
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorCreatingRoteiro), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  String _getDifficultyTranslation(BuildContext context, String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'FÁCIL':
        return AppLocalizations.of(context)!.difEasy;
      case 'MODERADO':
        return AppLocalizations.of(context)!.difMedium;
      case 'DIFÍCIL':
        return AppLocalizations.of(context)!.difHard;
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.roteiroToEdit != null ? AppLocalizations.of(context)!.editRoteiroTitle : AppLocalizations.of(context)!.createRoteiroTitle, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingPois
          ? Center(child: CircularProgressIndicator(color: kPrimaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_tituloController, AppLocalizations.of(context)!.itineraryNameHint),
                    SizedBox(height: 15),

                    // Área de seleção da imagem de capa
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                          image: _imagemCapaFile != null
                              ? DecorationImage(image: FileImage(_imagemCapaFile!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _imagemCapaFile == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 40, color: Colors.white),
                                    SizedBox(height: 5),
                                    Text(AppLocalizations.of(context)!.addCoverPhoto, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            : Stack(
                                children: [
                                  Positioned(
                                    top: 10, right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: Icon(Icons.edit, color: Colors.white, size: 20),
                                    ),
                                  )
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: _categoria,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        hintText: AppLocalizations.of(context)!.category,
                      ),
                      icon: Icon(Icons.arrow_drop_down, color: kPrimaryGreen),
                      items: _categorias.map((String cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _categoria = val);
                      },
                    ),
                    SizedBox(height: 15),

                    _buildTextField(_descricaoPtController, '${AppLocalizations.of(context)!.descriptionLabel} (PT)', maxLines: 4),
                    SizedBox(height: 15),

                    _buildTextField(_descricaoEnController, '${AppLocalizations.of(context)!.descriptionLabel} (EN)', maxLines: 4),
                    SizedBox(height: 30),

                    // Lista de pontos já associados ao roteiro
                    _buildGreenSection(
                      title: AppLocalizations.of(context)!.poisAdded,
                      child: _selectedPois.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(AppLocalizations.of(context)!.noLocationsAddedYet, style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _selectedPois.length,
                              itemBuilder: (context, index) {
                                final poi = _selectedPois[index];
                                return ListTile(
                                  title: Text("${index + 1}. ${poi.nome}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: IconButton(
                                    icon: Icon(Icons.remove, color: Colors.black),
                                    onPressed: () async {
                                      setState(() => _selectedPois.remove(poi));
                                      // Remove POI do carrinho temporário
                                      final prefs = await SharedPreferences.getInstance();
                                      List<String> cart = prefs.getStringList('roteiro_cart_poi_ids') ?? [];
                                      cart.remove(poi.id);
                                      await prefs.setStringList('roteiro_cart_poi_ids', cart);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.canAddPoisLater,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    SizedBox(height: 25),

                    // Lista de pontos disponíveis para adicionar
                    _buildGreenSection(
                      title: AppLocalizations.of(context)!.nearbyPois,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 15),
                                  Icon(Icons.search, color: Colors.grey),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) => setState(() => _searchQuery = val),
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(context)!.searchLocation,
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
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
                                      padding: EdgeInsets.zero,
                                      splashRadius: 20,
                                      constraints: const BoxConstraints(),
                                    ),
                                  SizedBox(width: 15),
                                ],
                              ),
                            ),
                          ),
                          
                          if (_availablePois.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Text(AppLocalizations.of(context)!.noLocationsAvailable, style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _availablePois.length,
                              itemBuilder: (context, index) {
                                final poi = _availablePois[index];
                                return ListTile(
                                  title: Text(poi.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: IconButton(
                                    icon: Icon(Icons.add, color: Colors.black),
                                    onPressed: () async {
                                      setState(() => _selectedPois.add(poi));
                                      // Adiciona POI ao carrinho temporário
                                      final prefs = await SharedPreferences.getInstance();
                                      List<String> cart = prefs.getStringList('roteiro_cart_poi_ids') ?? [];
                                      if (!cart.contains(poi.id)) cart.add(poi.id);
                                      await prefs.setStringList('roteiro_cart_poi_ids', cart);
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),

                    SizedBox(
                      width: 200,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _guardarRoteiro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: _isSaving
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                            : Text(widget.roteiroToEdit != null ? AppLocalizations.of(context)!.saveRoteiroButton : AppLocalizations.of(context)!.createRoteiroButton, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      validator: (val) => val == null || val.trim().isEmpty ? AppLocalizations.of(context)!.fieldRequired : null,
    );
  }

  Widget _buildGreenSection({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: kPrimaryGreen,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

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
  final _descricaoController = TextEditingController();
  final _searchController = TextEditingController();
  
  String _dificuldade = 'FÁCIL';
  final List<String> _dificuldades = ['FÁCIL', 'MODERADO', 'DIFÍCIL'];

  bool _isLoadingPois = true;
  bool _isSaving = false;
  
  List<POI> _allPois = [];
  final List<POI> _selectedPois = []; 

  // Imagem de Capa
  File? _imagemCapaFile;

  // Pesquisa
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    if (widget.roteiroToEdit != null) {
      _tituloController.text = widget.roteiroToEdit!.titulo;
      _descricaoController.text = widget.roteiroToEdit!.descricao;
      _dificuldade = widget.roteiroToEdit!.dificuldade;
    }
    _loadPois();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPois() async {
    final pois = await DatabaseService().getPOIs();
    
    // Se estiver a editar, carregamos os POIs do roteiro
    List<POI> preSelected = [];
    if (widget.roteiroToEdit != null) {
      preSelected = pois.where((p) => widget.roteiroToEdit!.poiIds.contains(p.id)).toList();
    } else {
      // Senão carregamos do carrinho
      final prefs = await SharedPreferences.getInstance();
      List<String> cartIds = prefs.getStringList('roteiro_cart_poi_ids') ?? [];
      preSelected = pois.where((p) => cartIds.contains(p.id)).toList();
    }

    if (mounted) {
      setState(() {
        _allPois = pois;
        _selectedPois.addAll(preSelected); // Adiciona logo ao criar a página!
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
      final matchesSearch = poi.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final isNotSelected = !_selectedPois.contains(poi);
      return matchesSearch && isNotSelected;
    }).toList();
  }

  Future<void> _guardarRoteiro() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPois.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Adiciona pelo menos 2 locais para criar um roteiro."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      double distTotal = 0;
      for (int i = 0; i < _selectedPois.length - 1; i++) {
        double d = Geolocator.distanceBetween(
          _selectedPois[i].location.latitude, _selectedPois[i].location.longitude,
          _selectedPois[i+1].location.latitude, _selectedPois[i+1].location.longitude
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
        // Upload para o Firebase Storage
        final fileName = 'roteiros/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = await ref.putFile(_imagemCapaFile!);
        capa = await uploadTask.ref.getDownloadURL();
      } else if (widget.roteiroToEdit != null) {
        capa = widget.roteiroToEdit!.imagemCapa;
      } else {
        capa = _selectedPois.isNotEmpty && _selectedPois.first.images.isNotEmpty ? _selectedPois.first.images.first : '';
      }

      final novoRoteiro = Roteiro(
        id: widget.roteiroToEdit?.id ?? '', // Firebase gera isto se for vazio
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        imagemCapa: capa,
        poiIds: _selectedPois.map((e) => e.id).toList(),
        dificuldade: _dificuldade,
        duracao: duracaoFinal,
        distancia: distKm,
        avaliacao: widget.roteiroToEdit?.avaliacao ?? 0.0,
        criadorId: widget.roteiroToEdit?.criadorId ?? '', // Vai ser substituído no service
      );
      
      if (widget.roteiroToEdit != null) {
        await RoteirosService().updateRoteiro(novoRoteiro);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Roteiro atualizado com sucesso!"), backgroundColor: Colors.green));
          Navigator.pop(context); // Voltar aos detalhes
        }
      } else {
        await RoteirosService().createRoteiro(novoRoteiro);
        
        // Limpar carrinho
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('roteiro_cart_poi_ids');
        
        // Verificar conquistas
        final novasBadges = await PassportService().onRoteiroCreated();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Roteiro criado com sucesso!"), backgroundColor: Colors.green));
          
          if (novasBadges.isNotEmpty) {
            await _showBadgeUnlockedDialog(novasBadges);
          }
          
          Navigator.pop(context); // Voltar
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao criar roteiro. Tens a sessão iniciada?"), backgroundColor: Colors.red),
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
            const Icon(Icons.military_tech_outlined, color: Color(0xFFFFD700), size: 54),
            const SizedBox(height: 8),
            const Text('Conquista Desbloqueada!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: badges.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Text(b.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
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
              child: const Text('Fantástico!', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(widget.roteiroToEdit != null ? "Editar Roteiro" : "Criar Novo Roteiro", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                    // Nome
                    _buildTextField(_tituloController, "Nome do roteiro"),
                    const SizedBox(height: 15),

                    // Imagem Placeholder / Selecionada
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
                                    const Icon(Icons.camera_alt_outlined, size: 40, color: Colors.white),
                                    const SizedBox(height: 5),
                                    const Text("Adicionar Capa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                                    ),
                                  )
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Categoria / Dificuldade
                    DropdownButtonFormField<String>(
                      value: _dificuldade,
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
                        hintText: "Categoria",
                      ),
                      icon: Icon(Icons.arrow_drop_down, color: kPrimaryGreen),
                      items: _dificuldades.map((String dif) {
                        return DropdownMenuItem(value: dif, child: Text(dif));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _dificuldade = val);
                      },
                    ),
                    const SizedBox(height: 15),

                    // Descrição
                    _buildTextField(_descricaoController, "Descrição", maxLines: 4),
                    const SizedBox(height: 30),

                    // PONTOS DE INTERESSE ADICIONADOS
                    _buildGreenSection(
                      title: "Pontos de interesse adicionados",
                      child: _selectedPois.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("Ainda não adicionaste nenhum local.", style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _selectedPois.length,
                              itemBuilder: (context, index) {
                                final poi = _selectedPois[index];
                                return ListTile(
                                  title: Text("${index + 1}. ${poi.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove, color: Colors.black),
                                    onPressed: () async {
                                      setState(() => _selectedPois.remove(poi));
                                      // Remove também do carrinho
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
                    
                    const SizedBox(height: 8),
                    const Text(
                      "Pode sempre adicionar POIs\nfuturamente ao editar um Roteiro",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 25),

                    // PONTOS DE INTERESSE PRÓXIMOS (Para Selecionar)
                    _buildGreenSection(
                      title: "Pontos de interesse próximos",
                      child: Column(
                        children: [
                          // Search bar inside
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
                                  const SizedBox(width: 15),
                                  const Icon(Icons.search, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) => setState(() => _searchQuery = val),
                                      decoration: const InputDecoration(
                                        hintText: "Pesquisar local...",
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
                                  const SizedBox(width: 15),
                                ],
                              ),
                            ),
                          ),
                          
                          if (_availablePois.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Text("Nenhum local disponível.", style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _availablePois.length,
                              itemBuilder: (context, index) {
                                final poi = _availablePois[index];
                                return ListTile(
                                  title: Text(poi.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add, color: Colors.black),
                                    onPressed: () async {
                                      setState(() => _selectedPois.add(poi));
                                      // Adiciona ao carrinho caso o utilizador volte atrás
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

                    const SizedBox(height: 40),

                    // BOTÃO CRIAR ROTEIRO
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
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                            : const Text("Criar Roteiro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
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
      validator: (val) => val == null || val.trim().isEmpty ? 'Campo obrigatório' : null,
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
          // Header Verde
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
          // Content
          child,
        ],
      ),
    );
  }
}

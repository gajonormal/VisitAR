import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/roteiro.dart';
import '../../models/poi.dart';
import 'services/database_services.dart';
import 'services/roteiros_service.dart';

class CreateRoteiroScreen extends StatefulWidget {
  const CreateRoteiroScreen({super.key});

  @override
  State<CreateRoteiroScreen> createState() => _CreateRoteiroScreenState();
}

class _CreateRoteiroScreenState extends State<CreateRoteiroScreen> {
  final Color kPrimaryGreen = const Color(0xFF0F9D58);

  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  
  String _dificuldade = 'FÁCIL';
  final List<String> _dificuldades = ['FÁCIL', 'MODERADO', 'DIFÍCIL'];

  bool _isLoadingPois = true;
  bool _isSaving = false;
  
  List<POI> _allPois = [];
  final List<POI> _selectedPois = []; 

  // Pesquisa
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadPois();
  }

  Future<void> _loadPois() async {
    final pois = await DatabaseService().getPOIs();
    if (mounted) {
      setState(() {
        _allPois = pois;
        _isLoadingPois = false;
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

      String capa = _selectedPois.first.images.isNotEmpty ? _selectedPois.first.images.first : '';

      final novoRoteiro = Roteiro(
        id: '',
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        imagemCapa: capa,
        poiIds: _selectedPois.map((p) => p.id).toList(),
        dificuldade: _dificuldade,
        duracao: duracaoFinal,
        distancia: distKm,
        avaliacao: 5.0,
        criadorId: '',
      );

      await RoteirosService().createRoteiro(novoRoteiro);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Roteiro '${novoRoteiro.titulo}' criado com sucesso!"), backgroundColor: kPrimaryGreen),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Criar Roteiro", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

                    // Imagem Placeholder (Design)
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Icon(Icons.camera_alt_outlined, size: 50, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Categoria / Dificuldade
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _dificuldade,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          border: InputBorder.none,
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
                                    onPressed: () => setState(() => _selectedPois.remove(poi)),
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
                            padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  hintText: "Pesquisar local...",
                                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                                  suffixIcon: Icon(Icons.tune, color: kPrimaryGreen),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),
                          ),
                          
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
                                  onPressed: () => setState(() => _selectedPois.add(poi)),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
        ),
        validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAddPoiScreen extends StatefulWidget {
  const AdminAddPoiScreen({super.key});

  @override
  State<AdminAddPoiScreen> createState() => _AdminAddPoiScreenState();
}

class _AdminAddPoiScreenState extends State<AdminAddPoiScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color kPrimaryGreen = const Color(0xFF0F9D58);

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descPtController = TextEditingController();
  final TextEditingController _descEnController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _arUrlController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  File? _audioPt;
  File? _audioEn;
  bool _isUploading = false;

  // --- 1. ESCOLHER IMAGENS ---
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xFile) => File(xFile.path)).toList());
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _pickAudio(String lang) async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        if (lang == 'pt') _audioPt = File(result.files.single.path!);
        if (lang == 'en') _audioEn = File(result.files.single.path!);
      });
    }
  }

  void _removeAudio(String lang) {
    setState(() {
      if (lang == 'pt') _audioPt = null;
      if (lang == 'en') _audioEn = null;
    });
  }

  // --- 2. GUARDAR POI (COM ESTRUTURA NOVA) ---
  Future<void> _savePOI() async {
    // Validações básicas
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text("Preenche os campos obrigatórios!")),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text("Adiciona pelo menos uma foto!")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload das Imagens
      List<String> imageUrls = [];
      
      for (var imageFile in _selectedImages) {
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg";
        Reference ref = FirebaseStorage.instance.ref().child('poi_images').child(fileName);
        
        await ref.putFile(imageFile);
        String url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // 1.5 Upload Audios
      String audioPtUrl = '';
      if (_audioPt != null) {
        Reference ref = FirebaseStorage.instance.ref().child('poi_audios').child("${DateTime.now().millisecondsSinceEpoch}_pt.mp3");
        await ref.putFile(_audioPt!);
        audioPtUrl = await ref.getDownloadURL();
      }
      String audioEnUrl = '';
      if (_audioEn != null) {
        Reference ref = FirebaseStorage.instance.ref().child('poi_audios').child("${DateTime.now().millisecondsSinceEpoch}_en.mp3");
        await ref.putFile(_audioEn!);
        audioEnUrl = await ref.getDownloadURL();
      }

      // 2. Tratar Coordenadas (Substituir , por .)
      double lat = double.parse(_latController.text.replaceAll(',', '.').trim());
      double lng = double.parse(_lngController.text.replaceAll(',', '.').trim());

      // 3. Criar Documento com a ESTRUTURA NOVA DO FIREBASE
      await FirebaseFirestore.instance.collection('pois').add({
        'nome': _nameController.text.trim(),
        'categoria': _categoryController.text.trim(),
        'medAvaliacao': 5, // Começa com 5 (ou 0, como preferires)
        'localizacao': GeoPoint(lat, lng), // Campo correto: 'localizacao'
        
        // Estrutura complexa de descrição (Map)
        'descricao': {
          'pt': _descPtController.text.trim(),
          'en': _descEnController.text.trim(),
        },

        // Estrutura complexa de AR (Map)
        'conteudoAr': {
          'modelUrl': _arUrlController.text.trim(),
          'scale': 1,
        },

        'imagens': imageUrls, // Campo correto: 'imagens'
        'audioMap': {
          'pt': audioPtUrl,
          'en': audioEnUrl,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: kPrimaryGreen, content: const Text("✅ POI Criado com sucesso!")),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Erro ao gravar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Novo Ponto de Interesse")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FOTOS
              const Text("Fotos (Obrigatório)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              
              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (ctx, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(image: FileImage(_selectedImages[index]), fit: BoxFit.cover),
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                          Positioned(
                            right: 0, top: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text("Adicionar da Galeria"),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              ),

              const SizedBox(height: 30),

              // DADOS DE TEXTO
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nome do Local", border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? "Obrigatório" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _descPtController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Descrição (PT)", border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? "Obrigatório" : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _audioPt == null 
                      ? OutlinedButton.icon(onPressed: () => _pickAudio('pt'), icon: const Icon(Icons.audiotrack), label: const Text("Adicionar Áudio PT"))
                      : OutlinedButton.icon(onPressed: () => _removeAudio('pt'), icon: const Icon(Icons.delete, color: Colors.red), label: Text("Remover ${_audioPt!.path.split(Platform.pathSeparator).last}", style: const TextStyle(color: Colors.red))),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _descEnController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Descrição (EN) - Opcional", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _audioEn == null 
                      ? OutlinedButton.icon(onPressed: () => _pickAudio('en'), icon: const Icon(Icons.audiotrack), label: const Text("Adicionar Áudio EN"))
                      : OutlinedButton.icon(onPressed: () => _removeAudio('en'), icon: const Icon(Icons.delete, color: Colors.red), label: Text("Remover ${_audioEn!.path.split(Platform.pathSeparator).last}", style: const TextStyle(color: Colors.red))),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? "Obrigatório" : null,
              ),
              const SizedBox(height: 15),

              // COORDENADAS
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Latitude (ex: 39.82)", border: OutlineInputBorder()),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Obrigatório";
                        if (double.tryParse(val.replaceAll(',', '.')) == null) return "Inválido";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Longitude (ex: -7.49)", border: OutlineInputBorder()),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Obrigatório";
                        if (double.tryParse(val.replaceAll(',', '.')) == null) return "Inválido";
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // MODELO 3D
              TextFormField(
                controller: _arUrlController,
                decoration: const InputDecoration(
                  labelText: "Link Modelo 3D (.glb)", 
                  border: OutlineInputBorder(),
                  helperText: "Opcional. Cola o URL direto.",
                ),
              ),

              const SizedBox(height: 40),

              // BOTÃO GUARDAR
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _savePOI,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text("A criar POI... "),
                            SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          ],
                        )
                      : const Text("CRIAR PONTO DE INTERESSE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
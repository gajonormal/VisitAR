import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  bool _isUploading = false;
  String _status = 'Pronto para iniciar.';
  int _current = 0;
  int _total = 0;
  List<String> _logs = [];
  File? _capaBarcocalFile; // Imagem de capa para o roteiro do Barrocal

  Future<void> _pickCapaBarrocal() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _capaBarcocalFile = File(picked.path));
    }
  }

  void _addLog(String msg) {
    setState(() {
      _logs.insert(0, msg);
    });
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _logs.clear();
      _status = 'A procurar diretórios...';
    });

    final String rootPath = Platform.isWindows ? 'C:\\Users\\berna\\Desktop\\visitar_teste\\firebase_data\\barrocal\\Barrocal' : '/sdcard/Android/data/com.example.visitar_teste/files/Barrocal';
    final rootDir = Directory(rootPath);

    if (!await rootDir.exists()) {
      _addLog('ERRO: Pasta não encontrada em $rootPath');
      setState(() => _isUploading = false);
      return;
    }

    List<FileSystemEntity> poiFolders = rootDir.listSync().whereType<Directory>().toList();
    setState(() => _total = poiFolders.length);

    _addLog('$_total pontos encontrados.');

    for (var i = 0; i < poiFolders.length; i++) {
      try {
        setState(() => _current = i + 1);
        final folder = poiFolders[i] as Directory;
        final folderName = folder.path.split(Platform.pathSeparator).last;
        
        _addLog('-> A processar $folderName...');

        String id = folderName.replaceAll(' ', '_').toLowerCase();
        String nome = folderName.contains('-') ? folderName.split('-').last.trim() : folderName;

        // Ler info.txt
        final infoFile = File('${folder.path}/info.txt');
        double lat = 0.0;
        double lng = 0.0;
        String categoria = 'Geral';
        String descPt = '';
        String descEn = '';

        if (await infoFile.exists()) {
          final lines = await infoFile.readAsLines();
          for (var line in lines) {
            if (line.startsWith('LATITUDE:')) lat = double.tryParse(line.substring(9).trim()) ?? 0.0;
            if (line.startsWith('LONGITUDE:')) lng = double.tryParse(line.substring(10).trim()) ?? 0.0;
            if (line.startsWith('CATEGORIA:')) categoria = line.substring(10).trim();
            if (line.startsWith('DESC_PT:')) descPt = line.substring(8).trim();
            if (line.startsWith('DESC_EN:')) descEn = line.substring(8).trim();
          }
        }

        // Procurar Ficheiros
        List<File> images = [];
        Map<String, File> audios = {};
        File? panoramaFile;

        final files = folder.listSync(recursive: false).whereType<File>();
        for (var f in files) {
          final lower = f.path.toLowerCase();
          if (lower.endsWith('.jpg') || lower.endsWith('.png') || lower.endsWith('.jpeg')) {
            images.add(f);
          } else if (lower.endsWith('.mp3')) {
            if (lower.contains('en ')) audios['en'] = f;
            else audios['pt'] = f;
          }
        }

        // Ver se há panoramas
        final panoDir = Directory('${folder.path}/360');
        if (await panoDir.exists()) {
          final panoFiles = panoDir.listSync().whereType<File>();
          for (var f in panoFiles) {
            if (f.path.toLowerCase().endsWith('.jpg') || f.path.toLowerCase().endsWith('.jpeg')) {
              panoramaFile = f;
              break;
            }
          }
        }

        // 1. Upload Imagens
        List<String> imageUrls = [];
        for (int j = 0; j < images.length; j++) {
          var img = images[j];
          _addLog('      Enviando imagem ${j+1}/${images.length}...');
          String filename = img.path.split(Platform.pathSeparator).last;
          final ref = FirebaseStorage.instance.ref().child('pois/$id/imagens/$filename');
          await ref.putFile(img);
          String url = await ref.getDownloadURL();
          imageUrls.add(url);
        }
        _addLog('   ${imageUrls.length} imagens enviadas.');

        // 2. Upload Audios
        Map<String, String> audioUrls = {};
        int audIndex = 1;
        for (var key in audios.keys) {
          _addLog('      Enviando áudio ${audIndex++}/${audios.length}...');
          String filename = audios[key]!.path.split(Platform.pathSeparator).last;
          final ref = FirebaseStorage.instance.ref().child('pois/$id/audios/$filename');
          await ref.putFile(audios[key]!);
          String url = await ref.getDownloadURL();
          audioUrls[key] = url;
        }
        _addLog('   ${audioUrls.length} audios enviados.');

        // 3. Upload Panorama
        if (panoramaFile != null) {
          String filename = panoramaFile.path.split(Platform.pathSeparator).last;
          final ref = FirebaseStorage.instance.ref().child('panoramas/$id/$filename');
          await ref.putFile(panoramaFile);
          String url = await ref.getDownloadURL();

          // Guardar Panorama no Firestore sem apagar os marcadores que já existem!
          await FirebaseFirestore.instance.collection('panoramas').doc(id).set({
            'imageUrl': url,
          }, SetOptions(merge: true));
          _addLog('   Panorama enviado.');
        }

        // 4. Guardar POI no Firestore
        await FirebaseFirestore.instance.collection('pois').doc(id).set({
          'nome': nome,
          'categoria': categoria,
          'localizacao': GeoPoint(lat, lng),
          'imagens': imageUrls.isNotEmpty ? imageUrls : ['https://via.placeholder.com/300'],
          'descricao': {
            'pt': descPt,
            'en': descEn,
          },
          'audioMap': audioUrls,
        });

        _addLog('OK: $nome guardado no Firestore.');
      } catch (e) {
        _addLog('ERRO FATAL EM ${poiFolders[i].path}: $e');
      }
    }

    setState(() {
      _isUploading = false;
      _status = 'Processo concluído!';
    });
  }

  Future<void> _criarRoteiroBarrocal() async {
    setState(() {
      _isUploading = true;
      _status = 'A criar roteiro do Barrocal...';
      _logs.clear();
    });

    try {
      // IDs dos POIs na ordem definida pelo utilizador
      // (gerados pelo upload: folderName.replaceAll(' ', '_').toLowerCase())
      final List<String> poiIds = [
        'poi1-chave_do_barrocal',
        'poi2-mirante_de_castelo_branco',
        'poi3-pedra_da_rondoa',
        'poi17-cogumelo_gigante_do_barrocal',
        'poi4-mirante_do_barrocal',
        'poi5-carreiro_do_barrocal',
        'poi6-santuario_rupestre',
        'poi7-tunel_do_lagarto',
        'poi8-circulo_do_domo',
        'poi9-carreiro_do_lagarto',
        'poi10-mirante_do_carvalhal',
        'poi11-observatorio_dos_abelharucos',
        'poi12-mirante_da_raia',
        'poi13-mirante_smartinho',
        'poi18-bloco_pedestal',
        'poi14-caminho_dos_penedos',
        'poi15-mirante_da_sr_de_mercules',
        'poi16-atalho_da_quinta',
      ];

      _addLog('A verificar se os POIs existem no Firestore...');
      // Verificar que os POIs existem
      int found = 0;
      for (final id in poiIds) {
        final doc = await FirebaseFirestore.instance.collection('pois').doc(id).get();
        if (doc.exists) {
          found++;
        } else {
          _addLog('AVISO: POI "$id" não encontrado no Firestore!');
        }
      }
      _addLog('$found/${poiIds.length} POIs encontrados.');

      _addLog('A criar documento do roteiro...');

      // Upload da imagem de capa (se selecionada)
      String capaUrl = '';
      if (_capaBarcocalFile != null) {
        _addLog('A enviar imagem de capa...');
        final fileName = 'roteiros/barrocal_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_capaBarcocalFile!);
        capaUrl = await ref.getDownloadURL();
        _addLog('Imagem de capa enviada.');
      }

      await FirebaseFirestore.instance.collection('roteiros').add({
        'titulo': 'Roteiro do Parque do Barrocal',
        'mapaDescricao': {
          'pt': 'Percorra os pontos mais emblemáticos do Parque do Barrocal, descobrindo as suas formações geológicas únicas, mirantes panorâmicos e a rica biodiversidade deste espaço natural de Castelo Branco.',
          'en': 'Explore the most iconic spots of Barrocal Park, discovering its unique geological formations, panoramic viewpoints and the rich biodiversity of this natural space in Castelo Branco.',
        },
        'categoria': 'Trilho',
        'duracao': '1h 30m',
        'distancia': 2.5,
        'criadorId': 'admin',
        'imagemCapa': capaUrl,
        'poiIds': poiIds,
        'trailAsset': 'assets/roteiros/barrocal_trail.geojson',
        'dataCriacao': DateTime.now(),
      });

      _addLog('✅ Roteiro do Barrocal criado com sucesso!');
      _addLog('ℹ️ Lembra-te de atualizar o campo "imagemCapa" no Firebase Console com a URL da imagem.');

      setState(() {
        _status = 'Roteiro criado com sucesso!';
        _isUploading = false;
      });
    } catch (e) {
      _addLog('ERRO ao criar roteiro: $e');
      setState(() {
        _isUploading = false;
        _status = 'Erro!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Painel de Upload')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('A ler pastas diretamente de /sdcard/Download/Barrocal'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading ? null : _startUpload,
              child: Text(_isUploading ? 'A enviar $_current de $_total...' : 'Iniciar Upload do Barrocal'),
            ),
            SizedBox(height: 12),
            // Seleção de imagem de capa para o roteiro
            GestureDetector(
              onTap: _isUploading ? null : _pickCapaBarrocal,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                  image: _capaBarcocalFile != null
                      ? DecorationImage(
                          image: FileImage(_capaBarcocalFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _capaBarcocalFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                          SizedBox(height: 6),
                          Text('Selecionar imagem de capa do roteiro', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.edit, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _criarRoteiroBarrocal,
              icon: Icon(Icons.route),
              label: Text('Criar Roteiro do Barrocal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Text(_status, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (c, i) => Text(_logs[i], style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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




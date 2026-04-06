import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ModelViewerScreen extends StatefulWidget {
  final String filePath; // Pode ser path local (/data/user/...) ou URL (https://...)
  final String title;

  const ModelViewerScreen({super.key, required this.filePath, required this.title});

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen> {
  @override
  Widget build(BuildContext context) {
    String src = widget.filePath;

    // Se NÃO for um link da internet (http/https), assumimos que é um ficheiro local
    // e precisamos de adicionar o prefixo 'file://'
    if (!src.startsWith('http')) {
      if (!src.startsWith('file://')) {
        src = 'file://$src';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      body: ModelViewer(
        src: src, // O package trata do resto
        alt: "Modelo 3D de ${widget.title}",
        ar: false,
        autoRotate: true,
        cameraControls: true,
        backgroundColor: Colors.white,
      ),
    );
  }
}
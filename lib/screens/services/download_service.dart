import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio = Dio();

  /// Faz o download de um ficheiro (imagem ou GLB) e devolve o caminho local.
  /// Se o ficheiro já existir, devolve logo o caminho sem gastar net.
  Future<String?> downloadFile(String url, String fileName) async {
    try {
      // 1. Encontrar a pasta segura da App para guardar documentos
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // 2. Verificar se já existe
      if (await file.exists()) {
        print("Ficheiro já existe localmente: $filePath");
        return filePath; // Devolve o caminho local imediatamente
      }

      // 3. Se não existe, faz o download
      print("A iniciar download de: $url");
      await _dio.download(
        url, 
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print("Download: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      print("Download concluído: $filePath");
      return filePath;

    } catch (e) {
      print("Erro no download: $e");
      return null;
    }
  }

  /// Verifica se um ficheiro existe sem tentar baixar
  Future<bool> checkFileExists(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    return await file.exists();
  }
}
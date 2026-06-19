import 'dart:io';

void main() {
  final directory = Directory('lib');
  final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('poi.dart') || file.path.contains('panorama.dart')) continue;

    String content = file.readAsStringSync();
    String original = content;

    // POI fields
    content = content.replaceAll('.name', '.nome');
    content = content.replaceAll(' name:', ' nome:'); // named parameters
    content = content.replaceAll('.category', '.categoria');
    content = content.replaceAll(' category:', ' categoria:');
    content = content.replaceAll('.location', '.localizacao');
    content = content.replaceAll(' location:', ' localizacao:');
    content = content.replaceAll('.images', '.imagens');
    content = content.replaceAll(' images:', ' imagens:');
    content = content.replaceAll('.descriptionMap', '.mapaDescricao');
    content = content.replaceAll(' descriptionMap:', ' mapaDescricao:');
    content = content.replaceAll('.audioMap', '.mapaAudio');
    content = content.replaceAll(' audioMap:', ' mapaAudio:');
    content = content.replaceAll('.arModelUrl', '.urlModeloAr');
    content = content.replaceAll(' arModelUrl:', ' urlModeloAr:');
    content = content.replaceAll('.arScale', '.escalaAr');
    content = content.replaceAll(' arScale:', ' escalaAr:');
    
    // Panorama fields
    content = content.replaceAll('.imageUrl', '.urlImagem');
    content = content.replaceAll(' imageUrl:', ' urlImagem:');
    content = content.replaceAll('.markers', '.marcadores');
    content = content.replaceAll(' markers:', ' marcadores:');
    content = content.replaceAll('.poiId', '.idPoi');
    content = content.replaceAll(' poiId:', ' idPoi:');
    content = content.replaceAll('.yaw', '.rotacaoHorizontal');
    content = content.replaceAll(' yaw:', ' rotacaoHorizontal:');
    content = content.replaceAll('.pitch', '.rotacaoVertical');
    content = content.replaceAll(' pitch:', ' rotacaoVertical:');

    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}

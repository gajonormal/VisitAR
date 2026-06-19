import 'dart:io';

void main() {
  final directory = Directory('lib');
  final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    String original = content;

    // Fix Icons.location
    content = content.replaceAll('Icons.localizacao', 'Icons.location');
    
    // Fix roteiro poiIds which got mangled to idPois
    // Let's just restore poiIds to poiIds in roteiro context, or rename it properly to idsPois if we want Portuguese.
    // Actually, roteiro.dart: Let's see if we want it to be 'poiIds' or 'idsPois'. Let's revert to 'poiIds' to not break more things.
    content = content.replaceAll('.idPois', '.poiIds');
    content = content.replaceAll(' idPois:', ' poiIds:');
    content = content.replaceAll('\'idPois\'', '\'poiIds\'');
    content = content.replaceAll('\"idPois\"', '\"poiIds\"');

    if (content != original) {
      file.writeAsStringSync(content);
      print('Fixed ${file.path}');
    }
  }
}

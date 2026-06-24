import 'dart:io';

void main() {
  var file = File('lib/screens/explore_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('HistÃƒÂ³rico', 'Histórico');
  content = content.replaceAll('GeolÃƒÂ³gico', 'Geológico');
  content = content.replaceAll('FÃƒÂ¡cil', 'Fácil');
  content = content.replaceAll('DifÃƒÂ­cil', 'Difícil');
  content = content.replaceAll('Ã¢â‚¬â€ ', '—');
  content = content.replaceAll('LÃƒâ€œGICA', 'LÓGICA');
  content = content.replaceAll('EspaÃƒÂ§o', 'Espaço');
  content = content.replaceAll('disponÃƒÂ­vel', 'disponível');
  content = content.replaceAll('CONTEÃƒÅ¡DO', 'CONTEÚDO');
  content = content.replaceAll('SCROLLÃƒÂ VEL', 'SCROLLÁVEL');
  content = content.replaceAll('SaudaÃƒÂ§ÃƒÂ£o', 'Saudação');
  content = content.replaceAll('prÃƒÂ³ximos', 'próximos');
  content = content.replaceAll('SECÃƒâ€¡ÃƒÆ’O', 'SECÇÃO');
  content = content.replaceAll('Ã¢â€ â‚¬', '─');
  content = content.replaceAll('saudÃƒÂ£o', 'saudação');
  content = content.replaceAll('ÃƒÂ­', 'í');
  content = content.replaceAll('ÃƒÂ³', 'ó');
  content = content.replaceAll('ÃƒÂ¡', 'á');
  content = content.replaceAll('ÃƒÂ§', 'ç');
  content = content.replaceAll('ÃƒÂ£', 'ã');
  content = content.replaceAll('ÃƒÂ©', 'é');
  content = content.replaceAll('ÃƒÂª', 'ê');
  file.writeAsStringSync(content);
}

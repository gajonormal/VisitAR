import 'package:flutter_test/flutter_test.dart';
import 'package:visitar_teste/screens/services/passport_service.dart';

void main() {
  group('Testes Lógicos: Validação do Passaporte e Progressão de Roteiros', () {
    
    test('Deve calcular corretamente a percentagem de um roteiro incompleto (40%)', () {
      // Simula que o utilizador visitou 2 locais de um roteiro que tem 5 no total
      const progress = RoteiroProgress(visitedCount: 2, total: 5);
      
      expect(progress.isCompleted, false);
      expect(progress.percentage, 0.4); 
    });

    test('Deve identificar o roteiro como 100% concluído e elegível para badge', () {
      // Simula que o utilizador visitou todos os 5 locais
      const progress = RoteiroProgress(visitedCount: 5, total: 5);
      
      expect(progress.isCompleted, true);
      expect(progress.percentage, 1.0); 
    });
    
    test('Prevenção de divisões por zero (Roteiros corrompidos sem POIs)', () {
      // Simula erro na base de dados em que o roteiro vem com 0 POIs
      const progress = RoteiroProgress(visitedCount: 0, total: 0);
      
      expect(progress.isCompleted, false);
      expect(progress.percentage, 0.0); // Verifica a segurança da divisão
    });
  });
}

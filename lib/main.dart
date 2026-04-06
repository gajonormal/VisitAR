import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_map.dart'; // Importamos o ficheiro que criámos

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase (Ignoramos erros no teste para não crashar se falhar net)
  try {
    await Firebase.initializeApp();
    print("Firebase ligado");
  } catch (e) {
    print("Erro Firebase (Verificar net): $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisitAR',
      debugShowCheckedModeBanner: false, // Tira a etiqueta "Debug" feia
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'GoogleSans', // Define a fonte padrão da app
      ),
      // A App começa no nosso mapa
      home: const HomeMap(),
    );
  }
}
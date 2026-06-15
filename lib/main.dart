import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Ficheiro gerado pelo FlutterFire CLI
import 'screens/home_map.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicialização moderna com suporte multi-plataforma
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase ligado à nova base de dados!");
  } catch (e) {
    print("Erro Firebase: $e");
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
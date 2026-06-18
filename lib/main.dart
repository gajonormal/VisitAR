import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Ficheiro gerado pelo FlutterFire CLI
import 'screens/home_map.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Forçar a barra de status do Android (bateria, relógio) a ficar transparente e com ícones escuros
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  
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
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      // A App começa no nosso mapa
      home: const HomeMap(),
    );
  }
}
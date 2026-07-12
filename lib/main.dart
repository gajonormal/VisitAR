import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Ficheiro gerado automaticamente pelo FlutterFire CLI
import 'screens/home_map.dart';
import 'package:provider/provider.dart';
import 'screens/services/language_provider.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configura a barra de estado do Android para fundo transparente e ícones escuros,
  // garantindo boa legibilidade sobre o mapa ou fundos claros.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  
  try {
    // Inicializa o Firebase com as opções da plataforma atual.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase ligado à nova base de dados!");
  } catch (e) {
    debugPrint("Erro Firebase: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'VisitAR',
          debugShowCheckedModeBanner: false,
          locale: languageProvider.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
            fontFamily: 'GoogleSans', // Fonte padrão da aplicação
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black, 
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                fontFamily: 'GoogleSans',
              ),
            ),
          ),
          // Ecrã inicial da aplicação
          home: const HomeMap(),
        );
      },
    );
  }
}
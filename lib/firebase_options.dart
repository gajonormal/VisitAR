// Ficheiro gerado automaticamente pelo FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opções de configuração padrão do Firebase, com suporte multi-plataforma.
///
/// Exemplo de uso:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions não estão configuradas para Linux — '
          'execute novamente o FlutterFire CLI para reconfigurar.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não são suportadas nesta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCnOr7yy_OWXXrsNEKGmdgMA3Jsvnk4luE',
    appId: '1:783187110716:web:ac4f7a749c869928124c39',
    messagingSenderId: '783187110716',
    projectId: 'visitar-6b7fd',
    authDomain: 'visitar-6b7fd.firebaseapp.com',
    storageBucket: 'visitar-6b7fd.firebasestorage.app',
    measurementId: 'G-E3VWFEYLXT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZdpdgYBINirK1_9pdVgksrcBR3rDob6Y',
    appId: '1:783187110716:android:d89fe4fe8c5dbfa8124c39',
    messagingSenderId: '783187110716',
    projectId: 'visitar-6b7fd',
    storageBucket: 'visitar-6b7fd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCwGWWZe84YKk5zeipwxWQ9FMaFC3tbdvc',
    appId: '1:783187110716:ios:4b0b6284baa3698a124c39',
    messagingSenderId: '783187110716',
    projectId: 'visitar-6b7fd',
    storageBucket: 'visitar-6b7fd.firebasestorage.app',
    iosBundleId: 'com.example.visitarTeste',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCwGWWZe84YKk5zeipwxWQ9FMaFC3tbdvc',
    appId: '1:783187110716:ios:4b0b6284baa3698a124c39',
    messagingSenderId: '783187110716',
    projectId: 'visitar-6b7fd',
    storageBucket: 'visitar-6b7fd.firebasestorage.app',
    iosBundleId: 'com.example.visitarTeste',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCnOr7yy_OWXXrsNEKGmdgMA3Jsvnk4luE',
    appId: '1:783187110716:web:69f25f81b38105cb124c39',
    messagingSenderId: '783187110716',
    projectId: 'visitar-6b7fd',
    authDomain: 'visitar-6b7fd.firebaseapp.com',
    storageBucket: 'visitar-6b7fd.firebasestorage.app',
    measurementId: 'G-4DTTF2ZYXK',
  );
}

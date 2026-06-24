import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final snapshot = await FirebaseFirestore.instance.collection('panoramas').get();
  print("PANORAMAS IN FIRESTORE: ${snapshot.docs.length}");
  for (var doc in snapshot.docs) {
    print(" - ${doc.id}");
  }
}

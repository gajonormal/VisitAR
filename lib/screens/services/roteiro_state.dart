import 'package:flutter/material.dart';
  import '../../models/roteiro.dart';

  // Variável global simples para gerir o roteiro ativo no mapa sem complexidade de state management (Provider/Riverpod)
  final ValueNotifier<Roteiro?> activeRoteiroNotifier = ValueNotifier<Roteiro?>(null);

import 'package:flutter/material.dart';
  import '../../models/roteiro.dart';

  // ValueNotifier global que mantém o roteiro atualmente ativo no mapa.
  // Usado como alternativa leve a soluções de state management como Provider ou Riverpod.
  final ValueNotifier<Roteiro?> activeRoteiroNotifier = ValueNotifier<Roteiro?>(null);

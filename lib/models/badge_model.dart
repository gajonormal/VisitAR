import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de dados que representa um badge (conquista) do utilizador.
class BadgeModel {
  final String id;
  final String titulo;
  final String descricao;
  /// Grupo do badge (ex: "exploração", "roteiros", "criação").
  final String categoria;
  final String urlIcone;
  /// Tipo de condição para desbloquear o badge
  /// (ex: "visitar_poi", "concluir_roteiro", "criar_roteiro", "visitar_categoria").
  final String condicaoTipo;
  /// Categoria específica exigida pela condição, ou string vazia se não aplicável.
  final String condicaoAlvo;
  final int quantidadeAlvo;

  BadgeModel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.categoria,
    required this.urlIcone,
    required this.condicaoTipo,
    required this.condicaoAlvo,
    required this.quantidadeAlvo,
  });

  /// Constrói um [BadgeModel] a partir de um documento do Firestore.
  factory BadgeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BadgeModel(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descricao: data['descricao'] ?? '',
      categoria: data['categoria'] ?? '',
      urlIcone: data['urlIcone'] ?? '',
      condicaoTipo: data['condicaoTipo'] ?? '',
      condicaoAlvo: data['condicaoAlvo'] ?? '',
      quantidadeAlvo: (data['quantidadeAlvo'] ?? 1).toInt(),
    );
  }

  /// Constrói um [BadgeModel] a partir de um mapa JSON (para leitura offline).
  factory BadgeModel.fromMap(Map<String, dynamic> data) {
    return BadgeModel(
      id: data['id'] ?? '',
      titulo: data['titulo'] ?? '',
      descricao: data['descricao'] ?? '',
      categoria: data['categoria'] ?? '',
      urlIcone: data['urlIcone'] ?? '',
      condicaoTipo: data['condicaoTipo'] ?? '',
      condicaoAlvo: data['condicaoAlvo'] ?? '',
      quantidadeAlvo: (data['quantidadeAlvo'] ?? 1).toInt(),
    );
  }

  /// Serializa o badge para um mapa, útil para persistência ou envio ao Firestore.
  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'descricao': descricao,
    'categoria': categoria,
    'urlIcone': urlIcone,
    'condicaoTipo': condicaoTipo,
    'condicaoAlvo': condicaoAlvo,
    'quantidadeAlvo': quantidadeAlvo,
  };
}

/// Badges pré-definidos para seed inicial no Firestore
final List<Map<String, dynamic>> kDefaultBadges = [
  // Badges de exploração — desbloqueados ao visitar pontos de interesse.
  {
    'id': 'primeiro_carimbo',
    'titulo': 'Primeiro Carimbo',
    'descricao': 'Visitaste o teu primeiro ponto de interesse!',
    'categoria': 'exploração',
    'urlIcone': '',
    'condicaoTipo': 'visitar_poi',
    'condicaoAlvo': '',
    'quantidadeAlvo': 1,
  },
  {
    'id': 'conhecedor',
    'titulo': 'Conhecedor',
    'descricao': 'Visitaste 5 pontos de interesse.',
    'categoria': 'exploração',
    'urlIcone': '',
    'condicaoTipo': 'visitar_poi',
    'condicaoAlvo': '',
    'quantidadeAlvo': 5,
  },
  {
    'id': 'colecionador',
    'titulo': 'Colecionador',
    'descricao': 'Visitaste 10 pontos de interesse.',
    'categoria': 'exploração',
    'urlIcone': '',
    'condicaoTipo': 'visitar_poi',
    'condicaoAlvo': '',
    'quantidadeAlvo': 10,
  },
  {
    'id': 'grande_explorador',
    'titulo': 'Grande Explorador',
    'descricao': 'Visitaste 25 pontos de interesse.',
    'categoria': 'exploração',
    'urlIcone': '',
    'condicaoTipo': 'visitar_poi',
    'condicaoAlvo': '',
    'quantidadeAlvo': 25,
  },
  // Badges de roteiros — desbloqueados ao concluir roteiros.
  {
    'id': 'primeiro_roteiro',
    'titulo': 'Primeiro Roteiro',
    'descricao': 'Completaste o teu primeiro roteiro!',
    'categoria': 'roteiros',
    'urlIcone': '',
    'condicaoTipo': 'concluir_roteiro',
    'condicaoAlvo': '',
    'quantidadeAlvo': 1,
  },
  {
    'id': 'aventureiro',
    'titulo': 'Aventureiro',
    'descricao': 'Completaste 3 roteiros.',
    'categoria': 'roteiros',
    'urlIcone': '',
    'condicaoTipo': 'concluir_roteiro',
    'condicaoAlvo': '',
    'quantidadeAlvo': 3,
  },
  {
    'id': 'viajante',
    'titulo': 'Viajante',
    'descricao': 'Completaste 5 roteiros.',
    'categoria': 'roteiros',
    'urlIcone': '',
    'condicaoTipo': 'concluir_roteiro',
    'condicaoAlvo': '',
    'quantidadeAlvo': 5,
  },
  // Badges de criação — desbloqueados ao criar roteiros.
  {
    'id': 'criador',
    'titulo': 'Criador',
    'descricao': 'Criaste o teu primeiro roteiro!',
    'categoria': 'criação',
    'urlIcone': '',
    'condicaoTipo': 'criar_roteiro',
    'condicaoAlvo': '',
    'quantidadeAlvo': 1,
  },
  {
    'id': 'guia_local',
    'titulo': 'Guia Local',
    'descricao': 'Criaste 3 roteiros.',
    'categoria': 'criação',
    'urlIcone': '',
    'condicaoTipo': 'criar_roteiro',
    'condicaoAlvo': '',
    'quantidadeAlvo': 3,
  },
];

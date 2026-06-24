import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'services/passport_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  static const Color kPrimaryGreen = Color(0xFF0F9D58);
  static const Color kGold = Color(0xFFFFD700);

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  @override
  void initState() {
    super.initState();
    _seedBadgesIfNeeded();
  }

  Future<void> _seedBadgesIfNeeded() async {
    final snap = await FirebaseFirestore.instance.collection('badges').limit(1).get();
    if (snap.docs.isEmpty) {
      await PassportService().seedBadges();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Scaffold(body: Center(child: Text(AppLocalizations.of(context)!.sessionRequired)));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(AppLocalizations.of(context)!.myPassport,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            labelColor: PassportScreen.kPrimaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: PassportScreen.kPrimaryGreen,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(text: AppLocalizations.of(context)!.stampsTab),
              Tab(text: AppLocalizations.of(context)!.achievementsTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StampsTab(uid: uid),
            _BadgesTab(uid: uid),
          ],
        ),
      ),
    );
  }
}

// ————————————————————————————————————————————————
// TAB: CARIMBOS (Visitas)
// ————————————————————————————————————————————————
class _StampsTab extends StatelessWidget {
  final String uid;
  const _StampsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('visits')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: PassportScreen.kPrimaryGreen));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: PassportScreen.kPrimaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_on_outlined, color: PassportScreen.kPrimaryGreen, size: 38),
                ),
                SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.noStampsYet,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.noStampsSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contador
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: PassportScreen.kPrimaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.approval, color: PassportScreen.kPrimaryGreen, size: 28),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${docs.length} ${docs.length == 1 ? AppLocalizations.of(context)!.placesVisitedSingular : AppLocalizations.of(context)!.placesVisited}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!.continueExploring,
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final name = data['poiName'] ?? 'Local';
                    final category = data['poiCategory'] ?? '';
                    final image = data['poiImage'] ?? '';
                    final ts = data['timestamp'] as Timestamp?;
                    final date = ts != null
                        ? '${ts.toDate().day.toString().padLeft(2,'0')}/${ts.toDate().month.toString().padLeft(2,'0')}/${ts.toDate().year}'
                        : '';

                    return _StampCard(
                      nome: name,
                      categoria: category,
                      image: image,
                      date: date,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _getCategoryTranslation(BuildContext context, String category) {
  switch (category) {
    case 'Histórico':
      return AppLocalizations.of(context)!.catHistoric;
    case 'Natureza':
      return AppLocalizations.of(context)!.catNature;
    case 'Geológico':
      return AppLocalizations.of(context)!.catGeologic;
    case 'Trilho':
      return AppLocalizations.of(context)!.catTrail;
    case 'Gastronomia':
      return AppLocalizations.of(context)!.catGastronomy;
    default:
      return category;
  }
}


class _StampCard extends StatelessWidget {
  final String nome, categoria, image, date;
  const _StampCard({required this.nome, required this.categoria, required this.image, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F9D58).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Imagem / Placeholder
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image.isNotEmpty
                      ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (_,__,___) => _placeholder())
                      : _placeholder(),
                  // Carimbo overlay
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: PassportScreen.kPrimaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (categoria.isNotEmpty)
                  Text(_getCategoryTranslation(context, categoria), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                if (date.isNotEmpty)
                  Text(date, style: TextStyle(color: PassportScreen.kPrimaryGreen, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey[100],
    child: Center(child: Icon(Icons.location_on, color: Colors.grey, size: 36)),
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TAB: CONQUISTAS (Badges)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _BadgesTab extends StatelessWidget {
  final String uid;
  const _BadgesTab({required this.uid});

  // Icons por categoria
  static const Map<String, IconData> _categoryIcons = {
    'exploraÃ§Ã£o': Icons.map_outlined,
    'roteiros': Icons.route_outlined,
    'criaÃ§Ã£o': Icons.edit_location_alt_outlined,
  };

  // Icons por badge ID
  static const Map<String, IconData> _badgeIcons = {
    'primeiro_carimbo': Icons.pin_drop_outlined,
    'conhecedor': Icons.account_balance_outlined,
    'colecionador': Icons.flag_circle_outlined,
    'grande_explorador': Icons.public_outlined,
    'primeiro_roteiro': Icons.map_outlined,
    'aventureiro': Icons.emoji_events_outlined,
    'viajante': Icons.flight_takeoff_outlined,
    'criador': Icons.edit_outlined,
    'guia_local': Icons.military_tech_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('badges').snapshots(),
      builder: (context, allBadgesSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('badges')
              .snapshots(),
          builder: (context, userBadgesSnap) {
            if (allBadgesSnap.hasError) {
              return Center(child: Text('Erro: ${allBadgesSnap.error}'));
            }
            if (userBadgesSnap.hasError) {
              return Center(child: Text('Erro: ${userBadgesSnap.error}'));
            }
            if (allBadgesSnap.connectionState == ConnectionState.waiting ||
                userBadgesSnap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: PassportScreen.kPrimaryGreen));
            }

            final allBadges = allBadgesSnap.data?.docs ?? [];
            final earnedIds = (userBadgesSnap.data?.docs ?? []).map((d) => d.id).toSet();

            if (allBadges.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(AppLocalizations.of(context)!.noAchievementsDefined),
                ),
              );
            }

            // Agrupar por categoria
            final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
            for (final doc in allBadges) {
              final cat = doc.data()['categoria'] as String? ?? 'outros';
              grouped.putIfAbsent(cat, () => []).add(doc);
            }

            final earned = earnedIds.length;
            final total = allBadges.length;

            return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header de progresso
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PassportScreen.kGold.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.military_tech_outlined, color: PassportScreen.kGold, size: 32),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.achievementsProgress(earned, total),
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total > 0 ? earned / total : 0,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(PassportScreen.kGold),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Por categoria
            ...grouped.entries.map((entry) {
              final cat = entry.key;
              final badges = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_categoryIcons[cat] ?? Icons.category_outlined, size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        _getBadgeCategoryTranslation(context, cat),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ...badges.map((badgeDoc) {
                    final data = badgeDoc.data();
                    final badgeId = badgeDoc.id;
                    final isEarned = earnedIds.contains(badgeId);
                    final icon = _badgeIcons[badgeId] ?? Icons.star_border;
                    return _BadgeTile(
                      badgeId: badgeId,
                      icon: icon,
                      titulo: data['titulo'] ?? '',
                      descricao: data['descricao'] ?? '',
                      quantidadeAlvo: (data['quantidadeAlvo'] ?? 1).toInt(),
                      condicaoTipo: data['condicaoTipo'] ?? '',
                      isEarned: isEarned,
                    );
                  }),
                  SizedBox(height: 20),
                ],
              );
            }),
          ],
        );
          },
        );
      },
    );
  }

  String _getBadgeCategoryTranslation(BuildContext context, String category) {
    switch (category.toLowerCase()) {
      case 'exploraÃ§Ã£o':
        return AppLocalizations.of(context)!.badgeCatExploration;
      case 'roteiros':
        return AppLocalizations.of(context)!.badgeCatItineraries;
      case 'criaÃ§Ã£o':
        return AppLocalizations.of(context)!.badgeCatCreation;
      default:
        return category.isNotEmpty ? category[0].toUpperCase() + category.substring(1) : '';
    }
  }
}

class _BadgeTile extends StatelessWidget {
  final String badgeId;
  final IconData icon;
  final String titulo, descricao, condicaoTipo;
  final int quantidadeAlvo;
  final bool isEarned;

  const _BadgeTile({
    required this.badgeId,
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.quantidadeAlvo,
    required this.condicaoTipo,
    required this.isEarned,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEarned ? const Color(0xFFFFD700) : Colors.grey[200]!,
          width: isEarned ? 1.5 : 1,
        ),
        boxShadow: isEarned
            ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEarned ? const Color(0xFFFFD700).withValues(alpha: 0.15) : Colors.grey[50],
              border: isEarned ? null : Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Icon(
                isEarned ? icon : Icons.lock_outline_rounded,
                size: 26, 
                color: isEarned ? const Color(0xFFD4AF37) : Colors.grey[400],
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getBadgeTitle(context, badgeId, titulo),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isEarned ? Colors.black : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _getBadgeDesc(context, badgeId, descricao),
                  style: TextStyle(fontSize: 12, color: isEarned ? Colors.grey[700] : Colors.grey[400]),
                ),
              ],
            ),
          ),
          if (isEarned)
            Icon(Icons.verified, color: Color(0xFFFFD700), size: 20),
        ],
      ),
    );
  }

  String _getBadgeTitle(BuildContext context, String badgeId, String defaultVal) {
    switch (badgeId) {
      case 'primeiro_carimbo': return AppLocalizations.of(context)!.badgePrimeiroCarimboTitle;
      case 'conhecedor': return AppLocalizations.of(context)!.badgeConhecedorTitle;
      case 'colecionador': return AppLocalizations.of(context)!.badgeColecionadorTitle;
      case 'grande_explorador': return AppLocalizations.of(context)!.badgeGrandeExploradorTitle;
      case 'primeiro_roteiro': return AppLocalizations.of(context)!.badgePrimeiroRoteiroTitle;
      case 'aventureiro': return AppLocalizations.of(context)!.badgeAventureiroTitle;
      case 'viajante': return AppLocalizations.of(context)!.badgeViajanteTitle;
      case 'criador': return AppLocalizations.of(context)!.badgeCriadorTitle;
      case 'guia_local': return AppLocalizations.of(context)!.badgeGuiaLocalTitle;
      default: return defaultVal;
    }
  }

  String _getBadgeDesc(BuildContext context, String badgeId, String defaultVal) {
    switch (badgeId) {
      case 'primeiro_carimbo': return AppLocalizations.of(context)!.badgePrimeiroCarimboDesc;
      case 'conhecedor': return AppLocalizations.of(context)!.badgeConhecedorDesc;
      case 'colecionador': return AppLocalizations.of(context)!.badgeColecionadorDesc;
      case 'grande_explorador': return AppLocalizations.of(context)!.badgeGrandeExploradorDesc;
      case 'primeiro_roteiro': return AppLocalizations.of(context)!.badgePrimeiroRoteiroDesc;
      case 'aventureiro': return AppLocalizations.of(context)!.badgeAventureiroDesc;
      case 'viajante': return AppLocalizations.of(context)!.badgeViajanteDesc;
      case 'criador': return AppLocalizations.of(context)!.badgeCriadorDesc;
      case 'guia_local': return AppLocalizations.of(context)!.badgeGuiaLocalDesc;
      default: return defaultVal;
    }
  }
}


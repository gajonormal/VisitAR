import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi.dart';
import '../screens/details_screen.dart';

class PoiCard extends StatelessWidget {
  final POI poi;
  final Position? userPosition;

  const PoiCard({
    Key? key,
    required this.poi,
    this.userPosition,
  }) : super(key: key);

  String _formatDistance(POI poi) {
    if (userPosition == null) return '— km';
    double dist = Geolocator.distanceBetween(
        userPosition!.latitude, userPosition!.longitude,
        poi.localizacao.latitude, poi.localizacao.longitude);
    if (dist < 1000) return '${dist.toStringAsFixed(0)} m';
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'geológico':   return const Color(0xFFE67E22);
      case 'histórico':   return const Color(0xFF8B4513);
      case 'natureza':    return const Color(0xFF27AE60);
      case 'trilho':      return const Color(0xFF2980B9);
      case 'gastronomia': return const Color(0xFFC0392B);
      default:            return const Color(0xFF7F8C8D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(poi.categoria);
    final distStr = _formatDistance(poi);
    final String? imagePath = poi.imagens.isNotEmpty ? poi.imagens.first : null;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(poi: poi))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80, height: 80,
                child: imagePath == null || imagePath.isEmpty
                    ? Container(color: Colors.grey[200], child: Icon(Icons.landscape, color: Colors.grey[400]))
                    : imagePath.startsWith('http')
                        ? Image.network(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]))
                        : Image.file(File(imagePath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200])),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poi.categoria.toUpperCase(), style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  const SizedBox(height: 3),
                  Text(poi.nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(poi.description, style: TextStyle(fontSize: 12.5, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(distStr, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

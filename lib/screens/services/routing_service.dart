import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class RoutingService {
  static const String _osrmBaseUrl = 'http://router.project-osrm.org/route/v1/foot';

  /// Obtém a rota pedestre entre dois pontos usando OSRM.
  /// Retorna a lista de pontos (LatLng) que formam a rota.
  /// Caso a rota seja inválida ou desproporcional (fallback), devolve apenas uma linha reta (os dois pontos).
  static Future<List<LatLng>> getPedestrianRoute(LatLng start, LatLng end) async {
    try {
      final url = '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          // Distância real calculada pelo OSRM em metros
          final double osrmDistance = (route['distance'] as num).toDouble();
          
          // Distância em linha reta (bird's-eye view)
          final double straightLineDistance = Geolocator.distanceBetween(
            start.latitude, start.longitude,
            end.latitude, end.longitude,
          );

          // Lógica de Fallback: Se a distância real for mais do triplo da linha reta
          // e a linha reta for maior que 30 metros (para evitar falsos positivos perto de esquinas),
          // assumimos que não há trilho mapeado e o utilizador está a ser levado para muito longe.
          if (straightLineDistance > 30 && osrmDistance > (straightLineDistance * 3.5)) {
            print("OSRM Fallback ativado: Rota muito longa ($osrmDistance m vs $straightLineDistance m). Usando linha reta.");
            return [start, end];
          }

          final coordinates = route['geometry']['coordinates'] as List;
          List<LatLng> points = [];
          
          for (var coord in coordinates) {
            // GeoJSON devolve [longitude, latitude]
            points.add(LatLng(coord[1], coord[0]));
          }
          
          return points;
        }
      }
      
      // Se a API falhou por alguma razão, desenha linha reta de segurança
      return [start, end];
    } catch (e) {
      print("Erro no RoutingService: $e");
      // Fallback para linha reta
      return [start, end];
    }
  }

  /// Obtém uma rota contínua que passa por múltiplos POIs.
  static Future<List<LatLng>> getFullRoteiroRoute(List<LatLng> waypoints) async {
    if (waypoints.isEmpty) return [];
    if (waypoints.length == 1) return waypoints;

    List<LatLng> fullRoute = [];
    
    // Conecta cada ponto ao seguinte usando OSRM
    for (int i = 0; i < waypoints.length - 1; i++) {
      List<LatLng> segment = await getPedestrianRoute(waypoints[i], waypoints[i+1]);
      
      // Evita duplicar o ponto de ligação (o fim de um segmento é o início do outro)
      if (fullRoute.isNotEmpty && segment.isNotEmpty) {
        if (fullRoute.last == segment.first) {
          segment.removeAt(0);
        }
      }
      
      fullRoute.addAll(segment);
    }
    
    return fullRoute;
  }
}

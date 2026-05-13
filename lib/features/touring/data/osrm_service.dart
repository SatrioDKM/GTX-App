import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmService {
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = 'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          
          List<LatLng> polyline = geometry.map((coord) {
            return LatLng(coord[1], coord[0]); // OSRM returns [lon, lat]
          }).toList();
          
          return polyline;
        }
      }
    } catch (e) {
      print('OSRM Error: $e');
    }
    return [];
  }
}

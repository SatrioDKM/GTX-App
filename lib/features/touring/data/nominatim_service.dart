import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NominatimResult {
  final String displayName;
  final LatLng position;

  NominatimResult({required this.displayName, required this.position});
}

class NominatimService {
  Future<List<NominatimResult>> search(String query) async {
    if (query.isEmpty) return [];
    
    final url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=id';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'GTX-App/1.0 (satrio@email.com)',
        },
      );
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        
        return data.map((item) {
          return NominatimResult(
            displayName: item['display_name'] ?? 'Unknown Location',
            position: LatLng(
              double.parse(item['lat']),
              double.parse(item['lon']),
            ),
          );
        }).toList();
      }
    } catch (e) {
      print('Nominatim Error: $e');
    }
    return [];
  }
}

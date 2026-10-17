import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceResult {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const PlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class SearchService {
  static const _ak = 'zDsYNenGh84qZGOV9R1XujAbcxOGF29Q';
  static const _baseUrl = 'https://api.map.baidu.com/place/v2/search';

  static Future<List<PlaceResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'query': query,
      'region': '全国',
      'output': 'json',
      'ak': _ak,
      'page_size': '10',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data['status'] != 0) return [];

      final results = data['results'] as List?;
      if (results == null) return [];

      return results.map((r) {
        final loc = r['location'];
        return PlaceResult(
          name: r['name']?.toString() ?? '',
          address: r['address']?.toString() ?? '',
          lat: (loc['lat'] as num).toDouble(),
          lng: (loc['lng'] as num).toDouble(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

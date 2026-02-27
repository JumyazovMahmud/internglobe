import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/internship.dart';

class ApiService {
  static const String baseUrl = 'https://internships-api.p.rapidapi.com/active-ats-7d';
  static const Map<String, String> headers = {
    'X-RapidAPI-Key': '9daddf84ccmshff55fdfab91ff4ep1d3b04jsnd2d3c03217ba',
    'X-RapidAPI-Host': 'internships-api.p.rapidapi.com',
  };

  // Add timeout to prevent long waits
  Future<List<Internship>> fetchInternships({
    String? titleFilter,
    String? locationFilter,
    bool remote = false,
    int offset = 0,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      if (titleFilter != null && titleFilter.isNotEmpty) 'title_filter': titleFilter,
      if (locationFilter != null && locationFilter.isNotEmpty) 'location_filter': locationFilter,
      'remote': remote.toString(),
      'offset': offset.toString(),
    });

    try {
      // Add 10 second timeout
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - please check your connection');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Internship.fromJson(json)).toList();
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit reached - please wait a moment');
      } else {
        throw Exception('Failed to load internships: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
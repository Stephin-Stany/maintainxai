import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl = "http://localhost:8000";

  static Future<Map<String, dynamic>> getOverview() async {
    final response = await http.get(
      Uri.parse("$baseUrl/dashboard/overview"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load overview data");
    }
  }

  static Future<Map<String, dynamic>> getMaintenance() async {
    final response = await http.get(
      Uri.parse("$baseUrl/dashboard/maintenance"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load maintenance data");
    }
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:html' as html; // Used for triggering downloads in Flutter Web

class ApiService {
  // Use http://10.0.2.2:8000 for Android Emulator 
  // or http://localhost:8000 for iOS/Web/Desktop
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<Map<String, dynamic>> getSyncStatus() async {
  try {
    final response = await http.get(
      Uri.parse("$baseUrl/system-sync-status"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Sync check failed");
    }
  } catch (e) {
    return {"status": "offline", "issues": [e.toString()]};
  }
}

  /// Fetches general factory performance metrics
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

  /// Fetches ROI and maintenance history data
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

  /// Triggers a Gmail SMTP service request for a specific machine with dynamic urgency
  static Future<bool> sendServiceRequest(int machineId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/service-request/$machineId"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Backend Error: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Connection Error: $e");
      return false;
    }
  }

  /// NEW: Downloads machine-specific logs as a CSV file to the PC
  static Future<void> downloadLogs(int machineId) async {
    final String url = "$baseUrl/export-logs/$machineId";
    
    // For Web: Triggers the browser's download manager using a hidden anchor element
    html.AnchorElement anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "machine_${machineId}_logs.csv")
      ..click();
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // Replace this with your actual Gemini API Key from Google AI Studio.
  // DO NOT publish your app to GitHub with this key visible!
  static const String _apiKey = "PLACEHOLDER_API_KEY_HERE"; 
  static const String _baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

  Future<String> sendMessage(String message) async {
    if (_apiKey == "PLACEHOLDER_API_KEY_HERE") {
      // Fake response meant to guide the student to paste the key
      await Future.delayed(const Duration(seconds: 1));
      return "Hi there! This is a placeholder since the API Key isn't set yet. Add your Gemini API key in lib/services/gemini_service.dart to make me smart!";
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "You are a calming, non-medical mental health companion. User says: $message"}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return "I'm having a little trouble connecting right now. Let's take a deep breath.";
      }
    } catch (e) {
      return "An error occurred: $e. Please check your internet connection.";
    }
  }
}

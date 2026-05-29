import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MoodSummaryService {
  static final String _apiKey = dotenv.get(
    'OPENROUTER_API_KEY_SUMMARY',
    fallback: '',
  );
  static const String _baseUrl =
      "https://openrouter.ai/api/v1/chat/completions";

  static const List<List<String>> _modelGroups = [
    [
      "qwen/qwen-2.5-72b-instruct:free",
      "meta-llama/llama-3.3-70b-instruct:free",
      "google/gemini-flash-1.5:free",
    ],
    [
      "deepseek/deepseek-r1:free",
      "mistralai/mistral-small-24b-instruct-2501:free",
      "google/gemini-2.0-flash-lite-preview-02-05:free",
    ],
    [
      "openai/gpt-4o-mini",
      "anthropic/claude-3-haiku",
      "mistralai/mistral-nemo",
    ],
  ];

  static const String _systemPrompt =
      '''You are a compassionate mental wellness journal analyst. 
Your job is to read the user's mood logs, journal entries, 
and chat conversations from a single day and write a short, 
warm, human-sounding paragraph (3-4 sentences max) that 
reflects back WHY they may have felt that way.

Rules:
- Be specific to what they actually wrote, never generic
- Do not give advice or suggestions
- Do not use clinical language
- Do not start with "It seems like" or "Based on your data"
- Speak directly to the user using "you" and "your"
- If the mood was negative, validate without dramatizing
- If the mood was positive, celebrate simply
- Keep it under 80 words
- Return plain text only, no bullet points, no titles''';

  Future<String> generateDailySummary(
    String dateStr,
    String userDataText,
  ) async {
    if (_apiKey.isEmpty) {
      return "Summary unavailable right now, try again later (API key missing)";
    }

    if (userDataText.trim().isEmpty) {
      return "";
    }

    for (int i = 0; i < _modelGroups.length; i++) {
      final group = _modelGroups[i];

      try {
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
                'HTTP-Referer': 'https://mentalbloom.app',
                'X-Title': 'MentalBloom',
              },
              body: jsonEncode({
                "models": group,
                "route": "fallback",
                "messages": [
                  {"role": "system", "content": _systemPrompt},
                  {
                    "role": "user",
                    "content":
                        "Here is the user's data for $dateStr:\n\n$userDataText",
                  },
                ],
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choices = data['choices'];
          if (choices is List && choices.isNotEmpty) {
            final text = choices.first['message']?['content'];
            if (text is String && text.trim().isNotEmpty) {
              String cleanedText = text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
              if (cleanedText.isNotEmpty) {
                return cleanedText;
              }
            }
          }
        } else if (response.statusCode == 429) {
          if (i < _modelGroups.length - 1) {
            continue;
          }
        }
      } catch (e) {
      }
    }

    return "Summary unavailable right now, try again later";
  }
}

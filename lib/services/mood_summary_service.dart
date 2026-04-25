import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MoodSummaryService {
  static final String _apiKey = dotenv.get('OPENROUTER_API_KEY_SUMMARY', fallback: '');
  static const String _baseUrl = "https://openrouter.ai/api/v1/chat/completions";

  static const List<List<String>> _modelGroups = [
    // Group 1 - Free & Fast (try first)
    [
      "google/gemma-3-4b-it:free",
      "google/gemma-3-1b-it:free",
      "mistralai/mistral-7b-instruct:free",
      "meta-llama/llama-3-8b-instruct:free",
      "meta-llama/llama-3.2-3b-instruct:free",
      "meta-llama/llama-3.2-1b-instruct:free",
      "qwen/qwen-2.5-7b-instruct:free",
      "qwen/qwen-2-7b-instruct:free",
      "microsoft/phi-3-mini-128k-instruct:free",
      "microsoft/phi-3-medium-128k-instruct:free",
      "huggingfaceh4/zephyr-7b-beta:free",
      "openchat/openchat-7b:free",
    ],
    // Group 2 - Free & Better (fallback)
    [
      "google/gemma-3-12b-it:free",
      "google/gemma-3-27b-it:free",
      "mistralai/mixtral-8x7b-instruct:free",
      "meta-llama/llama-3.1-8b-instruct:free",
      "meta-llama/llama-3.1-70b-instruct:free",
      "nousresearch/nous-capybara-7b:free",
      "qwen/qwen-2.5-72b-instruct:free",
      "mistralai/mistral-nemo:free",
    ],
    // Group 3 - Free & Powerful (fallback)
    [
      "deepseek/deepseek-r1:free",
      "deepseek/deepseek-chat:free",
      "meta-llama/llama-3.3-70b-instruct:free",
      "meta-llama/llama-4-scout:free",
      "nvidia/llama-3.1-nemotron-70b-instruct:free",
      "google/gemini-2.0-flash-thinking-exp:free",
      "google/gemini-2.0-flash-exp:free",
      "google/learnlm-1.5-pro-experimental:free",
      "mistralai/mistral-small-3.1-24b-instruct:free",
    ],
    // Group 4 - Paid but cheap (last resort)
    [
      "mistralai/mistral-7b-instruct",
      "google/gemma-2-9b-it",
      "meta-llama/llama-3.1-8b-instruct",
      "qwen/qwen-2.5-7b-instruct",
      "microsoft/phi-3-medium-128k-instruct",
      "mistralai/mistral-nemo",
      "google/gemma-2-27b-it",
      "mistralai/mixtral-8x7b-instruct",
    ]
  ];

  static const String _systemPrompt = '''You are a compassionate mental wellness journal analyst. 
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

  Future<String> generateDailySummary(String dateStr, String userDataText) async {
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
                  {
                    "role": "system",
                    "content": _systemPrompt,
                  },
                  {"role": "user", "content": "Here is the user's data for $dateStr:\n\n$userDataText"},
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
              return text.trim();
            }
          }
        } else if (response.statusCode == 429) {
          // Rate limit, try next group
          if (i < _modelGroups.length - 1) {
            continue;
          }
        } else {
          // Keep trying or fail silently
        }
      } catch (e) {
        // network exception, try next group or fail
      }
    }

    return "Summary unavailable right now, try again later";
  }
}

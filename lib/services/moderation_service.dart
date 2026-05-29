import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ModerationResult {
  final bool safe;
  final String? reason;

  ModerationResult({required this.safe, this.reason});
}

class ModerationService {
  final List<List<String>> modelGroups = [
    [
      "qwen/qwen-2.5-72b-instruct:free",
      "meta-llama/llama-3.3-70b-instruct:free",
      "google/gemini-flash-1.5:free"
    ],
    [
      "deepseek/deepseek-r1:free",
      "mistralai/mistral-small-24b-instruct-2501:free",
      "google/gemini-2.0-flash-lite-preview-02-05:free"
    ],
    [
      "openai/gpt-4o-mini",
      "anthropic/claude-3-haiku",
      "mistralai/mistral-nemo"
    ]
  ];

  Future<ModerationResult?> tryModerate(String content, List<String> group) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final prompt = '''
You are a content moderator for a mental health support app. A user wants to post this message:

"$content"

Respond ONLY with a valid JSON object, no extra text, no markdown, no explanation:
{
  "safe": true or false,
  "reason": "brief reason if unsafe, null if safe"
}

Mark UNSAFE if the content contains:
- Mockery, judgment or dismissiveness
- Anything that could worsen mental state
- Toxic positivity that invalidates feelings
- Any form of bullying or cruelty
- Triggering content related to self harm
- Sarcasm that could be hurtful
- Hate speech of any kind

Mark SAFE if the content is:
- Supportive and empathetic
- Sharing personal experience to help
- Encouraging without dismissing pain
- Neutral and kind
- A personal story or feeling
''';

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://mentalbloom.app',
          'X-Title': 'Mental Bloom',
        },
        body: jsonEncode({
          'models': group,
          'route': 'fallback',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['choices'][0]['message']['content'];

        text = text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();

        try {
          final parsed = jsonDecode(text);
          return ModerationResult(
            safe: parsed['safe'] ?? true,
            reason: parsed['reason'],
          );
        } catch (e) {
          return ModerationResult(safe: true);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ModerationResult> moderateContent(String content) async {
    for (List<String> group in modelGroups) {
      final result = await tryModerate(content, group);
      if (result != null) {
        return result;
      }
    }

    // Fail-Closed: If all AI groups fail, we block the post to ensure community safety
    return ModerationResult(
      safe: false,
      reason: "Moderation service is temporarily unavailable. Please try again in a moment.",
    );
  }
}

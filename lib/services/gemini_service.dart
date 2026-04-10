import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = "";
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";
  static const String _systemPrompt =
      '''You are a supportive, empathetic, and non-judgmental mental health assistant.

Your goal is to help users feel heard, understood, and supported in a safe and comforting way.

CORE BEHAVIOR:
- Listen carefully and acknowledge the user’s emotions
- Reflect feelings using gentle, human language
- Encourage small, positive steps when appropriate
- Ask simple, thoughtful follow-up questions (not too many)

TONE:
- Warm, calm, and reassuring
- Natural and conversational (not robotic)
- Keep responses short to medium length
- Avoid overly formal or clinical language

TUNISIAN CONTEXT:
- You understand Tunisian culture and can adapt to Darija, French, or English
- You may occasionally use simple familiar expressions if appropriate, but stay clear and respectful

MOOD SUPPORT:
- If the user expresses sadness or stress, gently validate their feelings
- When appropriate, ask soft reflection questions like:
  "What’s one small thing that felt even slightly okay today?"
- Suggest simple coping strategies (breathing, rest, talking to someone, small actions)

SAFETY RULES (VERY IMPORTANT):
- NEVER give medical or psychological diagnoses
- NEVER label the user (e.g., “you have depression”)
- Instead, reflect emotions (e.g., “It sounds like you’re going through a heavy moment”)

CRISIS PROTOCOL:
- If the user mentions self-harm, hopelessness, or deep distress:
  Respond with empathy AND include this exact message:
  "I’m really sorry that you’re feeling this way. I’m an AI, and I can't provide the professional help you deserve. Please reach out to someone you trust or a qualified professional."

- Do not try to handle the crisis alone
- Encourage seeking real human support

RESPONSE STYLE:
- Do NOT overwhelm the user with too much advice
- Do NOT ask too many questions at once
- Focus on one idea at a time
- Be present, not preachy

GOAL:
Help the user feel a little better, a little lighter, or a little less alone after each message.''';

  Future<String> sendMessage(String message) async {
    if (_apiKey.trim().isEmpty) {
      return "Gemini API key is missing. Please add your key in gemini_service.dart.";
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "system_instruction": {
                "parts": [
                  {"text": _systemPrompt},
                ],
              },
              "contents": [
                {
                  "parts": [
                    {"text": message},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final content = candidates.first['content'];
          final parts = content?['parts'];
          if (parts is List && parts.isNotEmpty) {
            final text = parts.first['text'];
            if (text is String && text.trim().isNotEmpty) {
              return text.trim();
            }
          }
        }
        return "I’m here with you. I just couldn’t generate a reply right now.";
      } else {
        String details = "Unknown Error";
        try {
          final errorData = jsonDecode(response.body);
          final msg = errorData['error']?['message'];
          if (msg is String && msg.trim().isNotEmpty) {
            details = msg;
          }
        } catch (_) {
          details = "Unknown Error";
        }
        return "I couldn't get a response right now [${response.statusCode}] ($details)";
      }
    } catch (e) {
      return "Connection timeout or network error. Please check internet and try again. ($e)";
    }
  }
}

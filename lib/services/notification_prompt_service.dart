import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPromptService {
  static const String _nextPromptAtKey = 'notification_prompt_next_at_ms';

  static Future<bool> shouldShowPrompt() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final nextPromptAtMs = prefs.getInt(_nextPromptAtKey);
    if (nextPromptAtMs == null) {
      return true;
    }

    return DateTime.now().millisecondsSinceEpoch >= nextPromptAtMs;
  }

  static Future<void> deferForOneDay() async {
    final prefs = await SharedPreferences.getInstance();
    final nextPromptAt = DateTime.now().add(const Duration(days: 1));
    await prefs.setInt(_nextPromptAtKey, nextPromptAt.millisecondsSinceEpoch);
  }

  static Future<void> clearDeferral() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nextPromptAtKey);
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/gemini_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _msgController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _hasAgreedToDisclaimer = false;

  @override
  void initState() {
    super.initState();
    // Show disclaimer naturally after screen finishes building
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMedicalDisclaimer();
    });
  }

  void _showMedicalDisclaimer() {
    showDialog(
      context: context,
      barrierDismissible: false, // Must click agree to close
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Disclaimer'),
          ],
        ),
        content: const Text(
          "This app is not a medical device or a substitute for professional help. "
          "If you are in crisis or having thoughts of hurting yourself, please contact emergency services immediately.",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() {
                _hasAgreedToDisclaimer = true;
                _messages.add({
                  'sender': 'bot',
                  'text': 'Hello! I am here to listen. How are you feeling today?'
                });
              });
              Navigator.pop(context);
            },
            child: const Text('I Understand', style: TextStyle(color: AppColors.textMain)),
          )
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _msgController.clear();

    final response = await _geminiService.sendMessage(text);

    if (!mounted) return;
    setState(() {
      _messages.add({'sender': 'bot', 'text': response});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Companion', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        elevation: 1,
      ),
      body: !_hasAgreedToDisclaimer
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['sender'] == 'user';
                      
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : AppColors.white,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                              bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            msg['text'],
                            style: const TextStyle(fontSize: 16, color: AppColors.textMain),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          )
        ],
      ),
    );
  }
}

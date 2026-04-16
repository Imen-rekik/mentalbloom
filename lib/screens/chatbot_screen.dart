import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/ai_service.dart';


class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _msgController = TextEditingController();
  final AIService _aiService = AIService();

  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  //
  //
  // greeting from the bot
  @override
  void initState() {
    super.initState();
    _messages.add({
      'sender': 'bot',
      'text': 'Hello! I am here to listen. How are you feeling today?',
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  //
  //
  //
  // handling sending message and bot response
  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollToBottom();
    _msgController.clear();

    final response = await _aiService.sendMessage(text);


    if (!mounted) return;
    setState(() {
      _messages.add({'sender': 'bot', 'text': response});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  //
  //
  // scroll to bottom when new message
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  //
  //
  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'AI Companion',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        elevation: 1,
      ),
      //
      // chat
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser
                            ? const Radius.circular(0)
                            : const Radius.circular(16),
                        bottomLeft: !isUser
                            ? const Radius.circular(0)
                            : const Radius.circular(16),
                      ),
                      boxShadow: isUser
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Text(
                      msg['text'],
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          //
          //
          //
          // loading indicator
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

  //
  //
  //
  //
  // type a message box
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          //
          //
          // send button
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

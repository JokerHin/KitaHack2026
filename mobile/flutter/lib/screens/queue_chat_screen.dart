import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class QueueChatScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const QueueChatScreen({super.key, required this.patient});

  @override
  State<QueueChatScreen> createState() => _QueueChatScreenState();
}

class _QueueChatScreenState extends State<QueueChatScreen> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'from': 'you', 'text': text});
      _sending = true;
      _controller.clear();
    });

    final reply = await GeminiService.instance.generateChatReply(
      patientData: widget.patient,
      userMessage: text,
    );

    setState(() {
      _messages.add({'from': 'ai', 'text': reply});
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with AI')),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final fromYou = m['from'] == 'you';
                return Align(
                  alignment:
                      fromYou ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fromYou
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      m['text'] ?? '',
                      style: TextStyle(
                          color: fromYou ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          // Ensure input row is visible above system keyboard and overlays
          Padding(
            padding: EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration.collapsed(
                          hintText: 'Ask the AI about this patient...'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  IconButton(
                    icon: _sending
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

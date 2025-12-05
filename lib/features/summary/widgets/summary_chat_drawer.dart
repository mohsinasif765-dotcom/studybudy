import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';
import 'package:studybudy_ai/features/summary/services/summary_service.dart';

class SummaryChatDrawer extends StatefulWidget {
  final String documentContext;

  const SummaryChatDrawer({super.key, required this.documentContext});

  @override
  State<SummaryChatDrawer> createState() => _SummaryChatDrawerState();
}

class _SummaryChatDrawerState extends State<SummaryChatDrawer> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Hi! I\'ve analyzed your document. Ask me anything about it!'}
  ];

  bool _isLoading = false;
  bool _isListening = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _controller.text = val.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'text': userText});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final aiResponse = await SummaryService().chatWithDocument(
        widget.documentContext, 
        userText
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'text': aiResponse});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🛠️ FIX 1: Wrap in Material to provide context for TextField
    return Material(
      color: Colors.transparent,
      child: Container(
        // 🛠️ FIX 2: Define Height so Expanded knows limits
        height: double.infinity, 
        width: MediaQuery.of(context).size.width * 0.90, // Mobile width constraint
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
          ]
        ),
        child: Column(
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryStart, AppColors.primaryEnd]),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30)),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Study Assistant", style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text("Powered by AI", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
            ),

            // 2. Chat Area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 10, top: 10),
                      child: Row(children: [
                        Icon(Icons.smart_toy_outlined, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Thinking...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    ).animate().fade().slideX();
                  }

                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                      decoration: BoxDecoration(
                        color: isUser 
                            ? AppColors.primaryStart 
                            : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                        ),
                        boxShadow: [
                           if(isUser) BoxShadow(color: AppColors.primaryStart.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: isUser 
                        ? Text(msg['text']!, style: const TextStyle(color: Colors.white))
                        : MarkdownBody(
                            data: msg['text']!,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                    ),
                  ).animate().fade().slideY(begin: 0.1, duration: 300.ms);
                },
              ),
            ),

            // 3. Input Area
            Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.redAccent : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none, 
                          color: _isListening ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: _isListening ? "Listening..." : "Ask a question...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryStart,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
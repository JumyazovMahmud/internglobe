import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── Data model ───────────────────────────────────────────────────────────────

enum _Sender { user, ai }

class _Message {
  final _Sender sender;
  final String text;
  final List<String> suggestions;

  const _Message({
    required this.sender,
    required this.text,
    this.suggestions = const [],
  });
}

// ── Screen ───────────────────────────────────────────────────────────────────

class InterestChatScreen extends StatefulWidget {
  final void Function(List<String> interests) onInterestsSelected;
  final List<String> currentInterests;

  /// Pass true if the user has opened this chat before.
  final bool isReturningUser;

  const InterestChatScreen({
    super.key,
    required this.onInterestsSelected,
    this.currentInterests = const [],
    this.isReturningUser = false,
  });

  @override
  State<InterestChatScreen> createState() => _InterestChatScreenState();
}

class _InterestChatScreenState extends State<InterestChatScreen>
    with SingleTickerProviderStateMixin {
  final _messages = <_Message>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  final Set<String> _selectedInterests = {};

  int _quizStep = 0;
  final List<String> _quizAnswers = [];

  // Short context string seeded after quiz, used in free chat prompts
  String _chatContext = '';

  // Track if we already retried to avoid infinite loops
  bool _isRetrying = false;

  static const _apiKey = 'apf_hkzsankeh802nlmy2jya0xzj';
  static const _apiUrl = 'https://apifreellm.com/api/v1/chat';

  static const _quizQuestions = [
    "Hi! 👋 I'm your career assistant. Let's find internship interests that suit you.\n\nFirst — what are you currently studying or what's your educational background?",
    "Great! What kind of work excites you most — do you prefer working with people, data, technology, creativity, or something else?",
    "Nice! Are you drawn more to big corporations, startups, non-profits, or government organisations?",
    "Last question — do you have any hobbies or personal projects that you'd love to turn into a career someday?",
  ];

  static const _quizLabels = [
    'Education',
    'Work style',
    'Company type',
    'Hobbies',
  ];

  static const _returningQuickActions = [
    '🔍 Find new roles for me',
    '💡 Explore a specific industry',
    '📝 Retake the quiz',
    '❓ What does a role involve?',
  ];

  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 400), _startChat);
  }

  @override
  void dispose() {
    _dotController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Decide opening experience ─────────────────────────────────────────────

  void _startChat() {
    if (widget.isReturningUser || widget.currentInterests.isNotEmpty) {
      _quizStep = -1;
      final saved = widget.currentInterests.isNotEmpty
          ? ' You have ${widget.currentInterests.length} saved interest${widget.currentInterests.length == 1 ? '' : 's'}.'
          : '';
      _addAiMessage(
        "Hello! 👋 What can I help you with today?$saved",
        _returningQuickActions,
      );
    } else {
      _nextQuizStep();
    }
  }

  // ── New chat ──────────────────────────────────────────────────────────────

  void _startNewChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Start new chat?'),
        content: const Text(
            'This will clear the current conversation. Your saved interests will stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _quizAnswers.clear();
                _chatContext = '';
                _quizStep = -1;
                _isTyping = false;
                _isRetrying = false;
              });
              Future.delayed(const Duration(milliseconds: 300), () {
                _addAiMessage(
                  "New chat started! 👋 What can I help you with?",
                  _returningQuickActions,
                );
              });
            },
            child: Text('Start new',
                style: TextStyle(
                    color: Colors.blue[700], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Quiz flow ─────────────────────────────────────────────────────────────

  void _nextQuizStep() {
    if (_quizStep < _quizQuestions.length) {
      _addAiMessage(_quizQuestions[_quizStep], []);
      _quizStep++;
    } else {
      _quizStep = -1;
      _generateInterestsFromQuiz();
    }
  }

  void _addAiMessage(String text, List<String> suggestions) {
    setState(() {
      _messages
          .add(_Message(sender: _Sender.ai, text: text, suggestions: suggestions));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;
    _inputController.clear();

    final trimmed = text.trim();
    _isRetrying = false;

    // Handle retake quiz quick action
    if (trimmed == '📝 Retake the quiz') {
      setState(() {
        _messages.add(_Message(sender: _Sender.user, text: trimmed));
        _quizStep = 0;
        _quizAnswers.clear();
        _chatContext = '';
      });
      await Future.delayed(const Duration(milliseconds: 400));
      _nextQuizStep();
      return;
    }

    setState(() {
      _messages.add(_Message(sender: _Sender.user, text: trimmed));
      _isTyping = true;
    });
    _scrollToBottom();

    if (_quizStep > 0 && _quizStep <= _quizQuestions.length) {
      _quizAnswers.add(trimmed);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _isTyping = false);
      _nextQuizStep();
    } else {
      await _callFreeChat(trimmed);
    }
  }

  // ── Generate interests after quiz ─────────────────────────────────────────

  Future<void> _generateInterestsFromQuiz() async {
    setState(() => _isTyping = true);
    _scrollToBottom();

    final summary = StringBuffer();
    for (int i = 0; i < _quizAnswers.length; i++) {
      final label =
      i < _quizLabels.length ? _quizLabels[i] : 'Answer ${i + 1}';
      summary.writeln('$label: ${_quizAnswers[i]}');
    }

    final existing = widget.currentInterests.isNotEmpty
        ? 'Do NOT suggest these already saved: ${widget.currentInterests.join(', ')}.'
        : '';

    final prompt =
        'A student answered these questions about themselves:\n\n$summary\n$existing\n'
        'Suggest exactly 5 specific internship role titles that suit them.\n'
        'Return ONLY this JSON, no markdown, no extra text:\n'
        '{"interests":["Role 1","Role 2","Role 3","Role 4","Role 5"],"message":"short warm message"}';

    try {
      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({'message': prompt}),
      )
          .timeout(const Duration(seconds: 40)); // ← increased

      if (!mounted) return;

      debugPrint('QUIZ STATUS: ${response.statusCode}');
      debugPrint('QUIZ BODY: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final raw = data['response'] as String;
      final clean = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final parsed = jsonDecode(clean);
      final interests = List<String>.from(parsed['interests'] ?? []);
      final message =
          parsed['message'] as String? ?? "Here are roles that suit you!";

      // Store a short context for free chat
      _chatContext =
      'Student background: ${_quizAnswers.join(' | ')}. Suggested roles: ${interests.join(', ')}.';

      setState(() {
        _isTyping = false;
        _messages.add(_Message(
          sender: _Sender.ai,
          text: message,
          suggestions: interests,
        ));
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _addAiMessage(
            "Tap any role above to add it ✨\n\nFeel free to keep chatting — ask me about any career, industry, or what a specific role involves!",
            [],
          );
        }
      });
    } catch (e) {
      debugPrint('ERROR in _generateInterestsFromQuiz: $e');
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_Message(
          sender: _Sender.ai,
          text: 'Sorry, I had trouble analysing your answers. Please try again.',
        ));
      });
    }
    _scrollToBottom();
  }

  // ── Free chat ─────────────────────────────────────────────────────────────

  Future<void> _callFreeChat(String userMessage) async {
    try {
      final savedInterests = widget.currentInterests.isNotEmpty
          ? 'Already saved interests (never suggest these): ${widget.currentInterests.join(', ')}. '
          : '';

      final context =
      _chatContext.isNotEmpty ? 'Context: $_chatContext\n' : '';

      final prompt =
          'You are a friendly career advisor helping a student find internship interests. '
          'Keep replies short (2-3 sentences). '
          'When you mention specific job/internship titles wrap them in [[ ]] e.g. [[UX Designer]]. '
          '$savedInterests\n'
          '$context'
          'Student says: $userMessage\n'
          'Reply:';

      debugPrint('FREE CHAT PROMPT LENGTH: ${prompt.length}');

      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({'message': prompt}),
      )
          .timeout(const Duration(seconds: 40)); // ← increased

      if (!mounted) return;

      debugPrint('FREE CHAT STATUS: ${response.statusCode}');
      debugPrint('FREE CHAT BODY: ${response.body}');

      // Rate limited — wait and retry once
      if (response.statusCode == 429) {
        int retryAfter = 1;
        try {
          final body = jsonDecode(response.body);
          retryAfter = (body['retryAfter'] as num?)?.toInt() ?? 1;
        } catch (_) {}
        await Future.delayed(Duration(seconds: retryAfter + 1));
        await _callFreeChat(userMessage);
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final raw = data['response'] as String;

      final suggestions = RegExp(r'\[\[(.+?)\]\]')
          .allMatches(raw)
          .map((m) => m.group(1)!)
          .toList();
      final cleanText =
      raw.replaceAllMapped(RegExp(r'\[\[(.+?)\]\]'), (m) => m.group(1)!);

      setState(() {
        _isTyping = false;
        _messages.add(_Message(
          sender: _Sender.ai,
          text: cleanText,
          suggestions: suggestions,
        ));
      });

      _isRetrying = false;
    } catch (e, stack) {
      debugPrint('ERROR in _callFreeChat: $e');
      debugPrint('STACK: $stack');
      if (!mounted) return;

      // Retry once on timeout
      if (e.toString().contains('TimeoutException') && !_isRetrying) {
        debugPrint('Timeout — retrying once...');
        _isRetrying = true;
        try {
          await _callFreeChat(userMessage);
          return;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_Message(
          sender: _Sender.ai,
          text: 'Sorry, the server is slow right now. Please try again.',
        ));
      });
      _isRetrying = false;
    }
    _scrollToBottom();
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  void _confirmInterests() {
    if (_selectedInterests.isEmpty) return;
    widget.onInterestsSelected(_selectedInterests.toList());
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child:
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Career Assistant',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text('AI-powered',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
            tooltip: 'New chat',
            onPressed: _startNewChat,
          ),
          if (_selectedInterests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _confirmInterests,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: Text(
                  'Add ${_selectedInterests.length}',
                  style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected interests bar
          if (_selectedInterests.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.blue[50],
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedInterests.map((interest) {
                  return Chip(
                    label:
                    Text(interest, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () =>
                        setState(() => _selectedInterests.remove(interest)),
                    backgroundColor: Colors.blue[100],
                    deleteIconColor: Colors.blue[700],
                    labelStyle: TextStyle(
                        color: Colors.blue[800], fontWeight: FontWeight.w500),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[i]);
              },
            ),
          ),

          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_Message message) {
    final isAi = message.sender == _Sender.ai;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
        isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment:
            isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isAi) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.blue[700]!, Colors.blue[400]!]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 14),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isAi ? Colors.white : Colors.blue[700],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isAi ? 4 : 18),
                      bottomRight: Radius.circular(isAi ? 18 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isAi ? Colors.grey[800] : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Suggestion chips
          if (message.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.suggestions.map((s) {
                  final isQuickAction = _returningQuickActions.contains(s);
                  final isSelected = _selectedInterests.contains(s);

                  return GestureDetector(
                    onTap: () {
                      if (isQuickAction) {
                        _sendMessage(s);
                      } else {
                        setState(() {
                          if (isSelected) {
                            _selectedInterests.remove(s);
                          } else if (_selectedInterests.length < 5) {
                            _selectedInterests.add(s);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Max 5 interests'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isQuickAction
                            ? Colors.white
                            : (isSelected ? Colors.blue[700] : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isQuickAction
                              ? Colors.blue[300]!
                              : (isSelected
                              ? Colors.blue[700]!
                              : Colors.blue[200]!),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isQuickAction && isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.check,
                                  size: 14, color: Colors.white),
                            ),
                          Text(
                            s,
                            style: TextStyle(
                              fontSize: 13,
                              color: isQuickAction
                                  ? Colors.blue[700]
                                  : (isSelected
                                  ? Colors.white
                                  : Colors.blue[700]),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isQuickAction && !isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.add,
                                  size: 14, color: Colors.blue[400]),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[400]!]),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (context, _) {
                return Row(
                  children: List.generate(3, (i) {
                    final offset =
                    ((_dotController.value * 3) - i).clamp(0.0, 1.0);
                    final bounce =
                    offset < 0.5 ? offset * 2 : (1 - offset) * 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 7,
                      height: 7 + (bounce * 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_inputController.text),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
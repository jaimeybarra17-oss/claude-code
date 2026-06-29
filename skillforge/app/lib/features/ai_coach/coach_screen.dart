import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The AI Career Coach chat. Sends messages to the `ai-coach` Edge Function and
/// streams the reply. Quick-prompts surface the canonical coach jobs from the
/// product spec ("test me", "study plan", "review my mistakes", ...).
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _messages = <(_Role, String)>[
    (_Role.coach, "Hi! I'm your career coach. Ask me anything, or tap a prompt below."),
  ];

  static const _quickPrompts = [
    'Create today\'s study plan',
    'Test me',
    'Review my mistakes',
    'What should I study next?',
    'Am I ready for an interview?',
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add((_Role.user, text));
      // In the app: stream SupabaseService.askCoach(...) into a coach bubble.
      _messages.add((_Role.coach, '…'));
    });
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Coach')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final (role, text) = _messages[i];
                final isUser = role == _Role.user;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Text(text,
                        style: TextStyle(
                            color: isUser
                                ? AppColors.canvas
                                : AppColors.textPrimary)),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (final p in _quickPrompts)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ActionChip(
                        label: Text(p), onPressed: () => _send(p)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                        hintText: 'Ask your coach…',
                        border: OutlineInputBorder()),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                    onPressed: () => _send(_input.text),
                    icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Role { user, coach }

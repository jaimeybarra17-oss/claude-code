import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Lesson player. Renders the structured JSONB `lessons.body` block list
/// (text, callouts, video, interactive/simulation hosts) and, on completion,
/// flips `lesson_progress.status` to 'completed' — which triggers the
/// server-side reward pipeline (XP, streak, progress, badges).
class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.title, required this.blocks});

  final String title;

  /// Each block: { "type": "text"|"callout"|"video"|..., "md": "...", ... }
  final List<Map<String, dynamic>> blocks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final block in blocks) _block(context, block),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ElevatedButton(
          // In the app: update lesson_progress.status -> 'completed'.
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Complete lesson  ✓'),
        ),
      ),
    );
  }

  Widget _block(BuildContext context, Map<String, dynamic> block) {
    final type = block['type'] as String?;
    final md = block['md'] as String? ?? '';
    switch (type) {
      case 'callout':
        final warning = block['style'] == 'warning';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: (warning ? AppColors.warning : AppColors.info)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Text(md),
        );
      case 'video':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Center(child: Icon(Icons.play_circle_outline, size: 48)),
        );
      case 'text':
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(md, style: const TextStyle(height: 1.5)),
        );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// The onboarding questionnaire. Collects the answers that seed the
/// personalized roadmap (persisted to `onboarding_responses`), then routes home.
/// Steps mirror the product spec: age, country, career interest, experience,
/// current income, income goal, weekly time, learning style, career goal.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _step = 0;

  // Collected answers (would be submitted to Supabase on completion).
  final Map<String, dynamic> _answers = {};

  static const _steps = <_Step>[
    _Step('How old are you?', 'We tailor pacing and content to your stage.'),
    _Step('Where are you based?', 'Used for local salary and licensing info.'),
    _Step('Which career excites you?', 'Pick your first path — you can add more.'),
    _Step('Your experience level?', 'Complete beginner to seasoned pro.'),
    _Step('Current income?', 'Sets the baseline for your progress.'),
    _Step('Income goal?', 'The target your roadmap is built to reach.'),
    _Step('Weekly learning time?', 'We pace your roadmap to fit your life.'),
    _Step('Preferred learning style?', 'Visual, hands-on, reading, or mixed.'),
    _Step('Your career goal?', 'In a sentence — what does success look like?'),
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      _controller.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      // TODO: persist _answers to onboarding_responses, then generate roadmap.
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _steps.length;
    final step = _steps[_step];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.elevated,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Step ${_step + 1} of ${_steps.length}',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Text(step.title,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text(step.subtitle,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              ElevatedButton(
                onPressed: _next,
                child: Text(
                    _step == _steps.length - 1 ? 'Build my roadmap' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step {
  final String title;
  final String subtitle;
  const _Step(this.title, this.subtitle);
}

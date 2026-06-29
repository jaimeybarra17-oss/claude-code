import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Jobs hub — resume builder, AI resume feedback, applications tracker, saved
/// listings, and interview prep. Backed by resumes / applications / job_listings
/// and the resume-feedback + mock-interview Edge Functions.
class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  static const _actions = <(IconData, String, String)>[
    (Icons.description_outlined, 'Resume Builder', 'Build & export your resume'),
    (Icons.auto_awesome, 'AI Resume Review', 'Get scored, actionable feedback'),
    (Icons.record_voice_over_outlined, 'Mock Interview', 'Practice with the AI interviewer'),
    (Icons.track_changes_outlined, 'Applications', 'Track every opportunity'),
    (Icons.bookmark_outline, 'Saved Jobs', 'Listings you want to revisit'),
    (Icons.calculate_outlined, 'Salary Calculator', 'Project your earning path'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined,
                      color: AppColors.success, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Career Readiness',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('72 / 100 — almost interview-ready',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (icon, title, subtitle) in _actions)
            Card(
              child: ListTile(
                leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {/* route to the feature */},
              ),
            ),
        ],
      ),
    );
  }
}

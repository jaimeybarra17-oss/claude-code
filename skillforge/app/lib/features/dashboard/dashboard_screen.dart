import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import 'widgets.dart';

/// The Home Dashboard. Renders the headline metrics from the schema:
/// current career, daily lesson CTA, XP/level, weekly + career progress,
/// streak, achievements, daily challenge, AI coach tip, certification,
/// hours studied, and estimated salary progress.
///
/// Wired here with representative data; in the app these come from Riverpod
/// providers backed by [SupabaseService]. The accent is the active career's.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.profile, this.career, this.enrollment});

  final Profile? profile;
  final Career? career;
  final Enrollment? enrollment;

  @override
  Widget build(BuildContext context) {
    // Fallback demo data so the screen renders standalone in development.
    final p = profile ??
        const Profile(
            id: 'demo',
            displayName: 'Jordan',
            totalXp: 1240,
            coins: 320,
            level: 4,
            plan: 'free');
    final c = career ??
        const Career(
            id: 'demo',
            slug: 'electrician',
            name: 'Electrician',
            icon: '⚡',
            accent: AppColors.defaultAccent,
            medianSalary: 60000);
    final e = enrollment ??
        const Enrollment(
            careerId: 'demo', progressPct: 32, hoursStudied: 18.5);

    final estSalary = ((c.medianSalary ?? 0) * (0.4 + e.progressPct / 100 * 0.6))
        .round();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Greeting + streak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hi, ${p.displayName ?? 'there'} 👋',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const StreakFlame(days: 7),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Career hero card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    ProgressRing(
                        progress: e.progressPct / 100,
                        accent: c.accent,
                        label: 'Career'),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.icon ?? ''} ${c.name}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Level ${p.level}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Est. salary  \$$estSalary',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Daily lesson CTA
            ElevatedButton(
              onPressed: () {/* go_router → lesson player */},
              child: const Text('Continue Daily Lesson  →'),
            ),
            const SizedBox(height: AppSpacing.lg),

            // XP bar
            XpBar(progress: p.levelProgress, xp: p.totalXp),
            const SizedBox(height: AppSpacing.lg),

            // Stat tiles
            Row(
              children: [
                StatTile(
                    label: 'Hours Studied',
                    value: e.hoursStudied.toStringAsFixed(1),
                    icon: Icons.timer_outlined),
                const SizedBox(width: AppSpacing.sm),
                StatTile(
                    label: 'Career Progress',
                    value: '${e.progressPct.round()}%',
                    icon: Icons.trending_up),
                const SizedBox(width: AppSpacing.sm),
                StatTile(
                    label: 'Coins',
                    value: '${p.coins}',
                    icon: Icons.monetization_on_outlined),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Daily challenge
            _SectionCard(
              icon: '◇',
              title: 'Daily Challenge',
              body: 'Complete one lesson today to earn +30 XP and 10 coins.',
              accent: c.accent,
            ),
            const SizedBox(height: AppSpacing.md),

            // AI coach tip
            _SectionCard(
              icon: '💡',
              title: 'AI Coach Tip',
              body:
                  'You missed a question on wire gauge yesterday. Want a 2-minute refresher?',
              accent: AppColors.info,
            ),
            const SizedBox(height: AppSpacing.md),

            // Upcoming certification
            _SectionCard(
              icon: '🏅',
              title: 'Upcoming Certification',
              body:
                  'Reach 100% to earn your SkillForge ${c.name} Certificate. ${e.progressPct.round()}% done.',
              accent: AppColors.xpGold,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

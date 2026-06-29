import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../dashboard/widgets.dart';

/// Profile — identity, level/XP, streak, badges, plan, and settings entry.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile ??
        const Profile(
            id: 'demo',
            displayName: 'Jordan',
            totalXp: 1240,
            coins: 320,
            level: 4,
            plan: 'free');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  (p.displayName ?? '?').characters.first.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.canvas),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayName ?? 'Learner',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Level ${p.level} · ${p.totalXp} XP',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const StreakFlame(days: 7),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          XpBar(progress: p.levelProgress, xp: p.totalXp),
          const SizedBox(height: AppSpacing.lg),
          if (!p.isPremium)
            Card(
              color: AppColors.elevated,
              child: ListTile(
                leading: const Text('✨', style: TextStyle(fontSize: 22)),
                title: const Text('Upgrade to Premium'),
                subtitle: const Text(
                    'Unlimited AI, simulations, certificates & coaching'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {/* Stripe checkout */},
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          const Text('Achievements',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: const [
              _Badge('⚡', 'First Spark'),
              _Badge('🦺', 'Safety First'),
              _Badge('🔥', 'Week Warrior'),
              _Badge('🌟', 'Rising Star'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final item in const ['Settings', 'Notifications', 'Help', 'Sign out'])
            Card(
              child: ListTile(
                title: Text(item),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.label);
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.elevated,
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

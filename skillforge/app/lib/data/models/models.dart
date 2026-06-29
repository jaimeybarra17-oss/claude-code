import 'package:flutter/material.dart';

/// Immutable domain models mapping the Supabase schema to the client.
/// Kept dependency-free so they're trivially testable.

class Career {
  final String id;
  final String slug;
  final String name;
  final String? tagline;
  final String? icon;
  final Color accent;
  final int? medianSalary;

  const Career({
    required this.id,
    required this.slug,
    required this.name,
    this.tagline,
    this.icon,
    required this.accent,
    this.medianSalary,
  });

  factory Career.fromJson(Map<String, dynamic> j) => Career(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: j['name'] as String,
        tagline: j['tagline'] as String?,
        icon: j['icon'] as String?,
        accent: _hex(j['accent_color'] as String?) ?? const Color(0xFFF5A623),
        medianSalary: j['median_salary'] as int?,
      );
}

class Profile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int totalXp;
  final int coins;
  final int level;
  final String? activeCareerId;
  final String plan;

  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    required this.totalXp,
    required this.coins,
    required this.level,
    this.activeCareerId,
    required this.plan,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        totalXp: (j['total_xp'] as num?)?.toInt() ?? 0,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        activeCareerId: j['active_career_id'] as String?,
        plan: j['plan'] as String? ?? 'free',
      );

  bool get isPremium => plan == 'premium' || plan == 'enterprise';

  /// XP threshold to reach a given level: 50 * n * (n - 1) — mirrors the
  /// `level_for_xp` SQL function so the client can render the XP bar exactly.
  static int xpForLevel(int n) => 50 * n * (n - 1);

  /// 0..1 progress toward the next level.
  double get levelProgress {
    final floor = xpForLevel(level);
    final ceil = xpForLevel(level + 1);
    if (ceil == floor) return 0;
    return ((totalXp - floor) / (ceil - floor)).clamp(0.0, 1.0);
  }
}

enum LessonKind { concept, video, interactive, quiz, simulation, boss }

enum ProgressStatus { locked, available, inProgress, completed }

class Module {
  final String id;
  final int level;
  final String title;
  final String? summary;
  final int xpReward;

  const Module({
    required this.id,
    required this.level,
    required this.title,
    this.summary,
    required this.xpReward,
  });

  factory Module.fromJson(Map<String, dynamic> j) => Module(
        id: j['id'] as String,
        level: (j['level'] as num).toInt(),
        title: j['title'] as String,
        summary: j['summary'] as String?,
        xpReward: (j['xp_reward'] as num?)?.toInt() ?? 100,
      );
}

class Enrollment {
  final String careerId;
  final double progressPct;
  final double hoursStudied;

  const Enrollment({
    required this.careerId,
    required this.progressPct,
    required this.hoursStudied,
  });

  factory Enrollment.fromJson(Map<String, dynamic> j) => Enrollment(
        careerId: j['career_id'] as String,
        progressPct: (j['progress_pct'] as num?)?.toDouble() ?? 0,
        hoursStudied: (j['hours_studied'] as num?)?.toDouble() ?? 0,
      );
}

Color? _hex(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse('FF$cleaned', radix: 16);
  return value == null ? null : Color(value);
}

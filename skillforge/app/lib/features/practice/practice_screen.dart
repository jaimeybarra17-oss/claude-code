import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Practice hub — the catalog of interactive simulations for the active career
/// (sourced from the `simulations` table). Each card launches a SimCanvas with
/// the engine + config for that scenario.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  // Representative set; in the app this comes from a simulations provider.
  static const _sims = <(_SimEngine, String, String)>[
    (_SimEngine.wiring, 'Virtual House Wiring', 'Wire a kitchen to code'),
    (_SimEngine.panel, 'Breaker Panel Builder', 'Balance the load'),
    (_SimEngine.meter, 'Voltage Testing Lab', 'Verify dead before touch'),
    (_SimEngine.wiring, 'Circuit Troubleshooting', 'Find the open neutral'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: GridView.count(
        padding: const EdgeInsets.all(AppSpacing.md),
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.9,
        children: [
          for (final (engine, title, subtitle) in _sims)
            _SimCard(engine: engine, title: title, subtitle: subtitle),
        ],
      ),
    );
  }
}

enum _SimEngine { wiring, panel, meter }

extension on _SimEngine {
  IconData get icon => switch (this) {
        _SimEngine.wiring => Icons.electrical_services,
        _SimEngine.panel => Icons.grid_view,
        _SimEngine.meter => Icons.speed,
      };
}

class _SimCard extends StatelessWidget {
  const _SimCard({
    required this.engine,
    required this.title,
    required this.subtitle,
  });

  final _SimEngine engine;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {/* launch SimCanvas(engine, config) */},
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(engine.icon, color: accent),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

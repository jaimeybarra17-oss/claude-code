import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge/data/models/models.dart';

/// Verifies the client level curve matches the `level_for_xp` SQL function,
/// so the XP bar renders the same thresholds the server awards against.
void main() {
  group('Profile.xpForLevel', () {
    test('matches the 50 * n * (n - 1) curve', () {
      expect(Profile.xpForLevel(1), 0);
      expect(Profile.xpForLevel(2), 100);
      expect(Profile.xpForLevel(3), 300);
      expect(Profile.xpForLevel(4), 600);
      expect(Profile.xpForLevel(5), 1000);
      expect(Profile.xpForLevel(10), 4500);
    });
  });

  group('Profile.levelProgress', () {
    test('is 0 at the start of a level and approaches 1 near the next', () {
      const atFloor = Profile(
          id: 'x', totalXp: 600, coins: 0, level: 4, plan: 'free'); // L4 floor
      expect(atFloor.levelProgress, 0);

      const mid = Profile(
          id: 'x', totalXp: 800, coins: 0, level: 4, plan: 'free');
      // L4..L5 spans 600..1000, so 800 is halfway.
      expect(mid.levelProgress, closeTo(0.5, 0.001));
    });

    test('clamps within 0..1', () {
      const over = Profile(
          id: 'x', totalXp: 5000, coins: 0, level: 4, plan: 'free');
      expect(over.levelProgress, lessThanOrEqualTo(1.0));
      expect(over.levelProgress, greaterThanOrEqualTo(0.0));
    });
  });

  test('isPremium reflects plan tier', () {
    const free = Profile(id: 'x', totalXp: 0, coins: 0, level: 1, plan: 'free');
    const premium =
        Profile(id: 'x', totalXp: 0, coins: 0, level: 1, plan: 'premium');
    expect(free.isPremium, false);
    expect(premium.isPremium, true);
  });
}

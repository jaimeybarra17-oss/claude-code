# SkillForge — Design System

Dark-first, premium, gamified. The aesthetic target is "Apple-level polish meets
Duolingo delight": deep neutral canvas, a single energetic accent per career,
generous spacing, fluid motion, and zero clutter.

## Foundations

### Color — base (dark)

| Token | Hex | Use |
| ----- | --- | --- |
| `bg/canvas` | `#0B0E14` | App background |
| `bg/surface` | `#141925` | Cards, sheets |
| `bg/elevated` | `#1C2230` | Modals, popovers |
| `border/subtle` | `#252C3B` | Hairlines, dividers |
| `text/primary` | `#F5F7FA` | Headings, body |
| `text/secondary` | `#9AA4B2` | Captions, labels |
| `text/disabled` | `#5A6473` | Disabled |

### Color — semantic

| Token | Hex |
| ----- | --- |
| `success` | `#34D399` |
| `warning` | `#FBBF24` |
| `danger`  | `#F87171` |
| `info`    | `#60A5FA` |
| `xp/gold` | `#FFC857` |
| `streak/flame` | `#FF6B35` |

### Color — per-career accent

The active career's `accent_color` (from the `careers` table) themes the dashboard
gradient, progress rings, and primary buttons. Examples: Electrician `#F5A623`,
Cybersecurity `#5C6BC0`, Software Dev `#42A5F5`. This makes each career feel
distinct while sharing one component library.

### Typography

- **Display / headings:** Inter (or SF Pro on iOS), tight tracking.
- **Body:** Inter 400/500.
- **Numerals (XP, timers):** tabular figures so counters don't jitter.

| Style | Size / Weight |
| ----- | ------------- |
| Display | 34 / 700 |
| Title | 22 / 700 |
| Headline | 17 / 600 |
| Body | 15 / 400 |
| Caption | 13 / 500 |

### Spacing & shape

- 4-pt spacing grid (`4, 8, 12, 16, 24, 32, 48`).
- Corner radii: cards `20`, buttons `14`, chips `999` (pill).
- Elevation via soft shadows + 1px subtle borders, never harsh drop shadows.

### Motion

- Standard easing `cubic-bezier(0.2, 0.0, 0, 1)`; durations 150–300ms.
- **Reward moments** (XP gain, level up, badge unlock) get spring physics +
  haptics + confetti — these are the dopamine beats and deserve extra craft.
- Respect `reduce motion`: swap springs for fades.

## Core components

| Component | Notes |
| --------- | ----- |
| `XPBar` | Animated fill to next-level threshold; tabular XP counter. |
| `StreakFlame` | Flame badge with day count; pulses when extended today. |
| `ProgressRing` | Career progress %, accent-colored sweep. |
| `LessonCard` | State-aware: locked / available / in-progress / completed. |
| `SkillTreeNode` | Node on the path map; unlock animation on completion. |
| `StatTile` | Dashboard metric (Hours Studied, Est. Salary, Level). |
| `CoachBubble` | Streaming AI message with typing shimmer. |
| `SimCanvas` | Host surface for interactive simulations. |
| `PrimaryButton` | Accent-filled, 14 radius, press-scale 0.97 + haptic. |

## Dashboard layout (mobile-first)

```
┌─────────────────────────────┐
│  Greeting · StreakFlame 🔥7  │
│  ┌───────────────────────┐  │
│  │  Career hero card     │  │  active career, accent gradient,
│  │  ProgressRing  Level  │  │  ProgressRing + level + Est. salary
│  └───────────────────────┘  │
│  [ Continue Daily Lesson ▸ ] │  primary CTA
│  XP ▓▓▓▓░░  ·  Coins 320     │
│  ┌─────┬─────┬─────┐         │
│  │Hours│ %   │Cert │  StatTiles
│  └─────┴─────┴─────┘         │
│  Daily Challenge  ◇          │
│  AI Coach Tip 💡             │
│  Achievements row ●●●○○       │
└─────────────────────────────┘
```

Bottom navigation: **Learn · Practice · Coach · Jobs · Profile**. Five destinations
max keeps navigation simple and thumb-reachable.

The Flutter implementation of these tokens lives in
`app/lib/core/theme/app_theme.dart`.

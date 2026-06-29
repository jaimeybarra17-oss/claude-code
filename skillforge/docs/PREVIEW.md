# Live web preview

Every push to the SkillForge work branch (or `main`) builds the Flutter app for
the web and deploys it to GitHub Pages, so you can click through the real app —
no install required. The build is also attached to each run as a downloadable
`skillforge-web` artifact.

Workflow: [`.github/workflows/skillforge-web-preview.yml`](../../.github/workflows/skillforge-web-preview.yml)

## Preview URL

```
https://jaimeybarra17-oss.github.io/claude-code/
```

## One-time setup (repo owner)

GitHub Pages must be enabled once for the link to go live:

1. Repo **Settings → Pages**.
2. **Build and deployment → Source: GitHub Actions**.

That's it — the next push deploys automatically, and the URL updates on every
push thereafter. (Public repo required for free GitHub Pages.)

## What you'll see

The preview ships with placeholder backend config, so it renders the full UI
with realistic demo data (the same content shown in the design mockups). To make
the preview *fully live* — real auth, your progress, the AI coach — point the
build at a Supabase project by replacing the values the workflow copies from
`app/.env.example` (e.g. inject `SUPABASE_URL` / `SUPABASE_ANON_KEY` from repo
secrets before `flutter build web`).

## Run it yourself

```bash
cd skillforge/app
cp .env.example .env
flutter pub get
flutter run -d chrome
```

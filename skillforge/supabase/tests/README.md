# SkillForge backend tests

Runs the full migration set + seed against a real PostgreSQL and asserts the
server-authoritative reward pipeline (XP, level, streak, career progress,
badges, trophies, leaderboards) behaves correctly.

## Run locally (bare Postgres)

```bash
createdb skillforge_test
PSQL="psql -d skillforge_test -v ON_ERROR_STOP=1"

# Test-only shim for the Supabase auth layer (skip on real Supabase).
$PSQL -f supabase/tests/00_supabase_stub.sql

# Schema, then seed (run seed from the supabase/ dir so \i includes resolve).
for f in supabase/migrations/*.sql; do $PSQL -f "$f"; done
( cd supabase && $PSQL -f seed.sql )

# Assertions (transaction is rolled back; safe to re-run).
$PSQL -f supabase/tests/gamification_test.sql
```

A passing run prints `gamification_test: ALL ASSERTIONS PASSED`.

## Run on real Supabase

`supabase db reset` applies `migrations/` then `seed.sql`. Do **not** apply
`00_supabase_stub.sql` — Supabase already provides `auth`. Run only
`gamification_test.sql` against the resulting database.

CI runs all of the above automatically — see
`.github/workflows/skillforge-ci.yml`.

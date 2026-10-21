# Backend runbook

Bluecoins works fully without a backend. The optional cloud account uses **Supabase** (Postgres +
Auth) on its free plan. This page is for the person running it.

## What lives where

| On the phone (SQLite, the source of truth) | In Supabase (a private copy) |
|---|---|
| settings, check-ins, incomes, expenses, categories, bills, cycle starts | the same seven tables in `public`, plus `user_id` and `server_updated_at` |
| theme, lock, reminder, sync positions (preferences) | nothing |

Every row has `id`, `updated_at` (ms, a clock that never goes backwards), `deleted_at` (deletes are
soft, so they can sync) and, on the phone only, `dirty` (changed, not uploaded yet).

## How signing in becomes data access

1. The app asks Google for an ID token (`google_sign_in`, using the **web** client ID).
2. `supabase.auth.signInWithIdToken` swaps it for a Supabase session (a JWT).
3. Every request carries that JWT. Postgres reads `auth.uid()` from it, and **row-level security**
   lets each table return and accept only rows where `user_id = auth.uid()`.
4. The app ships only the **publishable** key. It is public by design; RLS is what protects data.
   The `secret` / `service_role` key never goes into the app, CI or this repository.

## Sync in one paragraph

Push: rows with `dirty = 1` go up in batches of 500 (an upsert on `user_id,id`); a row is marked
clean only if it did not change meanwhile. Pull: rows after the saved `(server_updated_at, id)` come
down in pages of 1000, with a 60 s overlap once per run. A database trigger stamps
`server_updated_at`, caps a phone's clock at one minute ahead of the server, and **ignores a write
that is not newer than the stored row**, so the newest edit wins on every phone and retries are
harmless. Code: `lib/data/sync/sync_engine.dart` (tested against a fake cloud in `test/data/sync_test.dart`).

## One-time setup

1. **Supabase project.** supabase.com > New project, name `bluecoins`, a region near your users,
   a strong database password (keep it in a password manager). Then Authentication > Providers:
   turn **Email off** and leave **Anonymous off**, so only Google can create users.
2. **Schema.** Apply `supabase/migrations/*.sql` in order (SQL editor, or `npx supabase db push`, or
   the Supabase MCP `apply_migration`). Then run `supabase/tests/rls.sql` once: it ends with
   `all rls checks passed` and rolls back. Check Database > Advisors shows no security warnings
   (an advisory that `delete_my_account` is callable by signed-in users is expected).
3. **Google Cloud** (console.cloud.google.com), one project:
   - OAuth consent screen: app name, support email, scopes `email` and `profile`.
   - Credentials > OAuth client ID > **Web application**. Copy its client ID and secret into
     Supabase > Authentication > Providers > Google (enable it; add the Android client ID to
     "Authorized Client IDs", web first).
   - Credentials > OAuth client ID > **Android**: package `com.tanimaziz.bluecoins` and the SHA-1 of the
     key the APK is signed with. Make one per key: your debug key, the release key
     (`keytool -list -v -keystore ~/.bluecoins-release/bluecoins.jks`), and later the Play App
     Signing key (Play Console > App integrity).
   - Publish the consent screen to "In production" so any Google user can sign in (basic scopes
     need no review).
4. **App config.** `cp config/env.example.json config/env.json` and fill `SUPABASE_URL`,
   `SUPABASE_PUBLISHABLE_KEY` (Project settings > API keys) and `GOOGLE_WEB_CLIENT_ID`. Build with
   `--dart-define-from-file=config/env.json` (`tool/build_release.sh` does this automatically).

## Everyday operations

- **Change the schema.** Add a new file `supabase/migrations/<timestamp>_<what>.sql`, never edit an
  old one. New tables must `enable row level security`, get the `bc_touch` trigger and policies like
  the existing ones, and be granted explicitly (`grant select, insert, update ... to authenticated`):
  Supabase no longer exposes new tables to the API automatically. Mirror the change on the phone with a
  drift migration (`lib/data/database.dart`, bump `schemaVersion`) and add the table to `syncTables`.
- **Back up (free plan has no automatic backups).** Monthly: `npx supabase db dump --db-url "<connection string>" -f bluecoins.sql`,
  encrypt it (`age` or `gpg`), keep it somewhere you control. Every signed-in phone also holds a full
  copy; More > Account and sync > **Upload everything again** rebuilds a lost cloud from a phone.
- **Paused project.** Free projects pause after about a week with no traffic. The app keeps working
  offline and syncs once you press **Restore** in the Supabase dashboard.
- **Delete a user on request.** Dashboard > Authentication > Users > delete (all their rows cascade),
  or the user does it in the app.
- **Watch.** Dashboard > Reports and Advisors; the free plan allows 500 MB, 50,000 monthly active users
  and 5 GB egress. A heavy user writes about 1 MB of rows a year.
- **Limits and growth.** Supabase Pro ($25/month) gives 8 GB and 100,000 users. The app is plain
  Postgres underneath, so `pg_dump` moves it anywhere, including a self-hosted Supabase.

## Known limits

- Last write wins per row by clock: two offline edits to the same row keep only the later one.
- Amounts are stored to 2 decimals (currencies with 3 decimals round to 0.01).
- The Google ID token is exchanged without a nonce, which Supabase accepts when the token has none.

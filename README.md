# Bluecoins

Track your money with **one balance a day**. Type what you have left; Bluecoins works out what you
spent, your daily average, what you can safely spend today, your savings and where you will end
the month. Free, open source, no ads, no bank login. Works offline. Signing in with Google is
optional and only backs your data up and syncs your phones.

> "Bluecoins" is a working name. An unrelated app called Bluecoins Finance exists on the stores,
> so pick a different name before publishing this one.

## What it does

- **One number a day.** Spending is worked out from how your balance changed, with your income
  left out. Skip days and the gap is spread over the days it covers.
- **Cycles that follow your payday**, not the calendar month. Edit the boundaries or start a new
  cycle any time. A salary on a boundary day can count in the previous cycle's savings.
- **Safe to spend today**, a pace bar (money spent against days passed) and a projected end balance.
- Optional **expenses with categories**, **income**, **bills** (a reminder, never part of your numbers
  until you pay), and a **what-if** sandbox that never saves anything.
- **Insights**: spend per day, cumulative spend against budget, balance over time, savings and
  average by cycle, where it went, any date range, your biggest spend.
- **Export** to Excel (history, cycle table, charts) or a JSON backup you can restore; **import**
  balances pasted as text ("26 april, 123720").
- A daily reminder (never shows amounts), an optional app lock, dark and light themes.
- **Optional cloud account** (Google sign-in, Supabase): back up and sync several phones. See
  [docs/BACKEND.md](docs/BACKEND.md).

The calculation rules live in `lib/domain/ledger/` and are covered by unit tests.

## Build and run

Needs Flutter 3.47 (Dart 3.13) and an Android SDK.

```bash
flutter pub get
dart run build_runner build -d          # generates the database code
flutter test                            # unit and widget tests
flutter run                             # local-only: no account features
```

To turn on cloud sign-in, copy `config/env.example.json` to `config/env.json`, fill in your
Supabase URL, publishable key and Google web client ID, and run with
`flutter run --dart-define-from-file=config/env.json`. Setup steps are in
[docs/BACKEND.md](docs/BACKEND.md).

The tests use the system SQLite on Linux (see `hooks` in `pubspec.yaml`).

### Release build

```bash
tool/build_release.sh      # signed, obfuscated arm64 APK in dist/, then tool/security_audit.sh
```

The signing key is read from `~/.bluecoins-release/key.properties`, outside the repository.
Back that folder up: without it no update can install over an existing install.

## Layout

```
lib/core/       money (integer minor units), dates, formatting
lib/domain/     the ledger engine, entry parser, what-if maths (pure Dart)
lib/data/       drift database, store, backup, sync engine, auth, reminders
lib/app/        providers, router, theme, lock gate, Excel export
lib/features/   onboarding, home, add, history, insights, more
supabase/       migrations and the row-level-security tests
tool/           release build, APK security audit, icon generator
```

## Privacy

Your data stays on your phone unless you sign in. See [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md).

## License

MIT, see [LICENSE](LICENSE). The bundled Noto Sans fonts are under the SIL Open Font License
(`assets/fonts/OFL.txt`).

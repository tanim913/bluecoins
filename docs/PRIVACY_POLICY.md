# Enough privacy policy

_Last updated: 2026-10-26._

**Short version:** your money data stays on your phone. If you choose to sign in, an encrypted
copy is stored in your own account so you can restore it or use another phone. We never sell or
share it, show ads, or look at your bank.

## What the app stores on your phone

Your balances, incomes, expenses, categories, bills, budget and settings, in a private database
inside the app. Nothing else about you.

## Your profile

- You can add a **name** and a **gender** (both optional). If you are signed in they are saved in your
  account like your other data, so they come back on a new phone. If you are not signed in they stay
  on the phone.
- A **profile photo** you choose is stored only on your phone, in the app's private folder. It is never
  uploaded. If you sign in, the app can also show the photo from your Google account; that picture is
  loaded straight from Google.

## Checking for updates

Once a day the app asks GitHub whether a newer release of Enough exists (this reveals your phone's
IP address to GitHub, like opening any web page). Nothing else is sent. You can turn it off in Settings >
Tell me about new versions.

## If you sign in with Google

- We receive your Google account id, email address, name and photo link, to create your account.
- Your entries are uploaded to a Supabase database (Postgres) and are readable only by your own
  account (row-level security). The data is encrypted in transit and at rest by the host.
- Signing in is optional. Without it nothing leaves your phone.

## What we do not do

No analytics, no advertising, no tracking, no bank or SMS access, no contact or location access.

## Permissions

Notifications (the daily reminder, which never shows amounts), and the system fingerprint or PIN
prompt if you turn the app lock on.

## Your choices

- **Export** everything any time (Excel or a JSON file).
- **Delete** your cloud account and all its data inside the app: More > Account and sync > Delete
  my account. You can also follow [delete-account.md](delete-account.md).
- **Sign out** to remove the data from the phone (a safety copy stays inside the app).

## Children

Enough is not aimed at children under 13.

## Changes

Changes will be listed here with a new date.

## Contact

Questions or requests: open an issue at
[github.com/tanim913/bluecoins/issues](https://github.com/tanim913/bluecoins/issues). Do not put
your balances or other private details in a public issue.

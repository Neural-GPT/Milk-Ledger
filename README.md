# Milk Delivery Management System — MVP Scaffold

## What's here

```
milk-management-system/
├── backend/     FastAPI + PostgreSQL API (fully scaffolded, ready for your DB credentials)
├── mobile/      Flutter app skeleton (login, record-milk, customer dashboard)
├── docs/        Audit/visibility model reference
└── admin/       (empty — Next.js admin dashboard, build after MVP core is proven)
```

## Decisions locked in for this MVP
- **Admin login:** merged into the milkman login form — same "Username" + "Phone number" fields. The app tries milkman login first (name + phone); if no milkman matches that phone number, it retries as admin (username + numeric password). Admin account created once via `python -m scripts.create_admin`, run locally.
- **Milkman login:** name + phone number, no separate password. Accounts are created by the admin (`POST /admin/milkmen`, or `python -m scripts.create_milkman` for quick local testing) — milkmen never self-register.
- **Customer login:** phone number only, no password. The first device to log in with a given number "claims" it — after that, the same number can't log in from a different device until the **admin** clears it via `POST /admin/customers/{id}/reset-device` (moved off the milkman so they can't bump a customer off their own phone).
- **Notifications:** In-app, shown as both an immediate popup and a persistent dismissible "pill" on the customer's home tab. Today's entries get a Hindi message ("आज का दूध: X L"); back-dated ones get a neutral English message. Firebase push comes in v2.
- **Feedback:** star rating + optional comment (`POST /feedback`), available from a button on both dashboards and prompted automatically once a week. Every submission notifies all admins; `GET /feedback/admin` lists them all.
- **Database:** SQLite for local dev — a single file (`milk_delivery.db`), zero install, no server to run. Swap to Aiven Postgres later by changing `.env` and uncommenting `asyncpg` in `requirements.txt` — nothing else in the codebase needs to change (same pattern as your LeetTrack backend).
- **Same-day edits only:** a milkman can edit a milk entry's quantity only on the day it was logged (`PATCH /milk-entries/{id}` returns 403 for past dates). Past entries are locked for integrity.
- **Activity logs, per role:** `/audit-logs/me` (customer), `/audit-logs/milkman` (milkman, filtered to today for the "My Log" tab), `/admin/audit-logs` (everything, grouped by milkman in the app, with year/month filtering), plus `/admin/audit-logs/export` (CSV) and `/admin/audit-logs/wipe` (permanent delete, scoped by month or, with `confirm=true`, everything). All log entries are enriched server-side with customer/milkman names and who performed the action, so nothing shows as a bare UUID.
- **Offline support:** the milkman's dashboard and the customer's home tab cache their last successful response and fall back to it when there's no connection; login state persists across restarts so returning to the app (even offline) goes straight to the right dashboard instead of forcing a login screen.

## Getting the backend running locally (SQLite, no install needed)

```powershell
cd backend

# 1. Configure environment - the default already points at a local SQLite file
copy .env.example .env

# 2. Install dependencies
pip install -r requirements.txt --break-system-packages

# 3. Create tables - IMPORTANT: if you have an old postgres-based .env or
#    an old milk_delivery.db from before this change, delete milk_delivery.db
#    first so it's rebuilt with the current schema.
python -m scripts.init_db

# 4. Create your admin account (username + password, chosen by you)
python -m scripts.create_admin

# 4b. (optional, for quick testing) Create a milkman account directly
python -m scripts.create_milkman

# 5. Run the API
uvicorn app.main:app --reload
```

Visit `http://localhost:8000/docs` for interactive API docs (Swagger UI) — you can test
every endpoint from there, including admin login.

### Moving to Aiven Postgres later
In `.env`, comment out the SQLite line and uncomment the Postgres one (fill in your
Aiven credentials). In `requirements.txt`, uncomment `asyncpg`. Reinstall dependencies,
then re-run `python -m scripts.init_db` against the new database. At that point it's
also worth setting up Alembic migrations instead of the quick `init_db` script, for
proper schema version history.

## The audit-trail requirement you asked for
Every create/update/delete of a milk entry, and every price change, writes a row to
`audit_logs` **and** the domain table itself in the same transaction (see
`app/services/audit.py` and how it's called from `app/routers/milk_entries.py` /
`prices.py`). Reading those logs always goes through `get_audit_logs()`, which filters
by role:
- **Admin** → sees all rows, no filter.
- **Milkman** → sees only rows where `milkman_id` matches their own record.
- **Customer** → sees only rows where `customer_id` matches their own record.

There's no endpoint that returns unfiltered audit data — the three routes in
`app/routers/audit.py` (`/audit-logs/admin`, `/audit-logs/milkman`, `/audit-logs/me`)
are the only way in, and each one is pinned to its role.

## Admin login, specifically
The admin doesn't have a separate login screen anymore — they use the same "Username" + "Phone number" form as milkmen. The app tries the milkman flow first (name + phone); if no milkman account matches that phone number at all, it retries the same two values as an admin username + numeric password. The admin's password is kept numbers-only on purpose, to match that field.
- The admin account itself is created by running `python -m scripts.create_admin` directly on the machine hosting the backend — there's deliberately no HTTP endpoint that can create an admin, since that would let anyone with API access mint themselves an admin account.
- Re-running the script with the same username lets the admin reset their own password.

## Next steps
1. Run it locally, apply the icon (see below), and put the flow through its paces.
2. When you're ready to move off the local DB, send over the Aiven credentials — swapping is a one-line `.env` change.
3. At that point we should also add Alembic migrations instead of the quick `init_db` script, for proper schema version history.

## Applying the app icon
The icon is a generated glass-of-milk graphic at `assets/icon/icon.png`. After `flutter pub get`, run:
```powershell
dart run flutter_launcher_icons
```
This writes the actual Android launcher icons into `android/app/src/main/res/mipmap-*/`. Re-run it any time you replace `icon.png`.

## Setting the Android app label
`flutter create .` generates its own `AndroidManifest.xml` with a default label. After running it, open `android/app/src/main/AndroidManifest.xml` and set:
```xml
android:label="Milk Ledger"
```
on the `<application>` tag. (The in-app title and window title are already "Milk Ledger" — this is the only piece that needs a manual edit, since it lives in a file Flutter generates locally rather than one I can ship in the zip.)

## Deploying the backend to Render
1. Push the `backend` folder to a GitHub repo (Render deploys from a repo, not a zip upload).
2. In Render, create a new **Web Service**, point it at that repo, and it should auto-detect Python. Set the start command to what's in `Procfile`: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`.
3. Set the `DATABASE_URL` environment variable to your Aiven Postgres connection string, and uncomment `asyncpg` in `requirements.txt` before pushing (Render will run `pip install -r requirements.txt`).
4. Once deployed, update `ApiClient.baseUrl` in the Flutter app to your Render URL (`https://your-service.onrender.com`) and remove the `adb reverse` step — you won't need it once the backend has a real public URL.

**Keeping it awake on Render's free tier:** free services spin down after ~15 minutes of no traffic, and the first request after that takes 30-60s to wake back up. `GET /health` now checks the database connection too (not just that the process is alive), so it's a real health check, not just a ping. Point an external cron at it every 10-14 minutes — [cron-job.org](https://cron-job.org) or [UptimeRobot](https://uptimerobot.com) both work, or a scheduled GitHub Actions workflow with a `curl` step. Any of those keeps the service warm without you having to run anything yourself.

## Offline behavior
- **Login persists across restarts.** Once logged in, the app remembers the role and jumps straight to the right dashboard on next launch — no forced re-login, even with no network, since that decision only reads local storage.
- **Read screens fall back to cached data.** The milkman's dashboard and the customer's home tab cache their last successful response; if a request fails due to a connectivity issue, they show that cached data instead of a blank screen, with an "Offline - showing saved data" banner. Real API errors (like a 401 from an expired token) are *not* swallowed by this — only connection failures fall back to cache.
- This is read-only offline support — there's no queueing of writes (recording milk, adding a customer, etc.) made while offline. Those still require a live connection, and will show a clear connection error if attempted offline.

## Real SMS via TextBee
Today's milk entries now also send an actual SMS to the customer (not just the in-app pill/popup), using [TextBee](https://textbee.dev) — a free/cheap service that turns a spare Android phone into an SMS gateway.

1. Install the TextBee app on any Android phone (needs a SIM with SMS credit).
2. In the app, add the device and grab your **API Key** and **Device ID** from the dashboard.
3. Put them in `.env`:
   ```
   TEXTBEE_API_KEY=your_key_here
   TEXTBEE_DEVICE_ID=your_device_id_here
   DEFAULT_COUNTRY_CODE=+91
   ```
4. That's it — `app/services/sms.py` picks them up automatically. If they're left blank (like in local dev without a TextBee device set up), SMS sending just quietly does nothing and the in-app notification still works fine — nothing breaks either way.

Only *today's* entries trigger an SMS (matching the "आज का दूध" in-app message) — backdated entries only get the neutral in-app notification, since a same-day SMS for an old date wouldn't make sense.

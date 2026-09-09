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
- **Admin login:** username + password. Account created once via `python -m scripts.create_admin`, run locally.
- **Milkman login:** username + password. Accounts are created by the admin (`POST /admin/milkmen`, or `python -m scripts.create_milkman` for quick local testing) — milkmen never self-register.
- **Customer login:** phone number only, no password. The first device to log in with a given number "claims" it — after that, the same number can't log in from a different device until the milkman clears it via `POST /customers/{id}/reset-device`.
- **Notifications:** In-app only for now (`notifications` table + `/notifications/me`). Firebase push comes in v2.
- **Database:** SQLite for local dev — a single file (`milk_delivery.db`), zero install, no server to run. Swap to Aiven Postgres later by changing `.env` and uncommenting `asyncpg` in `requirements.txt` — nothing else in the codebase needs to change (same pattern as your LeetTrack backend).
- **Device lock resets:** only the admin can clear a customer's device lock (`POST /admin/customers/{id}/reset-device`) — milkmen no longer have this power, so they can't bump a customer off their own phone.
- **Same-day edits only:** a milkman can edit a milk entry's quantity only on the day it was logged (`PATCH /milk-entries/{id}` returns 403 for past dates). Past entries are locked for integrity.
- **Notifications in Hindi for today's milk:** when an entry is logged or edited for *today*, the customer's notification reads "आज का दूध: X L". Back-dated entries get a neutral English message instead, since "today's milk" wouldn't make sense for them.
- **Activity logs, per role:** `/audit-logs/me` (customer, own account only), `/audit-logs/milkman` (milkman, own actions — the app filters this to today's entries for the "My Log" tab), `/admin/audit-logs` (everything, with year/month filtering), plus `/admin/audit-logs/export` (CSV) and `/admin/audit-logs/wipe` (permanent delete, scoped by month or, with `confirm=true`, everything).

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
- `POST /auth/admin-login` with `{"username": "...", "password": "..."}` → returns a JWT, same as the other login paths.
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

## A note on the app name
The app is titled **"Milk Legder"** per your instruction — kept your exact spelling. If that was meant to read "Milk Ledger," just say so and I'll fix the title string and Android label in one pass.

## Setting the Android app label
`flutter create .` generates its own `AndroidManifest.xml` with a default label. After running it, open `android/app/src/main/AndroidManifest.xml` and set:
```xml
android:label="Milk Legder"
```
on the `<application>` tag.

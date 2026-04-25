# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Temizlik Takip Sistemi** — a cleaning management system with a Node.js/Express REST API backend and a Flutter mobile frontend. Staff scan QR codes to log cleaning sessions; admins manage users, schedule tasks, and view weekly KPI dashboards.

## Commands

### Backend

```bash
cd backend/backend
npm run dev      # Start server (port 4000)
npm start        # Same as dev
node src/create_user_cli.js   # Interactive user creation
node src/create_room_cli.js   # Interactive room creation
```

No test suite is configured.

### Frontend (Flutter)

```bash
cd frontend
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Static analysis (flutter_lints)
flutter build apk        # Build Android APk
```

## Architecture

### Backend (`backend/backend/src/`)

- `index.js` — Express app entry point, route mounting, CORS setup
- `db.js` — SQLite initialization; tables are auto-created and schema is migrated (ALTER TABLE with existence checks) on startup. A default admin is seeded on first run using `ADMIN_DEFAULT_EMAIL` / `ADMIN_DEFAULT_PASSWORD` from env; seed is skipped if either var is absent or the email already exists in the DB.
- `middleware/authMiddleware.js` — JWT validation; attaches `req.user` (id, name, role)
- `routes/` — auth, rooms, cleaning, admin, tasks

**Database**: SQLite file at `backend/backend/temizlik_sistemi.sqlite`. Key tables:
- `users` — role (`admin`/`staff`), `approval_status` (`pending`/`approved`/`rejected`)
- `rooms` — belongs to `locations`
- `cleaning_logs` — stores logs with optional `notes` and base64 `image`
- `scheduled_tasks` — assigned to users; auto-matched to a cleaning log on creation

**Database API style**: callback-based `sqlite3` (not Promises). Keep new queries consistent with existing patterns.

**Key business logic**:
- Registration is restricted to `@pau.edu.tr` email domain; new accounts require admin approval
- Creating a cleaning log automatically finds and completes the nearest matching pending scheduled task for that room/user
- Weekly KPI score: `(total*5) + (completed*3) + (noted*1) + (photo*2) + (on_time*4) - (late*2)`

**Security notes**:
- `JWT_SECRET` is read from `process.env` — `index.js` calls `process.exit(1)` at startup if it is missing (fail-fast)
- `GET /api/users` requires a valid token **and** `role === 'admin'`; unauthenticated or staff requests get 401/403
- CORS uses a whitelist: only origins listed in `ALLOWED_ORIGINS` env var are accepted; requests with no `Origin` header (mobile, curl) pass through
- Admin seed reads `ADMIN_DEFAULT_EMAIL` and `ADMIN_DEFAULT_PASSWORD` from env; if either is absent the seed is skipped — no password exists anywhere in source code

**Environment configuration** (`backend/backend/.env`):
Copy `.env.example` to `.env` and fill in the values. Required variables:
- `JWT_SECRET` — minimum 64 random characters (`node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`)
- `ADMIN_DEFAULT_EMAIL` / `ADMIN_DEFAULT_PASSWORD` — used for first-run admin seed
- `ALLOWED_ORIGINS` — comma-separated list of allowed CORS origins
- `PORT` — defaults to `4000`

**Security gotchas**:
- **dotenv and `#`**: dotenv treats unquoted `#` as a comment delimiter, silently truncating the rest of the value. Any `.env` value containing `#`, `$`, or `!` **must** be wrapped in double quotes (e.g. `ADMIN_DEFAULT_PASSWORD="Pa$$w0rd#99"`). This bit us during production prep — a 16-char password was read as 9 chars until the bug was caught via `bcrypt.compare` returning false.

### Frontend (`frontend/lib/`)

- `main.dart` — app entry, named route definitions, token-aware initial route
- `screens/` — one file per screen; no separate state management layer
- Auth token stored in `SharedPreferences`; all authenticated screens read the token and call the API directly using the `http` package inside `FutureBuilder` widgets
- API base URL is hardcoded to `http://10.0.2.2:4000` (Android emulator loopback). Change this in each screen file for real-device or production use.

**Role-based routing**: `home_screen.dart` renders different navigation options for `admin` vs `staff` roles.

**QR flow**: `qr_cleaning_screen.dart` uses `mobile_scanner` to scan a room QR code (contains the integer room ID), then navigates to the cleaning log form.

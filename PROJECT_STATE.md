# Project State: Crypto-to-Fiat Off-Ramp Platform

## 1. What Is Built
- **Monorepo Architecture**: Workspaces initialized (`/packages/shared`, `/apps/api`, `/apps/admin`, `/apps/mobile`, `/docs`).
- **Shared Domain Package (`@offramp/shared`)**: Enums, types, and `MoneyUtil` for exact integer minor-unit arithmetic (kobo, pesewas, satoshis, micro-units).
- **PostgreSQL 17 & Redis 7 Infrastructure**: Database `offramp_db` migrated with 15 Prisma models; Redis 7 caching and rate limiting connected.
- **Master Ledger & Fixture Seed**: Seeded master double-entry accounts, super admin, test user, KYC Tier 1 profile, wallets, bank accounts, and initial rates.
- **Authentication & Security Engine (`/apps/api`)**:
  - OTP request and verification service with Redis rate limiting and attempt caps.
  - User signup and login with JWT access token and rotating refresh token sessions.
  - Device fingerprinting and session revocation.
  - Transaction PIN service with bcrypt hashing, attempt counter, and 30-minute lockout after 5 consecutive failures.
  - Two-Factor Authentication (TOTP) with secret generation, QR code data URL, enable, and disable.
  - Staff / Admin login with role-based access control (`SUPER_ADMIN`, `ADMIN`, `SUPPORT`, `COMPLIANCE`).
  - Rate limiting via `@nestjs/throttler` and route-level protection.
- **Automated Tests**: 16/16 E2E tests passing in `apps/api/test/auth.e2e-spec.ts`.
- **Documentation**: `/docs/schema.md` and `/docs/api.md` updated.
- **Mobile Theme & Design Tokens**: Flutter theme with "Green Gradients & Cousins" palette in `apps/mobile/lib/theme/app_colors.dart`.

## 2. What Is Mocked / Sandboxed
- Sandbox OTP code is returned in response body during development mode.
- Mock exchange rates and sandbox crypto deposit addresses.

## 3. API Endpoints That Exist
- `POST /api/v1/auth/otp/request`
- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/admin/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/pin/set`
- `POST /api/v1/auth/pin/verify`
- `POST /api/v1/auth/pin/change`
- `POST /api/v1/auth/2fa/generate`
- `POST /api/v1/auth/2fa/enable`
- `POST /api/v1/auth/2fa/disable`
- `GET /api/v1/auth/devices`
- `DELETE /api/v1/auth/devices/:id`

## 4. Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis URI
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: Auth signing keys
- `PORT`: `4000`

## 5. Decisions Made and Why
- **Bcrypt + Lockout for PINs**: 4-digit transaction PINs are securely hashed and protected against brute-force attacks via a 5-attempt threshold that triggers a 30-minute lockout.
- **Session-bound Refresh Tokens**: Refresh tokens embed the database session ID and are stored as one-way hashes to detect token replay or theft.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- **Prompt 3: Ledger service**
  - Build the ledger module: create accounts, post balanced entries in a DB transaction, reject unbalanced entries, compute balances from entries, and expose `credit(user, amount, ref)`, `debit(user, amount, ref)`, `hold(...)`, `release(...)`.
  - All calls require an idempotency key.
  - Write thorough tests including concurrency and duplicates.

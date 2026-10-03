# Project State: Crypto-to-Fiat Off-Ramp Platform

## 1. What Is Built
- **Monorepo Architecture**: Workspaces initialized (`/packages/shared`, `/apps/api`, `/apps/admin`, `/apps/mobile`, `/docs`).
- **Shared Domain Package (`@offramp/shared`)**: Enums, types, and `MoneyUtil` for exact integer minor-unit arithmetic (kobo, pesewas, satoshis, micro-units).
- **PostgreSQL 17 & Redis 7 Infrastructure**: Database `offramp_db` migrated with 15 Prisma models; Redis 7 caching, rate limiting, and session stores active.
- **Authentication & Security Engine (`/apps/api`)**:
  - OTP verification with rate limiting and attempt caps.
  - JWT Access Token & Refresh Token session rotation.
  - Transaction PIN with high-salt bcrypt hashing and 30-minute lockout after 5 consecutive failed attempts.
  - TOTP Two-Factor Authentication with QR code data URLs.
  - Role-based access control (`SUPER_ADMIN`, `ADMIN`, `SUPPORT`, `COMPLIANCE`).
- **Double-Entry Ledger Module (`/apps/api/src/ledger`)**:
  - Core primitives: `postBalancedEntry`, `credit`, `debit`, `hold`, `release`, `settleHold`.
  - Dynamic live balance calculation from immutable journal entries ($\sum \text{Debits} - \sum \text{Credits}$).
  - Strict idempotency key protection preventing double-crediting or duplicate postings.
  - Concurrency verified with atomic database transactions.
- **Automated Test Suite**: 25/25 E2E tests passing across Auth and Ledger modules.
- **Documentation**: `/docs/schema.md` and `/docs/api.md` updated with complete specifications.

## 2. What Is Mocked / Sandboxed
- Sandbox OTP code transparency in development mode.
- Mock exchange rates and sandbox crypto deposit addresses.

## 3. API Endpoints That Exist
- **Auth**: `POST /auth/otp/request`, `POST /auth/signup`, `POST /auth/login`, `POST /auth/admin/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`, `POST /auth/pin/set`, `POST /auth/pin/verify`, `POST /auth/pin/change`, `POST /auth/2fa/generate`, `POST /auth/2fa/enable`, `POST /auth/2fa/disable`, `GET /auth/devices`, `DELETE /auth/devices/:id`.
- **Ledger**: `GET /ledger/balances`, `POST /ledger/hold`, `POST /ledger/release`, `POST /ledger/credit`, `POST /ledger/debit`.

## 4. Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis URI
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: Auth signing keys
- `PORT`: `4000`

## 5. Decisions Made and Why
- **No Editable Balance Column**: Followed Rule #1 strictly; balances are computed by aggregating immutable double-entry journal lines.
- **Two-tier Sub-Accounts per User**: Each user receives an `ACTIVE` liability sub-account (`2010-USER-...`) and a `HOLD` liability sub-account (`2020-HOLD-...`) so payout reservations never compromise available balances.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- **Prompt 4: Wallets and deposit detection (adapter pattern)**
  - Create `WalletProvider` interface: `createAddress(user, asset, network)`, `getDepositStatus(txHash)`, `verifyWebhookSignature(req)`.
  - Implement `SandboxWalletProvider` (simulated addresses & simulated deposits via admin endpoint).
  - Build deposit webhook handler: signature verification, dedupe by `tx_hash`, confirmation tracking, rate locking at first detection, and ledger credit upon finality.
  - Add TODO adapter file for production provider with docs link.

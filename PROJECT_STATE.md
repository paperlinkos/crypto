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
- **Wallets & Deposit Detection Module (`/apps/api/src/wallets`)**:
  - `IWalletProvider` interface and `SandboxWalletProvider` generating valid-format TRC20, Bitcoin, and EVM deposit addresses with QR code generation.
  - `ProductionWalletProvider` template with documentation links for Yellow Card, Fireblocks, and Quidax.
  - Deposit webhook handler with signature verification, deduplication by `tx_hash`, and confirmation tracking.
  - **Rate Lock Guarantee**: Live spot rate locked upon initial detection (`1/3` confirmations).
  - **Automatic Double-Entry Settlement**: Converts crypto micro-units to fiat kobo and posts balanced ledger credit upon finality (`3/3` confirmations).
  - Admin deposit simulation tool (`POST /wallets/simulate-deposit`).
- **Automated Test Suite**: 32/32 E2E tests passing across Auth, Ledger, and Wallets.
- **Documentation**: `/docs/schema.md` and `/docs/api.md` updated with complete specifications.

## 2. What Is Mocked / Sandboxed
- Sandbox wallet provider simulates blockchain addresses and HMAC signatures.
- Sandbox OTP transparency during development.

## 3. API Endpoints That Exist
- **Auth**: `POST /auth/otp/request`, `POST /auth/signup`, `POST /auth/login`, `POST /auth/admin/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`, `POST /auth/pin/set`, `POST /auth/pin/verify`, `POST /auth/pin/change`, `POST /auth/2fa/generate`, `POST /auth/2fa/enable`, `POST /auth/2fa/disable`, `GET /auth/devices`, `DELETE /auth/devices/:id`.
- **Ledger**: `GET /ledger/balances`, `POST /ledger/hold`, `POST /ledger/release`, `POST /ledger/credit`, `POST /ledger/debit`.
- **Wallets**: `GET /wallets`, `POST /wallets/assign`, `GET /wallets/deposits`, `GET /wallets/deposits/:txHash`, `POST /wallets/webhook`, `POST /wallets/simulate-deposit`.

## 4. Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis URI
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: Auth signing keys
- `PORT`: `4000`

## 5. Decisions Made and Why
- **Decoupled Wallet Adapters**: Used `IWalletProvider` interface so that switching custody providers (Yellow Card, Fireblocks, Quidax) requires zero changes to core accounting or deposit logic.
- **Instant Rate Lock at Mempool/1st Confirmation**: Prevents user from suffering slippage during the 3-block confirmation window.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- **Prompt 5: Rates engine**
  - Create `RateProvider` interface and a service that fetches spot prices (mock/sandbox first), applies a configurable spread per asset, caches in Redis, and stores snapshots in the `rates` table.
  - Expose `GET /rates` and `GET /rates/quote?asset=&amount=`.
  - Add admin endpoint to configure spread.
  - Stale-rate protection: if feed is older than N seconds (e.g. 90s), quotes are refused.

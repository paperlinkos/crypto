# Project State: Crypto-to-Fiat Off-Ramp Platform

## 1. What Is Built
- **Monorepo Architecture**: Workspaces initialized (`/packages/shared`, `/apps/api`, `/apps/admin`, `/apps/mobile`, `/docs`).
- **Shared Domain Package (`@offramp/shared`)**: Enums, types, and `MoneyUtil` for exact integer minor-unit arithmetic (kobo, pesewas, satoshis, micro-units).
- **PostgreSQL 17 & Redis 7 Infrastructure**: Database `offramp_db` migrated with 15 Prisma models; Redis 7 caching, rate limiting, and session stores active.
- **Authentication & Security Engine (`/apps/api`)**: OTP verification, JWT Access/Refresh rotation, PIN lockout after 5 fails, TOTP 2FA, and RBAC guards.
- **Double-Entry Ledger Module (`/apps/api/src/ledger`)**: Core double-entry journal postings, dynamic balance derivation, hold/release balance reservation, and strict idempotency.
- **Wallets & Deposit Detection Module (`/apps/api/src/wallets`)**: Dedicated address generation with QR codes, deposit webhook tracking, rate locking at 1st confirmation, and automated ledger settlement at 3 confirmations.
- **Rates Engine & Spread Controller (`/apps/api/src/rates`)**:
  - `IRateProvider` interface and `SandboxRateProvider` feeding spot prices for NGN and GHS pairs.
  - `ProductionRateProvider` template for Binance P2P and CoinGecko.
  - Configurable spread percentage per asset with admin update endpoint (`PATCH /rates/spread`).
  - Redis cache with 30-second TTL and DB snapshot logging.
  - **Stale-Rate Protection**: Automatically refuses quotes and disables conversions if rate feed latency exceeds 90 seconds.
  - Guaranteed 15-minute off-ramp quote calculator (`GET /rates/quote`).
- **Automated Test Suite**: 37/37 E2E tests passing across Auth, Ledger, Wallets, and Rates.
- **Documentation**: `/docs/schema.md` and `/docs/api.md` updated with complete specifications.

## 2. What Is Mocked / Sandboxed
- Sandbox market spot rates and simulated deposit addresses.
- Sandbox OTP transparency during development mode.

## 3. API Endpoints That Exist
- **Auth**: `POST /auth/otp/request`, `POST /auth/signup`, `POST /auth/login`, `POST /auth/admin/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`, `POST /auth/pin/set`, `POST /auth/pin/verify`, `POST /auth/pin/change`, `POST /auth/2fa/generate`, `POST /auth/2fa/enable`, `POST /auth/2fa/disable`, `GET /auth/devices`, `DELETE /auth/devices/:id`.
- **Ledger**: `GET /ledger/balances`, `POST /ledger/hold`, `POST /ledger/release`, `POST /ledger/credit`, `POST /ledger/debit`.
- **Wallets**: `GET /wallets`, `POST /wallets/assign`, `GET /wallets/deposits`, `GET /wallets/deposits/:txHash`, `POST /wallets/webhook`, `POST /wallets/simulate-deposit`.
- **Rates**: `GET /rates`, `GET /rates/quote`, `PATCH /rates/spread`, `POST /rates/refresh`.

## 4. Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis URI
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: Auth signing keys
- `PORT`: `4000`

## 5. Decisions Made and Why
- **Redis Multi-tier Caching**: Live spot rates cached with 30s TTL to prevent rate limiter bottlenecks, backed by immutable database snapshot logging for historical audit.
- **90-Second Stale Rate Cutoff**: Protects treasury against sudden market volatility by refusing off-ramp quotes if price feeds go offline.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- **Prompt 6: KYC**
  - Create `KycProvider` interface (`verifyBvn`, `verifyNin`, `verifyFace`, `verifyDocument`) with a sandbox implementation.
  - Implement tiers with limits (daily and per-transaction) enforced on the payout path.
  - Store only provider references and status, not raw ID images.
  - Add admin review states (`pending`, `approved`, `rejected`, `needs-more-info`) and audit logs.

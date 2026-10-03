# Project State: Crypto-to-Fiat Off-Ramp Platform

## 1. What Is Built
- **Monorepo Architecture**: Workspaces initialized (`/packages/shared`, `/apps/api`, `/apps/admin`, `/apps/mobile`, `/docs`).
- **Shared Domain Package (`@offramp/shared`)**: Enums, types, and `MoneyUtil` for exact integer minor-unit arithmetic (kobo, pesewas, satoshis, micro-units).
- **PostgreSQL 17 & Redis 7 Infrastructure**: Database `offramp_db` migrated with 15 Prisma models; Redis 7 active for caching, rate limiting, and sessions.
- **Authentication & Security Engine (`/apps/api`)**: OTP verification, JWT Access/Refresh rotation, PIN lockout after 5 fails, TOTP 2FA, and RBAC guards.
- **Double-Entry Ledger Module (`/apps/api/src/ledger`)**: Core journal postings, dynamic balance derivation, hold/release balance reservation, and strict idempotency.
- **Wallets & Deposit Detection Module (`/apps/api/src/wallets`)**: Dedicated address generation with QR codes, deposit webhook tracking, rate locking at 1st confirmation, and automated ledger settlement at 3 confirmations.
- **Rates Engine & Spread Controller (`/apps/api/src/rates`)**: Live spot prices, configurable spread %, Redis caching, 90-second stale rate cutoff, and guaranteed 15-minute off-ramp quotes.
- **KYC & Tiered Compliance Engine (`/apps/api/src/kyc`)**:
  - `IKycProvider` interface and `SandboxKycProvider` for BVN/NIN, Biometric Face Liveness, and Government ID checks.
  - `ProductionKycProvider` template for Smile Identity and Dojah.
  - Tier limits: Tier 0 (₦0), Tier 1 (₦500k/day), Tier 2 (₦5M/day), Tier 3 (₦50M/day).
  - Payout limit enforcement logic (`enforcePayoutLimits`) checking single-tx and 24h rolling daily aggregates.
  - Compliance review queue (`GET /kyc/admin/queue`) and manual review actions with audit logging.
  - Privacy compliance: stores only provider references and masked numbers, zero raw biometric image files.
- **Automated Test Suite**: 46/46 E2E tests passing across Auth, Ledger, Wallets, Rates, and KYC.
- **Documentation**: `/docs/schema.md` and `/docs/api.md` updated with complete specifications.

## 2. What Is Mocked / Sandboxed
- Sandbox KYC provider simulates NIBSS BVN/NIN lookups and face liveness.
- Sandbox rates, deposit wallets, and OTP transparency during development.

## 3. API Endpoints That Exist
- **Auth**: `POST /auth/otp/request`, `POST /auth/signup`, `POST /auth/login`, `POST /auth/admin/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`, `POST /auth/pin/set`, `POST /auth/pin/verify`, `POST /auth/pin/change`, `POST /auth/2fa/generate`, `POST /auth/2fa/enable`, `POST /auth/2fa/disable`, `GET /auth/devices`, `DELETE /auth/devices/:id`.
- **Ledger**: `GET /ledger/balances`, `POST /ledger/hold`, `POST /ledger/release`, `POST /ledger/credit`, `POST /ledger/debit`.
- **Wallets**: `GET /wallets`, `POST /wallets/assign`, `GET /wallets/deposits`, `GET /wallets/deposits/:txHash`, `POST /wallets/webhook`, `POST /wallets/simulate-deposit`.
- **Rates**: `GET /rates`, `GET /rates/quote`, `PATCH /rates/spread`, `POST /rates/refresh`.
- **KYC**: `GET /kyc/status`, `POST /kyc/tier1`, `POST /kyc/tier2`, `POST /kyc/tier3`, `GET /kyc/admin/queue`, `PATCH /kyc/admin/review/:profileId`.

## 4. Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis URI
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: Auth signing keys
- `PORT`: `4000`

## 5. Decisions Made and Why
- **Privacy-First ID Management**: Excluded raw document and selfie blobs from database storage; only vendor-issued cryptographically signed references (`providerRef`) and masked strings are retained.
- **24-Hour Rolling Aggregate**: Daily tier limits calculate dynamically against the last 24 hours of successful/processing payouts rather than a fixed calendar day, preventing end-of-day limit bypasses.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- **Prompt 7: Bank accounts and payouts**
  - Create `PayoutProvider` interface (`resolveAccount`, `listBanks`, `createTransfer`, `getTransferStatus`, `verifyWebhookSignature`) with a sandbox implementation.
  - Implement: add bank account with NUBAN name enquiry.
  - Withdraw from ledger balance: place hold, trigger payout, then settle on success or release on failure.
  - Retries with backoff and reconciliation job for pending payouts.
  - Auto-settlement toggle (deposit confirmed $\rightarrow$ convert $\rightarrow$ pay out automatically to verified bank).

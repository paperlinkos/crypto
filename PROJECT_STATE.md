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
- **Bank Accounts & Off-Ramp Payouts Engine (`/apps/api/src/payouts`)**:
  - `IPayoutProvider` adapter architecture with `SandboxPayoutProvider` (supporting 11 Nigerian commercial banks/fintechs & 5 Ghanaian mobile money providers) and `ProductionPayoutProvider` template (Paystack / Monnify).
  - NUBAN bank account resolution with real name enquiry.
  - Bank account profile storage with default account management and duplicate protection.
  - Double-entry off-ramp withdrawal pipeline: PIN verification $\rightarrow$ KYC limit check $\rightarrow$ Ledger hold placed on active balance $\rightarrow$ Gateway transfer dispatched $\rightarrow$ Settle hold on success / Release hold on failure.
  - Asynchronous gateway webhook receiver with HMAC signature verification.
  - Auto-settlement toggle (`autoPayout: true`) and automated payout trigger upon crypto deposit finality.
  - Admin reconciliation worker for pending transfers.
- **Automated Test Suite**: 58/58 E2E tests passing across all 6 core API suites (`auth`, `ledger`, `wallets`, `rates`, `kyc`, `payouts`).
- **Documentation**: `/docs/schema.md` and `/docs/api.md` updated with complete specifications.

## 2. What Is Mocked / Sandboxed
- Sandbox Payout Provider simulates NUBAN lookup and gateway transfer lifecycle.
- Sandbox KYC Provider simulates BVN/NIN and facial biometrics.
- Sandbox Rate Feed simulates live NGN/GHS spot prices.
- Sandbox Wallet Provider simulates TRON/Bitcoin deposit webhooks.

## 3. API Endpoints That Exist
- **Auth**: `POST /auth/otp/request`, `POST /auth/signup`, `POST /auth/login`, `POST /auth/admin/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`, `POST /auth/pin/set`, `POST /auth/pin/verify`, `POST /auth/pin/change`, `POST /auth/2fa/generate`, `POST /auth/2fa/enable`, `POST /auth/2fa/disable`, `GET /auth/devices`, `DELETE /auth/devices/:id`.
- **Ledger**: `GET /ledger/balances`, `POST /ledger/hold`, `POST /ledger/release`, `POST /ledger/credit`, `POST /ledger/debit`.
- **Wallets**: `GET /wallets`, `POST /wallets/assign`, `GET /wallets/deposits`, `GET /wallets/deposits/:txHash`, `POST /wallets/webhook`, `POST /wallets/simulate-deposit`.
- **Rates**: `GET /rates`, `GET /rates/quote`, `PATCH /rates/spread`, `POST /rates/refresh`.
- **KYC**: `GET /kyc/status`, `POST /kyc/tier1`, `POST /kyc/tier2`, `POST /kyc/tier3`, `GET /kyc/admin/queue`, `PATCH /kyc/admin/review/:profileId`.
- **Payouts**: `GET /payouts/banks`, `POST /payouts/resolve-account`, `POST /payouts/bank-accounts`, `GET /payouts/bank-accounts`, `DELETE /payouts/bank-accounts/:id`, `POST /payouts/withdraw`, `PATCH /payouts/auto-settlement`, `GET /payouts/history`, `POST /payouts/webhook`, `POST /payouts/reconcile`.

## 4. Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string (`postgresql://offramp_user:offramp_secret_password@localhost:5432/offramp_db`)
- `REDIS_URL`: Redis URI (`redis://localhost:6379`)
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: Auth signing keys
- `PORT`: `4000`

## 5. Decisions Made and Why
- **Hold-and-Settle Double-Entry Architecture**: Customer funds are immediately placed into a `HOLD` liability account during off-ramp dispatch. If the recipient bank rejects or delays the transfer, funds remain safe and can be atomically released back to `ACTIVE` available balance without manual account edits.
- **Strict Idempotency Guard**: All withdrawals and webhooks utilize unique idempotency keys with unique database constraints to prevent duplicate disbursements under network retries.
- **Dynamic Deposit-to-Payout Pipeline**: When `autoPayout` is enabled on the user profile, confirmed crypto deposits automatically convert and route directly to their default verified bank account.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- **Phase 8: Flutter Client Mobile Application (`/apps/mobile`)**
  - Implement full design system with "Green Gradients & Cousins" palette (Electric Mint `#00E599`, Deep Emerald `#0E5A3E`, Obsidian Forest `#0A140F`, Porcelain Sage `#F6FAF7`).
  - Configure navigation framework (`go_router`) and state management (Riverpod).
  - Build screens:
    1. Onboarding & Phone/Email OTP Auth.
    2. 4-Digit PIN Setup & Biometrics (FaceID / Fingerprint).
    3. Home Dashboard (Balance Card, Quick Actions, Live Rates Ticker, Recent Activity Feed).
    4. Crypto Deposit Screen (QR Code, 1-tap Copy Address, Blockchain Confirmation Progress Ring).
    5. Live Rate Calculator & 15-Minute Guaranteed Quote Countdown Ring.
    6. Bank Account Management (NUBAN Bank Name Enquiry & Saved Accounts).
    7. Off-Ramp Instant Withdrawal & Auto-Payout Toggle.
    8. KYC Tier Progression & Verification Status Tracker.

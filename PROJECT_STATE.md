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
  - `IPayoutProvider` adapter architecture with `SandboxPayoutProvider` (11 Nigerian banks & 5 Ghanaian mobile money providers) and `ProductionPayoutProvider` template (Paystack / Monnify).
  - NUBAN bank account resolution with real name enquiry.
  - Double-entry off-ramp withdrawal pipeline: PIN verification $\rightarrow$ KYC limit check $\rightarrow$ Ledger hold placed on active balance $\rightarrow$ Gateway transfer dispatched $\rightarrow$ Settle hold on success / Release hold on failure.
  - Asynchronous gateway webhook receiver with HMAC signature verification.
  - Auto-settlement toggle and automated payout trigger upon crypto deposit finality.
- **Flutter Client Mobile Application (`/apps/mobile`)**:
  - **Design System ("Green & Its Cousins")**: Electric Mint (`#00E599`), Deep Emerald (`#0E5A3E`), Obsidian Forest (`#0A140F`), Porcelain Sage (`#F6FAF7`), Google Outfit typography.
  - **State Management & Router**: Flutter Riverpod 2.6 (`authProvider`, `ratesProvider`, `walletsProvider`) and GoRouter 14.8.
  - **Key Screens**:
    1. `OnboardingScreen`: Feature card stack with value proposition.
    2. `LoginScreen`: Email/Phone toggle, signup/login switch, and error banners.
    3. `OtpVerificationScreen`: 6-digit OTP verification with sandbox code transparency.
    4. `PinSetupScreen`: 4-digit numeric keypad with biometric Face ID / Fingerprint toggle.
    5. `HomeDashboardScreen`: Estimated fiat portfolio in NGN/GHS, live rates ticker, quick action pills, and recent deposits activity feed.
    6. `DepositScreen`: Asset & network pill selector, high-contrast QR code generation, 1-tap copy, and 15-minute rate lock guarantee info.
    7. `RateCalculatorScreen`: Live quote calculator with 15-minute guaranteed rate lock countdown circular progress ring and spread breakdown.
    8. `AppScaffold`: Minimalist floating pill dock navigation.
- **Automated Test Suite**: 58/58 NestJS backend API tests passing + Flutter widget smoke test passing.
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
- **Floating Pill Dock Navigation**: Keeps primary navigation within natural thumb reach while maximizing canvas real estate for cards and live progress rings.
- **Real-Time 15-Minute Countdown Ring**: Visual feedback with `ProgressRing` clearly communicates the guaranteed rate lock time window before market re-quote.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- **Phase 9: Next.js Admin Dashboard (`/apps/admin`)**
  - Implement Next.js + Tailwind CSS back-office dashboard.
  - Admin login with RBAC (`ADMIN`, `COMPLIANCE`, `SUPER_ADMIN`).
  - KYC compliance review queue with 1-click approve/reject.
  - Transactions, deposits, and payouts inspector with ledger balance audit trail.
  - Rate & spread controller.
  - Sandbox Deposit Simulator tool for live E2E off-ramp testing.

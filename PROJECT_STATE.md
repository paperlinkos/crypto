# Project State: Crypto-to-Fiat Off-Ramp Platform

## 1. What Is Built
- **Monorepo Architecture**: Clean workspaces (`/packages/shared`, `/apps/api`, `/apps/admin`, `/apps/mobile`, `/docs`).
- **Shared Domain Package (`@offramp/shared`)**: Exact integer minor-unit arithmetic (kobo, pesewas, satoshis, micro-units).
- **PostgreSQL 17 & Redis 7 Infrastructure**: Database `offramp_db` with 15 Prisma models; Redis 7 for caching, rate limiting, and sessions.
- **Authentication & Security Engine (`/apps/api`)**: OTP verification, JWT Access/Refresh rotation, PIN lockout after 5 fails, TOTP 2FA, and RBAC guards.
- **Double-Entry Ledger Module (`/apps/api/src/ledger`)**: Core journal postings, dynamic balance derivation, hold/release balance reservation, and strict idempotency.
- **Wallets & Deposit Detection Module (`/apps/api/src/wallets`)**: Dedicated address generation with QR codes, deposit webhook tracking, rate locking at 1st confirmation, and automated ledger settlement at 3 confirmations.
- **Rates Engine & Spread Controller (`/apps/api/src/rates`)**: Live spot prices, configurable spread %, Redis caching, 90-second stale rate cutoff, and guaranteed 15-minute off-ramp quotes.
- **KYC & Tiered Compliance Engine (`/apps/api/src/kyc`)**:
  - `IKycProvider` adapter architecture with `SandboxKycProvider` and `ProductionKycProvider` (Smile Identity / Dojah).
  - Tier limits: Tier 0 (₦0), Tier 1 (₦500k/day), Tier 2 (₦5M/day), Tier 3 (₦50M/day) with 24-hr rolling limit enforcement.
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
  - **Screens**: Onboarding, Login/Signup, OTP Verification, PIN Setup with Biometrics, Home Dashboard, Deposit Crypto (with QR), and Rate Calculator (with 15-minute countdown progress ring).
- **Next.js Admin Dashboard (`/apps/admin`)**:
  - Role-based staff authentication (`ADMIN`, `COMPLIANCE`, `SUPER_ADMIN`).
  - Executive KPI Cards: 24h Settlement Volume, Float Buffer, Average Settlement Latency.
  - KYC Compliance Review Queue with 1-click Approve / Reject actions.
  - Real-time Rates & Spread Margin Adjuster.
  - Interactive **Sandbox Deposit Simulator** to broadcast test blockchain deposits and observe live ledger credits.
- **Automated Test Suite**: 58/58 NestJS backend API tests passing + Flutter widget smoke test passing + Next.js production build passing.
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
- `PORT`: `4000` (API), `3000` (Admin Next.js)

## 5. Decisions Made and Why
- **Decoupled Architecture**: Both mobile and admin frontends communicate strictly via the versioned REST API (`/api/v1`), maintaining clean boundaries and enabling independent mobile and web deployments.
- **Deposit Simulation in Admin**: Empowers compliance officers and QA engineers to test deposit detection, rate locks, and direct bank payouts in real time without real cryptocurrency gas fees.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- Ready for end-to-end user walkthrough, client demo, and sandbox verification.

# Project State: Crypto-to-Fiat Off-Ramp Platform

## 1. What Is Built
- **Project Structure**: Monorepo established (`/packages/shared`, `/apps/api`, `/apps/admin`, `/apps/mobile`, `/docs`).
- **Project Rules**: Codified in `AGENTS.md` and `sss.md`, enforcing double-entry ledger, integer minor units, idempotency, audit logging, and the Green & Cousins minimal UI design system.
- **Shared Domain Package (`@offramp/shared`)**: Compiled TypeScript package with domain enums (`UserStatus`, `KycTier`, `CryptoAsset`, `BlockchainNetwork`, `FiatCurrency`, `LedgerAccountType`), DTO interfaces, and `MoneyUtil` for exact integer minor-unit arithmetic (kobo, pesewas, satoshis, micro-units).
- **PostgreSQL & Redis Infrastructure**: Local PostgreSQL 17 and Redis 7 configured and connected.
- **Database Schema (`apps/api/prisma/schema.prisma`)**: 15 complete models satisfying Prompt 1: `User`, `Device`, `Session`, `KycProfile`, `Wallet`, `Deposit`, `LedgerAccount`, `LedgerEntry`, `Rate`, `BankAccount`, `Payout`, `WebhookLog`, `AuditLog`, `AdminUser`, `SupportTicket`.
- **Database Seeding (`apps/api/prisma/seed.ts`)**: Master double-entry ledger accounts (Vaults, Bank Float, Liabilities, FX Revenue, Fees), super admin user, test user (KYC Tier 1), verified GTBank account, USDT TRC20 / BTC wallets, and live sandbox rates.
- **Documentation**: `/docs/schema.md` complete with Mermaid ER diagram and accounting flows.

## 2. What Is Mocked / Sandboxed
- Sandbox wallet addresses and simulated rates in seed data.
- Business logic is not written yet (per Prompt 1 explicit instruction).

## 3. API Endpoints That Exist
- None yet (Database layer & schema established in Phase 1).

## 4. Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string (`postgresql://offramp_user:offramp_secret_password@localhost:5432/offramp_db?schema=public`)
- `REDIS_URL`: Redis cache/queue URI (`redis://localhost:6379`)
- `PORT`: API server port (`4000`)
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: Auth keys

## 5. Decisions Made and Why
- **PostgreSQL Native + Redis Docker**: Used host PostgreSQL 17 to bypass Docker VM disk capacity constraints, while running Redis in Docker container.
- **Prisma ORM**: Selected for type-safe schema migrations, auto-generated TypeScript clients, and explicit SQL migration files.
- **BigInt Minor Units**: Stored monetary values as integer minor units in database (`BigInt` / `@db.BigInt`) to completely eliminate floating-point drift.

## 6. Open TODOs / Known Bugs
- None.

## 7. Exact Next Task
- Run Prisma migration (`npx prisma migrate dev --name init_schema`) to create PostgreSQL tables.
- Execute seed script (`npm run prisma:seed`) to populate master ledger and test fixtures.
- Scaffold `/apps/mobile` (Flutter) and `/apps/admin` (Next.js) shell foundations.

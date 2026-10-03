# Project Rules: Crypto-to-Fiat Off-Ramp System

## 1. Project Overview & Scope
You are building a crypto-to-fiat off-ramp app for a client (Nigeria first, Ghana later).
Users receive crypto at a personal wallet address, the platform converts it to NGN/GHS at a live rate, and pays out to the user's verified bank account.

### Technology Stack
- **Mobile**: Flutter (iOS + Android + Web preview), Riverpod, go_router
- **Backend**: Node.js + NestJS + TypeScript, PostgreSQL, Redis, BullMQ
- **Admin**: Next.js + Tailwind CSS
- **Monorepo Structure**:
  - `/apps/mobile`: Flutter client application
  - `/apps/api`: NestJS core API backend
  - `/apps/admin`: Next.js back-office dashboard
  - `/packages/shared`: Shared TypeScript types, DTOs, ledger models, constants
  - `/docs`: `schema.md`, `api.md`
  - `/PROJECT_STATE.md`: Kept updated after every phase

---

## 2. Non-Negotiable Core Rules
1. **Double-Entry Ledger**: Money is stored in a double-entry ledger. Never keep a single editable "balance" field. Use integer minor units (kobo for NGN, pesewas for GHS, satoshi-equivalents for crypto), never floating-point numbers.
2. **Idempotency**: Every webhook, deposit handling, and payout call is strictly idempotent (idempotency key + unique database constraint).
3. **Secrets Management**: Never put private keys, API keys, or secrets in code. Use environment variables and maintain an up-to-date `.env.example`.
4. **Adapter Architecture**: All third-party services (wallet provider, payout provider, KYC provider, rate feed) sit behind interfaces/adapters so the client can swap vendors seamlessly. Build SANDBOX adapters first.
5. **Audit Logging**: Every state change on money, rates, or KYC writes an immutable audit log row.
6. **Test-Driven Security**: Write comprehensive tests for ledger, webhooks, and payouts before moving to the next phase.
7. **Small Commits & Traceability**: Work in disciplined, small commits. After each task, summarize what changed and what is next.
8. **Real APIs & Mocks**: Do not invent external API endpoints. If a provider's API details are unknown, create the interface and a mock, leaving a TODO with the docs link.
9. **Dependency Approval**: Ask before adding any dependency not already specified in the architecture.

---

## 3. UI/UX & Design System Rules: Minimalist & Green Cousins Palette
The user has established a refined, minimal design language inspired by modern card-stacking and organic fluid interfaces:
- **Palette ("Green & Its Cousins")**:
  - **Electric Mint / Jade**: Primary action, active badges, progress rings (`#00E599` to `#10B981`)
  - **Deep Emerald**: High-emphasis elements and rich gradients (`#0E5A3E` / `#0A3F2C`)
  - **Obsidian Forest**: Deep charcoal with emerald/pine undertones (`#0A140F` / `#111C16`) for dark containers and bottom activity sheets
  - **Porcelain Sage Canvas**: Clean, airy background (`#F6FAF7` / `#EEF4F0`) for high contrast without harsh white glare
  - **Muted Sage Subtext**: Clear secondary hierarchy (`#5E7368`)
- **Key UI Layout Patterns**:
  - **Pill Segmented Controls**: Generous rounded toggles (e.g. `Instant Off-Ramp` vs `Deposit & Hold`, `NGN` vs `GHS`)
  - **Organic Curved Containers**: Smooth, flowing dividers separating light summary zones from dark detailed activity feeds
  - **Circular Progress Rings**: Utilized for live rate lock countdowns (e.g. `14:32 mins remaining`), blockchain confirmations (e.g. `2/3 confirmations`), and KYC tier usage
  - **Floating Dock Navigation**: Organic floating pill bar with notched/accented center quick-action button
  - **Zero Placeholders**: Formatted currency symbols (₦ and ₵), real network badges, QR code renders, and interactive states.

---

## 4. Phase-by-Phase Execution & State Discipline
- Never rush. Each phase must be built, verified with functional navigation and test coverage, and documented.
- After every phase, execute **Prompt S** to update `/PROJECT_STATE.md` with:
  1. What is built
  2. What is mocked / sandboxed
  3. API endpoints that exist
  4. Env vars required
  5. Open TODOs & decisions made
  6. Exact next task

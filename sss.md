# Off-Ramp App: Build Prompts (Antigravity first, Claude later)

A crypto-to-naira/cedis app: per-user wallet addresses, live rates, KYC, bank payouts.
Paste prompts in order. Finish and test each phase before the next.
Defaults below (Flutter, NestJS, Postgres) are editable. Change them in Prompt 0.

---

## How to use this file

1. Create the project folder and put **Prompt 0** into the agent's project rules file (Antigravity rules / `AGENTS.md`).
2. Run Prompts 1 to 9 one at a time.
3. After every phase, run **Prompt S (State update)** so `PROJECT_STATE.md` stays current. This is what lets you switch to Claude without losing context.
4. When you switch tools, use **Prompt H (Handoff)**.

---

## Prompt 0: Project rules (paste once, keep permanent)

```
You are building a crypto-to-fiat off-ramp app for a client (Nigeria first, Ghana later).
Users receive crypto at a personal wallet address, the platform converts it to NGN/GHS
at a live rate, and pays out to the user's verified bank account.

STACK (change here if needed):
- Mobile: Flutter (iOS + Android), Riverpod, go_router
- Backend: Node.js + NestJS + TypeScript, PostgreSQL, Redis, BullMQ
- Admin: Next.js + Tailwind
- Monorepo: /apps/mobile, /apps/api, /apps/admin, /packages/shared

NON-NEGOTIABLE RULES:
1. Money is stored in a double-entry ledger. Never keep a single editable "balance" field.
   Use integer minor units (kobo, satoshi-equivalents), never floats.
2. Every webhook and payout call is idempotent (idempotency key + unique constraint).
3. Never put private keys, API keys, or secrets in code. Use env vars and a .env.example.
4. All third-party services (wallet provider, payout provider, KYC provider, rate feed)
   sit behind interfaces/adapters so the client can swap vendors. Build SANDBOX adapters first.
5. Every state change on money or KYC writes an audit log row.
6. Write tests for ledger, webhooks, and payouts before moving on.
7. Work in small commits. After each task, summarize what changed and what is next.
8. Do not invent API endpoints. If a provider's API details are unknown, create the
   interface and a mock, and leave a TODO with the docs link to fill in.
9. Ask me before adding any dependency that is not already listed.
```

---

## Prompt 1: Scaffold and data model

```
Set up the monorepo per the project rules. Then design the PostgreSQL schema with migrations for:
users, devices, sessions, kyc_profiles (tier, status, provider_ref), wallets (user, asset, network,
address, provider_ref), deposits (tx_hash, asset, amount, confirmations, status, locked_rate),
ledger_accounts, ledger_entries (double-entry), rates, bank_accounts (verified name, bank code,
account number), payouts (status, provider_ref, idempotency_key), webhooks_log, audit_logs,
admin_users, support_tickets.
Output: migrations, an ER summary in /docs/schema.md, and seed data for dev.
Do not write business logic yet.
```

## Prompt 2: Auth and security

```
Implement in /apps/api: email/phone signup with OTP, login, refresh tokens, device tracking,
2FA (TOTP) option, transaction PIN (hashed, with attempt lockout), rate limiting on auth routes,
and role-based guards (user, admin, support). Add tests. Document endpoints in /docs/api.md.
```

## Prompt 3: Ledger service

```
Build the ledger module: create accounts, post balanced entries in a DB transaction,
reject unbalanced entries, compute balances from entries, and expose
credit(user, amount, ref), debit(user, amount, ref), hold(...), release(...).
All calls require an idempotency key. Write thorough tests including concurrency and duplicates.
```

## Prompt 4: Wallets and deposit detection (adapter pattern)

```
Create a WalletProvider interface: createAddress(user, asset, network), getDepositStatus(txHash),
verifyWebhookSignature(req). Implement a SandboxWalletProvider (fake addresses, simulated deposits
via an admin endpoint). Build the deposit webhook handler: verify signature, dedupe by tx_hash,
track confirmations, lock the rate when a deposit is first detected, credit the ledger only when
confirmed. Add a TODO adapter file for the real provider with a link to its docs.
```

## Prompt 5: Rates engine

```
Create a RateProvider interface and a service that fetches spot prices (mock first), applies a
configurable spread per asset, caches in Redis, and stores snapshots in the rates table.
Expose GET /rates and GET /rates/quote?asset=&amount=. Add an admin endpoint to change the spread.
Include stale-rate protection: if the feed is older than N seconds, quotes are refused.
```

## Prompt 6: KYC

```
Create a KycProvider interface (verifyBvn, verifyNin, verifyFace, verifyDocument) with a sandbox
implementation. Implement tiers with limits (daily and per-transaction) enforced on the payout path.
Store only provider references and status, not raw ID images. Add admin review states
(pending, approved, rejected, needs-more-info) and audit logs.
```

## Prompt 7: Bank accounts and payouts

```
Create a PayoutProvider interface (resolveAccount, listBanks, createTransfer, getTransferStatus,
verifyWebhookSignature) with a sandbox implementation. Implement: add bank account with name
enquiry, withdraw from ledger balance (hold, then payout, then settle or release on failure),
retries with backoff, reconciliation job that checks pending payouts, and the auto-settlement
toggle (deposit confirmed, then convert, then pay out automatically).
```

## Prompt 8: Flutter app

```
Build the Flutter app in /apps/mobile against the API docs in /docs/api.md.
Screens: onboarding, signup/login/OTP, biometric + PIN setup, KYC flow, home (balances, recent
activity), wallets (select asset, show address + QR, copy), rate calculator, history + detail,
add bank account, withdraw, settings/security, support.
Use a clean design system (theme file, reusable components), loading/empty/error states,
and push notification hooks for deposit detected, deposit confirmed, payout sent/failed.
Start with the first 3 flows only (auth, wallets, calculator), then stop for review.
```

## Prompt 9: Admin dashboard

```
Build the Next.js admin in /apps/admin: login with roles, user search, KYC review queue,
transactions + deposits + payouts views with filters, manual payout approve/retry,
rate + spread controls, fraud flags, audit log viewer, and a "simulate deposit" tool (sandbox only).
```

---

## Prompt S: State update (run after every phase)

```
Update /PROJECT_STATE.md with: what is built, what is mocked, API endpoints that exist,
env vars required, open TODOs, known bugs, decisions made and why, and the exact next task.
Keep it under 150 lines and write it so a different AI tool could continue without any chat history.
```

## Prompt H: Handoff (when switching tools)

```
Read /PROJECT_STATE.md, /docs/schema.md, /docs/api.md and the project rules.
Summarize your understanding of the project in 10 lines, list anything unclear,
then continue with the "next task" in PROJECT_STATE.md. Do not refactor existing code
unless I ask.
```

---

## Before go-live checklist (hand to client)

- [ ] Client confirms licensing status or licensed partner in writing
- [ ] Real provider adapters swapped in and tested in provider sandboxes
- [ ] Security review and penetration test
- [ ] Low limits for the pilot, with monitoring and alerts on
- [ ] Rate-risk policy agreed (who absorbs price moves between deposit and settlement)

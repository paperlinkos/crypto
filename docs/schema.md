# Database Schema & Double-Entry Ledger Architecture

This document describes the PostgreSQL data model and double-entry accounting engine for the Off-Ramp Platform.

---

## 1. Entity-Relationship (ER) Diagram

```mermaid
erDiagram
    users ||--o{ devices : "registers"
    users ||--o{ sessions : "authenticates"
    users ||--o| kyc_profiles : "submits"
    users ||--o{ wallets : "owns"
    users ||--o{ deposits : "receives"
    users ||--o{ bank_accounts : "links"
    users ||--o{ payouts : "withdraws"
    users ||--o{ support_tickets : "opens"
    users ||--o{ ledger_accounts : "has sub-accounts"

    wallets ||--o{ deposits : "routes"
    deposits ||--o| payouts : "auto-settles"
    bank_accounts ||--o{ payouts : "receives fiat"

    ledger_accounts ||--o{ ledger_entries : "debits"
    ledger_accounts ||--o{ ledger_entries : "credits"

    admin_users ||--o{ support_tickets : "assigned"

    users {
        uuid id PK
        varchar email UK
        varchar phone_number UK
        varchar password_hash
        varchar pin_hash
        int pin_attempts
        timestamptz pin_locked_until
        boolean is_two_factor_enabled
        enum status
        varchar country
        boolean auto_payout
        timestamptz created_at
    }

    kyc_profiles {
        uuid id PK
        uuid user_id FK,UK
        enum tier
        enum status
        varchar provider_ref
        varchar id_type
        varchar id_number_masked
        varchar verified_name
        bigint daily_limit_minor
        bigint single_tx_limit_minor
        timestamptz created_at
    }

    wallets {
        uuid id PK
        uuid user_id FK
        enum asset
        enum network
        varchar address UK
        varchar provider_ref
        timestamptz created_at
    }

    deposits {
        uuid id PK
        varchar tx_hash UK
        uuid wallet_id FK
        uuid user_id FK
        enum asset
        enum network
        bigint amount_minor
        int confirmations
        int required_confirmations
        enum status
        decimal locked_rate
        timestamptz locked_rate_expires_at
        timestamptz detected_at
        timestamptz confirmed_at
    }

    ledger_accounts {
        uuid id PK
        varchar account_number UK
        varchar name
        enum type
        varchar currency
        uuid user_id FK
        boolean is_active
        timestamptz created_at
    }

    ledger_entries {
        uuid id PK
        varchar transaction_ref
        uuid debit_account_id FK
        uuid credit_account_id FK
        bigint amount_minor
        varchar currency
        varchar description
        jsonb metadata
        timestamptz created_at
    }

    bank_accounts {
        uuid id PK
        uuid user_id FK
        varchar bank_code
        varchar bank_name
        varchar account_number
        varchar verified_name
        enum currency
        boolean is_default
        boolean is_verified
        timestamptz created_at
    }

    payouts {
        uuid id PK
        uuid user_id FK
        uuid bank_account_id FK
        uuid deposit_id FK
        varchar idempotency_key UK
        varchar provider_ref
        bigint amount_minor
        bigint fee_minor
        enum currency
        enum status
        int attempts
        timestamptz created_at
    }

    rates {
        uuid id PK
        enum asset
        enum fiat
        decimal base_spot_rate
        decimal spread_percent
        decimal effective_rate
        varchar source
        boolean is_stale
        timestamptz expires_at
        timestamptz created_at
    }

    audit_logs {
        uuid id PK
        varchar actor_type
        uuid actor_id
        varchar action
        varchar entity_type
        uuid entity_id
        jsonb previous_state
        jsonb new_state
        varchar ip_address
        timestamptz created_at
    }
```

---

## 2. Double-Entry Accounting Architecture

### Principles
1. **Never a Single "Balance" Field**: Balances are calculated by summing balanced journal entries:
   $$\text{Balance} = \sum \text{Debits} - \sum \text{Credits} \quad (\text{or vice versa depending on account type})$$
2. **Integer Minor Units**:
   - `NGN` (Kobo): ₦100.00 = `10000`
   - `GHS` (Pesewas): GH₵100.00 = `10000`
   - `USDT / USDC` (Micro-units): 100.000000 USDT = `100000000`
   - `BTC` (Satoshis): 1.00000000 BTC = `100000000`
3. **Account Classification**:
   - **ASSET**: Platform-owned resources (e.g. `1010-VAULT-USDT`, `1030-BANK-FLOAT-NGN`). Increases on DEBIT, decreases on CREDIT.
   - **LIABILITY**: Obligations owed to customers (e.g. `2010-LIABILITY-USER-NGN`). Increases on CREDIT, decreases on DEBIT.
   - **REVENUE**: Earnings from spread and fees (e.g. `4010-REVENUE-FX-SPREAD`). Increases on CREDIT.
   - **EXPENSE**: Costs incurred (e.g. `5010-EXPENSE-PAYOUT-FEES`). Increases on DEBIT.

### Concrete Journal Posting Examples

#### Scenario A: Deposit Confirmed (100 USDT received at locked rate ₦1,500/USDT)
*Effective NGN Payout: ₦150,000 (after 1.5% spread)*
1. **Crypto Ledger Entry** (USDT):
   - **Debit**: `1010-VAULT-USDT` (`100,000,000` micro-units) -> Platform Asset increases
   - **Credit**: `2001-PENDING-SETTLEMENT-USDT` (`100,000,000` micro-units)
2. **Fiat Ledger Entry** (NGN):
   - **Debit**: `2001-PENDING-SETTLEMENT-NGN` (`15,225,000` kobo = Base value ₦152,250)
   - **Credit**: `2010-LIABILITY-USER-NGN` (`15,000,000` kobo = Net payout ₦150,000)
   - **Credit**: `4010-REVENUE-FX-SPREAD` (`225,000` kobo = ₦2,250 platform spread profit)

#### Scenario B: Automated Bank Payout Executed
1. **Hold & Execution**:
   - **Debit**: `2010-LIABILITY-USER-NGN` (`15,000,000` kobo) -> User liability cleared
   - **Credit**: `1030-BANK-FLOAT-NGN` (`15,000,000` kobo) -> Bank float reduced
2. **Transfer Fee Expense (if applicable)**:
   - **Debit**: `5010-EXPENSE-PAYOUT-FEES` (`10,750` kobo = ₦107.50 rail fee)
   - **Credit**: `1030-BANK-FLOAT-NGN` (`10,750` kobo)

---

## 3. Idempotency & Safety Guarantees

- **Deposits**: `tx_hash` is unique at the database level. Webhook replays or duplicate block scans are ignored or return existing records.
- **Payouts**: Client generates a deterministic `idempotency_key` (e.g. `payout-user_id-deposit_id-timestamp`). The database enforces uniqueness so duplicate transfer orders can never be posted.
- **Ledger Entries**: Each ledger posting references a unique `transaction_ref`. Balanced entries are executed inside atomic `SERIALIZABLE` or `READ COMMITTED` transactions with row-level locks.

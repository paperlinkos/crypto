# API Specification: Off-Ramp Platform

Base URL: `http://localhost:4000/api/v1`
Interactive Swagger Docs: `http://localhost:4000/api/docs`

---

## 1. Authentication & Security Endpoints

### 1.1 Request OTP Code
- **Method**: `POST`
- **Route**: `/auth/otp/request`
- **Auth**: None (Rate limited: 5 requests / 10 mins)
- **Request Body**:
  ```json
  {
    "recipient": "user@example.com", // Or Nigerian phone number "+2348012345678"
    "purpose": "SIGNUP" // "SIGNUP" | "LOGIN" | "PASSWORD_RESET" | "PIN_RESET"
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "message": "Verification code sent to user@example.com",
    "expiresInSeconds": 600,
    "sandboxCode": "123456" // Returned in Sandbox / Dev mode only
  }
  ```

---

### 1.2 Sign Up & Verify OTP
- **Method**: `POST`
- **Route**: `/auth/signup`
- **Auth**: None
- **Request Body**:
  ```json
  {
    "recipient": "user@example.com",
    "code": "123456",
    "password": "SecurePassword123!",
    "country": "NG",
    "deviceFingerprint": "ios-uuid-abc-123",
    "deviceName": "iPhone 15 Pro",
    "os": "iOS 17.5"
  }
  ```
- **Success Response (201 Created)**:
  ```json
  {
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "eyJhbGciOi...",
    "sessionId": "b47c030d-...",
    "user": {
      "id": "c86e0821-...",
      "email": "user@example.com",
      "phoneNumber": null,
      "country": "NG",
      "status": "ACTIVE",
      "isPinSet": false,
      "isTwoFactorEnabled": false
    }
  }
  ```

---

### 1.3 Login
- **Method**: `POST`
- **Route**: `/auth/login`
- **Auth**: None (Rate limited)
- **Request Body**:
  ```json
  {
    "identifier": "user@example.com", // Email or phone number
    "password": "SecurePassword123!",
    "code2fa": "123456", // Required if user has 2FA enabled
    "deviceFingerprint": "ios-uuid-abc-123",
    "deviceName": "iPhone 15 Pro",
    "os": "iOS 17.5"
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "eyJhbGciOi...",
    "sessionId": "b47c030d-...",
    "user": {
      "id": "c86e0821-...",
      "email": "user@example.com",
      "country": "NG",
      "status": "ACTIVE",
      "isPinSet": true,
      "isTwoFactorEnabled": false
    }
  }
  ```

---

### 1.4 Admin & Operations Login
- **Method**: `POST`
- **Route**: `/auth/admin/login`
- **Auth**: None
- **Request Body**:
  ```json
  {
    "email": "admin@offramp.test",
    "password": "AdminPassword123!"
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "accessToken": "eyJhbGciOi...",
    "admin": {
      "id": "a90184b2-...",
      "email": "admin@offramp.test",
      "name": "OffRamp Super Admin",
      "role": "SUPER_ADMIN"
    }
  }
  ```

---

### 1.5 Rotate Refresh Token
- **Method**: `POST`
- **Route**: `/auth/refresh`
- **Auth**: None (Refresh Token rotation)
- **Request Body**:
  ```json
  {
    "refreshToken": "eyJhbGciOi..."
  }
  ```
- **Success Response (200 OK)**: Returns fresh `accessToken` and rotated `refreshToken`.

---

### 1.6 User Profile & KYC Limits (`/auth/me`)
- **Method**: `GET`
- **Route**: `/auth/me`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**:
  ```json
  {
    "id": "c86e0821-...",
    "email": "user@offramp.test",
    "phoneNumber": "+2348012345678",
    "country": "NG",
    "status": "ACTIVE",
    "isTwoFactorEnabled": false,
    "autoPayout": true,
    "isPinSet": true,
    "kyc": {
      "tier": "TIER_1",
      "status": "APPROVED",
      "verifiedName": "CHUKWUDI EMMANUEL OKONKWO",
      "idType": "BVN",
      "dailyLimitMinor": "50000000", // ₦500,000 in kobo
      "singleTxLimitMinor": "10000000" // ₦100,000 in kobo
    }
  }
  ```

---

### 1.7 Transaction PIN Management

#### Set PIN
- **Method**: `POST`
- **Route**: `/auth/pin/set`
- **Auth**: `Bearer <accessToken>`
- **Request Body**: `{ "pin": "1234" }` (4 numeric digits)
- **Response**: `{ "message": "Transaction PIN successfully set" }`

#### Verify PIN
- **Method**: `POST`
- **Route**: `/auth/pin/verify`
- **Auth**: `Bearer <accessToken>`
- **Request Body**: `{ "pin": "1234" }`
- **Lockout Rule**: 5 consecutive failed attempts trigger an automatic **30-minute lockout** with audit logging (`403 Forbidden`).

#### Change PIN
- **Method**: `POST`
- **Route**: `/auth/pin/change`
- **Auth**: `Bearer <accessToken>`
- **Request Body**: `{ "oldPin": "1234", "newPin": "5678" }`

---

### 1.8 Two-Factor Authentication (2FA TOTP)

#### Generate Secret & QR Code
- **Method**: `POST`
- **Route**: `/auth/2fa/generate`
- **Auth**: `Bearer <accessToken>`
- **Response**:
  ```json
  {
    "secret": "JBSWY3DPEHPK3PXP",
    "otpAuthUrl": "otpauth://totp/...",
    "qrCodeDataUrl": "data:image/png;base64,...",
    "message": "Scan the QR code in Google Authenticator..."
  }
  ```

#### Enable 2FA
- **Method**: `POST`
- **Route**: `/auth/2fa/enable`
- **Auth**: `Bearer <accessToken>`
- **Request Body**: `{ "code": "654321" }`

#### Disable 2FA
- **Method**: `POST`
- **Route**: `/auth/2fa/disable`
- **Auth**: `Bearer <accessToken>`
- **Request Body**: `{ "code": "654321" }`

---

### 1.9 Device & Session Tracking
- **List Devices**: `GET /auth/devices` (returns list of devices with active session metadata)
- **Revoke Device Session**: `DELETE /auth/devices/:sessionId`
- **Logout**: `POST /auth/logout`

---

## 2. Double-Entry Ledger Endpoints

All balances in the system are derived dynamically from immutable journal lines ($\sum \text{Debits} - \sum \text{Credits}$ or $\sum \text{Credits} - \sum \text{Debits}$). All amounts are integers in minor units (kobo, pesewas, satoshis, micro-USDT).

### 2.1 Get Current User Balances
- **Method**: `GET`
- **Route**: `/ledger/balances?currency=NGN`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**:
  ```json
  {
    "userId": "c86e0821-...",
    "currency": "NGN",
    "availableMinor": "3000000", // ₦30,000 in kobo
    "heldMinor": "1000000",      // ₦10,000 in kobo (reserved for pending bank transfer)
    "totalMinor": "4000000"      // ₦40,000 in kobo
  }
  ```

---

### 2.2 Place Balance Hold (Payout Reservation)
- **Method**: `POST`
- **Route**: `/ledger/hold`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "amountMinor": "1500000", // ₦15,000
    "currency": "NGN",
    "idempotencyRef": "PAYOUT-HOLD-uuid-001",
    "description": "Reserve funds for bank payout"
  }
  ```
- **Success Response (200 OK)**: Moves funds from user's `ACTIVE` liability account to `HOLD` liability account atomically.

---

### 2.3 Release Balance Hold (Failed Payout Refund)
- **Method**: `POST`
- **Route**: `/ledger/release`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "amountMinor": "1500000",
    "currency": "NGN",
    "idempotencyRef": "PAYOUT-RELEASE-uuid-001",
    "description": "Release held funds back to available"
  }
  ```
- **Success Response (200 OK)**: Moves funds from user's `HOLD` liability account back to `ACTIVE` liability account atomically.

---

### 2.4 Admin Manual Credit (Double-Entry Balanced Journal)
- **Method**: `POST`
- **Route**: `/ledger/credit?userId=<userId>`
- **Auth**: `Bearer <adminAccessToken>` (Requires `ADMIN` or `SUPER_ADMIN` role)
- **Request Body**:
  ```json
  {
    "amountMinor": "5000000",
    "currency": "NGN",
    "idempotencyRef": "ADMIN-CREDIT-uuid-001",
    "description": "Manual balance credit"
  }
  ```
- **Success Response (200 OK)**: Debits `1030-BANK-FLOAT-NGN` (Platform Asset) and credits `2010-USER-...-NGN` (Customer Liability).

---

### 2.5 Admin Manual Debit
- **Method**: `POST`
- **Route**: `/ledger/debit?userId=<userId>`
- **Auth**: `Bearer <adminAccessToken>` (Requires `ADMIN` or `SUPER_ADMIN` role)
- **Request Body**:
  ```json
  {
    "amountMinor": "1000000",
    "currency": "NGN",
    "idempotencyRef": "ADMIN-DEBIT-uuid-001",
    "description": "Manual balance debit"
  }
  ```
- **Success Response (200 OK)**: Debits `2010-USER-...-NGN` and credits `1030-BANK-FLOAT-NGN`. Rejects if user available balance is insufficient.

---

## 3. Wallets & Deposit Detection Endpoints

Personal deposit addresses are generated per user, asset, and network. Incoming deposits automatically lock the spot exchange rate and settle directly into the double-entry ledger upon finality (3 confirmations).

### 3.1 Get User Assigned Wallets
- **Method**: `GET`
- **Route**: `/wallets`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**:
  ```json
  [
    {
      "id": "w-uuid-001",
      "asset": "USDT",
      "network": "TRON_TRC20",
      "address": "TYDzsYUEpvnYmQk4zGP9sWWcTEd2MiAtW6",
      "qrCodeDataUrl": "data:image/png;base64,..."
    }
  ]
  ```

---

### 3.2 Generate or Assign Deposit Address
- **Method**: `POST`
- **Route**: `/wallets/assign`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "asset": "USDT",
    "network": "TRON_TRC20"
  }
  ```
- **Success Response (200 OK)**: Returns assigned crypto address, network info, and QR code Data URL.

---

### 3.3 List User Deposit History
- **Method**: `GET`
- **Route**: `/wallets/deposits`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**:
  ```json
  [
    {
      "id": "dep-uuid-001",
      "txHash": "0x8f3d4e...",
      "asset": "USDT",
      "network": "TRON_TRC20",
      "amountMinor": "100000000", // 100 USDT
      "confirmations": 3,
      "requiredConfirmations": 3,
      "status": "PROCESSED",
      "lockedRate": "1521.825000",
      "detectedAt": "2026-10-03T07:00:00.000Z"
    }
  ]
  ```

---

### 3.4 Deposit Webhook Receiver
- **Method**: `POST`
- **Route**: `/wallets/webhook`
- **Headers**: `x-webhook-signature: <signature>`
- **Request Body**:
  ```json
  {
    "txHash": "0x8f3d...",
    "address": "TYDzsYUEpvnYmQk4zGP9sWWcTEd2MiAtW6",
    "asset": "USDT",
    "network": "TRON_TRC20",
    "amountMinor": "100000000",
    "confirmations": 3
  }
  ```
- **Execution Lifecycle**:
  1. Signature verification & webhook deduplication.
  2. Rate locked upon first detection (`confirmations: 1`).
  3. Double-entry ledger automatically credited when `confirmations >= 3`.

---

### 3.5 Simulate Deposit (Sandbox & Admin Tool)
- **Method**: `POST`
- **Route**: `/wallets/simulate-deposit`
- **Auth**: `Bearer <adminAccessToken>` (Admin only)
- **Request Body**: Same as webhook payload. Allows instant testing of the deposit-to-fiat pipeline without real crypto.

---

## 4. Rates Engine & Quote Calculator Endpoints

Market prices are fetched periodically, cached in Redis with a 30-second TTL, adjusted by a configurable platform spread %, and audited with a 90-second stale-rate cutoff.

### 4.1 List Live Rates & Spreads
- **Method**: `GET`
- **Route**: `/rates?fiat=NGN` (or `fiat=GHS`)
- **Auth**: Public
- **Success Response (200 OK)**:
  ```json
  [
    {
      "asset": "USDT",
      "fiat": "NGN",
      "baseSpotRate": 1545.0,
      "spreadPercent": 1.5,
      "effectiveRate": 1521.825,
      "source": "SANDBOX_FEED",
      "timestamp": "2026-10-03T07:30:00.000Z",
      "isStale": false
    }
  ]
  ```

---

### 4.2 Calculate Off-Ramp Quote
- **Method**: `GET`
- **Route**: `/rates/quote?asset=USDT&amount=100&fiat=NGN`
- **Auth**: Public
- **Success Response (200 OK)**:
  ```json
  {
    "quoteId": "QUOTE-9b2a...",
    "asset": "USDT",
    "fiat": "NGN",
    "cryptoAmount": "100",
    "baseSpotRate": "1545.0000",
    "spreadPercent": "1.5%",
    "effectiveRate": "1521.8250",
    "grossFiatAmount": "154500.00",
    "spreadFeeFiat": "2317.50",
    "netPayoutFiat": "152182.50",
    "netPayoutMinor": "15218250", // ₦152,182.50 in kobo
    "validForSeconds": 900,
    "expiresAt": "2026-10-03T07:45:00.000Z",
    "isStale": false
  }
  ```
- **Error (503 Service Unavailable)**: Returned if the feed latency exceeds 90 seconds.

---

### 4.3 Update Spread Percentage (Admin Only)
- **Method**: `PATCH`
- **Route**: `/rates/spread`
- **Auth**: `Bearer <adminAccessToken>` (Admin only)
- **Request Body**:
  ```json
  {
    "asset": "USDT",
    "spreadPercent": 2.0
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "message": "Spread for USDT updated to 2%",
    "asset": "USDT",
    "spreadPercent": 2
  }
  ```

---

## 5. KYC & Tiered Compliance Endpoints

Tier progression unlocks higher daily and single-transaction off-ramp payout limits. In compliance with Rule #5, raw biometric photos and unmasked ID numbers are never stored in the database.

### Tier Limits Overview

| Tier | Required Verification | Daily Limit | Single Tx Limit |
|---|---|---|---|
| **Tier 0** | Basic account (Email/Phone) | ₦0 | ₦0 |
| **Tier 1** | BVN or NIN Verification | ₦500,000 (50,000,000 kobo) | ₦100,000 (10,000,000 kobo) |
| **Tier 2** | Government ID + Biometric Face Liveness | ₦5,000,000 (500,000,000 kobo) | ₦1,000,000 (100,000,000 kobo) |
| **Tier 3** | Proof of Address (Utility Bill / Bank Statement) | ₦50,000,000 (5,000,000,000 kobo) | ₦10,000,000 (1,000,000,000 kobo) |

---

### 5.1 Get KYC Status & Remaining Limits
- **Method**: `GET`
- **Route**: `/kyc/status`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**:
  ```json
  {
    "tier": "TIER_1",
    "status": "APPROVED",
    "idType": "BVN",
    "idNumberMasked": "2233****890",
    "verifiedName": "CHUKWUDI OKONKWO",
    "dailyLimitMinor": "50000000",
    "singleTxLimitMinor": "10000000",
    "dailyUsedMinor": "0",
    "dailyRemainingMinor": "50000000"
  }
  ```

---

### 5.2 Submit Tier 1 (BVN / NIN)
- **Method**: `POST`
- **Route**: `/kyc/tier1`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "idNumber": "22334455667",
    "idType": "BVN", // "BVN" or "NIN"
    "firstName": "Chukwudi",
    "lastName": "Okonkwo"
  }
  ```
- **Success Response (200 OK)**: Upgrades account to Tier 1 immediately with ₦500,000 daily limit.

---

### 5.3 Submit Tier 2 (Government ID + Face Liveness)
- **Method**: `POST`
- **Route**: `/kyc/tier2`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "idType": "PASSPORT", // "PASSPORT" | "DRIVERS_LICENSE" | "NATIONAL_ID"
    "idNumber": "A98765432",
    "selfieBase64": "data:image/jpeg;base64,..."
  }
  ```
- **Success Response (200 OK)**: Upgrades account to Tier 2 (₦5,000,000 daily limit).

---

### 5.4 Submit Tier 3 (Proof of Address)
- **Method**: `POST`
- **Route**: `/kyc/tier3`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "residentialAddress": "Plot 10, Victoria Island",
    "city": "Lagos",
    "state": "Lagos",
    "utilityDocType": "ELECTRICITY_BILL"
  }
  ```
- **Success Response (200 OK)**: Queues profile for Compliance team review.

---

### 5.5 Compliance Review Queue (Admin/Staff Only)
- **List Pending Submissions**: `GET /kyc/admin/queue`
- **Review Profile**: `PATCH /kyc/admin/review/:profileId`
  - **Body**: `{ "status": "APPROVED" }` (Upgrades to Tier 3 ₦50,000,000 limit) or `{ "status": "REJECTED", "rejectionReason": "Address mismatch" }`.

---

## 6. Bank Accounts & Off-Ramp Payout Endpoints

Users link verified bank accounts (with automated NUBAN name resolution) and initiate off-ramp withdrawals protected by Transaction PIN, KYC rolling limit checks, and double-entry ledger hold-and-settle mechanics.

### 6.1 List Supported Commercial Banks
- **Method**: `GET`
- **Route**: `/payouts/banks?currency=NGN` (or `currency=GHS`)
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**:
  ```json
  [
    {
      "code": "058",
      "name": "Guaranty Trust Bank (GTBank)",
      "slug": "gtbank",
      "currency": "NGN"
    },
    {
      "code": "011",
      "name": "First Bank of Nigeria",
      "slug": "first-bank",
      "currency": "NGN"
    }
  ]
  ```

---

### 6.2 Resolve NUBAN Bank Account (Name Enquiry)
- **Method**: `POST`
- **Route**: `/payouts/resolve-account`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "accountNumber": "0123456789",
    "bankCode": "058"
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "accountNumber": "0123456789",
    "bankCode": "058",
    "bankName": "Guaranty Trust Bank (GTBank)",
    "accountName": "CHUKWUDI EMMANUEL OKONKWO"
  }
  ```

---

### 6.3 Add Verified Bank Account
- **Method**: `POST`
- **Route**: `/payouts/bank-accounts`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "bankCode": "058",
    "accountNumber": "0123456789",
    "isDefault": true,
    "currency": "NGN"
  }
  ```
- **Success Response (201 Created)**: Saves the bank account with verified name enquiry result.

---

### 6.4 List User Saved Bank Accounts
- **Method**: `GET`
- **Route**: `/payouts/bank-accounts`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**:
  ```json
  [
    {
      "id": "ba-uuid-001",
      "bankCode": "058",
      "bankName": "Guaranty Trust Bank (GTBank)",
      "accountNumber": "0123456789",
      "verifiedName": "CHUKWUDI EMMANUEL OKONKWO",
      "currency": "NGN",
      "isDefault": true,
      "isVerified": true
    }
  ]
  ```

---

### 6.5 Delete Saved Bank Account
- **Method**: `DELETE`
- **Route**: `/payouts/bank-accounts/:id`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**: `{ "message": "Bank account successfully removed" }`

---

### 6.6 Initiate Off-Ramp Withdrawal (PIN & KYC Protected)
- **Method**: `POST`
- **Route**: `/payouts/withdraw`
- **Auth**: `Bearer <accessToken>`
- **Request Body**:
  ```json
  {
    "bankAccountId": "ba-uuid-001",
    "amountMinor": "5000000", // ₦50,000 in kobo
    "pin": "1234",
    "idempotencyKey": "WITHDRAW-20261003-001",
    "currency": "NGN",
    "narration": "Off-ramp withdrawal to GTBank"
  }
  ```
- **Lifecycle & Execution**:
  1. Transaction PIN is verified against bcrypt hash with 30-min lockout guard.
  2. KYC rolling 24-hr and single-transaction limits are enforced.
  3. Balance is reserved in double-entry ledger (`ACTIVE` liability $\rightarrow$ `HOLD` liability).
  4. Transfer is dispatched to payout rail (Paystack/Monnify/Sandbox).
  5. Strict idempotency key guarantees duplicate calls never double-debit.
- **Success Response (200 OK)**:
  ```json
  {
    "id": "p-uuid-001",
    "userId": "u-uuid-001",
    "bankAccountId": "ba-uuid-001",
    "idempotencyKey": "WITHDRAW-20261003-001",
    "providerRef": "TRF_SANDBOX_A1B2C3",
    "amountMinor": "5000000",
    "feeMinor": "5375",
    "currency": "NGN",
    "status": "PROCESSING",
    "createdAt": "2026-10-03T07:45:00.000Z"
  }
  ```

---

### 6.7 Payout Webhook Receiver
- **Method**: `POST`
- **Route**: `/payouts/webhook`
- **Headers**: `x-payout-signature: <hmac>`
- **Request Body**:
  ```json
  {
    "event": "transfer.success",
    "data": {
      "reference": "TRF_SANDBOX_A1B2C3",
      "status": "SUCCESS",
      "amount": 50000
    }
  }
  ```
- **Behavior**:
  - `status === SUCCESS`: Executes `settleHold` in double-entry ledger and updates payout to `SUCCESS`.
  - `status === FAILED`: Executes `release` in double-entry ledger to return held balance back to user's `availableMinor`.

---

### 6.8 Auto-Settlement Preference Toggle
- **Method**: `PATCH`
- **Route**: `/payouts/auto-settlement`
- **Auth**: `Bearer <accessToken>`
- **Request Body**: `{ "autoPayout": true }`
- **Success Response (200 OK)**: `{ "id": "u-uuid-001", "autoPayout": true }`

---

### 6.9 Get User Payout History
- **Method**: `GET`
- **Route**: `/payouts/history`
- **Auth**: `Bearer <accessToken>`
- **Success Response (200 OK)**: Returns list of past off-ramp withdrawals with bank recipient details and terminal statuses.

---

### 6.10 Admin Payout Reconciliation Worker
- **Method**: `POST`
- **Route**: `/payouts/reconcile`
- **Auth**: `Bearer <adminAccessToken>` (Admin / Super Admin only)
- **Success Response (200 OK)**: `{ "reconciledCount": 0, "totalPending": 0 }`


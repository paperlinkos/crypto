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

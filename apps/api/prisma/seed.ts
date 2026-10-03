import { PrismaClient, UserStatus, KycTier, KycStatus, CryptoAsset, BlockchainNetwork, FiatCurrency, LedgerAccountType, UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seeding for Off-Ramp development...');

  // 1. Seed System Ledger Accounts (Assets, Liabilities, Equity, Revenue, Expense)
  console.log('📊 Seeding Master Ledger Accounts...');
  const masterAccounts = [
    {
      accountNumber: '1010-VAULT-USDT',
      name: 'Platform USDT Custody Vault',
      type: LedgerAccountType.ASSET,
      currency: 'USDT',
    },
    {
      accountNumber: '1020-VAULT-BTC',
      name: 'Platform BTC Custody Vault',
      type: LedgerAccountType.ASSET,
      currency: 'BTC',
    },
    {
      accountNumber: '1030-BANK-FLOAT-NGN',
      name: 'Platform Bank Settlement Float (NGN)',
      type: LedgerAccountType.ASSET,
      currency: 'NGN',
    },
    {
      accountNumber: '2010-LIABILITY-USER-NGN',
      name: 'Customer Fiat Liability Pool (NGN)',
      type: LedgerAccountType.LIABILITY,
      currency: 'NGN',
    },
    {
      accountNumber: '4010-REVENUE-FX-SPREAD',
      name: 'FX Spread Trading Revenue',
      type: LedgerAccountType.REVENUE,
      currency: 'NGN',
    },
    {
      accountNumber: '5010-EXPENSE-PAYOUT-FEES',
      name: 'Bank Payout Rail Network Fees',
      type: LedgerAccountType.EXPENSE,
      currency: 'NGN',
    },
  ];

  for (const acc of masterAccounts) {
    await prisma.ledgerAccount.upsert({
      where: { accountNumber: acc.accountNumber },
      update: {},
      create: acc,
    });
  }

  // 2. Seed Super Admin User
  console.log('👤 Seeding Admin User...');
  const adminPasswordHash = await bcrypt.hash('AdminPassword123!', 10);
  const admin = await prisma.adminUser.upsert({
    where: { email: 'admin@offramp.test' },
    update: {},
    create: {
      email: 'admin@offramp.test',
      passwordHash: adminPasswordHash,
      name: 'OffRamp Super Admin',
      role: UserRole.SUPER_ADMIN,
      isActive: true,
    },
  });

  // 3. Seed Sample Retail User
  console.log('📱 Seeding Test User...');
  const userPasswordHash = await bcrypt.hash('UserPassword123!', 10);
  const pinHash = await bcrypt.hash('1234', 10);

  const testUser = await prisma.user.upsert({
    where: { email: 'user@offramp.co' },
    update: { passwordHash: userPasswordHash, pinHash: pinHash },
    create: {
      email: 'user@offramp.co',
      phoneNumber: '+2348012345678',
      passwordHash: userPasswordHash,
      pinHash: pinHash,
      status: UserStatus.ACTIVE,
      country: 'NG',
      autoPayout: true,
    },
  });

  await prisma.user.upsert({
    where: { email: 'user@offramp.test' },
    update: { passwordHash: userPasswordHash, pinHash: pinHash },
    create: {
      email: 'user@offramp.test',
      phoneNumber: '+2348098765432',
      passwordHash: userPasswordHash,
      pinHash: pinHash,
      status: UserStatus.ACTIVE,
      country: 'NG',
      autoPayout: true,
    },
  });

  // 4. Seed KYC Profile for User (Tier 1 Verified)
  await prisma.kycProfile.upsert({
    where: { userId: testUser.id },
    update: {},
    create: {
      userId: testUser.id,
      tier: KycTier.TIER_1,
      status: KycStatus.APPROVED,
      providerRef: 'SANDBOX-BVN-998822',
      idType: 'BVN',
      idNumberMasked: '2233****890',
      verifiedName: 'CHUKWUDI EMMANUEL OKONKWO',
      dailyLimitMinor: BigInt(50000000), // ₦500,000 in kobo
      singleTxLimitMinor: BigInt(10000000), // ₦100,000 in kobo
    },
  });

  // 5. Seed Verified Bank Account for User
  await prisma.bankAccount.upsert({
    where: {
      userId_bankCode_accountNumber: {
        userId: testUser.id,
        bankCode: '058',
        accountNumber: '0123456789',
      },
    },
    update: {},
    create: {
      userId: testUser.id,
      bankCode: '058',
      bankName: 'Guaranty Trust Bank (GTBank)',
      accountNumber: '0123456789',
      verifiedName: 'CHUKWUDI EMMANUEL OKONKWO',
      currency: FiatCurrency.NGN,
      isDefault: true,
      isVerified: true,
    },
  });

  // 6. Seed Dedicated Sandbox Wallets for User
  await prisma.wallet.upsert({
    where: {
      userId_asset_network: {
        userId: testUser.id,
        asset: CryptoAsset.USDT,
        network: BlockchainNetwork.TRON_TRC20,
      },
    },
    update: {},
    create: {
      userId: testUser.id,
      asset: CryptoAsset.USDT,
      network: BlockchainNetwork.TRON_TRC20,
      address: 'TYDzsYUEpvnYmQk4zGP9sWWcTEd2MiAtW6',
      providerRef: 'SANDBOX_WALLET_USDT_TRC20_001',
    },
  });

  await prisma.wallet.upsert({
    where: {
      userId_asset_network: {
        userId: testUser.id,
        asset: CryptoAsset.BTC,
        network: BlockchainNetwork.BITCOIN,
      },
    },
    update: {},
    create: {
      userId: testUser.id,
      asset: CryptoAsset.BTC,
      network: BlockchainNetwork.BITCOIN,
      address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
      providerRef: 'SANDBOX_WALLET_BTC_001',
    },
  });

  // 7. Seed Initial Exchange Rates
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 15 * 60 * 1000); // 15 mins validity

  await prisma.rate.createMany({
    data: [
      {
        asset: CryptoAsset.USDT,
        fiat: FiatCurrency.NGN,
        baseSpotRate: 1545.0,
        spreadPercent: 1.5,
        effectiveRate: 1521.825, // 1545 * (1 - 0.015)
        source: 'SANDBOX_MOCK',
        expiresAt,
      },
      {
        asset: CryptoAsset.BTC,
        fiat: FiatCurrency.NGN,
        baseSpotRate: 104500000.0,
        spreadPercent: 1.5,
        effectiveRate: 102932500.0,
        source: 'SANDBOX_MOCK',
        expiresAt,
      },
      {
        asset: CryptoAsset.USDT,
        fiat: FiatCurrency.GHS,
        baseSpotRate: 15.8,
        spreadPercent: 1.5,
        effectiveRate: 15.563,
        source: 'SANDBOX_MOCK',
        expiresAt,
      },
    ],
  });

  console.log('✅ Seeding completed successfully!');
  console.log('   - Admin: admin@offramp.test / AdminPassword123!');
  console.log('   - User:  user@offramp.test  / UserPassword123! (PIN: 1234)');
}

main()
  .catch((e) => {
    console.error('❌ Error during seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

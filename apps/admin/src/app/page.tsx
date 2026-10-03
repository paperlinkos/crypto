export default function AdminHomePage() {
  return (
    <main className="max-w-6xl mx-auto px-6 py-12">
      <div className="flex items-center justify-between pb-8 border-b border-porcelain-border">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald/10 text-emerald text-xs font-semibold uppercase tracking-wider mb-2">
            <span className="w-2 h-2 rounded-full bg-mint animate-pulse" />
            Phase 1 Initialized
          </div>
          <h1 className="text-3xl font-extrabold tracking-tight text-obsidian">
            OffRamp Operations Console
          </h1>
          <p className="text-sm text-gray-500 mt-1">
            Institutional crypto-to-fiat treasury, ledger, and compliance manager (Nigeria 🇳🇬 &amp; Ghana 🇬🇭)
          </p>
        </div>
        <div className="text-right">
          <span className="text-xs text-gray-400 font-mono">Environment: Sandbox Dev</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <div className="bg-white rounded-card p-6 border border-porcelain-border shadow-sm">
          <div className="text-xs font-semibold text-emerald uppercase tracking-wider">Double-Entry Ledger</div>
          <div className="text-2xl font-bold mt-2 text-obsidian">Master Accounts</div>
          <p className="text-sm text-gray-500 mt-1">Vaults, Bank Floats, Liabilities, FX Spread Revenue</p>
        </div>

        <div className="bg-white rounded-card p-6 border border-porcelain-border shadow-sm">
          <div className="text-xs font-semibold text-mint-dark uppercase tracking-wider">Provider Adapters</div>
          <div className="text-2xl font-bold mt-2 text-obsidian">Sandbox Active</div>
          <p className="text-sm text-gray-500 mt-1">Simulated Wallets, NUBAN Name Enquiry, Bank Payouts</p>
        </div>

        <div className="bg-white rounded-card p-6 border border-porcelain-border shadow-sm">
          <div className="text-xs font-semibold text-blue-600 uppercase tracking-wider">Security &amp; Safety</div>
          <div className="text-2xl font-bold mt-2 text-obsidian">Strict Idempotency</div>
          <p className="text-sm text-gray-500 mt-1">Unique constraints, immutable audit logs, rate lock guarantee</p>
        </div>
      </div>
    </main>
  );
}

'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  TrendingUp,
  ShieldCheck,
  ArrowDownLeft,
  ArrowUpRight,
  Wallet,
  Cpu,
  Clock,
  CheckCircle2,
} from 'lucide-react';
import { Sidebar } from '../components/Sidebar';
import { StatCard } from '../components/StatCard';
import { KycQueueTable } from '../components/KycQueueTable';
import { RatesSpreadManager } from '../components/RatesSpreadManager';
import { DepositSimulator } from '../components/DepositSimulator';
import { AdminApiClient } from '../lib/api';

export default function AdminDashboardPage() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState('overview');
  const [loading, setLoading] = useState(true);
  const [kycQueue, setKycQueue] = useState<any[]>([]);
  const [rates, setRates] = useState<any[]>([]);

  const fetchDashboardData = async () => {
    try {
      const [kycRes, ratesRes] = await Promise.all([
        AdminApiClient.request('/kyc/admin/queue').catch(() => []),
        AdminApiClient.request('/rates?fiat=NGN').catch(() => []),
      ]);
      setKycQueue(Array.isArray(kycRes) ? kycRes : []);
      setRates(Array.isArray(ratesRes) ? ratesRes : []);
    } catch (_) {
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const token = AdminApiClient.getAccessToken();
    if (!token) {
      router.push('/login');
      return;
    }
    fetchDashboardData();
  }, [router]);

  return (
    <div className="flex bg-porcelain min-h-screen text-gray-900 font-sans">
      {/* Sidebar Navigation */}
      <Sidebar
        activeTab={activeTab}
        onSelectTab={setActiveTab}
        pendingKycCount={kycQueue.length}
      />

      {/* Main Content Area */}
      <main className="flex-1 p-8 overflow-y-auto">
        {/* Top Greeting Bar */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-gray-900">Platform Overview</h1>
            <p className="text-xs text-gray-500 mt-0.5">Real-time crypto-to-fiat off-ramp operations & ledger status.</p>
          </div>
          <div className="flex items-center space-x-3">
            <span className="flex items-center space-x-1.5 px-3 py-1 bg-emerald/10 text-emerald text-xs font-bold rounded-full">
              <span className="w-2 h-2 rounded-full bg-mint animate-pulse" />
              <span>SETTLEMENT RAILS ACTIVE</span>
            </span>
          </div>
        </div>

        {/* Top KPI Stat Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-5 mb-8">
          <StatCard
            title="24H Settlement Volume"
            value="₦142,500,000"
            subtitle="Combined NGN & GHS"
            trend="+18.4%"
            icon={TrendingUp}
            variant="emerald"
          />
          <StatCard
            title="Pending KYC Reviews"
            value={kycQueue.length.toString()}
            subtitle="Tier 2 & 3 verifications"
            icon={ShieldCheck}
          />
          <StatCard
            title="Bank Float Reserve"
            value="₦850,000,000"
            subtitle="GTBank / Monnify Clearing"
            icon={Wallet}
          />
          <StatCard
            title="Avg Settlement Time"
            value="38 seconds"
            subtitle="Deposit to bank credit"
            icon={Clock}
          />
        </div>

        {/* Tab Views */}
        {activeTab === 'overview' && (
          <div className="space-y-8">
            <RatesSpreadManager rates={rates} onRefresh={fetchDashboardData} />
            <KycQueueTable items={kycQueue} onRefresh={fetchDashboardData} />
            <DepositSimulator onSimulateSuccess={fetchDashboardData} />
          </div>
        )}

        {activeTab === 'kyc' && (
          <KycQueueTable items={kycQueue} onRefresh={fetchDashboardData} />
        )}

        {activeTab === 'rates' && (
          <RatesSpreadManager rates={rates} onRefresh={fetchDashboardData} />
        )}

        {activeTab === 'simulator' && (
          <DepositSimulator onSimulateSuccess={fetchDashboardData} />
        )}

        {activeTab === 'transactions' && (
          <div className="bg-white p-8 rounded-2xl border border-porcelain-border shadow-sm text-center">
            <ArrowDownLeft className="w-10 h-10 text-emerald mx-auto mb-3" />
            <h3 className="font-bold text-gray-900 text-base">Transactions & Ledger Journals</h3>
            <p className="text-xs text-gray-500 mt-1 max-w-md mx-auto">
              All double-entry transactions are strictly immutable and recorded in the double-entry journal with debit/credit balance proofs.
            </p>
          </div>
        )}

        {activeTab === 'audit' && (
          <div className="bg-white p-8 rounded-2xl border border-porcelain-border shadow-sm text-center">
            <CheckCircle2 className="w-10 h-10 text-mint mx-auto mb-3" />
            <h3 className="font-bold text-gray-900 text-base">Immutable Audit Log Viewer</h3>
            <p className="text-xs text-gray-500 mt-1 max-w-md mx-auto">
              Every state change on money, KYC tier upgrades, and rates is cryptographically timestamped and logged.
            </p>
          </div>
        )}
      </main>
    </div>
  );
}

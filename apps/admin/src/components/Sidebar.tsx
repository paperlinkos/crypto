'use client';

import React from 'react';
import {
  LayoutDashboard,
  ShieldCheck,
  ArrowLeftRight,
  TrendingUp,
  Cpu,
  FileText,
  LogOut,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { AdminApiClient } from '../lib/api';

interface SidebarProps {
  activeTab: string;
  onSelectTab: (tab: string) => void;
  pendingKycCount?: number;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  onSelectTab,
  pendingKycCount = 0,
}) => {
  const user = AdminApiClient.getCurrentUser();

  const navItems = [
    { id: 'overview', label: 'Overview', icon: LayoutDashboard },
    {
      id: 'kyc',
      label: 'KYC Compliance',
      icon: ShieldCheck,
      badge: pendingKycCount > 0 ? pendingKycCount : undefined,
    },
    { id: 'transactions', label: 'Deposits & Payouts', icon: ArrowLeftRight },
    { id: 'rates', label: 'Rates & Spreads', icon: TrendingUp },
    { id: 'simulator', label: 'Deposit Simulator', icon: Cpu, highlight: true },
    { id: 'audit', label: 'Audit Logs', icon: FileText },
  ];

  return (
    <aside className="w-64 bg-obsidian text-white flex flex-col border-r border-obsidian-border min-h-screen">
      {/* Brand Header */}
      <div className="p-6 border-b border-obsidian-border">
        <div className="flex items-center space-x-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-mint to-emerald flex items-center justify-center font-bold text-obsidian text-lg">
            ⚡
          </div>
          <div>
            <h1 className="font-bold text-base tracking-tight text-white">OffRamp Admin</h1>
            <p className="text-xs text-mint font-medium tracking-wide">INSTITUTIONAL PORTAL</p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-4 py-6 space-y-1.5">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onSelectTab(item.id)}
              className={cn(
                'w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-medium transition-all duration-150',
                isActive
                  ? 'bg-emerald text-white shadow-md'
                  : 'text-gray-400 hover:text-white hover:bg-obsidian-surface'
              )}
            >
              <div className="flex items-center space-x-3">
                <Icon className={cn('w-4 h-4', isActive ? 'text-mint' : 'text-gray-400')} />
                <span>{item.label}</span>
              </div>
              {item.badge != null && (
                <span className="bg-amber-500 text-obsidian text-xs font-bold px-2 py-0.5 rounded-full">
                  {item.badge}
                </span>
              )}
              {item.highlight && !isActive && (
                <span className="bg-mint/20 text-mint text-[10px] font-bold px-2 py-0.5 rounded-md border border-mint/30">
                  SANDBOX
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* User Footer & Logout */}
      <div className="p-4 border-t border-obsidian-border bg-obsidian-surface">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 rounded-full bg-emerald flex items-center justify-center text-mint font-bold text-xs">
              {user?.name?.[0] || 'A'}
            </div>
            <div className="overflow-hidden">
              <p className="text-xs font-bold text-white truncate">{user?.name || 'Administrator'}</p>
              <p className="text-[10px] text-mint font-mono uppercase">{user?.role || 'ADMIN'}</p>
            </div>
          </div>
          <button
            onClick={() => {
              AdminApiClient.clearAuth();
              window.location.href = '/login';
            }}
            title="Sign out"
            className="p-1.5 text-gray-400 hover:text-red-400 rounded-lg hover:bg-obsidian transition-colors"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );
};

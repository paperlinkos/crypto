'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { AdminApiClient } from '../../lib/api';

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('admin@offramp.test');
  const [password, setPassword] = useState('AdminPassword123!');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await AdminApiClient.request('/auth/admin/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });

      AdminApiClient.setAuth(res.accessToken, res.admin);
      router.push('/');
    } catch (err: any) {
      setError(err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-obsidian flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-obsidian-surface border border-obsidian-border rounded-3xl p-8 shadow-2xl">
        <div className="text-center mb-8">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-mint to-emerald flex items-center justify-center font-bold text-obsidian text-2xl mx-auto mb-4">
            ⚡
          </div>
          <h2 className="text-2xl font-bold text-white tracking-tight">OffRamp Console</h2>
          <p className="text-xs text-gray-400 mt-1">Staff, Compliance & Executive Dashboard</p>
        </div>

        {error && (
          <div className="mb-6 p-3 bg-red-900/30 border border-red-500/50 rounded-xl text-red-300 text-xs">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-gray-300 mb-1.5">Staff Email</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-obsidian border border-obsidian-border rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-mint"
              placeholder="admin@offramp.test"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-300 mb-1.5">Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full bg-obsidian border border-obsidian-border rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-mint"
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full mt-4 py-3 bg-gradient-to-r from-mint to-emerald text-obsidian font-bold text-sm rounded-xl shadow-lg hover:opacity-95 transition-all"
          >
            {loading ? 'Authenticating...' : 'Sign In to Console'}
          </button>
        </form>

        <div className="mt-8 pt-6 border-t border-obsidian-border text-center text-xs text-gray-500">
          <span>Protected by RBAC & Double-Entry Audit Logging</span>
        </div>
      </div>
    </div>
  );
}

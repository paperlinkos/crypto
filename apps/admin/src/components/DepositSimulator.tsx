'use client';

import React, { useState } from 'react';
import { Cpu, Send, CheckCircle2, AlertTriangle, ArrowRight } from 'lucide-react';
import { AdminApiClient } from '../lib/api';

export const DepositSimulator: React.FC<{ onSimulateSuccess?: () => void }> = ({ onSimulateSuccess }) => {
  const [asset, setAsset] = useState('USDT');
  const [network, setNetwork] = useState('TRON_TRC20');
  const [address, setAddress] = useState('');
  const [amount, setAmount] = useState('100');
  const [confirmations, setConfirmations] = useState(3);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);

  const handleSimulate = async () => {
    if (!address.trim()) {
      alert('Please enter a valid user deposit address.');
      return;
    }

    setLoading(true);
    setResult(null);
    try {
      const txHash = `0x_sim_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
      // Convert standard amount to minor units (100 USDT = 100,000,000 micro-units)
      const minor = asset === 'BTC' ? Math.floor(parseFloat(amount) * 100000000) : Math.floor(parseFloat(amount) * 1000000);

      const res = await AdminApiClient.request('/wallets/simulate-deposit', {
        method: 'POST',
        body: JSON.stringify({
          txHash,
          address: address.trim(),
          asset,
          network,
          amountMinor: minor.toString(),
          confirmations: Number(confirmations),
        }),
      });

      setResult(res);
      onSimulateSuccess?.();
    } catch (err: any) {
      alert(`Simulation failed: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-2xl border border-porcelain-border shadow-sm overflow-hidden">
      <div className="p-5 border-b border-porcelain-border flex items-center justify-between bg-obsidian text-white">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-emerald rounded-xl text-mint">
            <Cpu className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h3 className="font-bold text-white text-lg">Sandbox Deposit Simulator</h3>
              <span className="text-[10px] bg-mint/20 text-mint font-bold px-2 py-0.5 rounded border border-mint/30">
                ADMIN TOOL
              </span>
            </div>
            <p className="text-xs text-gray-400">
              Simulate incoming blockchain deposits to test rate locks and automatic off-ramp bank payouts.
            </p>
          </div>
        </div>
      </div>

      <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Form Controls */}
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Target Crypto Asset</label>
            <div className="grid grid-cols-3 gap-2">
              {['USDT', 'USDC', 'BTC'].map((a) => (
                <button
                  key={a}
                  type="button"
                  onClick={() => {
                    setAsset(a);
                    if (a === 'BTC') setNetwork('BITCOIN_MAINNET');
                    else setNetwork('TRON_TRC20');
                  }}
                  className={`py-2 text-xs font-bold rounded-xl border transition-all ${
                    asset === a ? 'bg-emerald text-white border-emerald' : 'bg-porcelain-sage text-gray-600'
                  }`}
                >
                  {a}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Destination Crypto Address</label>
            <input
              type="text"
              placeholder="e.g. TYDzsYUEpvnYmQk4zGP9sWWcTEd2MiAtW6"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              className="w-full p-2.5 text-xs font-mono border rounded-xl focus:outline-none focus:border-emerald"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Amount ({asset})</label>
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="w-full p-2.5 text-xs font-semibold border rounded-xl focus:outline-none focus:border-emerald"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Confirmations</label>
              <select
                value={confirmations}
                onChange={(e) => setConfirmations(Number(e.target.value))}
                className="w-full p-2.5 text-xs font-semibold border rounded-xl focus:outline-none focus:border-emerald"
              >
                <option value={1}>1 / 3 (Rate Locked)</option>
                <option value={2}>2 / 3 (Confirming)</option>
                <option value={3}>3 / 3 (Final / Ledger Credited)</option>
              </select>
            </div>
          </div>

          <button
            disabled={loading}
            onClick={handleSimulate}
            className="w-full py-3 bg-gradient-to-r from-mint to-emerald text-obsidian font-bold text-sm rounded-xl shadow-md hover:opacity-95 transition-all flex items-center justify-center space-x-2"
          >
            <Send className="w-4 h-4" />
            <span>{loading ? 'Simulating Broadcast...' : 'Broadcast Simulated Deposit'}</span>
          </button>
        </div>

        {/* Output & Pipeline Logs */}
        <div className="bg-obsidian rounded-2xl p-5 border border-obsidian-border text-white flex flex-col justify-between">
          <div>
            <h4 className="text-xs font-bold uppercase tracking-wider text-mint mb-3">Live Simulation Result</h4>
            {result ? (
              <div className="space-y-2.5 text-xs">
                <div className="p-3 bg-emerald-deep/60 rounded-xl border border-emerald/40">
                  <p className="text-mint font-bold flex items-center space-x-1.5">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Deposit Event Processed</span>
                  </p>
                  <p className="text-[11px] text-gray-300 font-mono mt-1 truncate">Tx: {result.txHash}</p>
                </div>
                <div className="grid grid-cols-2 gap-2 text-gray-300 text-[11px]">
                  <div className="p-2 bg-obsidian-surface rounded-lg">
                    <span className="text-gray-400">Status:</span> <b className="text-white">{result.status}</b>
                  </div>
                  <div className="p-2 bg-obsidian-surface rounded-lg">
                    <span className="text-gray-400">Confirmations:</span>{' '}
                    <b className="text-mint">{result.confirmations}/3</b>
                  </div>
                  <div className="p-2 bg-obsidian-surface rounded-lg">
                    <span className="text-gray-400">Locked Rate:</span>{' '}
                    <b className="text-white">₦{result.lockedRate}</b>
                  </div>
                  <div className="p-2 bg-obsidian-surface rounded-lg">
                    <span className="text-gray-400">Ledger Post:</span>{' '}
                    <b className={result.status === 'PROCESSED' ? 'text-mint' : 'text-amber-400'}>
                      {result.status === 'PROCESSED' ? 'CREDITED' : 'PENDING'}
                    </b>
                  </div>
                </div>
              </div>
            ) : (
              <div className="h-48 flex flex-col items-center justify-center text-center text-gray-500">
                <Cpu className="w-8 h-8 mb-2 opacity-50 text-mint" />
                <p className="text-xs">Fill parameters and broadcast to inspect live deposit state transition.</p>
              </div>
            )}
          </div>

          <div className="pt-3 border-t border-obsidian-border text-[11px] text-gray-400 flex items-center justify-between">
            <span>Pipeline: Ingest → Lock Rate → Double-Entry Ledger</span>
            <span className="text-mint font-semibold">100% Sandbox Safe</span>
          </div>
        </div>
      </div>
    </div>
  );
};

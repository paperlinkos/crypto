'use client';

import React, { useState } from 'react';
import { TrendingUp, RefreshCw, Sliders, Check } from 'lucide-react';
import { AdminApiClient } from '../lib/api';

interface RateItem {
  asset: string;
  fiat: string;
  baseSpotRate: number;
  spreadPercent: number;
  effectiveRate: number;
  source: string;
  isStale: boolean;
  timestamp: string;
}

interface RatesSpreadManagerProps {
  rates: RateItem[];
  onRefresh: () => void;
}

export const RatesSpreadManager: React.FC<RatesSpreadManagerProps> = ({ rates, onRefresh }) => {
  const [spreadMap, setSpreadMap] = useState<Record<string, number>>({});
  const [savingAsset, setSavingAsset] = useState<string | null>(null);
  const [successAsset, setSuccessAsset] = useState<string | null>(null);

  const handleSpreadChange = (asset: string, val: number) => {
    setSpreadMap((prev) => ({ ...prev, [asset]: val }));
  };

  const handleSaveSpread = async (asset: string) => {
    const spreadPercent = spreadMap[asset];
    if (spreadPercent == null) return;

    setSavingAsset(asset);
    try {
      await AdminApiClient.request('/rates/spread', {
        method: 'PATCH',
        body: JSON.stringify({ asset, spreadPercent }),
      });
      setSuccessAsset(asset);
      setTimeout(() => setSuccessAsset(null), 2500);
      onRefresh();
    } catch (err: any) {
      alert(`Failed to update spread: ${err.message}`);
    } finally {
      setSavingAsset(null);
    }
  };

  return (
    <div className="bg-white rounded-2xl border border-porcelain-border shadow-sm overflow-hidden">
      <div className="p-5 border-b border-porcelain-border flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-porcelain-sage rounded-xl text-emerald">
            <Sliders className="w-5 h-5" />
          </div>
          <div>
            <h3 className="font-bold text-gray-900 text-lg">Rates Engine & Spread Controller</h3>
            <p className="text-xs text-gray-500">Live Binance/CoinGecko spot prices with dynamic platform revenue margin %.</p>
          </div>
        </div>
        <button
          onClick={onRefresh}
          className="flex items-center space-x-1.5 px-3 py-1.5 text-xs font-semibold text-emerald bg-porcelain-sage hover:bg-emerald/10 rounded-xl transition-colors"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Refresh Spot Prices</span>
        </button>
      </div>

      <div className="p-6 grid grid-cols-1 md:grid-cols-3 gap-5">
        {rates.map((rate) => {
          const currentSpread = spreadMap[rate.asset] ?? rate.spreadPercent;
          const isSaving = savingAsset === rate.asset;
          const isSuccess = successAsset === rate.asset;

          return (
            <div
              key={`${rate.asset}-${rate.fiat}`}
              className="p-5 rounded-2xl border border-porcelain-border bg-porcelain/30 hover:border-emerald/40 transition-all flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-2">
                    <span className="w-7 h-7 rounded-lg bg-emerald text-mint flex items-center justify-center font-bold text-xs">
                      {rate.asset[0]}
                    </span>
                    <h4 className="font-bold text-gray-900 text-base">{rate.asset} / {rate.fiat}</h4>
                  </div>
                  <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-emerald/10 text-emerald">
                    {rate.source}
                  </span>
                </div>

                <div className="mt-4 space-y-2 text-xs">
                  <div className="flex justify-between text-gray-500">
                    <span>Base Market Spot:</span>
                    <span className="font-mono font-bold text-gray-800">
                      ₦{rate.baseSpotRate.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </span>
                  </div>
                  <div className="flex justify-between text-gray-500">
                    <span>Effective Customer Rate:</span>
                    <span className="font-mono font-bold text-emerald text-sm">
                      ₦{rate.effectiveRate.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </span>
                  </div>
                </div>

                {/* Spread Slider */}
                <div className="mt-5 pt-4 border-t border-porcelain-border">
                  <div className="flex justify-between text-xs font-semibold text-gray-700 mb-1.5">
                    <span>Spread Margin:</span>
                    <span className="text-emerald font-bold">{currentSpread.toFixed(2)}%</span>
                  </div>
                  <input
                    type="range"
                    min="0.2"
                    max="5.0"
                    step="0.1"
                    value={currentSpread}
                    onChange={(e) => handleSpreadChange(rate.asset, parseFloat(e.target.value))}
                    className="w-full accent-emerald cursor-pointer"
                  />
                  <div className="flex justify-between text-[10px] text-gray-400 mt-1">
                    <span>0.2% (Low)</span>
                    <span>2.5%</span>
                    <span>5.0% (High)</span>
                  </div>
                </div>
              </div>

              <div className="mt-5">
                <button
                  disabled={isSaving}
                  onClick={() => handleSaveSpread(rate.asset)}
                  className="w-full py-2 bg-emerald hover:bg-emerald-deep text-white rounded-xl text-xs font-bold transition-colors flex items-center justify-center space-x-1.5"
                >
                  {isSuccess ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-mint" />
                      <span>Saved!</span>
                    </>
                  ) : (
                    <span>{isSaving ? 'Updating...' : 'Apply Spread'}</span>
                  )}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

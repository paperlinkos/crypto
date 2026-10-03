'use client';

import React, { useState } from 'react';
import { ShieldCheck, CheckCircle2, XCircle, AlertCircle, RefreshCw } from 'lucide-react';
import { formatFiatMinor } from '../lib/utils';
import { AdminApiClient } from '../lib/api';

interface KycItem {
  id: string;
  userId: string;
  tier: string;
  status: string;
  idType?: string;
  idNumberMasked?: string;
  verifiedName?: string;
  rejectionReason?: string;
  dailyLimitMinor: string;
  createdAt: string;
  user?: {
    email?: string;
    phoneNumber?: string;
  };
}

interface KycQueueTableProps {
  items: KycItem[];
  onRefresh: () => void;
}

export const KycQueueTable: React.FC<KycQueueTableProps> = ({ items, onRefresh }) => {
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [rejectModalId, setRejectModalId] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState('');

  const handleReview = async (profileId: string, status: 'APPROVED' | 'REJECTED', reason?: string) => {
    setLoadingId(profileId);
    try {
      await AdminApiClient.request(`/kyc/admin/review/${profileId}`, {
        method: 'PATCH',
        body: JSON.stringify({
          status,
          rejectionReason: reason,
        }),
      });
      setRejectModalId(null);
      setRejectReason('');
      onRefresh();
    } catch (err: any) {
      alert(`Review action failed: ${err.message}`);
    } finally {
      setLoadingId(null);
    }
  };

  return (
    <div className="bg-white rounded-2xl border border-porcelain-border shadow-sm overflow-hidden">
      <div className="p-5 border-b border-porcelain-border flex items-center justify-between">
        <div>
          <h3 className="font-bold text-gray-900 text-lg">KYC Compliance Review Queue</h3>
          <p className="text-xs text-gray-500">Tier 2 & Tier 3 verification requests requiring compliance review.</p>
        </div>
        <button
          onClick={onRefresh}
          className="flex items-center space-x-1.5 px-3 py-1.5 text-xs font-semibold text-emerald bg-porcelain-sage hover:bg-emerald/10 rounded-xl transition-colors"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Refresh Queue</span>
        </button>
      </div>

      {items.length === 0 ? (
        <div className="p-12 text-center">
          <ShieldCheck className="w-12 h-12 text-mint mx-auto mb-3" />
          <p className="font-semibold text-gray-900">Queue is Clear</p>
          <p className="text-xs text-gray-500 mt-1">No pending KYC verifications awaiting manual review.</p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-porcelain-sage text-gray-600 text-xs uppercase font-semibold">
              <tr>
                <th className="px-5 py-3">User & Contact</th>
                <th className="px-5 py-3">Tier Requested</th>
                <th className="px-5 py-3">Verification Detail</th>
                <th className="px-5 py-3">Daily Limit</th>
                <th className="px-5 py-3">Status</th>
                <th className="px-5 py-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-porcelain-border text-gray-800">
              {items.map((item) => (
                <tr key={item.id} className="hover:bg-porcelain/50 transition-colors">
                  <td className="px-5 py-4">
                    <p className="font-semibold text-gray-900">{item.user?.email || 'User'}</p>
                    <p className="text-xs text-gray-500">{item.user?.phoneNumber || item.userId.slice(0, 8)}</p>
                  </td>
                  <td className="px-5 py-4">
                    <span className="font-bold text-emerald text-xs bg-porcelain-sage px-2.5 py-1 rounded-lg border border-porcelain-border">
                      {item.tier.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-5 py-4">
                    <p className="font-medium">{item.verifiedName || 'N/A'}</p>
                    <p className="text-xs text-gray-500">
                      {item.idType} • {item.idNumberMasked || 'Provided'}
                    </p>
                  </td>
                  <td className="px-5 py-4 font-mono font-semibold text-xs">
                    {formatFiatMinor(item.dailyLimitMinor)}
                  </td>
                  <td className="px-5 py-4">
                    <span className="inline-flex items-center space-x-1 text-xs font-bold px-2.5 py-0.5 rounded-full bg-amber-100 text-amber-800">
                      <AlertCircle className="w-3 h-3 mr-1" />
                      {item.status}
                    </span>
                  </td>
                  <td className="px-5 py-4 text-right">
                    <div className="flex items-center justify-end space-x-2">
                      <button
                        disabled={loadingId === item.id}
                        onClick={() => handleReview(item.id, 'APPROVED')}
                        className="px-3 py-1.5 bg-emerald text-white rounded-lg text-xs font-semibold hover:bg-emerald-deep flex items-center space-x-1 transition-colors"
                      >
                        <CheckCircle2 className="w-3.5 h-3.5 text-mint" />
                        <span>Approve</span>
                      </button>
                      <button
                        disabled={loadingId === item.id}
                        onClick={() => setRejectModalId(item.id)}
                        className="px-3 py-1.5 bg-red-50 text-red-700 hover:bg-red-100 rounded-lg text-xs font-semibold flex items-center space-x-1 transition-colors border border-red-200"
                      >
                        <XCircle className="w-3.5 h-3.5" />
                        <span>Reject</span>
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Rejection Modal */}
      {rejectModalId && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full shadow-2xl border border-porcelain-border">
            <h4 className="font-bold text-gray-900 text-base">Reject KYC Submission</h4>
            <p className="text-xs text-gray-500 mt-1">Provide a compliance reason for the customer.</p>
            <textarea
              className="w-full mt-4 p-3 text-sm border rounded-xl focus:outline-none focus:border-red-500"
              rows={3}
              placeholder="e.g. Document photo was blurry or address does not match utility bill."
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
            <div className="mt-4 flex justify-end space-x-2">
              <button
                onClick={() => setRejectModalId(null)}
                className="px-4 py-2 text-xs font-semibold text-gray-600 hover:bg-gray-100 rounded-xl"
              >
                Cancel
              </button>
              <button
                disabled={!rejectReason.trim() || loadingId !== null}
                onClick={() => handleReview(rejectModalId, 'REJECTED', rejectReason)}
                className="px-4 py-2 text-xs font-semibold bg-red-600 text-white hover:bg-red-700 rounded-xl"
              >
                Confirm Rejection
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

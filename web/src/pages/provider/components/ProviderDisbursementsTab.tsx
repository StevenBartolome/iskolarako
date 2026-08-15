import React from 'react';
import type { DisbursementTx } from '../types';

interface ProviderDisbursementsTabProps {
  totalCredited: number;
  totalPending: number;
  disbursementsList: DisbursementTx[];
  setIsPayoutModalOpen: (open: boolean) => void;
}

export const ProviderDisbursementsTab: React.FC<ProviderDisbursementsTabProps> = ({
  totalCredited,
  totalPending,
  disbursementsList,
  setIsPayoutModalOpen,
}) => {
  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Disbursements</h2>
          <p className="text-sm text-[#6C6C70] mt-1 font-medium">Release specific program batch payouts using the batch wizard</p>
        </div>
        <button
          onClick={() => setIsPayoutModalOpen(true)}
          className="bg-[#2D5941] hover:bg-[#1A3C2E] text-white px-5 py-2.5 rounded-xl text-sm font-bold shadow-md cursor-pointer transition-all"
        >
          Process Payouts Batch
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6">
          <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Current Cash Allocation</span>
          <h4 className="text-3xl font-bold text-[#1A3C2E] font-serif mt-1">₱11,100,000</h4>
          <p className="text-[11px] text-[#6C6C70] mt-2">DOST-SEI provider balance</p>
        </div>
        <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6">
          <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Total Credited</span>
          <h4 className="text-3xl font-bold text-[#2D5941] font-serif mt-1">₱{totalCredited.toLocaleString()}</h4>
          <p className="text-[11px] text-[#2D5941] mt-2">Credited to linked student accounts</p>
        </div>
        <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6">
          <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Pending Release</span>
          <h4 className="text-3xl font-bold text-[#C97B2E] font-serif mt-1">₱{totalPending.toLocaleString()}</h4>
          <p className="text-[11px] text-[#C97B2E] mt-2">Waiting in payouts queue</p>
        </div>
      </div>

      <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 overflow-hidden shadow-sm">
        <div className="p-5 border-b border-[#D9D2C5]/40 bg-[#F9F5EF]/20">
          <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Transaction Ledger</h3>
        </div>
        <table className="w-full border-collapse text-left text-sm">
          <thead>
            <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-xs font-bold text-[#6C6C70] uppercase tracking-wider">
              <th className="px-6 py-4">Transaction ID</th>
              <th className="px-6 py-4">Scholar</th>
              <th className="px-6 py-4">Target Program</th>
              <th className="px-6 py-4">Method</th>
              <th className="px-6 py-4">Amount</th>
              <th className="px-6 py-4">Status</th>
              <th className="px-6 py-4 text-right">Date</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
            {disbursementsList.map((tx) => (
              <tr key={tx.id} className="hover:bg-[#F9F5EF]/30 transition-colors">
                <td className="px-6 py-4 text-xs font-bold text-[#2D5941]">{tx.id}</td>
                <td className="px-6 py-4 font-bold text-[#1C1C1E]">{tx.scholar}</td>
                <td className="px-6 py-4 text-[#6C6C70]">{tx.program}</td>
                <td className="px-6 py-4 text-[#1C1C1E]">{tx.method}</td>
                <td className="px-6 py-4 text-[#2D5941] font-bold">{tx.amount}</td>
                <td className="px-6 py-4">
                  <span
                    className={`px-3 py-1 rounded-full text-xs font-bold ${tx.status === 'Completed'
                      ? 'bg-[#EBF5EE] text-[#2D5941]'
                      : tx.status === 'Processing'
                        ? 'bg-[#F9F0E0] text-[#C97B2E]'
                        : 'bg-[#FDF2F2] text-[#B34040]'
                      }`}
                  >
                    {tx.status}
                  </span>
                </td>
                <td className="px-6 py-4 text-right text-xs text-[#8E8E93]">{tx.date}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

import React from 'react';
import type { TransactionRecord } from '../types';

interface AdminFundsTabProps {
  transactions: TransactionRecord[];
}

export const AdminFundsTab: React.FC<AdminFundsTabProps> = ({ transactions }) => {
  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
      <div>
        <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">Fund Release Ledgers</h3>
        <p className="text-xs text-[#6C6C70]">System admin monitors the transactions and audit reports without handling money directly.</p>
      </div>

      <div className="overflow-x-auto text-xs text-[#6C6C70]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
              <th className="py-2.5">Transaction ID</th>
              <th>Provider</th>
              <th>Scholar</th>
              <th>Amount</th>
              <th>Reference</th>
              <th>Status</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            {transactions.map(tx => (
              <tr key={tx.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                <td className="py-3 font-semibold text-[#1C1C1E]">{tx.id}</td>
                <td>{tx.provider}</td>
                <td className="font-semibold">{tx.scholar}</td>
                <td className="font-bold text-[#2D5941]">₱{tx.amount.toLocaleString()}</td>
                <td className="font-mono text-[10px]">{tx.reference}</td>
                <td>
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                    tx.status === 'COMPLETED' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                    tx.status === 'PENDING' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                    'bg-red-50 text-[#B34040]'
                  }`}>
                    {tx.status}
                  </span>
                </td>
                <td>{tx.date}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

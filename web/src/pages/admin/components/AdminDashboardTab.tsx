import React from 'react';
import type { AuditLogEntry, AdminTab } from '../types';

interface AdminDashboardTabProps {
  setActiveTab: (tab: AdminTab) => void;
  auditLogs: AuditLogEntry[];
}

export const AdminDashboardTab: React.FC<AdminDashboardTabProps> = ({
  setActiveTab,
  auditLogs,
}) => {
  return (
    <div className="space-y-6">
      {/* Metric Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Total Registered Students</span>
          <span className="text-3xl font-extrabold font-serif text-[#1A3C2E] mt-2">12,540</span>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Scholarship Providers</span>
          <div className="flex items-baseline justify-between mt-2">
            <span className="text-3xl font-extrabold font-serif text-[#1A3C2E]">184</span>
            <span className="text-[10px] text-[#2D5941] bg-[#EBF5EE] font-bold px-2 py-0.5 rounded">151 Verified</span>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Pending Verifications</span>
          <div className="flex items-baseline justify-between mt-2">
            <span className="text-3xl font-extrabold font-serif text-[#C97B2E]">23</span>
            <span className="text-[10px] text-[#C97B2E] bg-[#FFF8EE] font-bold px-2 py-0.5 rounded">Requires Review</span>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Active Scholarships</span>
          <span className="text-3xl font-extrabold font-serif text-[#2D5941] mt-2">327</span>
        </div>
      </div>

      {/* Sub-Metrics Section */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
          <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Application Pipeline</h3>
          <div className="space-y-3">
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Pending Applications:</span>
              <span className="font-bold text-[#1C1C1E]">1,842</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Approved Scholars:</span>
              <span className="font-bold text-[#2D5941]">1,200</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Reported/Scam Flagged:</span>
              <span className="font-bold text-[#B34040]">2</span>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
          <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Finances</h3>
          <div className="space-y-3">
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Total Released:</span>
              <span className="font-extrabold text-[#2D5941]">₱2,504,500</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Pending Disbursements:</span>
              <span className="font-bold text-[#C97B2E]">₱125,000</span>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
          <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Provider Management Panel</h3>
          <div className="flex gap-2">
            <button
              onClick={() => setActiveTab('providers')}
              className="flex-1 text-center bg-[#2D5941] text-white text-xs font-bold py-2 px-3 rounded-xl hover:bg-[#1A3C2E] transition-colors cursor-pointer"
            >
              Pending List
            </button>
            <button
              onClick={() => setActiveTab('reports')}
              className="flex-1 text-center bg-[#C97B2E] text-white text-xs font-bold py-2 px-3 rounded-xl hover:bg-[#B56D24] transition-colors cursor-pointer"
            >
              View Reports
            </button>
          </div>
        </div>
      </div>

      {/* Recent System Activity */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <h3 className="text-base font-bold text-[#1A3C2E] font-serif mb-4">Recent Audit Activity</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-[#6C6C70]">
            <thead>
              <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                <th className="py-2.5">Time</th>
                <th>Admin</th>
                <th>Action</th>
                <th>Target Entity</th>
                <th>IP Address</th>
              </tr>
            </thead>
            <tbody>
              {auditLogs.slice(0, 5).map(log => (
                <tr key={log.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                  <td className="py-2">{log.date} {log.time}</td>
                  <td className="font-semibold text-[#1C1C1E]">{log.admin}</td>
                  <td>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                      log.action.includes('APPROVED') ? 'bg-[#EBF5EE] text-[#2D5941]' :
                      log.action.includes('SUSPENDED') ? 'bg-red-50 text-[#B34040]' :
                      'bg-[#EDE8DE] text-[#6C6C70]'
                    }`}>
                      {log.action}
                    </span>
                  </td>
                  <td>{log.target}</td>
                  <td className="font-mono text-[10px]">{log.ip}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

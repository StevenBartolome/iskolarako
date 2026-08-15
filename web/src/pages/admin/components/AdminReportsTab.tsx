import React from 'react';
import type { AdminReport } from '../types';

interface AdminReportsTabProps {
  reports: AdminReport[];
  handleReportAction: (id: number, status: 'Resolved' | 'Dismissed') => void;
  showToast: (msg: string) => void;
}

export const AdminReportsTab: React.FC<AdminReportsTabProps> = ({
  reports,
  handleReportAction,
  showToast,
}) => {
  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
      <div>
        <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">Escalations, Reports & Complaints</h3>
        <p className="text-xs text-[#6C6C70]">Help protect scholars by moderating flagged providers and scholarships.</p>
      </div>

      <div className="space-y-4">
        {reports.map(rep => (
          <div key={rep.id} className="p-5 border border-[#D9D2C5] rounded-2xl bg-[#F9F5EF]/30 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[#1A3C2E] uppercase">REPORT #{rep.id}</span>
                <span className={`text-[10px] font-bold px-2 py-0.5 rounded ${
                  rep.status === 'Resolved' ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-[#FFF8EE] text-[#C97B2E]'
                }`}>{rep.status}</span>
              </div>
              <h4 className="text-sm font-bold text-[#1C1C1E]">
                Reported {rep.type}: <strong className="text-[#2D5941]">{rep.reportedEntity}</strong>
              </h4>
              <p className="text-xs text-[#6C6C70]">
                Reason: <span className="text-[#B34040] font-medium">"{rep.reason}"</span>
              </p>
              <p className="text-[10px] text-[#8E8E93]">Submitted by: {rep.reporter} on {rep.date}</p>
            </div>
            {rep.status === 'Under Investigation' && (
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => handleReportAction(rep.id, 'Resolved')}
                  className="bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold px-3 py-2 rounded-xl cursor-pointer border-0"
                >
                  Dismiss Report
                </button>
                <button
                  type="button"
                  onClick={() => {
                    showToast(`Suspended associated Provider for Report #${rep.id}`);
                    handleReportAction(rep.id, 'Resolved');
                  }}
                  className="bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold px-3 py-2 rounded-xl cursor-pointer border-0"
                >
                  Suspend Provider
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

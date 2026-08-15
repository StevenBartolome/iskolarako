import React from 'react';
import type { Program, ScholarAward } from '../types';

interface ProviderDashboardTabProps {
  programsList: Program[];
  scholarsList: ScholarAward[];
  applicantsList: any[];
  totalCredited: number;
  totalPending: number;
}

export const ProviderDashboardTab: React.FC<ProviderDashboardTabProps> = ({
  programsList,
  scholarsList,
  applicantsList,
  totalCredited,
  totalPending,
}) => {
  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Dashboard</h2>
        <p className="text-sm text-[#6C6C70] mt-1 font-medium">Real-time Scholarship Monitoring</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Permanent Programs</span>
          <h3 className="text-3xl font-bold text-[#1A3C2E] font-serif mt-1">{programsList.length}</h3>
          <span className="text-xs text-[#2D5941] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#2D5941]" /> Fully Lifecycle Managed
          </span>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Active Scholars (Awards)</span>
          <h3 className="text-3xl font-bold text-[#C97B2E] font-serif mt-1">{scholarsList.length}</h3>
          <span className="text-xs text-[#C97B2E] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#C97B2E]" /> Undergoing renewal checks
          </span>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Active Cycle Applicants</span>
          <h3 className="text-3xl font-bold text-[#B34040] font-serif mt-1">{applicantsList.length}</h3>
          <span className="text-xs text-[#B34040] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#B34040]" /> In active intake cycles
          </span>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Funds Released</span>
          <h3 className="text-3xl font-bold text-[#2D5941] font-serif mt-1">₱{(totalCredited / 1000000).toFixed(2)}M</h3>
          <span className="text-xs text-[#2D5941] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#2D5941]" /> ₱{(totalPending / 1000).toFixed(0)}K pending release
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm lg:col-span-2 space-y-6">
          <div className="flex justify-between items-center">
            <h4 className="font-bold text-[#1A3C2E] font-serif">Fund Allocation Distribution</h4>
            <span className="text-xs font-semibold text-[#8E8E93]">AY 2026-2027</span>
          </div>
          <div className="space-y-4 pt-2">
            {programsList.map(prog => (
              <div key={prog.id}>
                <div className="flex justify-between text-xs font-semibold text-[#1C1C1E] mb-1.5">
                  <span>{prog.title}</span>
                  <span>{prog.budgetUsed} / {prog.budgetTotal}</span>
                </div>
                <div className="w-full bg-[#EDE8DE] h-3.5 rounded-full overflow-hidden">
                  <div className="bg-[#2D5941] h-full rounded-full" style={{ width: '65%' }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-5">
          <h4 className="font-bold text-[#1A3C2E] font-serif">Recent System Events</h4>
          <div className="space-y-4 text-xs">
            <div className="flex gap-3 pb-3 border-b border-[#D9D2C5]/40">
              <div className="w-8 h-8 rounded-full bg-[#EBF5EE] text-[#2D5941] flex items-center justify-center font-bold shrink-0">IA</div>
              <div>
                <p className="font-semibold text-[#1C1C1E]">Scholar Award Issued</p>
                <p className="text-[10px] text-[#6C6C70] mt-0.5">Applicant upgraded to continuing status</p>
              </div>
            </div>
            <div className="flex gap-3 pb-3 border-b border-[#D9D2C5]/40">
              <div className="w-8 h-8 rounded-full bg-[#F9F0E0] text-[#C97B2E] flex items-center justify-center font-bold shrink-0">RC</div>
              <div>
                <p className="font-semibold text-[#1C1C1E]">Renewal Policy Warning</p>
                <p className="text-[10px] text-[#6C6C70] mt-0.5">Marcus Vian flagged (GWA 2.10 under Conditional Policy)</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

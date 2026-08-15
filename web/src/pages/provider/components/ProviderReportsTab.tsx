import React from 'react';

export const ProviderReportsTab: React.FC = () => {
  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Reports & Audits</h2>
          <p className="text-sm text-[#6C6C70] mt-1 font-medium">Export system utilization and compliance audit logs</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm flex flex-col justify-between">
          <div>
            <h4 className="text-base font-bold text-[#1A3C2E] font-serif">Fund Utilization Summary</h4>
            <p className="text-xs text-[#6C6C70] mt-1">Full breakdown of disbursement ratios and budget balances.</p>
          </div>
          <div className="mt-6 flex justify-between items-center border-t border-[#D9D2C5]/40 pt-4">
            <span className="text-[10px] text-[#8E8E93] font-bold">PDF / EXCEL</span>
            <button className="text-xs font-bold text-[#C97B2E] hover:underline cursor-pointer">Download</button>
          </div>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm flex flex-col justify-between">
          <div>
            <h4 className="text-base font-bold text-[#1A3C2E] font-serif">Scholar Performance Audit</h4>
            <p className="text-xs text-[#6C6C70] mt-1">Summary of scholars' GWAs, grade sheet validation, and failures.</p>
          </div>
          <div className="mt-6 flex justify-between items-center border-t border-[#D9D2C5]/40 pt-4">
            <span className="text-[10px] text-[#8E8E93] font-bold">CSV / XLSX</span>
            <button className="text-xs font-bold text-[#C97B2E] hover:underline cursor-pointer">Download</button>
          </div>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm flex flex-col justify-between">
          <div>
            <h4 className="text-base font-bold text-[#1A3C2E] font-serif">Announcements Engagement</h4>
            <p className="text-xs text-[#6C6C70] mt-1">Metrics on student read acknowledgments and message reach.</p>
          </div>
          <div className="mt-6 flex justify-between items-center border-t border-[#D9D2C5]/40 pt-4">
            <span className="text-[10px] text-[#8E8E93] font-bold">PDF</span>
            <button className="text-xs font-bold text-[#C97B2E] hover:underline cursor-pointer">Download</button>
          </div>
        </div>
      </div>
    </div>
  );
};

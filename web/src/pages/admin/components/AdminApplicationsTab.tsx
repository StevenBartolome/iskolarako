import React from 'react';

export const AdminApplicationsTab: React.FC = () => {
  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <h3 className="text-base font-bold text-[#1A3C2E] font-serif mb-4">Application Pipelines Dashboard</h3>
        <div className="grid grid-cols-5 gap-4 mb-6 text-center">
          <div className="p-3 bg-gray-50 rounded-xl border border-[#D9D2C5]/50">
            <span className="text-lg font-bold text-gray-700">1,842</span>
            <p className="text-[10px] text-gray-500 font-bold uppercase mt-1">Pending</p>
          </div>
          <div className="p-3 bg-amber-50 rounded-xl border border-[#C97B2E]/20">
            <span className="text-lg font-bold text-[#C97B2E]">923</span>
            <p className="text-[10px] text-[#C97B2E] font-bold uppercase mt-1">Under Review</p>
          </div>
          <div className="p-3 bg-[#EBF5EE] rounded-xl border border-[#2D5941]/20">
            <span className="text-lg font-bold text-[#2D5941]">412</span>
            <p className="text-[10px] text-[#2D5941] font-bold uppercase mt-1">Approved</p>
          </div>
          <div className="p-3 bg-red-50 rounded-xl border border-[#B34040]/20">
            <span className="text-lg font-bold text-[#B34040]">301</span>
            <p className="text-[10px] text-[#B34040] font-bold uppercase mt-1">Rejected</p>
          </div>
          <div className="p-3 bg-blue-50 rounded-xl border border-blue-200">
            <span className="text-lg font-bold text-blue-700">76</span>
            <p className="text-[10px] text-blue-500 font-bold uppercase mt-1">Withdrawn</p>
          </div>
        </div>

        <div className="overflow-x-auto text-xs text-[#6C6C70]">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                <th className="py-2.5">Student ID</th>
                <th>Scholarship Program</th>
                <th>Status</th>
                <th>Last Provider Activity</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b border-[#D9D2C5]/40 py-2">
                <td className="py-2.5 font-bold text-[#1C1C1E]">STU-2931</td>
                <td>DOST Merit Scholarship Program</td>
                <td><span className="px-2 py-0.5 rounded bg-amber-50 text-[#C97B2E] font-bold text-[10px]">Under Review</span></td>
                <td>3 hours ago by DOST Representative</td>
              </tr>
              <tr className="border-b border-[#D9D2C5]/40 py-2">
                <td className="py-2.5 font-bold text-[#1C1C1E]">STU-1824</td>
                <td>Tulong Dunong Financial Assistance</td>
                <td><span className="px-2 py-0.5 rounded bg-[#EBF5EE] text-[#2D5941] font-bold text-[10px]">Approved</span></td>
                <td>1 day ago by CHED Representative</td>
              </tr>
              <tr className="border-b border-[#D9D2C5]/40 py-2">
                <td className="py-2.5 font-bold text-[#1C1C1E]">STU-0294</td>
                <td>ABC Tech Innovators Grant</td>
                <td><span className="px-2 py-0.5 rounded bg-gray-100 text-gray-700 font-bold text-[10px]">Pending</span></td>
                <td>Stuck - 5 days without activity</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

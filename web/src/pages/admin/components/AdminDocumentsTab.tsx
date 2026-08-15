import React from 'react';

interface AdminDocumentsTabProps {
  showToast: (msg: string) => void;
}

export const AdminDocumentsTab: React.FC<AdminDocumentsTabProps> = ({ showToast }) => {
  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
      <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-4">Document Verification Logs</h3>
      <p className="text-xs text-[#6C6C70] mb-6">
        Track student requirement submissions and provider review logs. System admin provides oversight.
      </p>

      <div className="overflow-x-auto text-xs text-[#6C6C70]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
              <th className="py-2.5">Document ID</th>
              <th>Student</th>
              <th>Type</th>
              <th>Provider Verification Status</th>
              <th className="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
              <td className="py-3 font-semibold text-[#1C1C1E]">DOC-77291</td>
              <td>Maria Santos</td>
              <td>Official Transcript of Records (GWA 1.25)</td>
              <td><span className="text-[#2D5941] font-bold">Verified by DOST-SEI</span></td>
              <td className="text-right">
                <button type="button" onClick={() => showToast('Document flagged as: Verified')} className="text-gray-400 hover:text-red-500 font-bold border-0 bg-transparent cursor-pointer">Flag File</button>
              </td>
            </tr>
            <tr className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
              <td className="py-3 font-semibold text-[#1C1C1E]">DOC-77292</td>
              <td>Ethan Gomez</td>
              <td>Certificate of Indigency</td>
              <td><span className="text-[#C97B2E] font-bold">Under Review</span></td>
              <td className="text-right">
                <button type="button" onClick={() => showToast('Flagged document STU-1023 as suspicious.')} className="text-red-600 hover:underline font-bold border-0 bg-transparent cursor-pointer">Flag Suspicious</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
};

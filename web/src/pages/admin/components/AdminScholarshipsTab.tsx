import React from 'react';
import type { ScholarshipAdminView } from '../types';
import { supabase } from '@/services/supabaseClient';

interface AdminScholarshipsTabProps {
  loadingScholarships: boolean;
  scholarships: ScholarshipAdminView[];
  setSelectedScholarshipDetails: (prog: any) => void;
  handleScholarshipAction: (id: any, action: 'Approved' | 'Rejected' | 'Suspended') => void;
}

export const AdminScholarshipsTab: React.FC<AdminScholarshipsTabProps> = ({
  loadingScholarships,
  scholarships,
  setSelectedScholarshipDetails,
  handleScholarshipAction,
}) => {
  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
      <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-4">Scholarship Governance</h3>
      <p className="text-xs text-[#6C6C70] mb-6">
        Review and moderate scholarships created by providers. All programs must be approved before publishing.
      </p>

      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs text-[#6C6C70]">
          <thead>
            <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
              <th className="py-3">Title</th>
              <th>Provider</th>
              <th>Category</th>
              <th>Grant Value</th>
              <th>Status</th>
              <th>Submitted</th>
              <th className="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loadingScholarships ? (
              <tr>
                <td colSpan={7} className="py-8 text-center text-xs text-[#6C6C70] italic">
                  Loading scholarships governance list...
                </td>
              </tr>
            ) : scholarships.length === 0 ? (
              <tr>
                <td colSpan={7} className="py-8 text-center text-xs text-[#6C6C70] italic">
                  No scholarships found in database.
                </td>
              </tr>
            ) : (
              scholarships.map(s => (
                <tr key={s.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                  <td className="py-4 font-bold text-[#1C1C1E]">{s.title}</td>
                  <td>{s.providerName}</td>
                  <td>{s.category}</td>
                  <td className="font-semibold text-[#2D5941]">₱{s.amount.toLocaleString()}</td>
                  <td>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                      s.status === 'Published' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                      s.status === 'Pending Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                      'bg-red-50 text-[#B34040]'
                    }`}>
                      {s.status}
                    </span>
                  </td>
                  <td>{s.dateCreated}</td>
                  <td className="text-right">
                    <div className="flex justify-end gap-1.5">
                      <button
                        type="button"
                        onClick={async () => {
                          try {
                            const { data: fullProg } = await supabase
                              .from('scholarship_programs')
                              .select(`
                                *,
                                provider ( name ),
                                scholarship_categories ( name )
                              `)
                              .eq('id', s.id)
                              .single();
                            if (fullProg) {
                              setSelectedScholarshipDetails(fullProg);
                            }
                          } catch (e) {
                            console.error(e);
                          }
                        }}
                        className="bg-[#EDE8DE] text-[#1A3C2E] hover:bg-[#D9D2C5] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                      >
                        View
                      </button>
                      {s.status === 'Pending Review' && (
                        <>
                          <button
                            type="button"
                            onClick={() => handleScholarshipAction(s.id, 'Approved')}
                            className="bg-[#2D5941] text-white hover:bg-[#1A3C2E] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                          >
                            Approve
                          </button>
                          <button
                            type="button"
                            onClick={() => handleScholarshipAction(s.id, 'Rejected')}
                            className="bg-[#B34040] text-white hover:bg-[#8E2F2F] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                          >
                            Reject
                          </button>
                        </>
                      )}
                      {s.status === 'Published' && (
                        <button
                          type="button"
                          onClick={() => handleScholarshipAction(s.id, 'Suspended')}
                          className="bg-red-50 text-[#B34040] border border-solid border-[#B34040]/30 px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer hover:bg-red-100"
                        >
                          Suspend
                        </button>
                      )}
                      {s.status === 'Suspended' && (
                        <button
                          type="button"
                          onClick={() => handleScholarshipAction(s.id, 'Approved')}
                          className="bg-[#EBF5EE] text-[#2D5941] border border-solid border-[#2D5941]/30 px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer hover:bg-green-100"
                        >
                          Unsuspend / Publish
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

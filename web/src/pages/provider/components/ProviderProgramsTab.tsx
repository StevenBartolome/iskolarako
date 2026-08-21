import React from 'react';
import type { Program, ProviderDetails } from '../types';
import { supabase } from '@/services/supabaseClient';

interface ProviderProgramsTabProps {
  providerDetails: ProviderDetails | null;
  programsList: Program[];
  showToast: (msg: string) => void;
  onOpenCreateProgram: () => void;
  setActiveTab: (tab: any) => void;
  handleViewDetails: (prog: Program) => void;
  handleEditProgram: (prog: Program) => void;
  handleOpenRenewModal: (prog: Program) => void;
  handleOpenEditCycle?: (prog: Program, cyc: any) => void;
  handleDeleteCycle?: (id: string, name: string) => void;
  setProgramToClose: (prog: Program | null) => void;
  setIsCloseConfirmOpen: (open: boolean) => void;
  fetchPrograms: () => Promise<void>;
}

export const ProviderProgramsTab: React.FC<ProviderProgramsTabProps> = ({
  providerDetails,
  programsList,
  showToast,
  onOpenCreateProgram,
  setActiveTab,
  handleViewDetails,
  handleEditProgram,
  handleOpenRenewModal,
  handleOpenEditCycle,
  handleDeleteCycle,
  setProgramToClose,
  setIsCloseConfirmOpen,
  fetchPrograms,
}) => {
  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Scholarship Programs</h2>
          <p className="text-sm text-[#6C6C70] mt-1 font-medium">Permanent scholarship schemas, active application cycles, and renewal rules</p>
        </div>
        <button
          onClick={() => {
            if (providerDetails?.verificationStatus !== 'verified') {
              showToast('Create locked: Your organization is not verified. Please submit documents in the Verification Org tab.');
            } else {
              onOpenCreateProgram();
            }
          }}
          disabled={providerDetails?.verificationStatus !== 'verified'}
          className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-sm shadow-md transition-all border border-[#1A3C2E]/10 ${
            providerDetails?.verificationStatus === 'verified'
              ? 'bg-[#E8A838] hover:bg-[#cfa532] text-[#1A3C2E] cursor-pointer'
              : 'bg-gray-200 text-gray-500 cursor-not-allowed border-gray-400'
          }`}
        >
          <span>{providerDetails?.verificationStatus === 'verified' ? '+' : '🔒'}</span> New program
        </button>
      </div>

      {providerDetails && providerDetails.verificationStatus !== 'verified' && (
        <div className="bg-[#FFF8EE] border border-[#C97B2E]/30 rounded-2xl p-5 flex items-start gap-4 shadow-sm animate-fade-in">
          <div className="bg-[#C97B2E]/10 p-2.5 rounded-xl text-[#C97B2E] shrink-0">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m0-6h.01M5.07 19h13.86c1.54 0 2.5-1.67 1.73-3L13.73 4c-.77-1.3-2.67-1.3-3.44 0L2.18 16c-.77 1.3.2 3 1.73 3z" />
            </svg>
          </div>
          <div className="space-y-1">
            <h4 className="font-bold text-[#1A3C2E] text-sm">Scholarship Creation Locked</h4>
            <p className="text-xs text-[#6C6C70] leading-relaxed">
              Your organization is currently not verified (Status: <strong className="capitalize">{providerDetails.verificationStatus.replace('_', ' ')}</strong>). 
              You must upload and submit your organization credentials under the <strong>Verification Org</strong> tab. Once approved by the administrator, you will be allowed to post scholarships.
            </p>
            <button 
              onClick={() => setActiveTab('verification')}
              className="text-xs font-bold text-[#2D5941] hover:text-[#1A3C2E] underline mt-1.5 cursor-pointer block bg-transparent border-0 p-0 text-left font-sans"
            >
              Go to Verification Org &rarr;
            </button>
          </div>
        </div>
      )}

      {programsList.length === 0 ? (
        <div className="bg-[#F9F5EF]/60 rounded-3xl border border-dashed border-[#D9D2C5] p-12 text-center space-y-4">
          <div className="w-16 h-16 bg-[#EDE8DE] rounded-full flex items-center justify-center mx-auto text-[#2D5941] text-2xl">
            🎓
          </div>
          <div className="space-y-1">
            <h4 className="font-bold text-[#1A3C2E] font-serif text-lg">No Scholarship Programs Yet</h4>
            <p className="text-xs text-[#6C6C70] max-w-sm mx-auto">
              You haven't configured any programs yet. Click the <strong>New program</strong> button above to launch your first scholarship and cycle!
            </p>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          {programsList.map((prog) => (
            <div
              key={prog.id}
              className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-7 shadow-sm hover:shadow-md transition-all flex flex-col justify-between min-h-[380px] animate-fade-in"
            >
              <div className="space-y-3.5">
                <div className="flex justify-between items-center">
                  <span className="px-3.5 py-1.5 rounded-xl bg-[#1A3C2E] text-white text-xs font-bold tracking-wider">
                    {prog.provider}
                  </span>
                  <div className="flex items-center gap-1.5">
                    <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                      prog.status === 'Approved' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                      prog.status === 'Pending Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                      prog.status === 'Rejected' ? 'bg-red-50 text-[#B34040]' :
                      prog.status === 'Draft' ? 'bg-blue-50 text-blue-600' :
                      'bg-gray-100 text-gray-600'
                    }`}>
                      {prog.status}
                    </span>
                    <span className="px-3 py-1 rounded-lg text-[10px] font-bold bg-[#EDE8DE] text-[#6C6C70] border border-[#D9D2C5]">
                      ⚙️ Policy: {prog.renewalPolicy}
                    </span>
                  </div>
                </div>

                <div>
                  <h3 className="text-xl font-bold text-[#1A3C2E] font-serif leading-snug truncate">
                    {prog.title}
                  </h3>
                  <p className="text-xs text-[#6C6C70] mt-0.5 font-medium line-clamp-1">
                    {prog.description}
                  </p>
                </div>

                {/* Application Cycles checklist sub-layout */}
                <div className="space-y-1.5 pt-1">
                  <span className="text-[10px] uppercase font-bold text-[#8E8E93] tracking-wide block">Registered Cycles</span>
                  <div className="flex flex-col gap-1 max-h-24 overflow-y-auto">
                    {prog.cycles?.map((cyc: any) => (
                      <div key={cyc.id} className="flex justify-between items-center bg-[#F9F5EF] px-3 py-1.5 rounded-lg border border-[#D9D2C5]/30 text-xs">
                        <span className="font-bold text-[#1C1C1E]">{cyc.name}</span>
                        <div className="flex items-center gap-2">
                          <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                            cyc.status === 'Open' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                            cyc.status === 'Evaluating' ? 'bg-amber-100 text-amber-700' :
                            cyc.status === 'Upcoming' ? 'bg-blue-50 text-blue-600' :
                            'bg-gray-200 text-gray-600'
                          }`}>
                            {cyc.status}
                          </span>
                          {handleOpenEditCycle && (
                            <button onClick={(e) => { e.stopPropagation(); handleOpenEditCycle(prog, cyc); }} className="p-0.5 hover:text-[#2D5941] cursor-pointer bg-transparent border-0" title="Edit cycle">✏️</button>
                          )}
                          {handleDeleteCycle && (
                            <button onClick={(e) => { e.stopPropagation(); handleDeleteCycle(cyc.id.toString(), cyc.name); }} className="p-0.5 hover:text-red-700 cursor-pointer bg-transparent border-0" title="Delete cycle">🗑️</button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* Rejection Banner */}
              {prog.status === 'Rejected' && prog.rejectionRemarks && (
                <div className="bg-red-50 border border-red-200 rounded-xl px-3.5 py-2.5 my-2">
                  <span className="text-[9px] uppercase font-bold text-[#B34040] tracking-wider block mb-0.5">Rejection Remarks</span>
                  <p className="text-[11px] text-[#B34040] leading-snug line-clamp-2">{prog.rejectionRemarks}</p>
                </div>
              )}

              {/* Footer Meta & Structured Action Button Grid */}
              <div className="border-t border-[#D9D2C5]/50 pt-4 mt-4 space-y-3">
                {/* Meta stats bar */}
                <div className="flex items-center justify-between text-xs">
                  <div>
                    <span className="text-[#8E8E93] font-bold block uppercase tracking-wider text-[9px]">Funding Frequency</span>
                    <span className="text-[#1C1C1E] font-bold text-xs mt-0.5 block">{prog.fundingFrequency || 'Per Semester'}</span>
                  </div>
                  {prog.budgetTotal && (
                    <div className="text-right">
                      <span className="text-[#8E8E93] font-bold block uppercase tracking-wider text-[9px]">Total Allocation</span>
                      <span className="text-[#1A3C2E] font-bold text-xs mt-0.5 block">{prog.budgetTotal}</span>
                    </div>
                  )}
                </div>

                {/* Action Buttons Grid */}
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 pt-1">
                  <button
                    onClick={() => handleViewDetails(prog)}
                    className="py-2 px-3 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-[11px] font-bold border-0 cursor-pointer transition-all text-center shadow-2xs flex items-center justify-center gap-1.5"
                  >
                    <span>👁️</span> View
                  </button>
                  <button
                    onClick={() => handleEditProgram(prog)}
                    className="py-2 px-3 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-[11px] font-bold border-0 cursor-pointer transition-all text-center shadow-2xs flex items-center justify-center gap-1.5"
                  >
                    <span>✏️</span> Edit
                  </button>
                  <button
                    onClick={() => handleOpenRenewModal(prog)}
                    className="py-2 px-3 rounded-xl bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] text-[11px] font-bold border border-[#D9D2C5] cursor-pointer transition-all flex items-center justify-center gap-1.5 shadow-2xs"
                  >
                    <span>🔄</span> Renew
                  </button>
                  {prog.status === 'Rejected' ? (
                    <button
                      onClick={async () => {
                        try {
                          const { error } = await supabase
                            .from('scholarship_programs')
                            .update({ status: 'pending', rejection_remarks: null })
                            .eq('id', prog.id);
                          if (error) {
                            console.error('Error resubmitting program:', error);
                            showToast('Error resubmitting program.');
                          } else {
                            showToast(`"${prog.title}" has been resubmitted for review.`);
                            await fetchPrograms();
                          }
                        } catch (err) {
                          console.error('Unexpected error resubmitting program:', err);
                          showToast('An unexpected error occurred.');
                        }
                      }}
                      className="col-span-2 sm:col-span-2 py-2 px-3 rounded-xl bg-[#FFF8EE] hover:bg-amber-100 text-[#C97B2E] text-[11px] font-bold border border-amber-200 cursor-pointer transition-all text-center flex items-center justify-center gap-1.5 shadow-2xs"
                    >
                      <span>🔄</span> Resubmit for Review
                    </button>
                  ) : prog.status !== 'Closed' && prog.status !== 'closed' ? (
                    <button
                      onClick={() => { setProgramToClose(prog); setIsCloseConfirmOpen(true); }}
                      className="col-span-2 sm:col-span-2 py-2 px-3 rounded-xl bg-[#FDF2F2] hover:bg-red-100 text-[#B34040] text-[11px] font-bold border border-red-200 cursor-pointer transition-all text-center flex items-center justify-center gap-1.5 shadow-2xs"
                    >
                      <span>🔒</span> Close Program
                    </button>
                  ) : (
                    <button
                      onClick={async () => {
                        try {
                          const { error } = await supabase
                            .from('scholarship_programs')
                            .update({ status: 'active' })
                            .eq('id', prog.id);
                          if (error) {
                            console.error('Error re-opening program:', error);
                            showToast('Error re-opening program.');
                          } else {
                            showToast(`"${prog.title}" has been re-opened.`);
                            await fetchPrograms();
                          }
                        } catch (err) {
                          console.error('Unexpected error re-opening program:', err);
                          showToast('An unexpected error occurred.');
                        }
                      }}
                      className="col-span-2 sm:col-span-2 py-2 px-3 rounded-xl bg-[#EBF5EE] hover:bg-green-100 text-[#2D5941] text-[11px] font-bold border border-green-200 cursor-pointer transition-all text-center flex items-center justify-center gap-1.5 shadow-2xs"
                    >
                      <span>🔓</span> Re-open Program
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

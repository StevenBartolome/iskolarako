import React, { useState } from 'react';
import type { Program, ProviderDetails } from '../types';
import { supabase } from '@/services/supabaseClient';
import { createAuditLog } from '@/services/auditLogService';
import { sortCyclesNewestFirst } from '../utils/cycleUtils';

interface ProviderProgramsTabProps {
  providerDetails: ProviderDetails | null;
  programsList: Program[];
  showToast: (msg: string) => void;
  onOpenCreateProgram: () => void;
  setActiveTab: (tab: any) => void;
  handleViewDetails: (prog: Program) => void;
  handleEditProgram: (prog: Program) => void;
  handleOpenRenewModal: (prog: Program, targetMode?: 'renewal_2nd_sem' | 'next_academic_year') => void;
  handleOpenEditCycle?: (prog: Program, cyc: any) => void;
  handleDeleteCycle?: (id: string, name: string) => void;
  handleCloseCycle?: (id: string, name: string) => void;
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
  handleCloseCycle,
  setProgramToClose: _setProgramToClose,
  setIsCloseConfirmOpen: _setIsCloseConfirmOpen,
  fetchPrograms,
}) => {
  const [topUpProgram, setTopUpProgram] = useState<Program | null>(null);
  const [topUpAmount, setTopUpAmount] = useState<string>('');
  const [isSubmittingTopUp, setIsSubmittingTopUp] = useState(false);

  const handleTopUpSubmit = async () => {
    if (!topUpProgram || !topUpAmount.trim()) return;
    const addAmt = parseFloat(topUpAmount);
    if (isNaN(addAmt) || addAmt <= 0) {
      showToast('Please enter a valid top-up amount');
      return;
    }

    setIsSubmittingTopUp(true);
    try {
      const currentBudget = Number(topUpProgram.budget_total || topUpProgram.budgetTotal || 0);
      const newBudget = currentBudget + addAmt;

      const updateData: any = {
        budget_total: newBudget,
        updated_at: new Date().toISOString(),
      };

      const currentRawStatus = topUpProgram.rawStatus || 'active';
      if (currentRawStatus === 'paused') {
        updateData.status = 'active';
      }

      const { error } = await supabase
        .from('scholarship_programs')
        .update(updateData)
        .eq('id', topUpProgram.id);

      if (error) {
        console.error('Top up error:', error);
        showToast('Failed to top up program budget.');
      } else {
        showToast(`Successfully added ₱${addAmt.toLocaleString()} to "${topUpProgram.title}" budget!`);
        const { data: userData } = await supabase.auth.getUser();
        const actor = userData?.user?.email || 'Provider';
        createAuditLog(
          'TOPPED UP PROGRAM BUDGET',
          `Program: ${topUpProgram.title} - Added: ₱${addAmt.toLocaleString()}`,
          actor
        );
        setTopUpProgram(null);
        setTopUpAmount('');
        fetchPrograms();
      }
    } catch (err) {
      console.error('Top up exception:', err);
      showToast('Error executing budget top up.');
    } finally {
      setIsSubmittingTopUp(false);
    }
  };

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Scholarship Programs</h2>
          <p className="text-sm text-[#6C6C70] mt-1 font-medium">Permanent scholarship schemas, active application cycles, and budget allocation controls</p>
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
          {programsList.map((prog) => {
            const rawBudget = Number(prog.budget_total || prog.budgetTotal || 0);
            const totalDisbursed = Number(prog.disbursed_total || prog.disbursedTotal || 0);
            const remainingBudget = Math.max(0, rawBudget - totalDisbursed);
            const thresholdPct = Number(prog.low_budget_threshold || 0.20);
            const isLowBudget = rawBudget > 0 && remainingBudget <= (rawBudget * thresholdPct);
            const isDepleted = rawBudget > 0 && remainingBudget <= 0;

            return (
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
                        ⚙️ Policy: {prog.renewalPolicy || prog.renewal_policy || 'Semestral Re-evaluation'}
                      </span>
                    </div>
                  </div>

                  <div>
                    <h3 className="text-xl font-bold text-[#1A3C2E] font-serif leading-snug break-words">
                      {prog.title}
                    </h3>
                    <p className="text-xs text-[#6C6C70] mt-0.5 font-medium break-words">
                      {prog.description}
                    </p>
                  </div>

                  {/* Low Budget Alert Banner */}
                  {(isLowBudget || isDepleted) && (
                    <div className={`p-3 rounded-2xl border flex items-center justify-between gap-2 text-xs font-medium ${
                      isDepleted ? 'bg-[#FDF2F2] border-[#FADBD8] text-[#B34040]' : 'bg-[#FFF8EE] border-[#F5EAD6] text-[#C97B2E]'
                    }`}>
                      <div className="flex items-center gap-2">
                        <span>⚠️</span>
                        <span>
                          {isDepleted
                            ? 'Program Budget Depleted! Top up to enable scholar payouts.'
                            : `Low Budget Alert: ₱${remainingBudget.toLocaleString()} remaining.`}
                        </span>
                      </div>
                      <button
                        onClick={() => setTopUpProgram(prog)}
                        className="px-2.5 py-1 rounded-lg bg-[#C97B2E] text-white text-3xs font-extrabold cursor-pointer border-0 shrink-0 shadow-2xs"
                      >
                        + Top-Up
                      </button>
                    </div>
                  )}

                  {/* Application Cycles checklist sub-layout */}
                  <div className="space-y-1.5 pt-1">
                    <span className="text-[10px] uppercase font-bold text-[#8E8E93] tracking-wide block">Registered Cycles</span>
                    <div className="flex flex-col gap-1 max-h-24 overflow-y-auto">
                      {sortCyclesNewestFirst(prog.cycles)?.map((cyc: any) => (
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
                            {handleCloseCycle && cyc.status !== 'Closed' && cyc.status !== 'closed' && (
                              <button onClick={(e) => { e.stopPropagation(); handleCloseCycle(cyc.id.toString(), cyc.name); }} className="p-0.5 hover:text-amber-700 cursor-pointer bg-transparent border-0" title="Force Close cycle">🔒</button>
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

                {/* Smart Program Cycle Completion Banners & Re-Opening Prompts */}
                {(() => {
                  const freq = prog.fundingFrequency || prog.funding_frequency || 'Per Semester';
                  const isPerSemester = freq === 'Per Semester';
                  const cycles = prog.cycles || [];
                  if (cycles.length === 0) return null;

                  // Do not show completion banner if there is any active or open cycle
                  const hasActiveOpenCycle = cycles.some((c: any) => {
                    const st = (c.status || '').toLowerCase();
                    return st === 'open' || st === 'active' || st === 'draft' || st === 'pending';
                  });

                  if (hasActiveOpenCycle) {
                    return null;
                  }

                  // Find the index of the most recent 1st semester cycle (initial or new academic year batch)
                  const latestSem1CycleIndex = cycles.findLastIndex((c: any) =>
                    !(c.name || '').toLowerCase().includes('2nd') &&
                    !(c.semester || '').toLowerCase().includes('2nd') &&
                    c.cycleType !== 'renewal'
                  );

                  const sem1Cycle = latestSem1CycleIndex !== -1 ? cycles[latestSem1CycleIndex] : null;

                  // Find 2nd semester renewal cycle created specifically AFTER the latest 1st semester cycle
                  const sem2CycleForCurrentAY = latestSem1CycleIndex !== -1
                    ? cycles.slice(latestSem1CycleIndex + 1).find((c: any) =>
                        (c.name || '').toLowerCase().includes('2nd') ||
                        (c.semester || '').toLowerCase().includes('2nd') ||
                        c.cycleType === 'renewal'
                      )
                    : cycles.find((c: any) =>
                        ((c.name || '').toLowerCase().includes('2nd') ||
                        (c.semester || '').toLowerCase().includes('2nd')) &&
                        c.cycleType !== 'new_applicant'
                      );

                  const latestCycle = cycles[cycles.length - 1];

                  if (!isPerSemester && latestCycle && (latestCycle.status === 'Closed' || latestCycle.status === 'closed')) {
                    return (
                      <div className="bg-[#EBF5EE] border border-[#2D5941]/30 rounded-2xl p-3.5 my-2 space-y-2">
                        <div className="flex items-center gap-2">
                          <span className="text-base">🎉</span>
                          <div>
                            <h4 className="text-xs font-bold text-[#1A3C2E]">Program Cycle Completed</h4>
                            <p className="text-[11px] text-[#2D5941]">All scholars for {latestCycle.name} have completed disbursements.</p>
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => handleOpenRenewModal(prog, 'next_academic_year')}
                          className="w-full py-2 px-3 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer transition-all flex items-center justify-center gap-1.5 shadow-xs"
                        >
                          <span>🚀</span> Re-Open Program for Next Academic Year
                        </button>
                      </div>
                    );
                  }

                  if (isPerSemester) {
                    const isSem1Closed = sem1Cycle && (sem1Cycle.status === 'Closed' || sem1Cycle.status === 'closed');
                    const isSem2Closed = sem2CycleForCurrentAY && (sem2CycleForCurrentAY.status === 'Closed' || sem2CycleForCurrentAY.status === 'closed');

                    // If 1st semester cycle is closed and 2nd semester cycle has not been created for this current AY batch yet
                    if (isSem1Closed && !sem2CycleForCurrentAY) {
                      return (
                        <div className="bg-[#FFF8EE] border border-[#C97B2E]/30 rounded-2xl p-3.5 my-2 space-y-2">
                          <div className="flex items-center gap-2">
                            <span className="text-base">🎓</span>
                            <div>
                              <h4 className="text-xs font-bold text-[#8C5216]">1st Semester Cycle Completed</h4>
                              <p className="text-[11px] text-[#C97B2E]">Ready to accept 2nd semester renewal requirements from scholars.</p>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => handleOpenRenewModal(prog, 'renewal_2nd_sem')}
                            className="w-full py-2 px-3 rounded-xl bg-[#C97B2E] hover:bg-[#A86220] text-white text-xs font-bold border-0 cursor-pointer transition-all flex items-center justify-center gap-1.5 shadow-xs"
                          >
                            <span>🔄</span> Open 2nd Semester Renewal Cycle
                          </button>
                        </div>
                      );
                    }

                    // If 2nd semester cycle for the current AY has been created and is closed
                    if (isSem2Closed) {
                      return (
                        <div className="bg-[#EBF5EE] border border-[#2D5941]/30 rounded-2xl p-3.5 my-2 space-y-2">
                          <div className="flex items-center gap-2">
                            <span className="text-base">🏆</span>
                            <div>
                              <h4 className="text-xs font-bold text-[#1A3C2E]">Academic Year Fully Completed</h4>
                              <p className="text-[11px] text-[#2D5941]">Both 1st & 2nd semester cycles are completed for this program.</p>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => handleOpenRenewModal(prog, 'next_academic_year')}
                            className="w-full py-2 px-3 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer transition-all flex items-center justify-center gap-1.5 shadow-xs"
                          >
                            <span>🚀</span> Re-Open Program for Next Academic Year
                          </button>
                        </div>
                      );
                    }
                  }

                  return null;
                })()}

                {/* Footer Meta & Structured Action Button Grid */}
                <div className="border-t border-[#D9D2C5]/50 pt-4 mt-4 space-y-3">
                  {/* Meta stats bar */}
                  <div className="grid grid-cols-3 gap-2 text-xs bg-[#F9F5EF] p-3 rounded-2xl border border-[#D9D2C5]/40">
                    <div>
                      <span className="text-[#8E8E93] font-bold block uppercase tracking-wider text-[9px]">Frequency</span>
                      <span className="text-[#1C1C1E] font-bold text-xs mt-0.5 block truncate">{prog.fundingFrequency || 'Per Semester'}</span>
                    </div>
                    <div className="text-center border-x border-[#D9D2C5]/40 px-1">
                      <span className="text-[#8E8E93] font-bold block uppercase tracking-wider text-[9px]">Slots & Remaining</span>
                      <span className="text-[#1A3C2E] font-bold text-xs mt-0.5 block">
                        {(() => {
                          const totalSlots = Number(prog.totalSlots || prog.total_slots || 0);
                          const approvedCount = Number(prog.approvedCount || prog.approved_count || prog.scholars_count || 0);
                          if (totalSlots > 0) {
                            const remaining = Math.max(0, totalSlots - approvedCount);
                            return (
                              <>
                                <span>{approvedCount}/{totalSlots}</span>{' '}
                                <span className={`text-[10px] ${remaining === 0 ? 'text-[#B34040] font-extrabold' : 'text-[#C97B2E]'}`}>
                                  ({remaining === 0 ? 'Full' : `${remaining} left`})
                                </span>
                              </>
                            );
                          }
                          return <span>{approvedCount} Approved <span className="text-gray-400 text-[10px]">(∞)</span></span>;
                        })()}
                      </span>
                    </div>
                    <div className="text-right">
                      <span className="text-[#8E8E93] font-bold block uppercase tracking-wider text-[9px]">Budget / Left</span>
                      <span className="text-[#1A3C2E] font-bold text-xs mt-0.5 block truncate">
                        {rawBudget > 0 ? (
                          <>
                            ₱{rawBudget.toLocaleString()} <span className="text-[#C97B2E] text-[10px]">(₱{remainingBudget.toLocaleString()})</span>
                          </>
                        ) : (
                          <span className="text-gray-400 italic">₱0</span>
                        )}
                      </span>
                    </div>
                  </div>

                  {/* Action Buttons Grid */}
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-1">
                    <button
                      onClick={() => handleViewDetails(prog)}
                      className="py-2 px-2.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-[11px] font-bold border-0 cursor-pointer transition-all text-center shadow-2xs flex items-center justify-center gap-1"
                    >
                      <span>👁️</span> View
                    </button>
                    <button
                      onClick={() => handleEditProgram(prog)}
                      className="py-2 px-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-[11px] font-bold border-0 cursor-pointer transition-all text-center shadow-2xs flex items-center justify-center gap-1"
                    >
                      <span>✏️</span> Edit
                    </button>
                    <button
                      onClick={() => handleOpenRenewModal(prog)}
                      className="py-2 px-2.5 rounded-xl bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] text-[11px] font-bold border border-[#D9D2C5] cursor-pointer transition-all flex items-center justify-center gap-1 shadow-2xs"
                    >
                      <span>🔄</span> Renew
                    </button>
                    <button
                      onClick={() => setTopUpProgram(prog)}
                      className="py-2 px-2.5 rounded-xl bg-[#FFF8EE] hover:bg-[#F5EAD6] text-[#C97B2E] text-[11px] font-extrabold border border-[#F5EAD6] cursor-pointer transition-all flex items-center justify-center gap-1 shadow-2xs"
                    >
                      <span>➕</span> Top-Up
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Top-Up Budget Modal */}
      {topUpProgram && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-3xl p-6 max-w-md w-full border border-[#D9D2C5] shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-[#EDE8DE] pb-3">
              <div className="flex items-center gap-2">
                <span className="text-xl">➕</span>
                <h3 className="text-lg font-bold text-[#1A3C2E]">Top-Up Program Budget</h3>
              </div>
              <button
                onClick={() => setTopUpProgram(null)}
                className="text-gray-400 hover:text-gray-600 text-lg cursor-pointer bg-transparent border-0"
              >
                ✕
              </button>
            </div>

            <p className="text-xs text-[#6C6C70]">
              Add additional funding to <strong>"{topUpProgram.title}"</strong>. Current Total Allocation: ₱{Number(topUpProgram.budget_total || topUpProgram.budgetTotal || 0).toLocaleString()}.
            </p>

            <div>
              <label className="block text-xs font-bold text-[#1A3C2E] mb-1.5 uppercase">
                Top-Up Amount (PHP) *
              </label>
              <div className="relative">
                <span className="absolute left-3.5 top-2.5 text-xs font-bold text-[#8E8E93]">₱</span>
                <input
                  type="number"
                  placeholder="e.g. 200000"
                  value={topUpAmount}
                  onChange={(e) => setTopUpAmount(e.target.value)}
                  className="w-full pl-8 pr-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-bold text-[#1A3C2E] focus:outline-none focus:border-[#1A3C2E]"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-[#EDE8DE]">
              <button
                onClick={() => setTopUpProgram(null)}
                className="px-4 py-2 rounded-xl bg-[#F9F5EF] text-[#6C6C70] text-xs font-bold cursor-pointer border-0"
              >
                Cancel
              </button>
              <button
                onClick={handleTopUpSubmit}
                disabled={isSubmittingTopUp}
                className="px-5 py-2 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold cursor-pointer border-0 shadow-sm disabled:opacity-50"
              >
                {isSubmittingTopUp ? 'Adding Funds...' : 'Confirm Top-Up'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

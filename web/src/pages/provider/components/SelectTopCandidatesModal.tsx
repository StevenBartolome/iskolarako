import React, { useState, useEffect } from 'react';
import { Trophy, X, Info, GraduationCap } from 'lucide-react';
import { normalizeGwa } from '../utils/gwaUtils';

interface SelectTopCandidatesModalProps {
  isOpen: boolean;
  onClose: () => void;
  programTitle: string;
  cycleName?: string;
  totalSlots: number;
  alreadyApprovedCount: number;
  remainingSlots: number;
  topApplicants: any[];
  onConfirmApprove: (selectedAppIds: string[]) => Promise<void>;
  showToast?: (message: string) => void;
}

export const SelectTopCandidatesModal: React.FC<SelectTopCandidatesModalProps> = ({
  isOpen,
  onClose,
  programTitle,
  cycleName,
  totalSlots,
  alreadyApprovedCount,
  remainingSlots,
  topApplicants,
  onConfirmApprove,
  showToast,
}) => {
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  // Sync selected IDs whenever topApplicants changes or modal opens
  useEffect(() => {
    if (isOpen) {
      setSelectedIds(topApplicants.map(a => a.id));
    }
  }, [isOpen, topApplicants]);

  if (!isOpen) return null;

  const handleToggleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedIds(topApplicants.map(a => a.id));
    } else {
      setSelectedIds([]);
    }
  };

  const handleToggleIndividual = (id: string, checked: boolean) => {
    if (checked) {
      setSelectedIds(prev => [...prev, id]);
    } else {
      setSelectedIds(prev => prev.filter(item => item !== id));
    }
  };

  const handleConfirm = async () => {
    if (selectedIds.length === 0) {
      if (showToast) showToast('Please select at least one candidate to approve.');
      return;
    }
    setIsSubmitting(true);
    try {
      await onConfirmApprove(selectedIds);
      onClose();
    } catch (err) {
      console.error('Error during batch approval:', err);
      if (showToast) showToast('Failed to complete batch approval. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const allSelected = topApplicants.length > 0 && selectedIds.length === topApplicants.length;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 animate-fade-in">
      <div className="bg-white rounded-3xl max-w-4xl w-full max-h-[90vh] flex flex-col shadow-2xl border border-[#D9D2C5]/60 overflow-hidden">
        {/* Header */}
        <div className="bg-[#1A3C2E] text-white p-6 flex items-start justify-between">
          <div>
            <div className="flex items-center gap-2">
              <Trophy className="w-5 h-5 text-amber-400" />
              <h3 className="text-xl font-bold font-serif">Top Candidates Pre-Approval Selection</h3>
            </div>
            <p className="text-xs text-[#EBF5EE]/80 mt-1 font-medium">
              Automatically ranked by GWA percentage score for <span className="font-bold text-amber-300">{programTitle}</span>
              {cycleName ? ` (${cycleName})` : ''}
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={isSubmitting}
            className="text-white/70 hover:text-white cursor-pointer p-1 rounded-lg hover:bg-white/10 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Slot Metrics Summary */}
        <div className="bg-[#F9F5EF] p-5 border-b border-[#D9D2C5]/60 grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
          <div className="bg-white p-3 rounded-2xl border border-[#D9D2C5]/50 shadow-xs">
            <span className="text-[10px] font-bold uppercase tracking-wider text-[#6C6C70]">Max Capacity</span>
            <p className="text-lg font-extrabold text-[#1C1C1E]">{totalSlots} <span className="text-xs font-normal text-[#6C6C70]">slots</span></p>
          </div>
          <div className="bg-white p-3 rounded-2xl border border-[#D9D2C5]/50 shadow-xs">
            <span className="text-[10px] font-bold uppercase tracking-wider text-[#6C6C70]">Already Approved</span>
            <p className="text-lg font-extrabold text-[#2D5941]">{alreadyApprovedCount} <span className="text-xs font-normal text-[#6C6C70]">scholars</span></p>
          </div>
          <div className="bg-white p-3 rounded-2xl border border-[#D9D2C5]/50 shadow-xs">
            <span className="text-[10px] font-bold uppercase tracking-wider text-[#6C6C70]">Available Slots</span>
            <p className="text-lg font-extrabold text-amber-700">{remainingSlots} <span className="text-xs font-normal text-[#6C6C70]">remaining</span></p>
          </div>
          <div className="bg-[#EBF5EE] p-3 rounded-2xl border border-[#2D5941]/30 shadow-xs">
            <span className="text-[10px] font-bold uppercase tracking-wider text-[#2D5941]">Selected Top</span>
            <p className="text-lg font-extrabold text-[#1A3C2E]">{selectedIds.length} <span className="text-xs font-normal text-[#2D5941]">candidates</span></p>
          </div>
        </div>

        {/* Informational Banner */}
        <div className="px-6 py-3 bg-amber-50 border-b border-amber-200 flex items-center justify-between text-xs text-amber-900">
          <div className="flex items-center gap-2">
            <Info className="w-4 h-4 text-amber-700 shrink-0" />
            <span>
              Out of <strong>{totalSlots}</strong> total slots, <strong>{alreadyApprovedCount}</strong> are already approved.
              Showing the top <strong>{topApplicants.length}</strong> highest-ranked pending candidate(s).
            </span>
          </div>
        </div>

        {/* Ranked Applicants Table */}
        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 overflow-hidden">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-[#6C6C70] font-bold uppercase tracking-wider">
                  <th className="px-4 py-3 text-center w-10">
                    <input
                      type="checkbox"
                      checked={allSelected}
                      onChange={(e) => handleToggleSelectAll(e.target.checked)}
                      disabled={isSubmitting}
                      className="w-4 h-4 text-[#2D5941] rounded focus:ring-[#2D5941] cursor-pointer"
                    />
                  </th>
                  <th className="px-4 py-3 text-center w-16">Rank</th>
                  <th className="px-4 py-3">Applicant Name</th>
                  <th className="px-4 py-3">School & Course</th>
                  <th className="px-4 py-3 text-center">GWA / Score %</th>
                  <th className="px-4 py-3 text-center">Current Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
                {topApplicants.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-8 text-center text-[#8E8E93]">
                      No eligible pending candidates available for top slot selection.
                    </td>
                  </tr>
                ) : (
                  topApplicants.map((app, index) => {
                    const rankNum = index + 1;
                    const scale = app.gpa_scale || app.gpaScale || app.scholar?.gpa_scale || 'scale_5';
                    const score = normalizeGwa(app.grade, scale);
                    const isChecked = selectedIds.includes(app.id);

                    return (
                      <tr
                        key={app.id}
                        className={`transition-colors ${isChecked ? 'bg-[#EBF5EE]/30' : 'hover:bg-gray-50'}`}
                      >
                        <td className="px-4 py-3 text-center">
                          <input
                            type="checkbox"
                            checked={isChecked}
                            onChange={(e) => handleToggleIndividual(app.id, e.target.checked)}
                            disabled={isSubmitting}
                            className="w-4 h-4 text-[#2D5941] rounded focus:ring-[#2D5941] cursor-pointer"
                          />
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span
                            className={`inline-flex items-center justify-center w-6 h-6 rounded-full font-bold text-[11px] ${
                              rankNum <= 3
                                ? 'bg-amber-100 text-amber-900 border border-amber-300'
                                : 'bg-[#EDE8DE] text-[#1C1C1E]'
                            }`}
                          >
                            #{rankNum}
                          </span>
                        </td>
                        <td className="px-4 py-3 font-bold text-[#1C1C1E]">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 rounded-full bg-[#1A3C2E] text-white flex items-center justify-center text-[10px] font-bold uppercase">
                              {app.name.split(' ').map((n: string) => n[0]).join('')}
                            </div>
                            <span>{app.name}</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-[#6C6C70]">
                          <span className="block font-medium text-[#1C1C1E]">{app.school}</span>
                          <span className="text-[10px] text-[#8E8E93]">{app.course} ({app.yearLevel})</span>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <div className="inline-flex flex-col items-center">
                            <span className="font-serif font-bold text-[#1C1C1E]">{app.grade}</span>
                            <span className="text-[9px] font-extrabold text-[#2D5941] bg-[#EBF5EE] px-1.5 py-0.5 rounded border border-[#2D5941]/20">
                              Score: {score}%
                            </span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="px-2.5 py-1 rounded-full text-[10px] font-bold bg-[#F9F0E0] text-[#C97B2E]">
                            {app.status}
                          </span>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="bg-[#F9F5EF] p-5 border-t border-[#D9D2C5]/60 flex flex-wrap items-center justify-between gap-3">
          <div className="text-xs text-[#6C6C70]">
            Confirming will set the status of <strong>{selectedIds.length}</strong> selected top candidate(s) to <span className="text-[#2D5941] font-bold">Approved</span>.
          </div>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 rounded-xl text-xs font-bold text-[#6C6C70] hover:text-[#1C1C1E] bg-white border border-[#D9D2C5]/80 hover:bg-gray-50 transition-all cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleConfirm}
              disabled={isSubmitting || selectedIds.length === 0}
              className="px-5 py-2.5 rounded-xl text-xs font-bold text-white bg-[#1A3C2E] hover:bg-[#2D5941] disabled:opacity-50 disabled:cursor-not-allowed shadow-md hover:shadow-lg transition-all cursor-pointer flex items-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <svg className="animate-spin h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  <span>Approving Candidates...</span>
                </>
              ) : (
                <>
                  <GraduationCap className="w-4 h-4" />
                  <span>Confirm & Batch Approve ({selectedIds.length})</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

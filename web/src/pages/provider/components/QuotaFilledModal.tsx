import React, { useState, useMemo } from 'react';
import { Trophy, Info, Send, X } from 'lucide-react';
import { supabase } from '@/services/supabaseClient';
import { createAuditLog } from '@/services/auditLogService';
import { sendDecisionNotification } from '@/services/notificationService';
import { normalizeGwa, rankCandidates } from '../utils/gwaUtils';

interface QuotaFilledModalProps {
  isOpen: boolean;
  onClose: () => void;
  programTitle: string;
  cycleName: string;
  cycleId: string;
  totalSlots: number;
  unselectedApplicants: any[];
  providerName: string;
  onSuccess: () => void;
  showToast: (msg: string) => void;
  onConfirmApprove?: () => Promise<void>;
}

export const QuotaFilledModal: React.FC<QuotaFilledModalProps> = ({
  isOpen,
  onClose,
  programTitle,
  cycleName,
  cycleId: _cycleId,
  totalSlots,
  unselectedApplicants,
  providerName,
  onSuccess,
  showToast,
  onConfirmApprove,
}) => {
  const [templateType, setTemplateType] = useState<'standard' | 'exam'>('standard');
  const [reserveWaitlist, setReserveWaitlist] = useState<boolean>(false);
  const [waitlistCount, setWaitlistCount] = useState<number>(3);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  const defaultStandardMsg = `Thank you for applying to "${programTitle}". All available scholarship slots (${totalSlots} slots) for ${cycleName} have been filled by top-ranked candidates.`;
  const defaultExamMsg = `Thank you for taking the qualifying examination for "${programTitle}". Due to limited slot capacity (${totalSlots} slots filled), pending applications for this cycle have been finalized.`;

  const [customMessage, setCustomMessage] = useState<string>('');

  React.useEffect(() => {
    setCustomMessage(templateType === 'exam' ? defaultExamMsg : defaultStandardMsg);
  }, [templateType, programTitle, cycleName, totalSlots]);

  // Rank candidates by Normalized GWA Score + Submission Date
  const rankedApplicants = useMemo(() => {
    return rankCandidates(unselectedApplicants);
  }, [unselectedApplicants]);

  if (!isOpen) return null;

  const candidatesToClose = reserveWaitlist
    ? rankedApplicants.slice(waitlistCount)
    : rankedApplicants;

  const handleConfirmBatchResolution = async () => {
    if (candidatesToClose.length === 0 && !reserveWaitlist) {
      onClose();
      return;
    }

    setIsSubmitting(true);
    try {
      const { data: userData } = await supabase.auth.getUser();
      const currentUserId = userData?.user?.id;

      const remarksText = templateType === 'exam'
        ? `Not Selected — Qualifying Exam Quota Reached (${totalSlots} slots filled)`
        : `Not Selected — Slot Capacity Reached (${totalSlots} slots filled)`;

      const idsToClose = candidatesToClose.map(a => a.id);

      // Update waitlisted backup candidates if reserveWaitlist is checked
      if (reserveWaitlist) {
        const waitlistedCandidates = rankedApplicants.slice(0, waitlistCount);
        for (let i = 0; i < waitlistedCandidates.length; i++) {
          const wCand = waitlistedCandidates[i];
          await supabase
            .from('scholarship_applications')
            .update({
              status: 'under_review',
              remarks: `Waitlisted Backup (#${i + 1}) — Priority Candidate`,
              updated_at: new Date().toISOString(),
            })
            .eq('id', wCand.id);
        }
      }

      // 1. Batch Update Applications status to 'rejected'
      if (idsToClose.length > 0) {
        const { error: updErr } = await supabase
          .from('scholarship_applications')
          .update({
            status: 'rejected',
            remarks: remarksText,
            reviewed_at: new Date().toISOString(),
            reviewed_by: currentUserId || undefined,
            updated_at: new Date().toISOString(),
          })
          .in('id', idsToClose);

        if (updErr) throw updErr;

        // 2. Dispatch Notifications for each closed candidate
        for (const applicant of candidatesToClose) {
          const scholarId = applicant.scholarId || applicant.rawApplication?.scholar_id;

          // In-App Notification
          if (scholarId) {
            await supabase.from('notifications').insert({
              user_id: scholarId,
              title: templateType === 'exam' ? 'Qualifying Exam Update' : 'Scholarship Application Update',
              message: customMessage || (templateType === 'exam' ? defaultExamMsg : defaultStandardMsg),
              type: 'info',
              is_read: false,
              created_at: new Date().toISOString(),
            });
          }

          // Email Notification
          sendDecisionNotification({
            toEmail: applicant.email,
            toName: applicant.name,
            programTitle: programTitle,
            providerName: providerName || 'Scholarship Provider',
            status: 'Rejected',
            remarks: customMessage || remarksText,
            scholarId: scholarId,
          }).catch((err) => console.warn('[Quota Email Exception]:', err));
        }
      }

      // Log Audit Trail
      await createAuditLog(
        'BATCH RESOLVED QUOTA FILLED APPLICANTS',
        `Closed ${idsToClose.length} unselected applicants for ${programTitle} (${cycleName}) — ${templateType === 'exam' ? 'Exam Quota Reached' : 'Slot Capacity Reached'}`,
        userData?.user?.email || providerName
      );

      // Close the cycle in Supabase
      const { error: cycleErr } = await supabase
        .from('application_cycles')
        .update({ status: 'closed', updated_at: new Date().toISOString() })
        .eq('id', _cycleId);

      if (cycleErr) throw cycleErr;

      // Confirm approvals of selected candidates
      if (onConfirmApprove) {
        await onConfirmApprove();
      }

      showToast(`Successfully finalized ${idsToClose.length} unselected applications.`);
      onSuccess();
      onClose();
    } catch (err: any) {
      console.error('Error executing quota-filled batch resolution:', err);
      showToast(`Error: ${err.message || 'Failed to update applications'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center z-50 p-4 animate-fade-in">
      <div className="bg-white rounded-3xl p-6 sm:p-8 max-w-3xl w-full border border-[#D9D2C5] shadow-2xl space-y-6 max-h-[90vh] overflow-y-auto">
        {/* Modal Header */}
        <div className="flex items-start justify-between border-b border-[#EDE8DE] pb-4">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-100 text-amber-800 text-xs font-bold mb-2">
              <Trophy className="w-3.5 h-3.5 text-amber-700" />
              <span>Slot Capacity Reached ({totalSlots} / {totalSlots} Approved)</span>
            </div>
            <h3 className="text-2xl font-extrabold text-[#1A3C2E] font-serif leading-snug">
              Batch Resolution for Pending Applicants
            </h3>
            <p className="text-xs text-[#6C6C70] mt-1 font-medium">
              Program: <strong className="text-[#1C1C1E]">{programTitle}</strong> • Cycle: <strong className="text-[#1A3C2E]">{cycleName}</strong>
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 p-1.5 rounded-full hover:bg-gray-100 cursor-pointer transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Informative Alert Box */}
        <div className="bg-[#F9F5EF] p-4 rounded-2xl border border-[#D9D2C5]/60 text-xs space-y-1.5">
          <div className="flex items-center gap-2 font-bold text-[#1A3C2E]">
            <Info className="w-4 h-4 text-[#1A3C2E] shrink-0" />
            <span>Unbiased Candidate Ranking & Automated Resolution</span>
          </div>
          <p className="text-[#6C6C70] leading-relaxed">
            All approved scholarship slots for this cycle are now filled. Below, candidates are listed in <strong>objective rank order</strong> normalized across all grading scales (Scale 5.0, Scale 4.0, and Percentage).
          </p>
        </div>

        {/* Candidate Ranking Table */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <h4 className="text-xs font-extrabold uppercase tracking-wider text-[#1A3C2E]">
              Unselected Candidates ({rankedApplicants.length})
            </h4>
            <span className="text-[10px] text-[#8E8E93] font-bold">
              Sorted by Normalized Score (High → Low)
            </span>
          </div>

          <div className="border border-[#D9D2C5]/60 rounded-2xl overflow-hidden max-h-56 overflow-y-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead className="bg-[#EDE8DE]/60 text-[#6C6C70] font-bold uppercase text-[9px] tracking-wider sticky top-0 bg-[#EDE8DE]">
                <tr>
                  <th className="px-4 py-2.5">Rank</th>
                  <th className="px-4 py-2.5">Candidate Name</th>
                  <th className="px-4 py-2.5">School / Course</th>
                  <th className="px-4 py-2.5 text-center">Submitted Grade</th>
                  <th className="px-4 py-2.5 text-center">Normalized Score</th>
                  <th className="px-4 py-2.5 text-center">Current Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#D9D2C5]/30 text-xs">
                {rankedApplicants.map((app, idx) => {
                  const scale = app.gpa_scale || app.gpaScale || app.scholar?.gpa_scale || 'scale_5';
                  const normScore = normalizeGwa(app.grade || app.gpa, scale);
                  const isWaitlisted = reserveWaitlist && idx < waitlistCount;

                  return (
                    <tr
                      key={app.id}
                      className={isWaitlisted ? 'bg-amber-50/70 font-semibold' : 'hover:bg-gray-50'}
                    >
                      <td className="px-4 py-2.5 font-bold text-[#1A3C2E]">#{idx + 1}</td>
                      <td className="px-4 py-2.5 font-bold text-[#1C1C1E]">
                        {app.name}
                        {isWaitlisted && (
                          <span className="ml-1.5 text-[9px] px-1.5 py-0.5 rounded bg-amber-200 text-amber-900 font-extrabold">
                            Waitlisted Backup
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-2.5 text-gray-600 text-[11px] truncate max-w-[150px]">
                        {app.school} • {app.course}
                      </td>
                      <td className="px-4 py-2.5 text-center font-mono text-[#1C1C1E]">
                        {app.grade || app.gpa || 'N/A'}{' '}
                        <span className="text-[9px] text-gray-400">({scale.replace('scale_', 'Scale ')})</span>
                      </td>
                      <td className="px-4 py-2.5 text-center font-bold text-[#2D5941]">
                        {normScore}%
                      </td>
                      <td className="px-4 py-2.5 text-center">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                          app.status === 'For Exam' ? 'bg-purple-100 text-purple-700' :
                          app.status === 'Under Review' ? 'bg-blue-100 text-blue-700' :
                          'bg-amber-100 text-amber-800'
                        }`}>
                          {app.status}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Configuration Options */}
        <div className="space-y-4 pt-2 border-t border-[#EDE8DE]">
          <h4 className="text-xs font-extrabold uppercase tracking-wider text-[#1A3C2E]">
            Notification & Resolution Settings
          </h4>

          {/* Template Selector */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <label
              className={`p-3.5 rounded-2xl border cursor-pointer transition-all flex items-start gap-3 ${
                templateType === 'standard'
                  ? 'border-[#2D5941] bg-[#EBF5EE]/50 ring-2 ring-[#2D5941]/20'
                  : 'border-[#D9D2C5]/60 hover:bg-gray-50'
              }`}
            >
              <input
                type="radio"
                name="templateType"
                value="standard"
                checked={templateType === 'standard'}
                onChange={() => setTemplateType('standard')}
                className="mt-0.5 text-[#2D5941] focus:ring-[#2D5941]"
              />
              <div>
                <span className="block text-xs font-bold text-[#1C1C1E]">Standard Quota Filled Template</span>
                <span className="text-[11px] text-[#6C6C70] block mt-0.5">
                  Notifies candidates that slots were filled by top-ranked applicants.
                </span>
              </div>
            </label>

            <label
              className={`p-3.5 rounded-2xl border cursor-pointer transition-all flex items-start gap-3 ${
                templateType === 'exam'
                  ? 'border-[#2D5941] bg-[#EBF5EE]/50 ring-2 ring-[#2D5941]/20'
                  : 'border-[#D9D2C5]/60 hover:bg-gray-50'
              }`}
            >
              <input
                type="radio"
                name="templateType"
                value="exam"
                checked={templateType === 'exam'}
                onChange={() => setTemplateType('exam')}
                className="mt-0.5 text-[#2D5941] focus:ring-[#2D5941]"
              />
              <div>
                <span className="block text-xs font-bold text-[#1C1C1E]">Qualifying Exam Template</span>
                <span className="text-[11px] text-[#6C6C70] block mt-0.5">
                  Tailored for programs where candidates participated in screening exams.
                </span>
              </div>
            </label>
          </div>

          {/* Customize Rejection Message Input */}
          <div className="space-y-1.5">
            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide">
              Customize Rejection Notification Message
            </label>
            <textarea
              value={customMessage}
              onChange={(e) => setCustomMessage(e.target.value)}
              rows={3}
              className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-xs font-medium resize-y bg-white"
              placeholder="Enter custom rejection message here..."
            />
            <span className="text-[10px] text-[#6C6C70] block">
              This message will be sent to all closed candidates as an in-app notification and email update description.
            </span>
          </div>

          {/* Waitlist Toggle Option */}
          <div className="bg-[#F9F5EF] p-3.5 rounded-2xl border border-[#D9D2C5]/60 flex items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="reserveWaitlist"
                checked={reserveWaitlist}
                onChange={(e) => setReserveWaitlist(e.target.checked)}
                className="w-4 h-4 text-[#2D5941] rounded focus:ring-[#2D5941] cursor-pointer"
              />
              <label htmlFor="reserveWaitlist" className="text-xs font-bold text-[#1C1C1E] cursor-pointer">
                Keep Top Candidates Waitlisted as Backups
              </label>
            </div>

            {reserveWaitlist && (
              <div className="flex items-center gap-2">
                <span className="text-xs text-[#6C6C70] font-bold">Keep Top:</span>
                <select
                  value={waitlistCount}
                  onChange={(e) => setWaitlistCount(Number(e.target.value))}
                  className="bg-white border border-[#D9D2C5] rounded-xl px-2.5 py-1 text-xs font-bold outline-none"
                >
                  <option value={1}>Top 1</option>
                  <option value={2}>Top 2</option>
                  <option value={3}>Top 3</option>
                  <option value={5}>Top 5</option>
                </select>
              </div>
            )}
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[#EDE8DE]">
          <button
            type="button"
            onClick={onClose}
            disabled={isSubmitting}
            className="px-5 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-bold text-gray-600 hover:bg-gray-50 cursor-pointer transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleConfirmBatchResolution}
            disabled={isSubmitting}
            className="px-6 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold shadow-md cursor-pointer transition-all disabled:opacity-50 flex items-center gap-2"
          >
            {isSubmitting ? (
              <>
                <svg className="animate-spin h-3.5 w-3.5 text-white" viewBox="0 0 24 24" fill="none">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                </svg>
                <span>Processing...</span>
              </>
            ) : (
              <>
                <Send className="w-3.5 h-3.5" />
                <span>Confirm & Send Notifications ({candidatesToClose.length})</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

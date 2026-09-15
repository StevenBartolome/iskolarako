import React from 'react';
import { XCircle } from 'lucide-react';

interface RejectScholarshipModalProps {
  isOpen: boolean;
  remarks: string;
  setRemarks: (val: string) => void;
  onClose: () => void;
  onConfirm: () => void;
}

export const RejectScholarshipModal: React.FC<RejectScholarshipModalProps> = ({
  isOpen,
  remarks,
  setRemarks,
  onClose,
  onConfirm,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md p-8 text-left">
        <div className="flex items-center gap-3 mb-5">
          <div className="w-10 h-10 rounded-xl bg-red-50 flex items-center justify-center shrink-0">
            <XCircle className="w-5 h-5 text-red-600" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Reject Scholarship</h3>
            <p className="text-xs text-[#6C6C70]">Provide remarks so the provider can improve and resubmit.</p>
          </div>
        </div>

        <div className="space-y-3">
          <label className="text-[10px] uppercase font-bold text-[#8E8E93] tracking-wider block">Rejection Remarks *</label>
          <textarea
            value={remarks}
            onChange={(e) => setRemarks(e.target.value)}
            rows={4}
            placeholder="e.g. Missing eligibility criteria, incomplete benefit descriptions, unclear renewal policy..."
            className="w-full border border-[#D9D2C5] rounded-xl px-4 py-3 text-sm text-[#1C1C1E] font-sans resize-none focus:outline-none focus:border-[#1A3C2E] bg-[#F9F5EF]"
          />
          <p className="text-[10px] text-[#8E8E93]">These remarks will be visible to the provider and must be addressed before resubmission.</p>
        </div>

        <div className="flex gap-3 mt-6">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-3 rounded-xl border border-[#D9D2C5] text-[#1C1C1E] text-sm font-bold hover:bg-[#F9F5EF] transition-all cursor-pointer bg-white"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={!remarks.trim()}
            className="flex-1 py-3 rounded-xl bg-[#B34040] hover:bg-[#8E2F2F] text-white text-sm font-bold border-0 transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Confirm Reject
          </button>
        </div>
      </div>
    </div>
  );
};

import React from 'react';

interface RejectRemarksModalProps {
  isOpen: boolean;
  rejectRemarks: string;
  setRejectRemarks: (val: string) => void;
  onClose: () => void;
  onConfirm: () => void;
}

export const RejectRemarksModal: React.FC<RejectRemarksModalProps> = ({
  isOpen,
  rejectRemarks,
  setRejectRemarks,
  onClose,
  onConfirm,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
      <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-8 max-w-md w-full space-y-6 relative animate-fade-in">
        <button
          onClick={onClose}
          className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer bg-transparent border-0"
        >
          ✕
        </button>

        <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">Rejection Feedback</h3>
        <p className="text-xs text-[#6C6C70]">
          Enter the reason or feedback for rejecting the provider's verification documents. This will be visible to the provider.
        </p>

        <div className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
              Remarks / Feedback
            </label>
            <textarea
              value={rejectRemarks}
              onChange={(e) => setRejectRemarks(e.target.value)}
              placeholder="e.g. Document copy is blurry. Please upload a clear scan of your COR."
              rows={4}
              className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm font-semibold bg-white"
            />
          </div>

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 bg-transparent hover:bg-slate-50 text-[#6C6C70] border border-solid border-[#D9D2C5] py-3.5 rounded-xl text-sm font-bold cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onConfirm}
              className="flex-1 bg-[#B34040] hover:bg-[#8E2F2F] text-white py-3.5 rounded-xl text-sm font-bold shadow-md cursor-pointer transition-all border-0"
            >
              Confirm Rejection
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

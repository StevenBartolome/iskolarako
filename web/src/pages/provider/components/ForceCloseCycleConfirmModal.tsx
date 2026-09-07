import React from 'react';

interface ForceCloseCycleConfirmModalProps {
  isOpen: boolean;
  cycleName: string | null;
  onClose: () => void;
  onConfirm: () => void;
  isSubmitting?: boolean;
}

export const ForceCloseCycleConfirmModal: React.FC<ForceCloseCycleConfirmModalProps> = ({
  isOpen,
  cycleName,
  onClose,
  onConfirm,
  isSubmitting = false,
}) => {
  if (!isOpen || !cycleName) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md p-6 space-y-5 border border-[#D9D2C5]">
        <div className="w-14 h-14 rounded-2xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-800 text-2xl mx-auto shadow-xs">
          🔒
        </div>
        <div className="text-center space-y-2">
          <h3 className="text-xl font-extrabold text-[#1A3C2E] font-serif">Force Close Cycle?</h3>
          <p className="text-xs text-[#6C6C70] leading-relaxed">
            Are you sure you want to close the cycle <strong className="text-[#1C1C1E]">"{cycleName}"</strong>?
          </p>
          <div className="bg-[#F9F5EF] p-3 rounded-2xl border border-[#D9D2C5]/70 text-[11px] text-[#6C6C70] text-left leading-normal space-y-1">
            <span className="font-bold text-[#1A3C2E] block">⚠️ Impact of Closing:</span>
            <ul className="list-disc pl-4 space-y-0.5">
              <li>This marks the cycle as <strong>Closed</strong>, enabling you to start a new academic year or semester renewal.</li>
              <li>Scholars who haven't completed their bank info can still upload details and be processed manually later.</li>
            </ul>
          </div>
        </div>
        <div className="flex items-center gap-3 pt-2">
          <button
            type="button"
            onClick={onClose}
            disabled={isSubmitting}
            className="flex-1 px-4 py-3 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-xs font-bold border-0 cursor-pointer transition-all disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={isSubmitting}
            className="flex-1 px-4 py-3 rounded-xl bg-amber-800 hover:bg-amber-900 text-white text-xs font-bold border-0 cursor-pointer transition-all shadow-xs disabled:opacity-50 flex items-center justify-center gap-1.5"
          >
            {isSubmitting ? (
              <>
                <span className="animate-spin text-xs">⏳</span>
                <span>Closing...</span>
              </>
            ) : (
              <>
                <span>🔒</span>
                <span>Yes, Force Close</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

import React from 'react';
import { AlertTriangle } from 'lucide-react';
import type { Program } from '../ProviderPortal';

interface CloseProgramConfirmModalProps {
  isOpen: boolean;
  program: Program | null;
  onClose: () => void;
  onConfirm: () => void;
}

export const CloseProgramConfirmModal: React.FC<CloseProgramConfirmModalProps> = ({
  isOpen,
  program,
  onClose,
  onConfirm,
}) => {
  if (!isOpen || !program) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md p-8 space-y-5">
        <div className="w-14 h-14 rounded-2xl bg-[#FDF2F2] flex items-center justify-center text-[#B34040] mx-auto">
          <AlertTriangle className="w-7 h-7" />
        </div>
        <div className="text-center space-y-1">
          <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Close this Program?</h3>
          <p className="text-xs text-[#6C6C70] leading-relaxed">
            You are about to close <strong>"{program.title}"</strong>. It will be marked as <strong>Closed</strong> and no new applications will be accepted. This can be re-opened later by editing the program.
          </p>
        </div>
        <div className="flex gap-3 pt-2">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 px-4 py-3 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-sm font-bold border-0 cursor-pointer transition-all"
          >Cancel</button>
          <button
            type="button"
            onClick={onConfirm}
            className="flex-1 px-4 py-3 rounded-xl bg-[#B34040] hover:bg-red-700 text-white text-sm font-bold border-0 cursor-pointer transition-all"
          >Yes, Close Program</button>
        </div>
      </div>
    </div>
  );
};

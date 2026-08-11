import React from 'react';

interface VerificationModalProps {
  isOpen: boolean;
  onClose: () => void;
  email: string;
  errorMessage: string | null;
  codeDigits: string[];
  handleDigitChange: (idx: number, val: string) => void;
  handleDigitKeyDown: (idx: number, e: React.KeyboardEvent<HTMLInputElement>) => void;
  isSubmitting: boolean;
  handleVerifyCode: () => void;
}

export const VerificationModal: React.FC<VerificationModalProps> = ({
  isOpen,
  onClose,
  email,
  errorMessage,
  codeDigits,
  handleDigitChange,
  handleDigitKeyDown,
  isSubmitting,
  handleVerifyCode,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
      <div className="bg-white rounded-[32px] border border-[#EDE8DE] shadow-2xl p-8 max-w-md w-full space-y-6 relative text-center">
        <h3 className="text-2xl font-bold font-serif text-[#2D5941]">Verify Your Email</h3>
        <p className="text-xs text-[#8e8e93] leading-relaxed">
          We sent a 6-digit verification code to <br />
          <span className="font-semibold text-[#495057]">{email}</span>.
        </p>

        {errorMessage && (
          <p className="text-xs text-red-500 font-semibold bg-red-50 p-2 rounded-lg border border-red-200">
            {errorMessage}
          </p>
        )}

        {/* 6 Digit Inputs */}
        <div className="flex justify-center gap-2">
          {codeDigits.map((digit, idx) => (
            <input
              key={idx}
              id={`digit-${idx}`}
              type="text"
              maxLength={1}
              value={digit}
              onChange={(e) => handleDigitChange(idx, e.target.value)}
              onKeyDown={(e) => handleDigitKeyDown(idx, e)}
              className="w-10 h-12 text-center text-lg font-bold border border-solid border-[#EDE8DE] rounded-xl focus:border-[#2D5941] focus:ring-1 focus:ring-[#2D5941] outline-none bg-[#F9F5EF] text-[#495057]"
            />
          ))}
        </div>

        <div className="flex flex-col gap-3 pt-2">
          <button
            type="button"
            disabled={isSubmitting}
            onClick={handleVerifyCode}
            className="w-full py-3 rounded-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold uppercase tracking-wider transition-all duration-300 shadow-md hover:shadow-lg disabled:opacity-50 cursor-pointer border-0"
          >
            {isSubmitting ? 'Verifying...' : 'Verify & Register'}
          </button>
          <button
            type="button"
            onClick={onClose}
            className="text-xs text-[#8e8e93] hover:text-[#2D5941] hover:underline cursor-pointer bg-transparent border-0"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};

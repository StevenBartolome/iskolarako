import React, { useRef, useState, useEffect } from 'react';

interface VerificationModalProps {
  isOpen: boolean;
  onClose: () => void;
  email: string;
  errorMessage: string | null;
  enteredCode: string;
  setEnteredCode: (code: string) => void;
  isSubmitting: boolean;
  handleVerifyCode: () => void;
  onResendCode?: () => void;
}

export const VerificationModal: React.FC<VerificationModalProps> = ({
  isOpen,
  onClose,
  email,
  errorMessage,
  enteredCode,
  setEnteredCode,
  isSubmitting,
  handleVerifyCode,
  onResendCode,
}) => {
  const inputRef = useRef<HTMLInputElement>(null);
  const [isFocused, setIsFocused] = useState(false);
  const [resendTimer, setResendTimer] = useState(30);
  const [canResend, setCanResend] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => {
        inputRef.current?.focus();
      }, 100);
      setResendTimer(30);
      setCanResend(false);
    }
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen || canResend) return;
    const interval = setInterval(() => {
      setResendTimer((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          setCanResend(true);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [isOpen, canResend]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value.replace(/\D/g, '').slice(0, 6);
    setEnteredCode(val);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && enteredCode.length === 6) {
      handleVerifyCode();
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm px-4 animate-fade-in">
      <div className="bg-white rounded-[32px] border border-[#EDE8DE] shadow-2xl p-8 max-w-md w-full space-y-6 relative text-center">
        <div className="w-12 h-12 rounded-2xl bg-[#EBF5EE] text-[#2D5941] mx-auto flex items-center justify-center text-xl shadow-xs">
          ✉️
        </div>

        <div>
          <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">Verify Your Email</h3>
          <p className="text-xs text-[#8e8e93] leading-relaxed mt-1">
            We sent a 6-digit verification code to <br />
            <span className="font-semibold text-[#2D5941]">{email}</span>
          </p>
        </div>

        {errorMessage && (
          <p className="text-xs text-red-600 font-semibold bg-red-50 p-2.5 rounded-xl border border-red-200">
            {errorMessage}
          </p>
        )}

        {/* Single Input Field with Separated 6-Digit Display */}
        <div 
          className="relative flex justify-center items-center cursor-text py-2"
          onClick={() => inputRef.current?.focus()}
        >
          {/* Single actual hidden input that captures typing/pasting */}
          <input
            ref={inputRef}
            id="verification-code-input"
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            autoComplete="one-time-code"
            maxLength={6}
            value={enteredCode}
            onChange={handleChange}
            onKeyDown={handleKeyDown}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            className="absolute inset-0 w-full h-full opacity-0 z-20 cursor-text pointer-events-auto"
            autoFocus
          />

          {/* 6 Separated Visual Number Boxes */}
          <div className="flex justify-center gap-2.5 relative z-10 pointer-events-none">
            {Array.from({ length: 6 }).map((_, idx) => {
              const digit = enteredCode[idx] || '';
              const isCurrentCell = isFocused && (idx === enteredCode.length || (idx === 5 && enteredCode.length === 6));
              const isFilled = Boolean(digit);

              return (
                <div
                  key={idx}
                  className={`w-11 h-14 rounded-2xl border-2 flex items-center justify-center text-xl font-black font-mono transition-all duration-200 ${
                    isCurrentCell
                      ? 'border-[#2D5941] bg-white ring-4 ring-[#2D5941]/15 text-[#1A3C2E] shadow-sm scale-105'
                      : isFilled
                      ? 'border-[#2D5941]/60 bg-white text-[#1A3C2E] shadow-xs'
                      : 'border-[#EDE8DE] bg-[#F9F5EF] text-[#8E8E93]'
                  }`}
                >
                  {isFilled ? (
                    <span>{digit}</span>
                  ) : isCurrentCell ? (
                    <span className="w-0.5 h-6 bg-[#2D5941] animate-pulse rounded-full" />
                  ) : (
                    <span className="w-2 h-2 rounded-full bg-[#D9D2C5]/70" />
                  )}
                </div>
              );
            })}
          </div>
        </div>

        <div className="flex flex-col gap-3 pt-2">
          <button
            type="button"
            disabled={isSubmitting || enteredCode.length < 6}
            onClick={handleVerifyCode}
            className="w-full py-3.5 rounded-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold uppercase tracking-wider transition-all duration-300 shadow-md hover:shadow-lg disabled:opacity-50 cursor-pointer border-0"
          >
            {isSubmitting ? 'Verifying...' : 'Verify & Register'}
          </button>

          <div className="text-xs text-[#8e8e93]">
            {canResend ? (
              <span>
                Didn't receive the code?{' '}
                <button
                  type="button"
                  onClick={() => {
                    if (onResendCode) onResendCode();
                    setResendTimer(30);
                    setCanResend(false);
                  }}
                  className="font-bold text-[#2D5941] hover:underline bg-transparent border-0 cursor-pointer p-0"
                >
                  Resend Code
                </button>
              </span>
            ) : (
              <span>Resend code in <strong className="text-[#2D5941]">{resendTimer}s</strong></span>
            )}
          </div>

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

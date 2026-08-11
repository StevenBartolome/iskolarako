import React from 'react';

interface TermsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const TermsModal: React.FC<TermsModalProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
      <div className="bg-white rounded-3xl border border-[#EDE8DE] shadow-2xl p-8 max-w-lg w-full space-y-4 relative text-left">
        <button
          type="button"
          onClick={onClose}
          className="absolute top-6 right-6 text-[#8e8e93] hover:text-[#2D5941] font-bold text-lg cursor-pointer bg-transparent border-0"
        >
          ✕
        </button>
        <h3 className="text-2xl font-bold font-serif text-[#2D5941]">Terms & Conditions</h3>
        <div className="max-h-72 overflow-y-auto pr-2 text-xs text-[#6c757d] space-y-3 leading-relaxed">
          <p>Welcome to <strong>IskolarAko</strong>. By registering as a Scholarship Provider, you agree to comply with the following Terms and Conditions:</p>
          <h4 className="font-bold text-[#1c1c1e]">1. Provider Verification</h4>
          <p>All providers must submit valid organizational credentials. Access to cycle management and scholar matching is subject to verification approval by the System Admin layer.</p>
          <h4 className="font-bold text-[#1c1c1e]">2. Data Privacy & Student Records</h4>
          <p>You agree to handle all student data (including transcript documents, GWA grades, and contact details) with strict confidentiality and in compliance with the Data Privacy Act of 2012.</p>
          <h4 className="font-bold text-[#1c1c1e]">3. Fund Disbursements</h4>
          <p>Providers are responsible for ensuring that payouts, stipends, and grants are disbursed to matched scholars in a timely manner. System Admin monitoring of fund releases is strictly for compliance auditing.</p>
          <h4 className="font-bold text-[#1c1c1e]">4. Account Responsibility</h4>
          <p>You are solely responsible for maintaining the confidentiality of your login credentials and for all actions carried out under your organization portal.</p>
        </div>
        <div className="flex justify-end pt-2">
          <button
            type="button"
            onClick={onClose}
            className="px-6 py-2 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold cursor-pointer border-0"
          >
            I Understand
          </button>
        </div>
      </div>
    </div>
  );
};

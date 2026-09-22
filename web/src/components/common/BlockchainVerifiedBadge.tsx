import React, { useState, useEffect } from 'react';
import { Clock, AlertTriangle, ShieldCheck, ExternalLink } from 'lucide-react';
import { verifyDisbursementOnChain } from '../../utils/blockchain';

interface BlockchainVerifiedBadgeProps {
  txHash?: string;
  verified?: boolean;
  compact?: boolean;
  onClick?: () => void;
  // Dynamic validation properties
  dbAmount?: number;
  dbScholarId?: string;
  dbScholarName?: string;
}

export const BlockchainVerifiedBadge: React.FC<BlockchainVerifiedBadgeProps> = ({
  txHash,
  verified = true,
  compact = false,
  onClick,
  dbAmount,
  dbScholarId,
  dbScholarName = '',
}) => {
  const [isValidating, setIsValidating] = useState(false);
  const [isTampered, setIsTampered] = useState(false);

  useEffect(() => {
    // Only run live verification if the record is marked as verified, has a txHash,
    // and both database fields (amount, scholar UUID) are supplied.
    if (verified && txHash && dbAmount !== undefined && dbScholarId && dbScholarName) {
      let isMounted = true;
      const runVerification = async () => {
        setIsValidating(true);
        try {
          const res = await verifyDisbursementOnChain(txHash, dbAmount, dbScholarId, dbScholarName);
          if (isMounted) {
            setIsTampered(res.isTampered);
          }
        } catch (e) {
          console.error("Dynamic audit exception:", e);
        } finally {
          if (isMounted) {
            setIsValidating(false);
          }
        }
      };

      runVerification();
      return () => {
        isMounted = false;
      };
    } else {
      setIsTampered(false);
      setIsValidating(false);
    }
  }, [txHash, verified, dbAmount, dbScholarId, dbScholarName]);

  if (!verified && !txHash) {
    return (
      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-[#F9F5EF] text-[#6C6C70] border border-[#D9D2C5] shrink-0">
        <Clock className="w-3 h-3" />
        <span>Pending On-Chain</span>
      </span>
    );
  }

  if (isTampered) {
    if (compact) {
      return (
        <button
          type="button"
          onClick={onClick}
          className="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold bg-[#FDF2F2] text-[#B34040] hover:bg-[#B34040] hover:text-white border border-[#B34040]/30 transition-all cursor-pointer inline-flex items-center gap-1 shrink-0 animate-pulse"
          title="SECURITY ALERT: On-Chain Mismatch Detected!"
        >
          <AlertTriangle className="w-3 h-3" />
          <span>Tampered</span>
          <ExternalLink className="w-2.5 h-2.5" />
        </button>
      );
    }

    return (
      <button
        type="button"
        onClick={onClick}
        className="px-3 py-1 rounded-full text-xs font-extrabold bg-[#FDF2F2] text-[#B34040] hover:bg-[#B34040] hover:text-white border border-[#B34040]/30 transition-all cursor-pointer inline-flex items-center gap-1.5 shadow-2xs animate-pulse"
        title="SECURITY ALERT: Database values do not match on-chain ledger proof!"
      >
        <AlertTriangle className="w-3.5 h-3.5" />
        <span>Tamper Alert: Ledger Mismatch!</span>
        <ExternalLink className="w-3 h-3" />
      </button>
    );
  }

  if (compact) {
    return (
      <button
        type="button"
        onClick={onClick}
        className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-[#EBF5EE] text-[#2D5941] hover:bg-[#2D5941] hover:text-white border border-[#2D5941]/30 transition-all cursor-pointer inline-flex items-center gap-1 shrink-0"
        title="Click to view Blockchain Audit Certificate"
      >
        <ShieldCheck className="w-3 h-3" />
        <span>{isValidating ? 'Checking...' : 'Verified'}</span>
        <ExternalLink className="w-2.5 h-2.5" />
      </button>
    );
  }

  return (
    <button
      type="button"
      onClick={onClick}
      className="px-3 py-1 rounded-full text-xs font-bold bg-[#EBF5EE] text-[#2D5941] hover:bg-[#2D5941] hover:text-white border border-[#2D5941]/30 transition-all cursor-pointer inline-flex items-center gap-1.5 shadow-2xs"
      title="Click to view full Blockchain Audit Certificate & Polygon Proof"
    >
      <ShieldCheck className="w-3.5 h-3.5" />
      <span>{isValidating ? 'Validating On-Chain...' : 'Polygon Verified'}</span>
      <ExternalLink className="w-3 h-3" />
    </button>
  );
};

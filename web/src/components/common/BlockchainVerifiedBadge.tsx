import React from 'react';

interface BlockchainVerifiedBadgeProps {
  txHash?: string;
  verified?: boolean;
  compact?: boolean;
  onClick?: () => void;
}

export const BlockchainVerifiedBadge: React.FC<BlockchainVerifiedBadgeProps> = ({
  txHash,
  verified = true,
  compact = false,
  onClick,
}) => {
  if (!verified && !txHash) {
    return (
      <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-[#F9F5EF] text-[#6C6C70] border border-[#D9D2C5]">
        ⏳ Pending On-Chain
      </span>
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
        <span>⬡ Verified</span>
        <span className="text-[9px]">↗</span>
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
      <span className="text-sm">⬡</span>
      <span>Polygon Verified</span>
      <span className="text-[10px]">↗</span>
    </button>
  );
};

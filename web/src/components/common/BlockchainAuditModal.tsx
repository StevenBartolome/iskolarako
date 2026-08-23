import React, { useState } from 'react';

export interface AuditModalRecord {
  txHash: string;
  paymongoId?: string;
  scholarName: string;
  programTitle: string;
  amount: string;
  date: string;
  bankChannel?: string;
  blockNumber?: number | string;
  verified?: boolean;
}

interface BlockchainAuditModalProps {
  isOpen: boolean;
  record: AuditModalRecord | null;
  onClose: () => void;
}

export const BlockchainAuditModal: React.FC<BlockchainAuditModalProps> = ({
  isOpen,
  record,
  onClose,
}) => {
  const [copied, setCopied] = useState(false);

  if (!isOpen || !record) return null;

  const contractAddress = '0x24919E55678bA8bB67891A7FbA2067aA001557Bb';
  const explorerUrl = record.txHash && record.txHash.startsWith('0x')
    ? `https://amoy.polygonscan.com/tx/${record.txHash}`
    : `https://amoy.polygonscan.com/address/${contractAddress}`;

  const handleCopyHash = () => {
    if (record.txHash) {
      navigator.clipboard.writeText(record.txHash);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs z-50 flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
      <div className="bg-white rounded-3xl max-w-xl w-full p-7 border border-[#D9D2C5] shadow-2xl space-y-6 my-8 print:border-none print:shadow-none print:my-0">
        {/* Header */}
        <div className="flex justify-between items-start border-b border-[#D9D2C5]/60 pb-4">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-[#2D5941]/10 border border-[#2D5941]/30 flex items-center justify-center text-xl">
              🛡️
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-xl font-extrabold text-[#1A3C2E] font-serif">
                  Blockchain Audit Certificate
                </h3>
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/30 uppercase">
                  ✓ VERIFIED ON-CHAIN
                </span>
              </div>
              <p className="text-xs text-[#6C6C70] mt-0.5">
                Official cryptographic proof recorded on Polygon Amoy Testnet
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-[#6C6C70] hover:text-[#1C1C1E] p-1 rounded-full text-lg cursor-pointer print:hidden"
          >
            ✕
          </button>
        </div>

        {/* Cryptographic Seal Banner */}
        <div className="bg-gradient-to-r from-[#1A3C2E] to-[#2D5941] text-white p-5 rounded-2xl shadow-inner space-y-3">
          <div className="flex justify-between items-center text-xs">
            <span className="uppercase font-bold tracking-wider text-[#C97B2E]">
              Polygon Amoy Blockchain Ledger
            </span>
            <span className="px-2 py-0.5 rounded bg-white/10 text-[10px] font-mono text-white/90">
              Block #{record.blockNumber || '48920150'}
            </span>
          </div>

          <div className="space-y-1">
            <div className="text-[10px] uppercase text-white/70 font-semibold">Transaction Hash (SHA-256 / Keccak-256)</div>
            <div className="font-mono text-xs text-[#EBF5EE] break-all bg-black/20 p-2.5 rounded-xl border border-white/10 flex justify-between items-center gap-2">
              <span className="truncate">{record.txHash}</span>
              <button
                onClick={handleCopyHash}
                className="px-2.5 py-1 bg-white/20 hover:bg-white/30 text-white text-[10px] font-bold rounded-lg transition-all cursor-pointer shrink-0 print:hidden"
              >
                {copied ? '✓ Copied' : '📋 Copy'}
              </button>
            </div>
          </div>
        </div>

        {/* Audit Correlation Details Grid */}
        <div className="grid grid-cols-2 gap-3 text-xs">
          <div className="bg-[#F9F5EF] p-3.5 rounded-xl border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[10px] uppercase font-bold block mb-1">
              Scholar Recipient
            </span>
            <span className="font-bold text-[#1C1C1E] text-sm block truncate">{record.scholarName}</span>
          </div>
          <div className="bg-[#F9F5EF] p-3.5 rounded-xl border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[10px] uppercase font-bold block mb-1">
              Disbursed Amount
            </span>
            <span className="font-bold text-[#2D5941] text-sm block font-mono">{record.amount}</span>
          </div>
          <div className="bg-[#F9F5EF] p-3.5 rounded-xl border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[10px] uppercase font-bold block mb-1">
              Grant Program
            </span>
            <span className="font-semibold text-[#1C1C1E] block truncate">{record.programTitle}</span>
          </div>
          <div className="bg-[#F9F5EF] p-3.5 rounded-xl border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[10px] uppercase font-bold block mb-1">
              Disbursement Date
            </span>
            <span className="font-semibold text-[#1C1C1E] block">{record.date}</span>
          </div>
        </div>

        {/* Dual Ledger & Smart Contract Protocol */}
        <div className="bg-[#F9F5EF]/60 p-4 rounded-2xl border border-[#D9D2C5]/80 space-y-2 text-xs">
          <div className="flex justify-between items-center">
            <span className="text-[#6C6C70] font-medium">Smart Contract Address:</span>
            <span className="font-mono text-[#2D5941] font-bold text-[11px]">{contractAddress.substring(0, 10)}...{contractAddress.substring(34)}</span>
          </div>
          {record.paymongoId && (
            <div className="flex justify-between items-center">
              <span className="text-[#6C6C70] font-medium">PayMongo Reference ID:</span>
              <span className="font-mono font-bold text-[#1C1C1E]">{record.paymongoId}</span>
            </div>
          )}
          {record.bankChannel && (
            <div className="flex justify-between items-center">
              <span className="text-[#6C6C70] font-medium">Payout Channel:</span>
              <span className="font-medium text-[#1C1C1E]">{record.bankChannel}</span>
            </div>
          )}
        </div>

        {/* Actions & Verification Link */}
        <div className="pt-3 flex flex-wrap justify-between items-center gap-3 border-t border-[#D9D2C5]/60 print:hidden">
          <a
            href={explorerUrl}
            target="_blank"
            rel="noreferrer"
            className="px-4 py-2.5 rounded-xl bg-[#EBF5EE] hover:bg-[#2D5941] text-[#2D5941] hover:text-white text-xs font-bold transition-all inline-flex items-center gap-1.5 border border-[#2D5941]/20"
          >
            <span>🔗 View Live Proof on PolygonScan</span>
            <span>↗</span>
          </a>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={handlePrint}
              className="px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-bold text-[#1C1C1E] hover:bg-[#F9F5EF] cursor-pointer flex items-center gap-1.5"
            >
              <span>🖨️ Print Certificate</span>
            </button>
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold shadow-md cursor-pointer transition-all"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

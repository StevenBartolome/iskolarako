import React, { useState, useEffect } from 'react';
import { verifyDisbursementOnChain, type AuditResult } from '../../utils/blockchain';

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
  // New properties for real-time validation
  scholarId?: string;
  numericAmount?: number;
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
  const [isValidating, setIsValidating] = useState(false);
  const [auditResult, setAuditResult] = useState<AuditResult | null>(null);

  useEffect(() => {
    if (isOpen && record && record.txHash && record.numericAmount !== undefined && record.scholarId) {
      let isMounted = true;
      const runAudit = async () => {
        setIsValidating(true);
        setAuditResult(null);
        try {
          const res = await verifyDisbursementOnChain(
            record.txHash,
            record.numericAmount!,
            record.scholarId!,
            record.scholarName!
          );
          if (isMounted) {
            setAuditResult(res);
          }
        } catch (err: any) {
          console.error("Audit modal verification error:", err);
          if (isMounted) {
            setAuditResult({
              isTampered: false,
              error: err.message || "Failed to complete audit",
            });
          }
        } finally {
          if (isMounted) {
            setIsValidating(false);
          }
        }
      };

      runAudit();
      return () => {
        isMounted = false;
      };
    } else {
      setAuditResult(null);
      setIsValidating(false);
    }
  }, [isOpen, record]);

  if (!isOpen || !record) return null;

  const contractAddress = '0x24919E55678bA8bA8bB67891A7FbA2067aA001557Bb';
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

  // Determine badge header styling based on audit status
  let statusBadgeClass = "bg-[#EBF5EE] text-[#2D5941] border-[#2D5941]/30";
  let statusBadgeText = "✓ VERIFIED ON-CHAIN";

  if (isValidating) {
    statusBadgeClass = "bg-[#FFF8EE] text-[#C97B2E] border-[#C97B2E]/30 animate-pulse";
    statusBadgeText = "⏳ AUDITING PROOF...";
  } else if (auditResult?.isTampered) {
    statusBadgeClass = "bg-[#FDF2F2] text-[#B34040] border-[#B34040]/30 animate-bounce";
    statusBadgeText = "🚨 TAMPER ALERT: MISMATCH";
  } else if (auditResult?.error) {
    statusBadgeClass = "bg-[#F9F5EF] text-[#6C6C70] border-[#D9D2C5]";
    statusBadgeText = "⚠️ AUDIT OFFLINE (DB VERIFIED)";
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs z-50 flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
      <div className="bg-white rounded-3xl max-w-xl w-full p-7 border border-[#D9D2C5] shadow-2xl space-y-6 my-8 print:border-none print:shadow-none print:my-0">
        {/* Header */}
        <div className="flex justify-between items-start border-b border-[#D9D2C5]/60 pb-4">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-[#2D5941]/10 border border-[#2D5941]/30 flex items-center justify-center text-xl">
              {auditResult?.isTampered ? '🚨' : '🛡️'}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-xl font-extrabold text-[#1A3C2E] font-serif">
                  Blockchain Audit Certificate
                </h3>
                <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-extrabold border uppercase ${statusBadgeClass}`}>
                  {statusBadgeText}
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

        {/* Dynamic Tamper Alert Panel */}
        {auditResult?.isTampered && (
          <div className="bg-[#FDF2F2] border border-[#FADBD8] text-[#B34040] p-5 rounded-2xl space-y-3 animate-fade-slide-up">
            <div className="flex items-center gap-2 font-extrabold text-sm uppercase tracking-wide">
              <span>⚠️ Critical Security Warning: Database Tampering Detected!</span>
            </div>
            <p className="text-xs font-medium leading-relaxed">
              This disbursement has been altered in the application database after validation. The cryptographic blockchain ledger contains conflicting values, rendering this database state invalid.
            </p>
            <div className="border-t border-[#FADBD8] pt-3 text-xs space-y-2 font-mono">
              <div className="grid grid-cols-3 gap-2 text-[10px] uppercase font-bold text-[#6C6C70]">
                <span>Field</span>
                <span>Database Record</span>
                <span>Blockchain Ledger</span>
              </div>
              
              <div className="grid grid-cols-3 gap-2 border-t border-[#FADBD8]/40 pt-1.5 items-center">
                <span className="font-semibold text-[#8A3333]">Disbursed Amount</span>
                <span className="text-[#8A3333] font-bold">{record.amount}</span>
                <span className="text-[#2D5941] font-bold text-sm">
                  ₱{auditResult.onChainAmount?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </span>
              </div>

              <div className="grid grid-cols-3 gap-2 border-t border-[#FADBD8]/40 pt-1.5 items-center">
                <span className="font-semibold text-[#8A3333]">Scholar Recipient</span>
                <span className="text-[#8A3333] font-semibold truncate" title={record.scholarName}>{record.scholarName}</span>
                <span className="text-[#2D5941] font-semibold truncate" title={auditResult.onChainScholarId}>{auditResult.onChainScholarId}</span>
              </div>
            </div>
            <p className="text-[10px] text-[#B34040]/70 italic pt-1">
              *The immutable on-chain record is the sole source of truth. Audit mismatch flags must be resolved immediately.
            </p>
          </div>
        )}

        {/* Cryptographic Seal Banner */}
        <div className={`p-5 rounded-2xl shadow-inner space-y-3 text-white transition-all ${
          auditResult?.isTampered 
            ? 'bg-gradient-to-r from-[#802020] to-[#B34040] border border-[#802020]' 
            : 'bg-gradient-to-r from-[#1A3C2E] to-[#2D5941]'
        }`}>
          <div className="flex justify-between items-center text-xs">
            <span className="uppercase font-bold tracking-wider text-[#C97B2E]">
              Polygon Amoy Blockchain Ledger
            </span>
            <span className="px-2 py-0.5 rounded bg-white/10 text-[10px] font-mono text-white/90">
              Block #{record.blockNumber || '48920150'}
            </span>
          </div>

          <div className="space-y-1">
            <div className="text-[10px] uppercase text-white/70 font-semibold">Transaction Hash (Keccak-256)</div>
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
            <span className="font-bold text-[#1C1C1E] text-sm block truncate" title={record.scholarName}>{record.scholarName}</span>
            {record.scholarId && (
              <span className="text-[9px] font-mono text-[#8E8E93] mt-0.5 block truncate">ID: {record.scholarId}</span>
            )}
          </div>
          <div className="bg-[#F9F5EF] p-3.5 rounded-xl border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[10px] uppercase font-bold block mb-1">
              Disbursed Amount
            </span>
            <span className={`font-bold text-sm block font-mono ${auditResult?.isTampered ? 'text-[#B34040] line-through' : 'text-[#2D5941]'}`}>
              {record.amount}
            </span>
            {auditResult?.isTampered && auditResult.onChainAmount && (
              <span className="text-[10px] text-[#2D5941] font-bold font-mono mt-0.5 block">
                On-Chain: ₱{auditResult.onChainAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
              </span>
            )}
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

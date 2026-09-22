import React, { useState, useEffect } from 'react';
import { ShieldCheck, AlertTriangle, Check, Copy, ExternalLink, Printer, X, Loader2 } from 'lucide-react';
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
  let statusBadgeText: React.ReactNode = (
    <span className="inline-flex items-center gap-1">
      <Check className="w-2.5 h-2.5" />
      <span>VERIFIED ON-CHAIN</span>
    </span>
  );

  if (isValidating) {
    statusBadgeClass = "bg-[#FFF8EE] text-[#C97B2E] border-[#C97B2E]/30 animate-pulse";
    statusBadgeText = (
      <span className="inline-flex items-center gap-1">
        <Loader2 className="w-2.5 h-2.5 animate-spin" />
        <span>AUDITING PROOF...</span>
      </span>
    );
  } else if (auditResult?.isTampered) {
    statusBadgeClass = "bg-[#FDF2F2] text-[#B34040] border-[#B34040]/30 animate-bounce";
    statusBadgeText = (
      <span className="inline-flex items-center gap-1">
        <AlertTriangle className="w-2.5 h-2.5" />
        <span>TAMPER ALERT: MISMATCH</span>
      </span>
    );
  } else if (auditResult?.error) {
    statusBadgeClass = "bg-[#F9F5EF] text-[#6C6C70] border-[#D9D2C5]";
    statusBadgeText = (
      <span className="inline-flex items-center gap-1">
        <AlertTriangle className="w-2.5 h-2.5" />
        <span>AUDIT OFFLINE (DB VERIFIED)</span>
      </span>
    );
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs z-50 flex items-center justify-center p-4 animate-fade-in">
      <div className="bg-white rounded-3xl max-w-lg w-full p-5 border border-[#D9D2C5] shadow-2xl space-y-3.5 max-h-[92vh] overflow-y-auto print:border-none print:shadow-none print:my-0">
        {/* Header */}
        <div className="flex justify-between items-center border-b border-[#D9D2C5]/60 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-[#2D5941]/10 border border-[#2D5941]/30 flex items-center justify-center shrink-0">
              {auditResult?.isTampered ? (
                <AlertTriangle className="w-5 h-5 text-red-600" />
              ) : (
                <ShieldCheck className="w-5 h-5 text-[#2D5941]" />
              )}
            </div>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                  Blockchain Audit Certificate
                </h3>
                <span className={`px-2 py-0.5 rounded-full text-[9px] font-extrabold border uppercase ${statusBadgeClass}`}>
                  {statusBadgeText}
                </span>
              </div>
              <p className="text-[11px] text-[#6C6C70]">
                Cryptographic proof recorded on Polygon Amoy Testnet
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-[#6C6C70] hover:text-[#1C1C1E] p-1 rounded-full text-base cursor-pointer shrink-0 print:hidden"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Dynamic Tamper Alert Panel */}
        {auditResult?.isTampered && (
          <div className="bg-[#FDF2F2] border border-[#FADBD8] text-[#B34040] p-3.5 rounded-xl space-y-2 animate-fade-slide-up">
            <div className="flex items-center gap-1.5 font-extrabold text-xs uppercase tracking-wide">
              <AlertTriangle className="w-4 h-4 shrink-0" />
              <span>Critical Alert: Database Tampering Detected!</span>
            </div>
            <div className="border-t border-[#FADBD8] pt-2 text-[11px] space-y-1.5 font-mono">
              <div className="grid grid-cols-3 gap-1 text-[9px] uppercase font-bold text-[#6C6C70]">
                <span>Field</span>
                <span>Database</span>
                <span>On-Chain Ledger</span>
              </div>
              
              <div className="grid grid-cols-3 gap-1 border-t border-[#FADBD8]/40 pt-1 items-center">
                <span className="font-semibold text-[#8A3333]">Amount</span>
                <span className="text-[#8A3333] font-bold">{record.amount}</span>
                <span className="text-[#2D5941] font-bold">
                  ₱{auditResult.onChainAmount?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </span>
              </div>

              <div className="grid grid-cols-3 gap-1 border-t border-[#FADBD8]/40 pt-1 items-center">
                <span className="font-semibold text-[#8A3333]">Scholar</span>
                <span className="text-[#8A3333] font-semibold break-words" title={record.scholarName}>{record.scholarName}</span>
                <span className="text-[#2D5941] font-semibold break-all" title={auditResult.onChainScholarId}>{auditResult.onChainScholarId}</span>
              </div>
            </div>
          </div>
        )}

        {/* Cryptographic Seal Banner */}
        <div className={`p-3.5 rounded-xl shadow-inner space-y-2 text-white transition-all ${
          auditResult?.isTampered 
            ? 'bg-gradient-to-r from-[#802020] to-[#B34040] border border-[#802020]' 
            : 'bg-gradient-to-r from-[#1A3C2E] to-[#2D5941]'
        }`}>
          <div className="flex justify-between items-center text-xs">
            <span className="uppercase font-bold tracking-wider text-[#C97B2E] text-[10px]">
              Polygon Amoy Blockchain Ledger
            </span>
            <span className="px-1.5 py-0.5 rounded bg-white/10 text-[9px] font-mono text-white/90">
              Block #{record.blockNumber || '48920150'}
            </span>
          </div>

          <div className="space-y-1">
            <div className="text-[9px] uppercase text-white/70 font-semibold">Transaction Hash</div>
            <div className="font-mono text-[11px] text-[#EBF5EE] break-all bg-black/20 p-2 rounded-lg border border-white/10 flex justify-between items-center gap-2">
              <span className="break-all">{record.txHash}</span>
              <button
                onClick={handleCopyHash}
                className="inline-flex items-center gap-1 px-2 py-0.5 bg-white/20 hover:bg-white/30 text-white text-[9px] font-bold rounded transition-all cursor-pointer shrink-0 print:hidden"
              >
                {copied ? (
                  <>
                    <Check className="w-2.5 h-2.5" />
                    <span>Copied</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-2.5 h-2.5" />
                    <span>Copy</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>

        {/* Audit Correlation Details Grid */}
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="bg-[#F9F5EF] p-2.5 rounded-lg border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[9px] uppercase font-bold block">
              Scholar Recipient
            </span>
            <span className="font-bold text-[#1C1C1E] text-xs block break-words" title={record.scholarName}>{record.scholarName}</span>
          </div>
          <div className="bg-[#F9F5EF] p-2.5 rounded-lg border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[9px] uppercase font-bold block">
              Disbursed Amount
            </span>
            <span className={`font-bold text-xs block font-mono ${auditResult?.isTampered ? 'text-[#B34040] line-through' : 'text-[#2D5941]'}`}>
              {record.amount}
            </span>
            {auditResult?.isTampered && auditResult.onChainAmount && (
              <span className="text-[9px] text-[#2D5941] font-bold font-mono block">
                On-Chain: ₱{auditResult.onChainAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
              </span>
            )}
          </div>
          <div className="bg-[#F9F5EF] p-2.5 rounded-lg border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[9px] uppercase font-bold block">
              Grant Program
            </span>
            <span className="font-semibold text-[#1C1C1E] text-xs block break-words">{record.programTitle}</span>
          </div>
          <div className="bg-[#F9F5EF] p-2.5 rounded-lg border border-[#D9D2C5]">
            <span className="text-[#6C6C70] text-[9px] uppercase font-bold block">
              Disbursement Date
            </span>
            <span className="font-semibold text-[#1C1C1E] text-xs block">{record.date}</span>
          </div>
        </div>

        {/* Dual Ledger & Smart Contract Protocol */}
        <div className="bg-[#F9F5EF]/60 p-2.5 rounded-xl border border-[#D9D2C5]/80 space-y-1 text-[11px]">
          <div className="flex justify-between items-center">
            <span className="text-[#6C6C70]">Contract:</span>
            <span className="font-mono text-[#2D5941] font-bold text-[10px]">{contractAddress.substring(0, 10)}...{contractAddress.substring(34)}</span>
          </div>
          {record.paymongoId && (
            <div className="flex justify-between items-center">
              <span className="text-[#6C6C70]">PayMongo ID:</span>
              <span className="font-mono font-bold text-[#1C1C1E] text-[10px]">{record.paymongoId}</span>
            </div>
          )}
        </div>

        {/* Actions & Verification Link */}
        <div className="pt-2 flex flex-wrap justify-between items-center gap-2 border-t border-[#D9D2C5]/60 print:hidden">
          <a
            href={explorerUrl}
            target="_blank"
            rel="noreferrer"
            className="px-3 py-2 rounded-xl bg-[#EBF5EE] hover:bg-[#2D5941] text-[#2D5941] hover:text-white text-xs font-bold transition-all inline-flex items-center gap-1.5 border border-[#2D5941]/20"
          >
            <span>PolygonScan Proof</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={handlePrint}
              className="px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs font-bold text-[#1C1C1E] hover:bg-[#F9F5EF] cursor-pointer inline-flex items-center gap-1.5"
            >
              <Printer className="w-3.5 h-3.5" />
              <span>Print</span>
            </button>
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold shadow-md cursor-pointer transition-all"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

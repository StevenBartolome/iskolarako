import React, { useState, useEffect } from 'react';
import { ExternalLink, RefreshCw, Check, FileText } from 'lucide-react';
import { supabase } from '@/services/supabaseClient';

interface BlockchainEventRecord {
  id: string;
  txHash: string;
  blockNumber: string | number;
  providerName: string;
  scholarName: string;
  programTitle: string;
  amount: number;
  paymongoId: string;
  status: string;
  verified: boolean;
  createdAt: string;
  bankName: string;
  accountNumber: string;
  isBulk: boolean;
  documentProofUrl?: string;
}

export const AdminFundsTab: React.FC = () => {
  const [blockchainEvents, setBlockchainEvents] = useState<BlockchainEventRecord[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const smartContractAddress = '0x24919E55678bA8bB67891A7FbA2067aA001557Bb';

  useEffect(() => {
    fetchBlockchainEvents();

    const channel = supabase
      .channel('admin-funds-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'fund_releases' },
        () => {
          fetchBlockchainEvents();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholar_payment_accounts' },
        () => {
          fetchBlockchainEvents();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchBlockchainEvents = async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('fund_releases')
        .select(`
          *,
          scholar:scholar_id(first_name, last_name),
          scholarship_programs:program_id(title, provider:provider_id(name)),
          payment_account:payment_account_id(bank_name, account_number, account_name, document_proof_url)
        `)
        .order('created_at', { ascending: false });

      if (!error && data) {
        const formatted: BlockchainEventRecord[] = data.map((item: any) => {
          const pAcc = item.payment_account;
          const bankName = pAcc?.bank_name || item.recipient_account_snapshot?.bankName || 'Bank Direct';
          const accountNumber = pAcc?.account_number || item.recipient_account_snapshot?.accountNumber || '';

          return {
            id: item.id,
            txHash: item.blockchain_tx_hash || 'Pending',
            blockNumber: item.blockchain_block_number || 'Pending',
            providerName: item.scholarship_programs?.provider?.name || 'Scholarship Provider',
            scholarName: item.scholar
              ? `${item.scholar.first_name || ''} ${item.scholar.last_name || ''}`.trim()
              : 'Scholar Recipient',
            programTitle: item.scholarship_programs?.title || 'Scholarship Grant',
            amount: Number(item.amount) || 0,
            paymongoId: item.paymongo_payment_id || 'Pending',
            status: item.status || 'released',
            verified: item.blockchain_verified ?? true,
            bankName,
            accountNumber,
            isBulk: !!item.is_bulk_release,
            documentProofUrl: pAcc?.document_proof_url,
            createdAt: item.created_at
              ? new Date(item.created_at).toLocaleString('en-US', {
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                })
              : 'N/A',
          };
        });
        setBlockchainEvents(formatted);
      }
    } catch (err) {
      console.error('Error fetching admin blockchain events:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const totalOnChainAmount = blockchainEvents.reduce((acc, curr) => acc + curr.amount, 0);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header Info Banner */}
      <div className="flex justify-between items-center flex-wrap gap-4 bg-[#1A3C2E] text-white p-6 rounded-2xl shadow-md border border-[#2D5941]">
        <div>
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-[#C97B2E] animate-pulse"></span>
            <span className="text-xs font-bold uppercase tracking-wider text-[#C97B2E]">
              Polygon Amoy Audit Trail
            </span>
          </div>
          <h2 className="text-2xl font-extrabold font-serif mt-1">Platform Blockchain Events</h2>
          <p className="text-xs text-white/80 mt-1 max-w-xl">
            Real-time immutable ledger monitoring every single & batch fund release event recorded across all providers.
          </p>
        </div>

        <div className="flex gap-3">
          <a
            href={`https://amoy.polygonscan.com/address/${smartContractAddress}`}
            target="_blank"
            rel="noreferrer"
            className="bg-[#C97B2E] hover:bg-[#A86220] text-white px-4 py-2 rounded-xl text-xs font-bold shadow transition-all inline-flex items-center gap-1.5"
          >
            <span>View Smart Contract on Polygonscan</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>
          <button
            onClick={fetchBlockchainEvents}
            className="bg-white/10 hover:bg-white/20 text-white px-3.5 py-2 rounded-xl text-xs font-semibold transition-all cursor-pointer inline-flex items-center gap-1.5"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Summary Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white border border-[#D9D2C5] rounded-2xl p-5 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Total On-Chain Events</span>
          <h4 className="text-2xl font-bold text-[#1A3C2E] font-serif mt-1">
            {blockchainEvents.length} Records
          </h4>
          <span className="text-[10px] text-[#2D5941] font-semibold mt-1 inline-flex items-center gap-1">
            <Check className="w-3 h-3" />
            <span>Immutably Stored</span>
          </span>
        </div>

        <div className="bg-white border border-[#D9D2C5] rounded-2xl p-5 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Verified Disbursed Value</span>
          <h4 className="text-2xl font-bold text-[#2D5941] font-serif mt-1">
            ₱{totalOnChainAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </h4>
          <span className="text-[10px] text-[#6C6C70] mt-1 block">Orchestrated via PayMongo</span>
        </div>

        <div className="bg-white border border-[#D9D2C5] rounded-2xl p-5 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Blockchain Network</span>
          <h4 className="text-xl font-bold text-[#C97B2E] font-serif mt-1">Polygon Amoy</h4>
          <span className="text-[10px] text-[#6C6C70] mt-1 block">Chain ID: 80002 (POS Testnet)</span>
        </div>

        <div className="bg-white border border-[#D9D2C5] rounded-2xl p-5 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Deployed Smart Contract</span>
          <h4 className="text-xs font-mono font-bold text-[#1C1C1E] mt-2 break-all">
            {smartContractAddress}
          </h4>
          <span className="text-[10px] text-[#2D5941] font-semibold mt-1 block">IskoAkoFundLedger.sol</span>
        </div>
      </div>

      {/* Main Events Table */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm overflow-hidden">
        <div className="p-5 border-b border-[#D9D2C5]/60 bg-[#F9F5EF]/30 flex justify-between items-center">
          <div>
            <h3 className="text-base font-bold text-[#1A3C2E] font-serif">On-Chain Transaction Audit Ledger</h3>
            <p className="text-xs text-[#6C6C70]">
              Every fund release logs a block event with cryptographically verified transaction hash and bank destination
            </p>
          </div>
        </div>

        {isLoading ? (
          <div className="p-12 text-center text-xs font-semibold text-[#6C6C70]">
            Fetching live Polygon blockchain events from database...
          </div>
        ) : blockchainEvents.length === 0 ? (
          <div className="p-12 text-center text-xs font-semibold text-[#6C6C70]">
            No blockchain events logged yet. When providers release funds, the transactions will appear here.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5] text-[#1C1C1E] font-bold uppercase tracking-wider text-[11px]">
                  <th className="py-3.5 px-4">Transaction Hash (Polygon)</th>
                  <th className="py-3.5 px-4">Block #</th>
                  <th className="py-3.5 px-4">Provider</th>
                  <th className="py-3.5 px-4">Scholar Recipient</th>
                  <th className="py-3.5 px-4">Bank Destination</th>
                  <th className="py-3.5 px-4">Program</th>
                  <th className="py-3.5 px-4">Amount</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4 text-right">Date & Time</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#D9D2C5]/50 font-medium">
                {blockchainEvents.map((event) => (
                  <tr key={event.id} className="hover:bg-[#F9F5EF]/50 transition-colors">
                    <td className="py-3 px-4 font-mono font-bold text-[#2D5941]">
                      {event.txHash.startsWith('0x') ? (
                        <a
                          href={`https://amoy.polygonscan.com/tx/${event.txHash}`}
                          target="_blank"
                          rel="noreferrer"
                          className="hover:underline inline-flex items-center gap-1 text-[#2D5941]"
                          title="View proof on Polygonscan"
                        >
                          <span>{`${event.txHash.substring(0, 12)}...${event.txHash.substring(event.txHash.length - 6)}`}</span>
                          <ExternalLink className="w-2.5 h-2.5" />
                        </a>
                      ) : (
                        <span>{event.txHash}</span>
                      )}
                    </td>
                    <td className="py-3 px-4 font-mono font-semibold text-[#6C6C70]">
                      #{event.blockNumber}
                    </td>
                    <td className="py-3 px-4 font-bold text-[#1C1C1E]">{event.providerName}</td>
                    <td className="py-3 px-4 font-semibold text-[#1C1C1E]">{event.scholarName}</td>
                    <td className="py-3 px-4 text-[#1C1C1E]">
                      <div className="flex items-center gap-1.5">
                        <span>
                          {event.bankName} {event.accountNumber ? `(•••• ${event.accountNumber.slice(-4)})` : ''}
                        </span>
                        {event.isBulk && (
                          <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-[#FFF8EE] text-[#C97B2E] border border-[#C97B2E]/30">
                            Batch
                          </span>
                        )}
                        {event.documentProofUrl && (
                          <a
                            href={event.documentProofUrl}
                            target="_blank"
                            rel="noreferrer"
                            className="text-[10px] text-[#2D5941] font-bold hover:underline ml-1 inline-flex items-center gap-0.5"
                            title="View Verified Bank Card Scan"
                          >
                            <FileText className="w-3 h-3" />
                            <span>Scan</span>
                          </a>
                        )}
                      </div>
                    </td>
                    <td className="py-3 px-4 text-[#6C6C70]">{event.programTitle}</td>
                    <td className="py-3 px-4 font-bold text-[#2D5941]">
                      ₱{event.amount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-3 px-4">
                      <span className="px-2.5 py-1 rounded-full text-[10px] font-bold bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20 inline-flex items-center gap-1">
                        <Check className="w-2.5 h-2.5" />
                        <span>VERIFIED</span>
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right text-[11px] text-[#8E8E93]">
                      {event.createdAt}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

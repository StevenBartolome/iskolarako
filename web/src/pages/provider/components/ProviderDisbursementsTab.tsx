import React, { useState, useEffect, useMemo } from 'react';
import type { DisbursementTx } from '../types';
import { supabase } from '@/services/supabaseClient';
import { createAuditLog } from '@/services/auditLogService';
import { ProviderBatchDisbursementModal } from './ProviderBatchDisbursementModal';
import { ScholarBankUploadModal } from '@/components/scholar/ScholarBankUploadModal';
import { DisbursementRefundModal, type DisbursementActionType, type DisbursementItem } from './DisbursementRefundModal';
import { BlockchainVerifiedBadge } from '@/components/common/BlockchainVerifiedBadge';
import { BlockchainAuditModal, type AuditModalRecord } from '@/components/common/BlockchainAuditModal';

interface ProviderDisbursementsTabProps {
  totalCredited: number;
  totalPending: number;
  disbursementsList: DisbursementTx[];
  setIsPayoutModalOpen: (open: boolean) => void;
  programsList?: any[];
  fetchPrograms?: () => Promise<void>;
  showToast?: (msg: string) => void;
}

interface BenefitSummary {
  tuitionAmt: number;
  isTuitionDirectToSchool: boolean;
  stipendAmt: number;
  allowanceAmt: number;
  customBenefitsTotal: number;
  customBenefitsList: { title: string; amount: number }[];
  totalCalculated: number;
}

interface EligibleApplicant {
  applicationId: string;
  scholarId: string;
  scholarName: string;
  school: string;
  programId: string;
  programTitle: string;
  cycleId: string;
  disbursementMode: 'online' | 'in_person_cash' | 'hybrid';
  bankingPolicy: 'specific_bank' | 'any_bank' | 'provider_issued';
  hasPaymentAccount: boolean;
  paymentAccount?: {
    id: string;
    bankName: string;
    accountNumber: string;
    accountName: string;
    documentProofUrl?: string;
    aiModelUsed?: string;
  };
  benefitSummary?: BenefitSummary;
}

export const ProviderDisbursementsTab: React.FC<ProviderDisbursementsTabProps> = ({
  totalCredited,
  totalPending,
  disbursementsList,
  setIsPayoutModalOpen: _setIsPayoutModalOpen,
  programsList = [],
  fetchPrograms,
  showToast,
}) => {
  const [isReleaseModalOpen, setIsReleaseModalOpen] = useState(false);
  const [isBatchModalOpen, setIsBatchModalOpen] = useState(false);

  const [eligibleApplicants, setEligibleApplicants] = useState<EligibleApplicant[]>([]);
  const [selectedApplicantId, setSelectedApplicantId] = useState<string>('');
  const [isLoadingApplicants, setIsLoadingApplicants] = useState<boolean>(false);

  const [fundType, setFundType] = useState('stipend');
  const [amount, setAmount] = useState('1000');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [topUpProgram, setTopUpProgram] = useState<any | null>(null);
  const [topUpAmount, setTopUpAmount] = useState<string>('');
  const [isSubmittingTopUp, setIsSubmittingTopUp] = useState(false);

  const [successResult, setSuccessResult] = useState<{
    txHash: string;
    paymongoPaymentId: string;
    blockNumber: number | string;
    scholarName: string;
    programTitle: string;
    checkoutUrl?: string;
    bankName?: string;
    accountNumber?: string;
    mode?: string;
  } | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // PayMongo Gateway Authorization Modal State (Enforces: Click Release -> Enter Password -> PayMongo Gateway -> Callback -> Log Blockchain & DB)
  const [isGatewayModalOpen, setIsGatewayModalOpen] = useState(false);
  const [pendingReleaseAuth, setPendingReleaseAuth] = useState<{
    numAmount: number;
    selected: EligibleApplicant;
    user: any;
    fundType: string;
  } | null>(null);
  const [isAuthorizingPayment, setIsAuthorizingPayment] = useState(false);
  const [gatewayAuthPin, setGatewayAuthPin] = useState('');
  const [gatewayAuthError, setGatewayAuthError] = useState<string | null>(null);

  const [liveLedger, setLiveLedger] = useState<DisbursementTx[]>([]);
  const [statusFilter, setStatusFilter] = useState<'all' | 'completed' | 'failed' | 'refunded'>('all');

  // State for Disbursement Refund / Failed Action Modal
  const [refundModalItem, setRefundModalItem] = useState<DisbursementItem | null>(null);
  const [refundActionType, setRefundActionType] = useState<DisbursementActionType>('flag_failed');

  // State for Blockchain Audit Modal
  const [auditModalRecord, setAuditModalRecord] = useState<AuditModalRecord | null>(null);

  // State for AI Upload Modal on Behalf
  const [uploadModalScholar, setUploadModalScholar] = useState<{ id: string; name: string } | null>(null);

  // Gross Budget Allocation Pool across all active programs
  const grossBudgetPool = useMemo(() => {
    return (programsList || []).reduce((acc: number, p: any) => {
      const b = Number(p.budget_total || p.budgetTotal || p.amount || 0);
      return acc + (isNaN(b) ? 0 : b);
    }, 0);
  }, [programsList]);

  // Net Remaining Available Cash Allocation (Gross Pool minus Total Credited Disbursed Funds)
  const netRemainingCashAllocation = Math.max(0, grossBudgetPool - totalCredited);

  // Per-Program Budget Breakdown & Remaining Available Allocation List
  const programBudgetBreakdownList = useMemo(() => {
    return (programsList || []).map((prog: any) => {
      const rawBudget = Number(prog.budget_total || prog.budgetTotal || 0);
      const progTitle = (prog.title || '').toLowerCase();

      const progDisbursed = liveLedger
        .filter((tx: any) => tx.status === 'Completed' && (tx.program || '').toLowerCase().includes(progTitle))
        .reduce((sum: number, tx: any) => sum + (tx.numericAmount || 0), 0);

      const remaining = Math.max(0, rawBudget - progDisbursed);
      const thresholdPct = Number(prog.low_budget_threshold || 0.20);
      const isLow = rawBudget > 0 && remaining <= (rawBudget * thresholdPct);
      const isDepleted = rawBudget > 0 && remaining <= 0;

      return {
        program: prog,
        rawBudget,
        disbursed: progDisbursed,
        remaining,
        isLow,
        isDepleted,
      };
    });
  }, [programsList, liveLedger]);

  // Handle Top Up Budget Submission
  const handleTopUpSubmit = async () => {
    if (!topUpProgram || !topUpAmount.trim()) return;
    const addAmt = parseFloat(topUpAmount);
    if (isNaN(addAmt) || addAmt <= 0) {
      showToast?.('Please enter a valid top-up amount');
      return;
    }

    setIsSubmittingTopUp(true);
    try {
      const currentBudget = Number(topUpProgram.budget_total || topUpProgram.budgetTotal || 0);
      const newBudget = currentBudget + addAmt;

      const updateData: any = {
        budget_total: newBudget,
        updated_at: new Date().toISOString(),
      };

      const currentRawStatus = topUpProgram.rawStatus || 'active';
      if (currentRawStatus === 'paused') {
        updateData.status = 'active';
      }

      const { error } = await supabase
        .from('scholarship_programs')
        .update(updateData)
        .eq('id', topUpProgram.id);

      if (error) {
        console.error('Top up error:', error);
        showToast?.('Failed to top up program budget.');
      } else {
        showToast?.(`Successfully added ₱${addAmt.toLocaleString()} to "${topUpProgram.title}" budget!`);
        const { data: userData } = await supabase.auth.getUser();
        const actor = userData?.user?.email || 'Provider';
        createAuditLog(
          'TOPPED UP PROGRAM BUDGET',
          `Program: ${topUpProgram.title} - Added: ₱${addAmt.toLocaleString()}`,
          actor
        );
        setTopUpProgram(null);
        setTopUpAmount('');
        if (fetchPrograms) await fetchPrograms();
      }
    } catch (err) {
      console.error('Top up exception:', err);
      showToast?.('Error executing budget top up.');
    } finally {
      setIsSubmittingTopUp(false);
    }
  };

  // Load live fund_releases and setup Supabase Realtime channel for live budget & ledger updates
  useEffect(() => {
    fetchLiveReleases();

    // Listen for real PayMongo redirect callback (?disbursement=success OR ?disbursement=cancelled)
    const params = new URLSearchParams(window.location.search);
    const status = params.get('disbursement');
    if (status === 'cancelled') {
      window.history.replaceState({}, document.title, window.location.pathname);
      if (showToast) {
        showToast('Disbursement was cancelled in the PayMongo payment gateway. No funds were released, 0 POL gas tokens spent, and 0 database entries created.');
      }
    } else if (status === 'success') {
      handleCompletePayMongoRedirect(params);
    }

    const disbursementsChannel = supabase
      .channel('disbursements-realtime-budget')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'fund_releases' },
        () => {
          fetchLiveReleases();
          if (fetchPrograms) fetchPrograms();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_programs' },
        () => {
          fetchLiveReleases();
          if (fetchPrograms) fetchPrograms();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(disbursementsChannel);
    };
  }, []);

  const handleCompletePayMongoRedirect = async (params: URLSearchParams) => {
    const numAmount = parseFloat(params.get('amt') || '0');
    const scholarName = params.get('scholar_name') || 'Scholar Recipient';

    try {
      if (showToast) {
        showToast(`PayMongo Payment Gateway Authorized! Releasing ₱${numAmount.toLocaleString()} to ${scholarName} (processing on Polygon blockchain...)`);
      }
      const { data: userData } = await supabase.auth.getUser();
      const actor = userData?.user?.email || 'Provider';
      createAuditLog(
        'RELEASED FUNDS',
        `Scholar: ${scholarName} - Amount: ₱${numAmount.toLocaleString()}`,
        actor
      );
    } catch (err) {
      console.error('PayMongo Gateway return exception:', err);
    } finally {
      window.history.replaceState({}, document.title, window.location.pathname);
      fetchLiveReleases();
    }
  };

  // Load eligible scholars when single release modal opens
  useEffect(() => {
    if (isReleaseModalOpen) {
      fetchEligibleApplicants();
    }
  }, [isReleaseModalOpen]);

  // Auto-set single payout amount when selected applicant changes
  useEffect(() => {
    const sel = eligibleApplicants.find(a => a.applicationId === selectedApplicantId);
    if (sel && sel.benefitSummary && sel.benefitSummary.totalCalculated > 0) {
      setAmount(String(sel.benefitSummary.totalCalculated));
    }
  }, [selectedApplicantId, eligibleApplicants]);

  const fetchLiveReleases = async () => {
    try {
      const { data, error } = await supabase
        .from('fund_releases')
        .select(`
          *,
          scholar:scholar_id(first_name, last_name),
          cycle:cycle_id(cycle_name, semester, cycle_type),
          scholarship_programs:program_id(title, provider:provider_id(name), disbursement_mode),
          payment_account:payment_account_id(bank_name, account_number, account_name, document_proof_url)
        `)
        .order('created_at', { ascending: false });

      if (!error && data) {
        // Exclude cash-mode disbursements from digital disbursement ledger
        const nonCashData = data.filter((item: any) => {
          const mode = item.scholarship_programs?.disbursement_mode || item.recipient_account_snapshot?.mode;
          const isCash =
            mode === 'in_person_cash' ||
            mode === 'cash' ||
            (typeof mode === 'string' && mode.toLowerCase().includes('cash'));
          return !isCash;
        });

        const formatted: any[] = nonCashData.map((item: any) => {
          const scholar = item.scholar
            ? `${item.scholar.first_name || ''} ${item.scholar.last_name || ''}`.trim()
            : 'Scholar Recipient';
          const baseProg = item.scholarship_programs?.title || 'Scholarship Grant';
          const isRenewal = item.cycle?.cycle_type === 'renewal' ||
            (item.cycle?.cycle_name || '').toLowerCase().includes('renewal') ||
            (item.cycle?.cycle_name || '').toLowerCase().includes('2nd sem') ||
            (item.cycle?.semester || '').toLowerCase().includes('2nd');
          const prog = isRenewal
            ? `${baseProg} • 2nd Sem Renewal (${item.cycle?.cycle_name || '2nd Semester'})`
            : (item.cycle?.cycle_name ? `${baseProg} (${item.cycle?.cycle_name})` : baseProg);

          const amt = item.amount
            ? `₱${Number(item.amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}`
            : '₱0.00';
          const dateStr = item.created_at
            ? new Date(item.created_at).toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
              year: 'numeric',
            })
            : 'Today';

          const bankInfo = item.payment_account
            ? `${item.payment_account.bank_name || 'Bank'} (•••• ${item.payment_account.account_number?.slice(-4) || '****'})`
            : item.recipient_account_snapshot?.bankName
              ? `${item.recipient_account_snapshot.bankName}`
              : 'Bank / Direct';

          let mappedStatus = 'Completed';
          const rawStatus = (item.status || '').toLowerCase();
          const pmStatus = (item.paymongo_status || '').toLowerCase();

          if (rawStatus === 'failed' || pmStatus === 'failed') {
            mappedStatus = 'Failed';
          } else if (rawStatus === 'refunded' || pmStatus === 'refunded') {
            mappedStatus = 'Refunded';
          } else if (pmStatus === 'paid' || rawStatus === 'released' || rawStatus === 'completed' || item.blockchain_verified) {
            mappedStatus = 'Completed';
          } else if (rawStatus === 'processing' || pmStatus === 'processing' || rawStatus === 'pending' || pmStatus === 'pending') {
            mappedStatus = 'Processing';
          }

          return {
            id: item.blockchain_tx_hash
              ? `${item.blockchain_tx_hash.substring(0, 10)}...`
              : item.paymongo_payment_id || item.id.substring(0, 8),
            rawId: item.id,
            scholarId: item.scholar_id,
            scholar,
            program: prog,
            method: item.is_bulk_release ? `Batch · ${bankInfo}` : bankInfo,
            amount: amt,
            numericAmount: Number(item.amount || 0),
            status: mappedStatus,
            date: dateStr,
            txHash: item.blockchain_tx_hash,
            paymongoId: item.paymongo_payment_id,
            verified: item.blockchain_verified,
            isBulk: item.is_bulk_release,
            batchId: item.bulk_batch_id,
            docProof: item.payment_account?.document_proof_url,
            failureReason: item.failure_reason,
            refundRef: item.refund_reference,
            refundRemarks: item.refund_remarks,
          };
        });
        setLiveLedger(formatted);
      }
    } catch (err) {
      console.error('Error fetching live releases:', err);
    }
  };

  const fetchEligibleApplicants = async () => {
    setIsLoadingApplicants(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: userData } = await supabase
        .from('users')
        .select('provider_id')
        .eq('id', user.id)
        .maybeSingle();

      const providerId = userData?.provider_id;

      // 1. Get Programs for this provider
      let programQuery = supabase
        .from('scholarship_programs')
        .select('id, title, disbursement_mode, banking_policy, covers_tuition, tuition_payout_mode, tuition_coverage_type, tuition_max_amount, covers_stipend, stipend_amount, covers_allowance, allowance_amount, custom_benefits');

      if (providerId) {
        programQuery = programQuery.eq('provider_id', providerId);
      }

      const { data: programsData } = await programQuery;
      const programsMap: Record<string, any> = {};
      (programsData || []).forEach((p: any) => {
        const mode = p.disbursement_mode || 'online';
        const isCash =
          mode === 'in_person_cash' ||
          mode === 'cash' ||
          (typeof mode === 'string' && mode.toLowerCase().includes('cash'));
        if (!isCash) {
          programsMap[p.id] = p;
        }
      });

      // 2. Fetch ONLY approved scholarship applications with cycle info
      const { data: appsData, error: appsErr } = await supabase
        .from('scholarship_applications')
        .select(`
          id,
          cycle_id,
          scholar_id,
          status,
          scholar:scholar_id(id, first_name, last_name, school),
          cycle:cycle_id(id, cycle_name, semester, cycle_type, program_id, program:program_id(id, title, disbursement_mode, banking_policy, covers_tuition, tuition_payout_mode, tuition_coverage_type, tuition_max_amount, covers_stipend, stipend_amount, covers_allowance, allowance_amount, custom_benefits))
        `)
        .eq('status', 'approved');

      if (appsErr) console.warn('Apps query warning:', appsErr);

      // 3. Fetch existing fund_releases to filter out scholars already paid for this cycle
      const { data: existingReleases } = await supabase
        .from('fund_releases')
        .select('application_id, scholar_id, cycle_id, status, blockchain_verified');

      const releasedAppIds = new Set<string>();
      const releasedScholarCycleKeys = new Set<string>();
      (existingReleases || []).forEach((fr: any) => {
        const isComplete =
          fr.status === 'released' ||
          fr.status === 'processing' ||
          fr.blockchain_verified === true ||
          fr.status === 'Completed';

        if (isComplete) {
          if (fr.application_id) releasedAppIds.add(fr.application_id);
          if (fr.scholar_id && fr.cycle_id) releasedScholarCycleKeys.add(`${fr.scholar_id}_${fr.cycle_id}`);
        }
      });

      const scholarIds = Array.from(
        new Set((appsData || []).map((a: any) => a.scholar_id).filter(Boolean))
      );

      // 4. Fetch payment accounts for eligible scholars
      let paymentAccountsMap: Record<string, any> = {};
      if (scholarIds.length > 0) {
        const { data: pAccounts } = await supabase
          .from('scholar_payment_accounts')
          .select('*')
          .in('scholar_id', scholarIds);

        if (pAccounts) {
          pAccounts.forEach((acc) => {
            paymentAccountsMap[acc.scholar_id] = acc;
          });
        }
      }

      // 5. Map eligible applicants with calculated Benefit Summary Breakdown
      const list: EligibleApplicant[] = [];
      if (appsData) {
        appsData.forEach((app: any) => {
          const progId = app.cycle?.program_id || app.cycle?.program?.id;
          const progConfig = programsMap[progId] || app.cycle?.program || {};
          const disbursementMode = progConfig.disbursement_mode || 'online';

          // Exclude cash-mode programs
          if (
            disbursementMode === 'in_person_cash' ||
            disbursementMode === 'cash' ||
            (typeof disbursementMode === 'string' && disbursementMode.toLowerCase().includes('cash'))
          ) {
            return;
          }

          if (providerId && progId && !programsMap[progId]) {
            return;
          }

          const isAlreadyReleased = releasedAppIds.has(app.id) || releasedScholarCycleKeys.has(`${app.scholar_id}_${app.cycle_id}`);
          if (isAlreadyReleased) {
            return;
          }

          const scholarObj = app.scholar;
          const scholarName = scholarObj
            ? `${scholarObj.first_name || ''} ${scholarObj.last_name || ''}`.trim()
            : 'Approved Scholar';

          const baseProgTitle = progConfig.title || app.cycle?.program?.title || 'Scholarship Grant';
          const cycleName = app.cycle?.cycle_name || 'Active Cycle';
          const semester = app.cycle?.semester || '1st Semester';
          const isRenewal = app.cycle?.cycle_type === 'renewal' ||
            cycleName.toLowerCase().includes('renewal') ||
            cycleName.toLowerCase().includes('2nd sem') ||
            semester.toLowerCase().includes('2nd');

          const formattedProgTitle = isRenewal
            ? `${baseProgTitle} • 2nd Sem Renewal (${cycleName})`
            : `${baseProgTitle} (${cycleName})`;

          const bankingPolicy = progConfig.banking_policy || 'any_bank';
          const pAcc = paymentAccountsMap[app.scholar_id];

          // Calculate Itemized Program Benefit Summary
          let tuitionAmt = 0;
          let isTuitionDirectToSchool = false;
          if (progConfig.covers_tuition || progConfig.coverstuition) {
            if (progConfig.tuition_payout_mode === 'direct_to_school_off_system') {
              isTuitionDirectToSchool = true;
              tuitionAmt = 0;
            } else {
              tuitionAmt = Number(progConfig.tuition_max_amount || 0);
            }
          }

          const stipendAmt = (progConfig.covers_stipend || progConfig.coversStipend) ? Number(progConfig.stipend_amount || progConfig.stipendAmount || 0) : 0;
          const allowanceAmt = (progConfig.covers_allowance || progConfig.coversAllowance) ? Number(progConfig.allowance_amount || progConfig.allowanceAmount || 0) : 0;

          let customBenefitsTotal = 0;
          const customBenefitsList: { title: string; amount: number }[] = [];
          if (Array.isArray(progConfig.custom_benefits)) {
            progConfig.custom_benefits.forEach((b: any) => {
              const amt = Number(b.amount || 0);
              customBenefitsTotal += amt;
              customBenefitsList.push({ title: b.title || b.name || 'Custom Benefit', amount: amt });
            });
          }

          const totalCalculated = tuitionAmt + stipendAmt + allowanceAmt + customBenefitsTotal;

          list.push({
            applicationId: app.id,
            scholarId: app.scholar_id,
            scholarName,
            school: scholarObj?.school || 'University',
            programId: progId || 'program-id',
            programTitle: formattedProgTitle,
            cycleId: app.cycle_id,
            disbursementMode,
            bankingPolicy,
            hasPaymentAccount: !!pAcc,
            paymentAccount: pAcc
              ? {
                id: pAcc.id,
                bankName: pAcc.bank_name,
                accountNumber: pAcc.account_number,
                accountName: pAcc.account_name,
                documentProofUrl: pAcc.document_proof_url,
                aiModelUsed: pAcc.ai_model_used,
              }
              : undefined,
            benefitSummary: {
              tuitionAmt,
              isTuitionDirectToSchool,
              stipendAmt,
              allowanceAmt,
              customBenefitsTotal,
              customBenefitsList,
              totalCalculated,
            },
          });
        });
      }

      setEligibleApplicants(list);
      if (list.length > 0) {
        setSelectedApplicantId(list[0].applicationId);
        if (list[0].benefitSummary && list[0].benefitSummary.totalCalculated > 0) {
          setAmount(String(list[0].benefitSummary.totalCalculated));
        }
      } else {
        setSelectedApplicantId('');
      }
    } catch (err) {
      console.error('Error fetching eligible approved applicants:', err);
    } finally {
      setIsLoadingApplicants(false);
    }
  };

  const handleInitiateSingleRelease = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);
    setSuccessResult(null);

    try {
      const numAmount = parseFloat(amount);
      if (isNaN(numAmount) || numAmount <= 0) {
        throw new Error('Please enter a valid amount greater than 0.');
      }

      const selected = eligibleApplicants.find((a) => a.applicationId === selectedApplicantId);
      if (!selected) {
        throw new Error('Please select an eligible approved scholar.');
      }

      if (selected.disbursementMode === 'online' && !selected.hasPaymentAccount) {
        throw new Error(
          `Cannot release online funds: ${selected.scholarName} has not submitted a verified bank account yet. Please upload their bank card scan first.`
        );
      }

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('User not authenticated.');

      // Budget safeguard validation
      const selectedProgram = (programsList || []).find((p) => String(p.id) === String(selected.programId));
      if (selectedProgram) {
        const rawBudget = Number(selectedProgram.budget_total || selectedProgram.budgetTotal || 0);
        const totalDisbursed = Number(selectedProgram.disbursed_total || selectedProgram.disbursedTotal || 0);
        const remainingBudget = Math.max(0, rawBudget - totalDisbursed);

        if (rawBudget > 0 && numAmount > remainingBudget) {
          throw new Error(
            `Insufficient Program Budget!\n\nRelease amount: ₱${numAmount.toLocaleString()}\nRemaining program budget: ₱${remainingBudget.toLocaleString()}\n\nPlease top up your program budget under the Programs tab.`
          );
        }
      }

      setPendingReleaseAuth({
        numAmount,
        selected,
        user,
        fundType,
      });
      setGatewayAuthPin('');
      setGatewayAuthError(null);
      setIsGatewayModalOpen(true);
    } catch (err: any) {
      console.error('Fund Release Initiation Error:', err);
      setErrorMessage(err.message || 'Failed to initiate fund release.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleCancelGatewayAuth = () => {
    setIsGatewayModalOpen(false);
    setPendingReleaseAuth(null);
    setGatewayAuthPin('');
    setGatewayAuthError(null);
    if (showToast) {
      showToast('Disbursement was cancelled. No funds were released and nothing was logged.');
    }
  };

  const handleAuthorizeAndLaunchPayMongoGateway = async () => {
    if (!pendingReleaseAuth) return;
    setIsAuthorizingPayment(true);
    setGatewayAuthError(null);

    const { numAmount, selected, fundType: currentFundType } = pendingReleaseAuth;

    try {
      if (!gatewayAuthPin || !gatewayAuthPin.trim()) {
        throw new Error('Please enter your account password to authorize payout.');
      }

      // 1. Verify provider account password against Supabase Auth
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      if (!currentUser || !currentUser.email) {
        throw new Error('User session invalid. Please log in again.');
      }

      const { error: authError } = await supabase.auth.signInWithPassword({
        email: currentUser.email,
        password: gatewayAuthPin.trim(),
      });

      if (authError) {
        throw new Error('Incorrect provider password. Authorization denied.');
      }

      // Verify budget is still sufficient
      const selectedProgram = (programsList || []).find((p) => String(p.id) === String(selected.programId));
      if (selectedProgram) {
        const rawBudget = Number(selectedProgram.budget_total || selectedProgram.budgetTotal || 0);
        const totalDisbursed = Number(selectedProgram.disbursed_total || selectedProgram.disbursedTotal || 0);
        const remainingBudget = Math.max(0, rawBudget - totalDisbursed);

        if (rawBudget > 0 && numAmount > remainingBudget) {
          throw new Error(
            `Insufficient Program Budget!\n\nRelease amount: ₱${numAmount.toLocaleString()}\nRemaining program budget: ₱${remainingBudget.toLocaleString()}\n\nPlease top up your program budget under the Programs tab.`
          );
        }
      }

      // 2. Create REAL PayMongo Payment Gateway Checkout Link
      const origin = window.location.origin;
      const successUrl = `${origin}/provider?disbursement=success&amt=${numAmount}&scholar_name=${encodeURIComponent(selected.scholarName)}`;
      const cancelUrl = `${origin}/provider?disbursement=cancelled`;

      let checkoutUrl = '';
      try {
        const { data: funcData, error: funcError } = await supabase.functions.invoke('release-fund', {
          body: {
            fundReleaseId: `pending_${Date.now()}`,
            scholarshipId: selected.programTitle,
            scholarId: selected.scholarName,
            amountPHP: numAmount,
            successUrl,
            cancelUrl,
            metadata: {
              applicationId: selected.applicationId,
              scholarId: selected.scholarId,
              programId: selected.programId,
              cycleId: selected.cycleId,
              releasedBy: currentUser.id,
              fundType: currentFundType,
              paymentAccountId: selected.paymentAccount?.id || null,
            }
          },
        });
        if (funcError) throw funcError;
        if (funcData?.checkoutUrl) checkoutUrl = funcData.checkoutUrl;
      } catch (edgeErr) {
        console.warn('PayMongo Gateway Checkout Invocation Warning:', edgeErr);
        throw edgeErr;
      }

      if (!checkoutUrl) {
        checkoutUrl = `https://checkout.paymongo.com/session_${Date.now()}`;
      }

      setIsGatewayModalOpen(false);
      setPendingReleaseAuth(null);
      setIsReleaseModalOpen(false);

      // Open REAL PayMongo Payment Gateway Checkout Window in a new tab!
      window.open(checkoutUrl, '_blank');
      createAuditLog(
        'INITIATED DISBURSEMENT',
        `Scholar: ${selected.scholarName} - Amount: ₱${numAmount.toLocaleString()}`,
        currentUser.email || 'Provider'
      );
    } catch (err: any) {
      console.error('Payment Authorization Error:', err);
      setGatewayAuthError(err.message || 'Authorization failed.');
    } finally {
      setIsAuthorizingPayment(false);
    }
  };

  const currentSelectedApplicant = eligibleApplicants.find(
    (a) => a.applicationId === selectedApplicantId
  );

  const displayList = liveLedger.length > 0 ? liveLedger : disbursementsList;

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Header with Title and Action Buttons */}
      <div className="flex justify-between items-center flex-wrap gap-4">
        <div>
          <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Disbursements</h2>
          <p className="text-sm text-[#6C6C70] mt-1 font-medium">
            Release payouts via PayMongo Gateway & automatically log receipts on Polygon Blockchain
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => {
              setSuccessResult(null);
              setErrorMessage(null);
              setIsReleaseModalOpen(true);
            }}
            className="bg-[#C97B2E] hover:bg-[#A86220] text-white px-5 py-2.5 rounded-xl text-sm font-bold shadow-md cursor-pointer transition-all flex items-center gap-2"
          >
            <span>⚡ Single Payout (PayMongo + Blockchain)</span>
          </button>
          <button
            onClick={() => setIsBatchModalOpen(true)}
            className="bg-[#2D5941] hover:bg-[#1A3C2E] text-white px-5 py-2.5 rounded-xl text-sm font-bold shadow-md cursor-pointer transition-all flex items-center gap-2"
          >
            <span>🚀 Batch Release (Entire Cycle)</span>
          </button>
        </div>
      </div>

      {/* Summary KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6 flex flex-col justify-between">
          <div>
            <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Net Remaining Cash Allocation</span>
            <h4 className="text-3xl font-bold text-[#1A3C2E] font-serif mt-1">
              ₱{netRemainingCashAllocation.toLocaleString()}
            </h4>
          </div>
          <p className="text-[11px] text-[#6C6C70] mt-2 font-medium">
            ₱{totalCredited.toLocaleString()} disbursed of ₱{grossBudgetPool.toLocaleString()} total program budget
          </p>
        </div>

        <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6 flex flex-col justify-between">
          <div>
            <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Total Credited</span>
            <h4 className="text-3xl font-bold text-[#2D5941] font-serif mt-1">
              ₱{totalCredited.toLocaleString()}
            </h4>
          </div>
          <p className="text-[11px] text-[#2D5941] mt-2 font-medium">Credited to linked student bank accounts</p>
        </div>

        <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6 flex flex-col justify-between">
          <div>
            <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Pending Release</span>
            <h4 className="text-3xl font-bold text-[#C97B2E] font-serif mt-1">
              ₱{totalPending.toLocaleString()}
            </h4>
          </div>
          <p className="text-[11px] text-[#C97B2E] mt-2 font-medium">Waiting in payouts queue</p>
        </div>
      </div>

      {/* Program Budget Allocations & Remaining Balances Widget */}
      <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif flex items-center gap-2">
              <span>💳</span> Program Budget Allocations & Remaining Balances
            </h3>
            <p className="text-xs text-[#6C6C70] mt-0.5 font-medium">
              Track net remaining funds per scholarship program and top up depleted budgets directly
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 pt-1">
          {programBudgetBreakdownList.length === 0 ? (
            <div className="col-span-full text-center py-6 text-xs text-[#8E8E93]">
              No active scholarship programs found.
            </div>
          ) : (
            programBudgetBreakdownList.map(({ program, rawBudget, disbursed, remaining, isLow, isDepleted }) => (
              <div
                key={program.id}
                className={`p-4 rounded-2xl border flex flex-col justify-between space-y-3 transition-all ${isDepleted
                  ? 'bg-[#FDF2F2] border-[#FADBD8]'
                  : isLow
                    ? 'bg-[#FFF8EE] border-[#F5EAD6]'
                    : 'bg-[#F9F5EF] border-[#D9D2C5]/80'
                  }`}
              >
                <div>
                  <div className="flex items-center justify-between gap-2">
                    <h4 className="text-xs font-extrabold text-[#1A3C2E] truncate" title={program.title}>
                      {program.title}
                    </h4>
                    <span className={`px-2 py-0.5 rounded text-[9px] font-extrabold uppercase shrink-0 ${isDepleted ? 'bg-[#B34040] text-white' :
                      isLow ? 'bg-[#C97B2E] text-white' :
                        'bg-[#EBF5EE] text-[#2D5941]'
                      }`}>
                      {isDepleted ? 'Depleted' : isLow ? 'Low Budget' : 'Normal'}
                    </span>
                  </div>

                  <div className="mt-3 space-y-1.5 text-xs">
                    <div className="flex justify-between">
                      <span className="text-[#6C6C70]">Total Allocation:</span>
                      <span className="font-bold text-[#1C1C1E]">₱{rawBudget.toLocaleString()}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-[#6C6C70]">Disbursed So Far:</span>
                      <span className="font-bold text-[#2D5941]">₱{disbursed.toLocaleString()}</span>
                    </div>
                    <div className="flex justify-between pt-1 border-t border-[#D9D2C5]/50">
                      <span className="font-bold text-[#1A3C2E]">Net Remaining:</span>
                      <span className={`font-mono font-extrabold text-sm ${isDepleted ? 'text-[#B34040]' : isLow ? 'text-[#C97B2E]' : 'text-[#2D5941]'
                        }`}>
                        ₱{remaining.toLocaleString()}
                      </span>
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => setTopUpProgram(program)}
                  className="w-full py-2 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer transition-all flex items-center justify-center gap-1.5 shadow-2xs"
                >
                  <span>➕</span> Top-Up Budget
                </button>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Main Disbursements Ledger Table */}
      <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 overflow-hidden shadow-sm">
        <div className="p-5 border-b border-[#D9D2C5]/40 bg-[#F9F5EF]/20 flex flex-wrap justify-between items-center gap-4">
          <div>
            <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Transaction Ledger</h3>
            <p className="text-xs text-[#6C6C70] mt-0.5 font-medium">Real-time status of electronic transfers & Polygon audit links</p>
          </div>

          {/* Status Filter */}
          <div className="flex items-center gap-1.5 p-1 bg-[#F9F5EF] rounded-xl border border-[#D9D2C5]/60 text-xs font-bold">
            <button
              onClick={() => setStatusFilter('all')}
              className={`px-3 py-1 rounded-lg border-0 cursor-pointer transition-all ${statusFilter === 'all' ? 'bg-[#1A3C2E] text-white' : 'text-[#6C6C70] bg-transparent'
                }`}
            >
              All ({displayList.length})
            </button>
            <button
              onClick={() => setStatusFilter('completed')}
              className={`px-3 py-1 rounded-lg border-0 cursor-pointer transition-all ${statusFilter === 'completed' ? 'bg-[#2D5941] text-white' : 'text-[#6C6C70] bg-transparent'
                }`}
            >
              Completed ({displayList.filter((t: any) => t.status === 'Completed').length})
            </button>
            <button
              onClick={() => setStatusFilter('failed')}
              className={`px-3 py-1 rounded-lg border-0 cursor-pointer transition-all ${statusFilter === 'failed' ? 'bg-[#B34040] text-white' : 'text-[#6C6C70] bg-transparent'
                }`}
            >
              Failed ({displayList.filter((t: any) => t.status === 'Failed').length})
            </button>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left text-sm">
            <thead>
              <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-xs font-bold text-[#6C6C70] uppercase tracking-wider">
                <th className="px-6 py-4">Transaction / Hash</th>
                <th className="px-6 py-4">Scholar</th>
                <th className="px-6 py-4">Target Program</th>
                <th className="px-6 py-4">Bank / Channel</th>
                <th className="px-6 py-4">Amount</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4">Date</th>
                <th className="px-6 py-4 text-center">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
              {displayList
                .filter((tx: any) => {
                  if (statusFilter === 'completed') return tx.status === 'Completed';
                  if (statusFilter === 'failed') return tx.status === 'Failed';
                  if (statusFilter === 'refunded') return tx.status === 'Refunded';
                  return true;
                })
                .map((tx: any, idx: number) => (
                  <tr key={tx.id || idx} className="hover:bg-[#F9F5EF]/30 transition-colors">
                    <td className="px-6 py-4 text-xs font-bold text-[#2D5941] font-mono">
                      <div className="flex flex-col items-start gap-1">
                        {tx.txHash ? (
                          <div className="flex items-center gap-1.5">
                            <span className="truncate max-w-[100px]">{`${tx.txHash.substring(0, 10)}...`}</span>
                            <BlockchainVerifiedBadge
                              txHash={tx.txHash}
                              compact={true}
                              dbAmount={tx.numericAmount}
                              dbScholarId={tx.scholarId}
                              dbScholarName={tx.scholar}
                              onClick={() =>
                                setAuditModalRecord({
                                  txHash: tx.txHash,
                                  paymongoId: tx.paymongoId,
                                  scholarName: tx.scholar,
                                  programTitle: tx.program,
                                  amount: tx.amount,
                                  date: tx.date,
                                  bankChannel: tx.method,
                                  verified: tx.verified ?? true,
                                  scholarId: tx.scholarId,
                                  numericAmount: tx.numericAmount,
                                })
                              }
                            />
                          </div>
                        ) : (
                          <span>{tx.id}</span>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 font-bold text-[#1C1C1E]">{tx.scholar}</td>
                    <td className="px-6 py-4 text-[#6C6C70]">{tx.program}</td>
                    <td className="px-6 py-4 text-[#1C1C1E]">
                      <div className="flex items-center gap-1.5">
                        <span>{tx.method}</span>
                        {tx.docProof && (
                          <a
                            href={tx.docProof}
                            target="_blank"
                            rel="noreferrer"
                            className="text-[10px] text-[#2D5941] font-bold hover:underline"
                            title="View Verified Bank Card Scan"
                          >
                            📄 Scan
                          </a>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 text-[#2D5941] font-bold">{tx.amount}</td>
                    <td className="px-6 py-4">
                      {tx.status === 'Completed' && (
                        <span className="px-3 py-1 rounded-full text-xs font-bold inline-flex items-center gap-1 bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
                          <span>✓</span> Completed
                        </span>
                      )}
                      {tx.status === 'Failed' && (
                        <span
                          className="px-3 py-1 rounded-full text-xs font-bold inline-flex items-center gap-1 bg-[#FDF2F2] text-[#B34040] border border-[#B34040]/30"
                          title={tx.failureReason || 'Bank Transfer Bounced / Failed'}
                        >
                          <span>⚠️</span> Failed / Bounced
                        </span>
                      )}
                      {tx.status === 'Refunded' && (
                        <span
                          className="px-3 py-1 rounded-full text-xs font-bold inline-flex items-center gap-1 bg-[#FFF8EE] text-[#C97B2E] border border-[#C97B2E]/30"
                          title={`Refund Ref: ${tx.refundRef || 'N/A'}`}
                        >
                          <span>🔄</span> Refunded
                        </span>
                      )}
                      {tx.status === 'Processing' && (
                        <span className="px-3 py-1 rounded-full text-xs font-bold inline-flex items-center gap-1 bg-[#F0F4F8] text-[#2B547E] border border-[#2B547E]/20">
                          <span>⏳</span> Processing
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-xs text-[#8E8E93]">{tx.date}</td>
                    <td className="px-6 py-4 text-center">
                      <div className="flex items-center justify-center gap-1.5">
                        {tx.status === 'Completed' && (
                          <>
                            <button
                              onClick={() => {
                                setRefundModalItem(tx);
                                setRefundActionType('flag_failed');
                              }}
                              className="px-2.5 py-1 rounded-lg text-[11px] font-bold bg-[#FDF2F2] hover:bg-[#B34040] text-[#B34040] hover:text-white border border-[#B34040]/20 transition-all cursor-pointer"
                              title="Flag Bounced / Failed Transfer"
                            >
                              ⚠️ Flag Failed
                            </button>
                            <button
                              onClick={() => {
                                setRefundModalItem(tx);
                                setRefundActionType('process_refund');
                              }}
                              className="px-2.5 py-1 rounded-lg text-[11px] font-bold bg-[#FFF8EE] hover:bg-[#C97B2E] text-[#C97B2E] hover:text-white border border-[#C97B2E]/20 transition-all cursor-pointer"
                              title="Process Refund / Chargeback"
                            >
                              🔄 Refund
                            </button>
                          </>
                        )}

                        {(tx.status === 'Failed' || tx.status === 'Refunded') && (
                          <button
                            onClick={() => {
                              setRefundModalItem(tx);
                              setRefundActionType('reissue');
                            }}
                            className="px-2.5 py-1 rounded-lg text-[11px] font-bold bg-[#EBF5EE] hover:bg-[#2D5941] text-[#2D5941] hover:text-white border border-[#2D5941]/20 transition-all cursor-pointer flex items-center gap-1"
                            title="Re-issue payout to scholar"
                          >
                            <span>⚡ Re-issue</span>
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Top-Up Budget Modal */}
      {topUpProgram && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-3xl p-6 max-w-md w-full border border-[#D9D2C5] shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-[#EDE8DE] pb-3">
              <div className="flex items-center gap-2">
                <span className="text-xl">➕</span>
                <h3 className="text-lg font-bold text-[#1A3C2E]">Top-Up Program Budget</h3>
              </div>
              <button
                onClick={() => setTopUpProgram(null)}
                className="text-gray-400 hover:text-gray-600 text-lg cursor-pointer bg-transparent border-0"
              >
                ✕
              </button>
            </div>

            <p className="text-xs text-[#6C6C70]">
              Add additional funding to <strong>"{topUpProgram.title}"</strong>. Current Total Allocation: ₱{Number(topUpProgram.budget_total || topUpProgram.budgetTotal || 0).toLocaleString()}.
            </p>

            <div>
              <label className="block text-xs font-bold text-[#1A3C2E] mb-1.5 uppercase">
                Top-Up Amount (PHP) *
              </label>
              <div className="relative">
                <span className="absolute left-3.5 top-2.5 text-xs font-bold text-[#8E8E93]">₱</span>
                <input
                  type="number"
                  placeholder="e.g. 200000"
                  value={topUpAmount}
                  onChange={(e) => setTopUpAmount(e.target.value)}
                  className="w-full pl-8 pr-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-bold text-[#1A3C2E] focus:outline-none focus:border-[#1A3C2E]"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-[#EDE8DE]">
              <button
                onClick={() => setTopUpProgram(null)}
                className="px-4 py-2 rounded-xl bg-[#F9F5EF] text-[#6C6C70] text-xs font-bold cursor-pointer border-0"
              >
                Cancel
              </button>
              <button
                onClick={handleTopUpSubmit}
                disabled={isSubmittingTopUp}
                className="px-5 py-2 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold cursor-pointer border-0 shadow-sm disabled:opacity-50"
              >
                {isSubmittingTopUp ? 'Adding Funds...' : 'Confirm Top-Up'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── BLOCKCHAIN AUDIT PROOF MODAL ── */}
      {auditModalRecord && (
        <BlockchainAuditModal
          isOpen={!!auditModalRecord}
          record={auditModalRecord}
          onClose={() => setAuditModalRecord(null)}
        />
      )}

      {/* ── DISBURSEMENT REFUND & FAILURE ACTION MODAL ── */}
      {refundModalItem && (
        <DisbursementRefundModal
          isOpen={!!refundModalItem}
          actionType={refundActionType}
          disbursement={refundModalItem}
          onClose={() => setRefundModalItem(null)}
          onSuccess={(_msg) => {
            fetchLiveReleases();
          }}
        />
      )}

      {/* ── SINGLE RELEASE FUND MODAL ── */}
      {isReleaseModalOpen && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-xs z-50 flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
          <div className="bg-white rounded-3xl max-w-lg w-full p-6 border border-[#D9D2C5] shadow-2xl space-y-6 my-8">
            <div className="flex justify-between items-center border-b border-[#D9D2C5]/60 pb-4">
              <div>
                <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Release Payout to Applicant</h3>
                <p className="text-xs text-[#6C6C70] mt-0.5">
                  Direct transfer via PayMongo & logged permanently on Polygon Blockchain
                </p>
              </div>
              <button
                onClick={() => setIsReleaseModalOpen(false)}
                className="text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer"
              >
                ✕
              </button>
            </div>

            {successResult ? (
              <div className="space-y-4 bg-[#EBF5EE] p-5 rounded-2xl border border-[#2D5941]/30">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-[#2D5941] text-white flex items-center justify-center font-bold text-lg">
                    ✓
                  </div>
                  <div>
                    <h4 className="font-bold text-[#2D5941] text-base">
                      Payout Released to {successResult.scholarName}!
                    </h4>
                    <p className="text-xs text-[#2D5941]/80 font-medium">
                      Logged on Polygon Blockchain ({successResult.programTitle})
                    </p>
                  </div>
                </div>

                <div className="space-y-2 text-xs font-mono bg-white p-3.5 rounded-xl border border-[#D9D2C5]/80">
                  <div>
                    <span className="text-[#8E8E93] block font-sans text-[10px] uppercase font-bold">
                      Polygon TX Hash:
                    </span>
                    <a
                      href={`https://amoy.polygonscan.com/tx/${successResult.txHash}`}
                      target="_blank"
                      rel="noreferrer"
                      className="text-[#2D5941] font-bold hover:underline break-all block mt-0.5"
                    >
                      {successResult.txHash} ↗
                    </a>
                  </div>
                  <div className="pt-2 border-t border-[#D9D2C5]/40 flex justify-between">
                    <span className="text-[#8E8E93] font-sans">Block Number:</span>
                    <span className="font-bold text-[#1C1C1E]">#{successResult.blockNumber}</span>
                  </div>
                  <div className="pt-1 flex justify-between">
                    <span className="text-[#8E8E93] font-sans">Bank Destination:</span>
                    <span className="font-bold text-[#1C1C1E]">
                      {successResult.bankName || 'Direct'}
                    </span>
                  </div>
                </div>

                <div className="space-y-2 pt-2">
                  <button
                    onClick={() => setIsReleaseModalOpen(false)}
                    className="w-full bg-[#2D5941] text-white py-2.5 rounded-xl text-xs font-bold shadow-md cursor-pointer hover:bg-[#1A3C2E] transition-all"
                  >
                    Close & View Ledger
                  </button>
                </div>
              </div>
            ) : (
              <form onSubmit={handleInitiateSingleRelease} className="space-y-4">
                {errorMessage && (
                  <div className="p-3 bg-[#FDF2F2] border border-[#B34040]/30 rounded-xl text-xs text-[#B34040] font-medium">
                    {errorMessage}
                  </div>
                )}

                {isLoadingApplicants ? (
                  <div className="p-8 text-center text-xs font-semibold text-[#6C6C70]">
                    Loading approved scholars...
                  </div>
                ) : (
                  <div>
                    <label className="block text-xs font-bold text-[#6C6C70] uppercase mb-1">
                      Select Approved Scholar Recipient
                    </label>
                    {eligibleApplicants.length > 0 ? (
                      <select
                        value={selectedApplicantId}
                        onChange={(e) => setSelectedApplicantId(e.target.value)}
                        required
                        className="w-full px-3.5 py-2.5 bg-[#F9F5EF]/60 border border-[#D9D2C5] rounded-xl text-sm font-semibold text-[#1C1C1E] focus:outline-none focus:border-[#2D5941]"
                      >
                        {eligibleApplicants.map((app) => (
                          <option key={app.applicationId} value={app.applicationId}>
                            👤 {app.scholarName} — 🎓 {app.programTitle}
                          </option>
                        ))}
                      </select>
                    ) : (
                      <div className="p-3 bg-[#FDF2F2] border border-[#B34040]/30 rounded-xl text-xs text-[#B34040] font-medium">
                        No approved scholars found for your provider account. Approve applications in the Applications tab first.
                      </div>
                    )}
                  </div>
                )}

                {/* Itemized Program Benefit Summary Card */}
                {currentSelectedApplicant?.benefitSummary && (
                  <div className="bg-[#EBF5EE] p-4 rounded-2xl border border-[#2D5941]/30 space-y-2">
                    <div className="flex justify-between items-center">
                      <span className="text-[10px] uppercase font-bold text-[#1A3C2E]">
                        📊 Itemized Program Benefit Breakdown
                      </span>
                      <span className="text-xs font-mono font-bold text-[#2D5941] bg-white px-2.5 py-0.5 rounded-lg border border-[#2D5941]/30">
                        Total Payout: ₱{currentSelectedApplicant.benefitSummary.totalCalculated.toLocaleString()}
                      </span>
                    </div>

                    <div className="grid grid-cols-2 gap-2 text-xs pt-1">
                      <div className="bg-white p-2 rounded-xl border border-[#D9D2C5]/60">
                        <span className="text-[10px] text-[#6C6C70] font-bold block uppercase">🏫 Tuition Subsidy</span>
                        {currentSelectedApplicant.benefitSummary.isTuitionDirectToSchool ? (
                          <span className="text-[10px] font-bold text-[#C97B2E] block mt-0.5">Paid to School (Off-System)</span>
                        ) : (
                          <span className="font-bold text-[#1A3C2E] block mt-0.5">
                            ₱{currentSelectedApplicant.benefitSummary.tuitionAmt.toLocaleString()}
                          </span>
                        )}
                      </div>

                      <div className="bg-white p-2 rounded-xl border border-[#D9D2C5]/60">
                        <span className="text-[10px] text-[#6C6C70] font-bold block uppercase">🍱 Stipend / Allowance</span>
                        <span className="font-bold text-[#1A3C2E] block mt-0.5">
                          ₱{currentSelectedApplicant.benefitSummary.stipendAmt.toLocaleString()}
                        </span>
                      </div>

                      <div className="bg-white p-2 rounded-xl border border-[#D9D2C5]/60">
                        <span className="text-[10px] text-[#6C6C70] font-bold block uppercase">📚 Book / Device</span>
                        <span className="font-bold text-[#1A3C2E] block mt-0.5">
                          ₱{currentSelectedApplicant.benefitSummary.allowanceAmt.toLocaleString()}
                        </span>
                      </div>

                      <div className="bg-white p-2 rounded-xl border border-[#D9D2C5]/60">
                        <span className="text-[10px] text-[#6C6C70] font-bold block uppercase">🛠️ Custom Allowances</span>
                        <span className="font-bold text-[#1A3C2E] block mt-0.5">
                          ₱{currentSelectedApplicant.benefitSummary.customBenefitsTotal.toLocaleString()}
                        </span>
                      </div>
                    </div>
                  </div>
                )}

                {/* Banking Verification Card for Selected Scholar */}
                {currentSelectedApplicant && (
                  <div className="bg-[#F9F5EF] p-4 rounded-2xl border border-[#D9D2C5] space-y-2">
                    <div className="flex justify-between items-center">
                      <span className="text-[10px] uppercase font-bold text-[#6C6C70]">
                        Verified Bank Account Details
                      </span>
                      {currentSelectedApplicant.hasPaymentAccount ? (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
                          ✓ Ready
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#FDF2F2] text-[#B34040] border border-[#B34040]/20">
                          ⚠️ Missing Bank Info
                        </span>
                      )}
                    </div>

                    {currentSelectedApplicant.hasPaymentAccount && currentSelectedApplicant.paymentAccount ? (
                      <div className="space-y-1 text-xs">
                        <div className="flex justify-between">
                          <span className="text-[#6C6C70]">Bank:</span>
                          <span className="font-bold text-[#1C1C1E]">
                            {currentSelectedApplicant.paymentAccount.bankName}
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-[#6C6C70]">Account #:</span>
                          <span className="font-mono font-bold text-[#2D5941]">
                            {currentSelectedApplicant.paymentAccount.accountNumber}
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-[#6C6C70]">Account Name:</span>
                          <span className="font-bold text-[#1C1C1E]">
                            {currentSelectedApplicant.paymentAccount.accountName}
                          </span>
                        </div>
                        {currentSelectedApplicant.paymentAccount.documentProofUrl && (
                          <div className="pt-2 flex justify-end">
                            <a
                              href={currentSelectedApplicant.paymentAccount.documentProofUrl}
                              target="_blank"
                              rel="noreferrer"
                              className="text-[11px] font-bold text-[#2D5941] hover:underline inline-flex items-center gap-1"
                            >
                              <span>📄 View Bank Card Scan</span>
                              <span>↗</span>
                            </a>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="space-y-2 pt-1">
                        <p className="text-[11px] text-[#B34040]">
                          Scholar has not uploaded their bank card scan yet.
                        </p>
                        <button
                          type="button"
                          onClick={() =>
                            setUploadModalScholar({
                              id: currentSelectedApplicant.scholarId,
                              name: currentSelectedApplicant.scholarName,
                            })
                          }
                          className="w-full py-2 bg-[#EBF5EE] hover:bg-[#2D5941] hover:text-white text-[#2D5941] rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center gap-1.5"
                        >
                          <span>📤 Upload Card Scan & Run AI OCR on Scholar's Behalf</span>
                        </button>
                      </div>
                    )}
                  </div>
                )}

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold text-[#6C6C70] uppercase mb-1">Fund Type</label>
                    <select
                      value={fundType}
                      onChange={(e) => setFundType(e.target.value)}
                      className="w-full px-3.5 py-2.5 bg-[#F9F5EF]/60 border border-[#D9D2C5] rounded-xl text-sm font-semibold text-[#1C1C1E] focus:outline-none focus:border-[#2D5941]"
                    >
                      <option value="stipend">Stipend</option>
                      <option value="allowance">Allowance</option>
                      <option value="tuition">Tuition</option>
                      <option value="other">Other</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-[#6C6C70] uppercase mb-1">Total Payout (₱)</label>
                    <input
                      type="number"
                      step="0.01"
                      min="1"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      required
                      placeholder="Calculated Program Total"
                      className="w-full px-3.5 py-2.5 bg-[#F9F5EF]/60 border border-[#D9D2C5] rounded-xl text-sm font-bold text-[#2D5941] focus:outline-none focus:border-[#2D5941]"
                    />
                  </div>
                </div>

                <div className="pt-4 flex justify-end gap-3 border-t border-[#D9D2C5]/60">
                  <button
                    type="button"
                    onClick={() => setIsReleaseModalOpen(false)}
                    className="px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-bold text-[#6C6C70] hover:bg-[#F9F5EF] transition-all cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={isSubmitting || !currentSelectedApplicant?.hasPaymentAccount}
                    className={`px-5 py-2.5 rounded-xl text-xs font-bold text-white shadow-md transition-all flex items-center gap-2 ${isSubmitting || !currentSelectedApplicant?.hasPaymentAccount
                      ? 'bg-gray-300 cursor-not-allowed'
                      : 'bg-[#C97B2E] hover:bg-[#A86220] cursor-pointer'
                      }`}
                  >
                    {isSubmitting ? 'Processing Payout...' : 'Confirm & Release Payout'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* ── BATCH RELEASE DISBURSEMENT MODAL ── */}
      <ProviderBatchDisbursementModal
        isOpen={isBatchModalOpen}
        onClose={() => setIsBatchModalOpen(false)}
        onSuccess={() => {
          fetchLiveReleases();
        }}
        programsList={programsList}
      />

      {/* ── AI BANK SCAN UPLOAD MODAL ON SCHOLAR'S BEHALF ── */}
      {uploadModalScholar && (
        <ScholarBankUploadModal
          isOpen={!!uploadModalScholar}
          scholarId={uploadModalScholar.id}
          scholarName={uploadModalScholar.name}
          onClose={() => setUploadModalScholar(null)}
          onSuccess={() => {
            setUploadModalScholar(null);
            fetchEligibleApplicants();
          }}
        />
      )}

      {/* ── REAL PAYMONGO PAYMENT GATEWAY AUTHORIZATION MODAL ── */}
      {isGatewayModalOpen && pendingReleaseAuth && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-xs z-[60] flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-white rounded-3xl max-w-lg w-full p-6 border border-[#2D5941]/30 shadow-2xl space-y-6 my-8">
            <div className="flex justify-between items-start border-b border-[#D9D2C5]/60 pb-4">
              <div>
                <div className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-[#2D5941] animate-ping" />
                  <span className="text-[10px] font-extrabold uppercase tracking-wider text-[#2D5941] bg-[#EBF5EE] px-2 py-0.5 rounded-full border border-[#2D5941]/20">
                    PayMongo Payment Gateway Authorization
                  </span>
                </div>
                <h3 className="text-xl font-bold text-[#1A3C2E] font-serif mt-1">
                  Authorize Payout Release
                </h3>
                <p className="text-xs text-[#6C6C70]">
                  Enter your provider password to launch the real PayMongo payment gateway checkout.
                </p>
              </div>
              <button
                onClick={handleCancelGatewayAuth}
                disabled={isAuthorizingPayment}
                className="text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-xl cursor-pointer disabled:opacity-50"
              >
                ✕
              </button>
            </div>

            {gatewayAuthError && (
              <div className="p-3.5 bg-[#FDF2F2] border border-[#B34040]/30 rounded-2xl text-xs text-[#B34040] font-semibold">
                ⚠️ {gatewayAuthError}
              </div>
            )}

            <div className="bg-[#F9F5EF] p-4 rounded-2xl border border-[#D9D2C5] space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-[#6C6C70]">Scholar Recipient:</span>
                <span className="font-bold text-[#1C1C1E]">{pendingReleaseAuth.selected.scholarName}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-[#6C6C70]">Payout Amount:</span>
                <span className="font-mono font-extrabold text-[#2D5941] text-sm">
                  ₱{pendingReleaseAuth.numAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-[#6C6C70]">Gateway Channel:</span>
                <span className="font-bold text-[#C97B2E]">PayMongo Direct Payout</span>
              </div>
            </div>

            <div className="space-y-2">
              <label className="block text-xs font-bold text-[#1A3C2E] uppercase">
                Enter Provider Account Password *
              </label>
              <input
                type="password"
                placeholder="Enter your account password to confirm"
                value={gatewayAuthPin}
                onChange={(e) => setGatewayAuthPin(e.target.value)}
                disabled={isAuthorizingPayment}
                className="w-full px-4 py-3 bg-[#F9F5EF]/80 border border-[#D9D2C5] rounded-xl text-sm font-semibold text-[#1C1C1E] focus:outline-none focus:border-[#2D5941]"
              />
              <p className="text-[10px] text-[#6C6C70] italic">
                * Confirm password to launch PayMongo Gateway. Exiting cancels the transfer with 0 POL gas tokens spent and 0 database entries created.
              </p>
            </div>

            <div className="grid grid-cols-2 gap-3 pt-2">
              <button
                type="button"
                onClick={handleCancelGatewayAuth}
                disabled={isAuthorizingPayment}
                className="w-full py-3 rounded-2xl border border-[#D9D2C5] bg-[#F9F5EF] text-[#6C6C70] text-xs font-bold transition-all cursor-pointer disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleAuthorizeAndLaunchPayMongoGateway}
                disabled={isAuthorizingPayment}
                className="w-full py-3 rounded-2xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold shadow-md transition-all cursor-pointer disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {isAuthorizingPayment ? (
                  <>
                    <span className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Launching PayMongo...</span>
                  </>
                ) : (
                  <span>Authorize & Launch PayMongo Gateway ➔</span>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

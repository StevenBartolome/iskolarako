import React, { useState, useEffect } from 'react';
import {
  Zap,
  Bot,
  Loader2,
  AlertTriangle,
  ShieldCheck,
  Clock,
  CheckCircle2,
  AlertOctagon,
  ExternalLink,
  RefreshCw,
  Flag,
  Microscope,
  AlertCircle,
  XCircle,
  Building2,
  FileText,
  Lock,
  Ban,
  Check,
} from 'lucide-react';
import type { ProviderOrg, ProviderDocumentItem, AdminTab } from '../types';
import { supabase } from '@/services/supabaseClient';
import {
  verifyDocumentAuthenticity,
  getScoreAssessment,
  type ApplicantVerificationContext,
} from '@/services/aiExtractionService';

interface AdminProvidersTabProps {
  providerFilter: string;
  setProviderFilter: (filter: string) => void;
  providers: ProviderOrg[];
  selectedProvider: ProviderOrg | null;
  setSelectedProvider: (prov: ProviderOrg | null) => void;
  providerRequirementsMap: Record<string, { name: string; description: string; required: boolean }[]>;
  isChecklistCollapsed: boolean;
  setIsChecklistCollapsed: (collapsed: boolean) => void;
  isOversightCollapsed: boolean;
  setIsOversightCollapsed: (collapsed: boolean) => void;
  loadingPrograms: boolean;
  providerPrograms: any[];
  setSelectedScholarshipDetails: (prog: any) => void;
  setActiveTab: (tab: AdminTab) => void;
  handleVerifyProvider: (id: any, status: ProviderOrg['status'], remarks?: string) => void;
  handleReactivateProvider?: (id: any) => Promise<void>;
  onUpdateProviderDocs?: (
    providerId: any,
    updatedDocs: ProviderDocumentItem[],
    newStatus?: ProviderOrg['status'],
    newRemarks?: string
  ) => Promise<void>;
}

export const AdminProvidersTab: React.FC<AdminProvidersTabProps> = ({
  providerFilter,
  setProviderFilter,
  providers,
  selectedProvider,
  setSelectedProvider,
  providerRequirementsMap,
  isChecklistCollapsed,
  setIsChecklistCollapsed,
  isOversightCollapsed,
  setIsOversightCollapsed,
  loadingPrograms,
  providerPrograms,
  setSelectedScholarshipDetails,
  setActiveTab,
  handleVerifyProvider,
  handleReactivateProvider,
  onUpdateProviderDocs,
}) => {
  // Batch & AI Scanning States
  const [isBatchScanning, setIsBatchScanning] = useState(false);
  const [batchProgressMsg, setBatchProgressMsg] = useState('');
  const [expandedDocIndices, setExpandedDocIndices] = useState<Record<string, boolean>>({});
  const [autoScanSummary, setAutoScanSummary] = useState<{
    total: number;
    verified: number;
    flagged: number;
    actionTaken?: string;
  } | null>(null);

  const getFlagString = (flag: any): string => {
    if (!flag) return '';
    if (typeof flag === 'string') return flag.trim();
    if (typeof flag === 'object') {
      return flag.description || flag.flag || flag.reason || flag.message || flag.issue || JSON.stringify(flag);
    }
    return String(flag);
  };

  const toggleExpandDoc = (name: string) => {
    setExpandedDocIndices(prev => ({
      ...prev,
      [name]: !prev[name],
    }));
  };

  const getProviderContext = (prov: ProviderOrg): ApplicantVerificationContext => ({
    isProviderOrg: true,
    organizationName: prov.name,
    representativeName: prov.representative,
    providerType: prov.type,
    email: prov.email,
  });

  const evaluateAndAdjustStatus = (_prov: ProviderOrg, docs: ProviderDocumentItem[]) => {
    const scannableDocs = docs.filter(d => d.url && d.url !== '#');
    if (scannableDocs.length === 0) return;

    const flaggedDocs = docs.filter(
      d => d.status === 'Flagged' || d.aiVerification?.verificationStatus === 'flagged' || d.aiVerification?.verificationStatus === 'rejected'
    );
    const verifiedDocs = docs.filter(
      d => d.status === 'Verified' || d.aiVerification?.verificationStatus === 'verified'
    );

    setAutoScanSummary({
      total: scannableDocs.length,
      flagged: flaggedDocs.length,
      verified: verifiedDocs.length,
      actionTaken: flaggedDocs.length > 0
        ? `Provider has ${flaggedDocs.length} flagged requirement(s) requiring compliance review.`
        : `All ${scannableDocs.length} submitted organization document(s) verified authentic.`,
    });
  };

  // Single Document AI Scan
  const handleScanSingleDoc = async (docName: string) => {
    if (!selectedProvider) return;
    const doc = selectedProvider.documents.find(d => d.name === docName);
    if (!doc || !doc.url || doc.url === '#') return;

    // Set scanning spinner
    const updatedWithSpinner = selectedProvider.documents.map(d =>
      d.name === docName ? { ...d, isAiScanning: true } : d
    );
    setSelectedProvider({ ...selectedProvider, documents: updatedWithSpinner });

    try {
      const result = await verifyDocumentAuthenticity({
        documentUrl: doc.url,
        documentName: doc.name,
        applicantContext: getProviderContext(selectedProvider),
      });

      const isVerified = result.verificationStatus === 'verified';
      const isFlagged = result.verificationStatus === 'flagged' || result.verificationStatus === 'rejected';

      const nextDocs = selectedProvider.documents.map(d => {
        if (d.name !== docName) return d;
        return {
          ...d,
          isAiScanning: false,
          verified: isVerified,
          status: isVerified ? ('Verified' as const) : isFlagged ? ('Flagged' as const) : ('Pending' as const),
          remarks: result.flags && result.flags.length > 0 ? `AI Flag: ${getFlagString(result.flags[0])}` : (result.summary || ''),
          aiVerification: result,
        };
      });

      setSelectedProvider({ ...selectedProvider, documents: nextDocs });
      setExpandedDocIndices(prev => ({ ...prev, [docName]: true }));
      evaluateAndAdjustStatus(selectedProvider, nextDocs);

      if (onUpdateProviderDocs) {
        await onUpdateProviderDocs(selectedProvider.id, nextDocs);
      }
    } catch (err) {
      console.error('Error verifying provider org document:', err);
      const resetSpinner = selectedProvider.documents.map(d =>
        d.name === docName ? { ...d, isAiScanning: false } : d
      );
      setSelectedProvider({ ...selectedProvider, documents: resetSpinner });
    }
  };

  // Batch AI Scan
  const handleScanAllDocs = async (onlyUnscanned = false) => {
    if (!selectedProvider) return;
    const scannableDocs = selectedProvider.documents.filter(d => {
      if (!d.url || d.url === '#') return false;
      if (onlyUnscanned && d.aiVerification && !d.remarks?.toLowerCase().includes('resubmit')) {
        return false;
      }
      return true;
    });

    if (scannableDocs.length === 0) {
      evaluateAndAdjustStatus(selectedProvider, selectedProvider.documents);
      return;
    }

    setIsBatchScanning(true);
    setBatchProgressMsg(`Auto-Scanning ${scannableDocs.length} organization document(s)...`);

    let workingDocs = [...selectedProvider.documents];
    const context = getProviderContext(selectedProvider);

    for (let count = 0; count < scannableDocs.length; count++) {
      const doc = scannableDocs[count];
      setBatchProgressMsg(`Auto-Scanning (${count + 1}/${scannableDocs.length}): ${doc.name}...`);

      workingDocs = workingDocs.map(d => d.name === doc.name ? { ...d, isAiScanning: true } : d);
      setSelectedProvider({ ...selectedProvider, documents: workingDocs });

      try {
        const result = await verifyDocumentAuthenticity({
          documentUrl: doc.url,
          documentName: doc.name,
          applicantContext: context,
        });

        const isVerified = result.verificationStatus === 'verified';
        const isFlagged = result.verificationStatus === 'flagged' || result.verificationStatus === 'rejected';

        workingDocs = workingDocs.map(d => {
          if (d.name !== doc.name) return d;
          return {
            ...d,
            isAiScanning: false,
            verified: isVerified,
            status: isVerified ? ('Verified' as const) : isFlagged ? ('Flagged' as const) : ('Pending' as const),
            remarks: result.flags && result.flags.length > 0 ? `AI Flag: ${getFlagString(result.flags[0])}` : (result.summary || ''),
            aiVerification: result,
          };
        });

        setSelectedProvider({ ...selectedProvider, documents: workingDocs });
        setExpandedDocIndices(prev => ({ ...prev, [doc.name]: true }));
      } catch (err) {
        console.error(`Error verifying document ${doc.name}:`, err);
        workingDocs = workingDocs.map(d => d.name === doc.name ? { ...d, isAiScanning: false } : d);
        setSelectedProvider({ ...selectedProvider, documents: workingDocs });
      }
    }

    setBatchProgressMsg('Org Verification Complete!');
    evaluateAndAdjustStatus(selectedProvider, workingDocs);

    if (onUpdateProviderDocs) {
      await onUpdateProviderDocs(selectedProvider.id, workingDocs);
    }

    setTimeout(() => {
      setIsBatchScanning(false);
      setBatchProgressMsg('');
    }, 1200);
  };

  // Toggle individual requirement status
  const toggleDocVerified = async (docName: string, newStatus: 'Verified' | 'Flagged' | 'Pending') => {
    if (!selectedProvider) return;
    const nextDocs = selectedProvider.documents.map(d => {
      if (d.name !== docName) return d;
      return {
        ...d,
        status: newStatus,
        verified: newStatus === 'Verified',
        remarks: newStatus === 'Verified' ? '' : (d.remarks || 'Flagged by administrator'),
      };
    });

    setSelectedProvider({ ...selectedProvider, documents: nextDocs });
    evaluateAndAdjustStatus(selectedProvider, nextDocs);

    if (onUpdateProviderDocs) {
      await onUpdateProviderDocs(selectedProvider.id, nextDocs);
    }
  };

  // Mark all organization documents as verified
  const handleMarkAllVerified = async () => {
    if (!selectedProvider) return;
    const nextDocs = selectedProvider.documents.map(d => ({
      ...d,
      status: 'Verified' as const,
      verified: true,
      remarks: '',
    }));

    setSelectedProvider({ ...selectedProvider, documents: nextDocs });
    evaluateAndAdjustStatus(selectedProvider, nextDocs);

    if (onUpdateProviderDocs) {
      await onUpdateProviderDocs(selectedProvider.id, nextDocs);
    }
  };

  // Evaluate document status summary when a provider is selected (no automatic AI scan on open)
  useEffect(() => {
    if (selectedProvider) {
      evaluateAndAdjustStatus(selectedProvider, selectedProvider.documents);
    } else {
      setAutoScanSummary(null);
    }
  }, [selectedProvider?.id]);

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Organization Verification Pipeline</h3>
            <p className="text-xs text-[#6C6C70] mt-0.5">Automated AI compliance check & regulatory document verification.</p>
          </div>
          <div className="flex gap-2">
            <select
              value={providerFilter}
              onChange={(e) => setProviderFilter(e.target.value)}
              className="px-3 py-1.5 rounded-xl border border-[#D9D2C5] bg-white text-xs font-semibold"
            >
              <option value="All">All Statuses</option>
              <option value="Pending">Pending</option>
              <option value="Under Review">Under Review</option>
              <option value="Verified">Verified</option>
              <option value="Suspended">Suspended</option>
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Providers List (5 Cols) */}
          <div className="lg:col-span-5 space-y-3">
            {providers
              .filter(p => providerFilter === 'All' || p.status === providerFilter)
              .map(prov => (
                <div
                  key={prov.id}
                  onClick={() => setSelectedProvider(prov)}
                  className={`p-4 rounded-2xl border transition-all cursor-pointer flex justify-between items-center ${
                    selectedProvider?.id === prov.id
                      ? 'border-[#2D5941] bg-[#EBF5EE]/40 shadow-xs'
                      : 'border-[#D9D2C5] bg-white hover:bg-[#FFFFFF]/50'
                  }`}
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-sm text-[#1C1C1E]">{prov.name}</span>
                      <span className="text-[10px] bg-[#EDE8DE] text-[#6C6C70] font-bold px-2 py-0.5 rounded">
                        {prov.type}
                      </span>
                    </div>
                    <p className="text-xs text-[#6C6C70]">Rep: {prov.representative}</p>
                    <p className="text-[10px] text-[#8E8E93]">{prov.email} • Registered {prov.dateRegistered}</p>
                  </div>
                  <div className="flex flex-col items-end gap-1.5">
                    <span className={`text-[10px] font-bold px-2.5 py-1 rounded-full ${
                      prov.status === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                      prov.status === 'Under Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                      prov.status === 'Suspended' ? 'bg-red-50 text-[#B34040]' :
                      'bg-[#EDE8DE] text-[#6C6C70]'
                    }`}>
                      {prov.status}
                    </span>
                    {prov.documents?.some(d => d.aiVerification) && (
                      <span className="text-[9px] font-bold text-[#2D5941] bg-white px-1.5 py-0.5 rounded border border-[#2D5941]/30 inline-flex items-center gap-0.5">
                        <Zap className="w-2.5 h-2.5 text-[#2D5941]" />
                        <span>AI Audited</span>
                      </span>
                    )}
                  </div>
                </div>
              ))}
          </div>

          {/* Organization Verification & Detail Pane (7 Cols) */}
          <div className="lg:col-span-7 bg-[#FFFFFF]/50 border border-[#D9D2C5] rounded-3xl p-6">
            {selectedProvider ? (
              <div className="space-y-5">
                {/* Header */}
                <div className="flex items-start justify-between">
                  <div>
                    <h4 className="font-bold text-lg text-[#1A3C2E] font-serif">{selectedProvider.name}</h4>
                    <p className="text-xs text-[#6C6C70] mt-0.5">
                      {selectedProvider.type} Classification • Authorized Rep: <strong>{selectedProvider.representative}</strong>
                    </p>
                  </div>
                  <span className={`text-xs font-bold px-3 py-1 rounded-full ${
                    selectedProvider.status === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                    selectedProvider.status === 'Under Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                    selectedProvider.status === 'Suspended' ? 'bg-red-50 text-[#B34040]' :
                    'bg-[#EDE8DE] text-[#6C6C70]'
                  }`}>
                    {selectedProvider.status}
                  </span>
                </div>

                {/* Batch Verification Toolbar */}
                <div className="flex items-center justify-between bg-white p-3.5 rounded-2xl border border-[#D9D2C5] gap-3 flex-wrap">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-[#1A3C2E] inline-flex items-center gap-1">
                      <Bot className="w-4 h-4 text-[#1A3C2E]" />
                      <span>AI Forensic Engine:</span>
                    </span>
                    <span className="text-[10px] text-[#6C6C70]">Pixtral 12B & Gemini Vision</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      disabled={isBatchScanning || selectedProvider.documents.length === 0}
                      onClick={() => handleScanAllDocs(false)}
                      className="px-3 py-1.5 rounded-xl bg-[#C97B2E] hover:bg-[#A86220] text-white text-[11px] font-bold shadow-xs cursor-pointer inline-flex items-center gap-1.5 transition-all border-0 disabled:opacity-50"
                    >
                      {isBatchScanning ? (
                        <>
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                          <span>Scanning...</span>
                        </>
                      ) : (
                        <>
                          <Zap className="w-3.5 h-3.5" />
                          <span>Verify All Org Docs with AI</span>
                        </>
                      )}
                    </button>
                    <button
                      type="button"
                      onClick={handleMarkAllVerified}
                      className="px-3 py-1.5 rounded-xl bg-[#EBF5EE] hover:bg-[#2D5941] text-[#2D5941] hover:text-white text-[11px] font-bold border border-[#2D5941]/30 cursor-pointer inline-flex items-center gap-1 transition-all"
                    >
                      <Check className="w-3.5 h-3.5" />
                      <span>Mark All Verified</span>
                    </button>
                  </div>
                </div>

                {/* Batch Progress Banner */}
                {isBatchScanning && (
                  <div className="bg-[#FFF8EE] border border-[#C97B2E]/40 p-3 rounded-2xl flex items-center justify-between text-xs animate-pulse">
                    <div className="flex items-center gap-2 text-[#C97B2E] font-bold">
                      <Loader2 className="w-4 h-4 animate-spin text-[#C97B2E]" />
                      <span>{batchProgressMsg || 'Analyzing organization credentials with multi-AI vision...'}</span>
                    </div>
                  </div>
                )}

                {/* Smart AI Auto-Audit Summary Banner */}
                {autoScanSummary && !isBatchScanning && (
                  <div className={`p-3.5 rounded-2xl border flex items-center justify-between gap-3 text-xs shadow-xs transition-all ${
                    autoScanSummary.flagged > 0
                      ? 'bg-[#FFF8EE] border-[#C97B2E]/50 text-[#8C4A00]'
                      : 'bg-[#EBF5EE] border-[#2D5941]/40 text-[#2D5941]'
                  }`}>
                    <div className="flex items-center gap-2.5">
                      <span className="shrink-0">
                        {autoScanSummary.flagged > 0 ? (
                          <AlertTriangle className="w-5 h-5 text-amber-600" />
                        ) : (
                          <ShieldCheck className="w-5 h-5 text-[#2D5941]" />
                        )}
                      </span>
                      <div>
                        <strong className="block font-bold">
                          {autoScanSummary.flagged > 0 ? 'AI Auto-Audit Flagged Issues' : 'AI Organization Verification Passed'}
                        </strong>
                        <p className="text-[11px] opacity-90 mt-0.5">{autoScanSummary.actionTaken}</p>
                      </div>
                    </div>
                    <span className="text-[11px] font-bold px-2.5 py-1 rounded-full bg-white shadow-2xs shrink-0">
                      {autoScanSummary.verified}/{autoScanSummary.total} Verified
                    </span>
                  </div>
                )}

                {/* Requirements Checklist with AI Vision Forensic Cards */}
                {(() => {
                  const typeKey = selectedProvider.type === 'Government' ? 'public' : selectedProvider.type === 'Private' ? 'private' : 'ngo';
                  const reqs = providerRequirementsMap[typeKey] || [];
                  const allRequiredPassed = reqs
                    .filter(r => r.required)
                    .every(r => {
                      const d = selectedProvider.documents.find(doc => doc.name === r.name);
                      return d && (d.status === 'Verified' || d.verified);
                    });

                  return (
                    <div className="space-y-4">
                      {selectedProvider.status === 'Pending' && selectedProvider.documents.length === 0 && (
                        <div className="bg-[#FFF8EE] border border-[#C97B2E]/30 text-[#8C4A00] p-4 rounded-2xl text-xs space-y-1">
                          <strong className="font-bold block flex items-center gap-1.5 text-sm">
                            <Clock className="w-4 h-4" />
                            <span>Pending Verification Request</span>
                          </strong>
                          <p className="leading-relaxed opacity-90">
                            This organization has not yet submitted a formal verification request. Any files uploaded by the provider are currently in draft mode and will reflect here once they click "Submit Verification Request".
                          </p>
                        </div>
                      )}

                      <div className="border-t border-[#D9D2C5] pt-4">
                        <button
                          type="button"
                          onClick={() => setIsChecklistCollapsed(!isChecklistCollapsed)}
                          className="w-full flex justify-between items-center text-xs font-bold text-[#1C1C1E] uppercase cursor-pointer border-0 bg-transparent mb-2"
                        >
                          <span>Legal & Regulatory Requirements ({selectedProvider.documents.length} Submitted)</span>
                          <svg className={`w-3.5 h-3.5 transition-transform duration-200 ${isChecklistCollapsed ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                          </svg>
                        </button>
                        
                        {!isChecklistCollapsed && (
                          <div className="space-y-3 mt-2">
                            {reqs.map((req, idx) => {
                              const submittedDoc = selectedProvider.documents.find(d => d.name === req.name);
                              const isPassed = !!submittedDoc;
                              const aiRes = submittedDoc?.aiVerification;
                              const isExpanded = !!expandedDocIndices[req.name];
                              const docStatus = submittedDoc?.status || (submittedDoc?.verified ? 'Verified' : 'Pending');

                              return (
                                <div
                                  key={idx}
                                  className={`p-4 bg-white rounded-2xl border transition-all text-xs flex flex-col gap-2.5 shadow-sm ${
                                    docStatus === 'Verified'
                                      ? 'border-[#2D5941]/40'
                                      : docStatus === 'Flagged'
                                      ? 'border-[#B34040]/50 bg-[#FFFDFD]'
                                      : 'border-[#D9D2C5]/60'
                                  }`}
                                >
                                  {/* Row Header */}
                                  <div className="flex justify-between items-start flex-wrap gap-2">
                                    <div>
                                      <div className="flex items-center gap-1.5 flex-wrap">
                                        <span className="font-bold text-sm text-[#1A3C2E]">{req.name}</span>
                                        {req.required && (
                                          <span className="text-[8px] bg-red-50 text-red-600 font-bold px-1.5 py-0.5 rounded border border-red-200">
                                            REQUIRED
                                          </span>
                                        )}
                                        {/* AI Status Badge */}
                                        {aiRes ? (() => {
                                          const assessment = getScoreAssessment(aiRes.confidenceScore);
                                          return (
                                            <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold flex items-center gap-1 border ${
                                              aiRes.verificationStatus === 'verified' && assessment.quality === 'GOOD'
                                                ? 'bg-[#EBF5EE] text-[#2D5941] border-[#2D5941]/30'
                                                : aiRes.tamperingDetected || assessment.quality === 'BAD'
                                                ? 'bg-red-100 text-red-800 border-red-300'
                                                : 'bg-amber-100 text-amber-900 border-amber-300'
                                            }`}>
                                              <span className="inline-flex items-center gap-1">
                                                {aiRes.verificationStatus === 'verified' && assessment.quality === 'GOOD' ? (
                                                  <>
                                                    <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                                                    <span>AI Verified</span>
                                                  </>
                                                ) : aiRes.tamperingDetected || assessment.quality === 'BAD' ? (
                                                  <>
                                                    <AlertOctagon className="w-3 h-3 text-red-600" />
                                                    <span>Tampering Alert</span>
                                                  </>
                                                ) : (
                                                  <>
                                                    <AlertTriangle className="w-3 h-3 text-amber-600" />
                                                    <span>AI Flagged</span>
                                                  </>
                                                )}
                                              </span>
                                              <span className="font-semibold">
                                                ({assessment.quality === 'GOOD' ? 'Good' : assessment.quality === 'CAUTION' ? 'Needs Review' : 'High Risk'})
                                              </span>
                                            </span>
                                          );
                                        })() : submittedDoc?.isAiScanning ? (
                                          <span className="px-2 py-0.5 rounded-full text-[9px] font-bold bg-amber-100 text-amber-900 animate-pulse border border-amber-300 inline-flex items-center gap-1">
                                            <Loader2 className="w-2.5 h-2.5 animate-spin" />
                                            <span>AI Scanning...</span>
                                          </span>
                                        ) : null}
                                      </div>
                                      <p className="text-[11px] text-[#6C6C70] mt-0.5 leading-normal">{req.description}</p>
                                    </div>

                                    {/* Action Buttons Toolbar */}
                                    <div className="flex items-center gap-1.5 shrink-0 flex-wrap">
                                      {submittedDoc?.url && submittedDoc.url !== '#' && (
                                        <a
                                          href={submittedDoc.url}
                                          target="_blank"
                                          rel="noreferrer"
                                          className="px-2.5 py-1.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-[10.5px] font-bold border-0 cursor-pointer inline-flex items-center gap-1 transition-colors no-underline"
                                        >
                                          <span>Preview</span>
                                          <ExternalLink className="w-3 h-3" />
                                        </a>
                                      )}

                                      {submittedDoc?.url && submittedDoc.url !== '#' && (
                                        <button
                                          type="button"
                                          disabled={submittedDoc.isAiScanning}
                                          onClick={() => handleScanSingleDoc(req.name)}
                                          className="px-2.5 py-1.5 rounded-xl bg-amber-50 hover:bg-amber-100 text-[#C97B2E] text-[10.5px] font-bold border border-amber-300/60 cursor-pointer inline-flex items-center gap-1 transition-all disabled:opacity-50"
                                        >
                                          {submittedDoc.isAiScanning ? (
                                            <>
                                              <Loader2 className="w-3 h-3 animate-spin" />
                                              <span>Scanning...</span>
                                            </>
                                          ) : (
                                            <>
                                              {aiRes ? (
                                                <>
                                                  <RefreshCw className="w-3 h-3" />
                                                  <span>Re-scan AI</span>
                                                </>
                                              ) : (
                                                <>
                                                  <Zap className="w-3 h-3" />
                                                  <span>Run AI Scan</span>
                                                </>
                                              )}
                                            </>
                                          )}
                                        </button>
                                      )}

                                      {aiRes && (
                                        <button
                                          type="button"
                                          onClick={() => toggleExpandDoc(req.name)}
                                          className={`px-2.5 py-1.5 rounded-xl text-[10.5px] font-bold cursor-pointer transition-colors border ${
                                            isExpanded
                                              ? 'bg-[#1A3C2E] text-white border-[#1A3C2E]'
                                              : 'bg-white text-[#1A3C2E] border-[#D9D2C5] hover:bg-[#FFFFFF]'
                                          }`}
                                        >
                                          <span>{isExpanded ? '▲ Hide Report' : '▼ AI Forensic'}</span>
                                        </button>
                                      )}

                                      {isPassed && (
                                        <>
                                          <button
                                            type="button"
                                            onClick={() => toggleDocVerified(req.name, docStatus === 'Verified' ? 'Pending' : 'Verified')}
                                            className={`px-2.5 py-1.5 rounded-xl text-[10.5px] font-bold cursor-pointer transition-colors border-0 inline-flex items-center gap-1 ${
                                              docStatus === 'Verified'
                                                ? 'bg-[#2D5941] text-white shadow-2xs'
                                                : 'bg-[#EBF5EE] text-[#2D5941] hover:bg-[#2D5941] hover:text-white'
                                            }`}
                                          >
                                            <Check className="w-3 h-3" />
                                            <span>{docStatus === 'Verified' ? 'Verified' : 'Mark Verified'}</span>
                                          </button>
                                          <button
                                            type="button"
                                            onClick={() => toggleDocVerified(req.name, docStatus === 'Flagged' ? 'Pending' : 'Flagged')}
                                            className={`px-2.5 py-1.5 rounded-xl text-[10.5px] font-bold cursor-pointer transition-colors border-0 inline-flex items-center gap-1 ${
                                              docStatus === 'Flagged'
                                                ? 'bg-[#B34040] text-white shadow-2xs'
                                                : 'bg-red-50 text-[#B34040] hover:bg-[#B34040] hover:text-white'
                                            }`}
                                          >
                                            <Flag className="w-3 h-3" />
                                            <span>{docStatus === 'Flagged' ? 'Flagged' : 'Flag'}</span>
                                          </button>
                                        </>
                                      )}
                                    </div>
                                  </div>

                                  {/* Expandable Forensic Breakdown */}
                                  {isExpanded && aiRes && (() => {
                                    const assessment = getScoreAssessment(aiRes.confidenceScore);
                                    return (
                                      <div className="mt-1 p-3.5 bg-[#FFFFFF] rounded-2xl border border-[#D9D2C5] space-y-3 animate-fade-in text-xs">
                                        {/* Assessment Header Bar */}
                                        <div className="flex items-center justify-between border-b border-[#D9D2C5]/60 pb-2 flex-wrap gap-2">
                                          <div className="flex items-center gap-2 flex-wrap">
                                            <span className="font-bold text-[#1A3C2E] uppercase text-[10px] tracking-wider inline-flex items-center gap-1">
                                              <Microscope className="w-3.5 h-3.5" />
                                              <span>Forensic Analysis Report</span>
                                            </span>
                                            <span className="text-[10px] text-[#6C6C70] bg-[#F9F5EF] px-2 py-0.5 rounded-md border border-[#D9D2C5]">
                                              Model: <strong>{aiRes.aiModelUsed || 'Gemini 2.5 Flash'}</strong> ({aiRes.provider || 'DeepMind'})
                                            </span>
                                          </div>
                                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md border ${assessment.badgeStyle}`}>
                                            {assessment.label}
                                          </span>
                                        </div>

                                        {/* Dynamic Quality & Remark Explanation Card */}
                                        <div className={`p-2.5 rounded-xl border text-xs flex items-start gap-2.5 ${
                                          assessment.quality === 'GOOD'
                                            ? 'bg-[#EBF5EE]/60 border-[#2D5941]/30 text-[#1A3C2E]'
                                            : assessment.quality === 'CAUTION'
                                            ? 'bg-[#FFF8EE] border-[#C97B2E]/30 text-[#8C4A00]'
                                            : 'bg-red-50 border-red-200 text-red-900'
                                        }`}>
                                          <span className="shrink-0 mt-0.5">
                                            {assessment.quality === 'GOOD' ? (
                                              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                                            ) : assessment.quality === 'CAUTION' ? (
                                              <AlertCircle className="w-4 h-4 text-amber-600" />
                                            ) : (
                                              <XCircle className="w-4 h-4 text-red-600" />
                                            )}
                                          </span>
                                          <div className="space-y-0.5">
                                            <span className="font-bold block text-xs">
                                              Match Rating: {assessment.textRemark}
                                            </span>
                                            <p className="text-[11px] leading-relaxed opacity-90 font-normal">
                                              {assessment.quality === 'GOOD' && 'Document matches declared profile credentials with verified official seals and zero visual tampering detected.'}
                                              {assessment.quality === 'CAUTION' && 'Document is readable but contains minor data variance or unverified seal. Manual administrator check recommended.'}
                                              {assessment.quality === 'BAD' && 'High mismatch or potential visual alteration detected. Document flagged for security risk.'}
                                            </p>
                                          </div>
                                        </div>
                                      {/* Side-by-Side Comparison */}
                                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                                        {/* Left: Declared Org Profile */}
                                        <div className="bg-white p-3 rounded-xl border border-[#D9D2C5]/70 space-y-1">
                                          <span className="text-[10px] font-bold text-[#6C6C70] uppercase inline-flex items-center gap-1">
                                            <Building2 className="w-3 h-3" />
                                            <span>Declared Organization Profile</span>
                                          </span>
                                          <div className="space-y-1 text-xs">
                                            <div className="flex justify-between">
                                              <span className="text-[#6C6C70]">Organization:</span>
                                              <strong className="text-[#1C1C1E]">{selectedProvider.name}</strong>
                                            </div>
                                            <div className="flex justify-between">
                                              <span className="text-[#6C6C70]">Representative:</span>
                                              <strong className="text-[#1C1C1E]">{selectedProvider.representative}</strong>
                                            </div>
                                            <div className="flex justify-between">
                                              <span className="text-[#6C6C70]">Classification:</span>
                                              <strong className="text-[#2D5941]">{selectedProvider.type}</strong>
                                            </div>
                                          </div>
                                        </div>

                                        {/* Right: AI Extracted Document Data */}
                                        <div className="bg-white p-3 rounded-xl border border-[#D9D2C5]/70 space-y-1">
                                          <span className="text-[10px] font-bold text-[#6C6C70] uppercase inline-flex items-center gap-1">
                                            <FileText className="w-3 h-3" />
                                            <span>AI Extracted Legal Data</span>
                                          </span>
                                          <div className="space-y-1 text-xs">
                                            <div className="flex justify-between items-center">
                                              <span className="text-[#6C6C70]">Org on Document:</span>
                                              <div className="flex items-center gap-1">
                                                <strong className="text-[#1C1C1E]">{aiRes.extractedName || 'Not detected'}</strong>
                                                {aiRes.crossCheckResults.nameMatch ? (
                                                  <Check className="w-3 h-3 text-[#2D5941]" />
                                                ) : (
                                                  <AlertTriangle className="w-3 h-3 text-[#B34040]" />
                                                )}
                                              </div>
                                            </div>
                                            <div className="flex justify-between items-center">
                                              <span className="text-[#6C6C70]">Issuing Agency:</span>
                                              <strong className="text-[#1C1C1E]">{aiRes.extractedSchool || 'Agency Identified'}</strong>
                                            </div>
                                            {aiRes.extractedGwa && (
                                              <div className="flex justify-between items-center">
                                                <span className="text-[#6C6C70]">Registration / TIN:</span>
                                                <strong className="text-[#2D5941] font-mono">{aiRes.extractedGwa}</strong>
                                              </div>
                                            )}
                                          </div>
                                        </div>
                                      </div>

                                      {/* Security Signals */}
                                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-[11px]">
                                        <div className="flex items-center gap-1.5 bg-white p-2 rounded-lg border border-[#D9D2C5]/60">
                                          {aiRes.hasOfficialSealOrSignature ? (
                                            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                                          ) : (
                                            <AlertCircle className="w-3.5 h-3.5 text-amber-500 shrink-0" />
                                          )}
                                          <span className="text-[#1C1C1E]">
                                            {aiRes.hasOfficialSealOrSignature ? 'Official Dry Seal / Stamp Detected' : 'Seal Unclear'}
                                          </span>
                                        </div>
                                        <div className="flex items-center gap-1.5 bg-white p-2 rounded-lg border border-[#D9D2C5]/60">
                                          {aiRes.tamperingDetected ? (
                                            <XCircle className="w-3.5 h-3.5 text-red-600 shrink-0" />
                                          ) : (
                                            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                                          )}
                                          <span className="text-[#1C1C1E]">
                                            {aiRes.tamperingDetected ? 'Visual Alteration Detected' : 'No Digital Tampering'}
                                          </span>
                                        </div>
                                        <div className="flex items-center gap-1.5 bg-white p-2 rounded-lg border border-[#D9D2C5]/60 col-span-2 sm:col-span-1">
                                          <Lock className="w-3.5 h-3.5 text-[#6C6C70] shrink-0" />
                                          <span className="text-[#6C6C70] truncate font-mono text-[10px]" title={`SHA-256: ${aiRes.sha256Hash || 'N/A'}`}>
                                            Hash: {aiRes.sha256Hash?.slice(0, 10)}...
                                          </span>
                                        </div>
                                      </div>

                                      {/* Flagged Issues */}
                                      {aiRes.flags.length > 0 && (
                                        <div className="p-2.5 bg-[#FDF2F2] border border-[#B34040]/30 rounded-xl space-y-1">
                                          <span className="text-[10px] font-bold text-[#B34040] uppercase tracking-wider inline-flex items-center gap-1">
                                            <AlertTriangle className="w-3 h-3 text-[#B34040]" />
                                            <span>Compliance Anomalies & Warnings:</span>
                                          </span>
                                          <ul className="list-disc list-inside text-xs text-[#B34040] space-y-0.5 font-medium">
                                            {aiRes.flags.map((flag, fIdx) => (
                                              <li key={fIdx}>{getFlagString(flag)}</li>
                                            ))}
                                          </ul>
                                        </div>
                                      )}

                                      {/* Forensic Summary */}
                                      <div className="p-2.5 bg-white rounded-xl border border-[#D9D2C5]/60 text-xs text-[#1C1C1E]">
                                        <span className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-0.5">Forensic Summary:</span>
                                        <p className="text-xs text-[#1C1C1E]">{aiRes.summary}</p>
                                      </div>
                                      </div>
                                    );
                                  })()}
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>

                      {/* Active Remarks Box */}
                      {selectedProvider.remarks && (
                        <div className="bg-red-50/50 border border-red-200/40 text-red-900 rounded-xl p-4 text-xs font-sans space-y-1">
                          <strong>{selectedProvider.status === 'Suspended' ? 'Active Suspension Remarks:' : 'Active Moderation Remarks:'}</strong>
                          <p className="leading-relaxed">{selectedProvider.remarks}</p>
                        </div>
                      )}

                      {/* Action Decision Toolbar */}
                      <div className="flex flex-col gap-2 pt-4 border-t border-[#D9D2C5]">
                        {allRequiredPassed && (
                          <div className="bg-[#EBF5EE] border border-[#2D5941]/30 text-[#2D5941] p-2.5 rounded-xl text-xs font-bold text-center flex items-center justify-center gap-1.5">
                            <Check className="w-3.5 h-3.5" />
                            <span>All required organization compliance documents verified authentic. Ready for Approval.</span>
                          </div>
                        )}

                        {selectedProvider.status === 'Verified' ? (
                          <>
                            <button
                              type="button"
                              onClick={() => handleVerifyProvider(selectedProvider.id, 'Suspended')}
                              className="w-full bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0 shadow-sm transition-all inline-flex items-center justify-center gap-1.5"
                            >
                              <Ban className="w-3.5 h-3.5" />
                              <span>Suspend Organization with Remarks</span>
                            </button>
                            <p className="text-[10px] text-[#6C6C70] font-sans text-center leading-relaxed">
                              Suspending requires the provider to re-upload and re-submit their verification documents.
                            </p>
                          </>
                        ) : selectedProvider.status === 'Suspended' ? (
                          <div className="space-y-3">
                            <div className="bg-amber-50 border border-amber-200/60 text-amber-900 rounded-2xl p-4 text-xs font-sans leading-relaxed">
                              This provider organization is currently <strong>suspended</strong>. Active remarks: <em>"{selectedProvider.remarks || 'No specific remarks'}"</em>
                            </div>
                            <button
                              type="button"
                              onClick={() => {
                                if (handleReactivateProvider) {
                                  handleReactivateProvider(selectedProvider.id);
                                } else {
                                  handleVerifyProvider(selectedProvider.id, 'Verified');
                                }
                              }}
                              className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold py-3 rounded-xl cursor-pointer border-0 shadow-md transition-all flex items-center justify-center gap-2 font-sans"
                            >
                              <RefreshCw className="w-4 h-4" />
                              <span>Reactivate Organization & Clear Remarks</span>
                            </button>
                          </div>
                        ) : (
                          <div className="flex gap-2">
                            <button
                              type="button"
                              onClick={() => handleVerifyProvider(selectedProvider.id, 'Verified')}
                              className={`flex-1 text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0 shadow-sm transition-all inline-flex items-center justify-center gap-1.5 ${
                                allRequiredPassed
                                  ? 'bg-[#2D5941] hover:bg-[#1A3C2E] ring-2 ring-[#2D5941]/40'
                                  : 'bg-[#2D5941] hover:bg-[#1A3C2E]'
                              }`}
                            >
                              <Check className="w-3.5 h-3.5" />
                              <span>Approve Organization</span>
                            </button>
                            <button
                              type="button"
                              onClick={() => handleVerifyProvider(selectedProvider.id, 'Suspended')}
                              className="flex-1 bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0 shadow-sm transition-all"
                            >
                              Reject / Suspend
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })()}

                {/* Provider's Scholarship Programs Oversight Section */}
                <div className="space-y-3 pt-4 border-t border-[#D9D2C5]">
                  <button
                    type="button"
                    onClick={() => setIsOversightCollapsed(!isOversightCollapsed)}
                    className="w-full flex justify-between items-center text-xs font-bold text-[#1C1C1E] uppercase cursor-pointer border-0 bg-transparent mb-2"
                  >
                    <span>Scholarship Programs Oversight</span>
                    <svg className={`w-3.5 h-3.5 transition-transform duration-200 ${isOversightCollapsed ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  
                  {!isOversightCollapsed && (
                    <>
                      {loadingPrograms ? (
                        <div className="text-xs text-[#6C6C70] italic">Loading programs...</div>
                      ) : providerPrograms.length === 0 ? (
                        <div className="text-xs text-[#6C6C70] italic bg-white p-3 rounded-xl border border-[#D9D2C5]/50">No scholarship programs configured yet.</div>
                      ) : (
                        <div className="space-y-2 max-h-48 overflow-y-auto pr-1 mt-2">
                          {providerPrograms.map((prog) => (
                            <div key={prog.id} className="p-3 bg-white rounded-xl border border-[#D9D2C5]/50 text-xs flex justify-between items-center shadow-sm">
                              <div className="space-y-0.5">
                                <div className="font-bold text-[#1A3C2E] truncate max-w-[130px]" title={prog.title}>{prog.title}</div>
                                <div className="text-[10px] text-[#6C6C70]">Slots: {prog.total_slots || 'Unlimited'} • {prog.funding_frequency}</div>
                              </div>
                              <div className="flex items-center gap-1.5">
                                <span className={`text-[9px] font-bold px-2 py-0.5 rounded ${
                                  prog.status === 'Active' || prog.status === 'active' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                                  prog.status === 'Closed' || prog.status === 'closed' ? 'bg-red-50 text-[#B34040]' :
                                  'bg-[#EDE8DE] text-[#6C6C70]'
                                }`}>
                                  {prog.status}
                                </span>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    try {
                                      const { data: fullProg } = await supabase
                                        .from('scholarship_programs')
                                        .select(`
                                          *,
                                          provider ( name ),
                                          scholarship_categories ( name )
                                        `)
                                        .eq('id', prog.id)
                                        .single();

                                      if (fullProg) {
                                        setSelectedScholarshipDetails(fullProg);
                                        setActiveTab('scholarships');
                                      }
                                    } catch (e) {
                                      console.error(e);
                                    }
                                  }}
                                  className="bg-[#2D5941] text-white hover:bg-[#1A3C2E] px-2 py-1 rounded text-[9px] font-bold cursor-pointer border-0"
                                >
                                  View
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </>
                  )}
                </div>
              </div>
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-center py-12 text-[#8E8E93]">
                <svg className="w-10 h-10 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <p className="text-xs font-medium">Select a Provider from the pipeline to verify details with AI.</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

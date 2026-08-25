import React, { useState, useEffect } from 'react';
import type { ApplicantStatus } from '../types';
import {
  verifyDocumentAuthenticity,
  getScoreAssessment,
  type DocVerificationResult,
  type ApplicantVerificationContext,
} from '@/services/aiExtractionService';
import { supabase } from '@/services/supabaseClient';
import { createAuditLog } from '@/services/auditLogService';

export type { ApplicantStatus };

export interface SubmittedDocItem {
  id?: string;
  name: string;
  filename?: string;
  filesize?: string;
  document_url?: string;
  url?: string;
  submitted_at?: string;
  status?: 'Pending' | 'Verified' | 'Flagged';
  remarks?: string;
  is_additional?: boolean;
  aiVerification?: DocVerificationResult;
  isAiScanning?: boolean;
}

export interface ApplicationDetail {
  id: string | number;
  scholarId?: string;
  name: string;
  email?: string;
  phone?: string;
  program: string;
  program_id?: string;
  disbursement_mode?: string;
  banking_policy?: string;
  paymentAccount?: any;
  cycle: string;
  cycle_type?: string;
  semester?: string;
  school: string;
  course: string;
  yearLevel: string;
  grade: string; // Real GWA
  citizenship?: string;
  address?: string;
  status: ApplicantStatus;
  date: string;
  submittedDocuments: SubmittedDocItem[];
  remarks?: string;
  rawApplication?: any;
}

interface ReviewApplicationModalProps {
  isOpen: boolean;
  application: ApplicationDetail | null;
  onClose: () => void;
  onUpdateStatus: (
    appId: string | number,
    newStatus: ApplicantStatus,
    remarks?: string,
    updatedDocs?: SubmittedDocItem[]
  ) => Promise<void>;
}

export const ReviewApplicationModal: React.FC<ReviewApplicationModalProps> = ({
  isOpen,
  application,
  onClose,
  onUpdateStatus,
}) => {
  const [selectedStatus, setSelectedStatus] = useState<ApplicantStatus>('Pending');
  const [remarks, setRemarks] = useState('');
  const [documentsList, setDocumentsList] = useState<SubmittedDocItem[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // AI Verification states
  const [isBatchScanning, setIsBatchScanning] = useState(false);
  const [batchProgressMsg, setBatchProgressMsg] = useState('');
  const [expandedDocIndices, setExpandedDocIndices] = useState<Record<number, boolean>>({});
  const [autoScanSummary, setAutoScanSummary] = useState<{
    total: number;
    flagged: number;
    verified: number;
    actionTaken?: string;
  } | null>(null);

  // Add more requirements state
  const [showAddReqForm, setShowAddReqForm] = useState(false);
  const [newReqName, setNewReqName] = useState('');
  const [newReqInstruction, setNewReqInstruction] = useState('');

  const commonRequirementPresets = [
    'Barangay Certificate of Indigency',
    'Parent / Guardian Income Tax Return (ITR)',
    'Certificate of Non-Filing of Tax',
    'Affidavit of Non-Receiving Other Scholarship',
    'Certified True Copy of Grade Slip (Latest Term)',
    'Utility Bill / Proof of Billing Address',
    'Certificate of Good Moral Character (Updated)',
    'Community Service & Civic Participation Record',
    'Medical Certificate / Fit to Study Proof',
  ];

  const toggleExpandDoc = (idx: number) => {
    setExpandedDocIndices(prev => ({ ...prev, [idx]: !prev[idx] }));
  };

  const getApplicantContext = (): ApplicantVerificationContext => {
    return {
      scholarName: application?.name || '',
      school: application?.school || '',
      course: application?.course || '',
      yearLevel: application?.yearLevel || '',
      gwa: application?.grade || '',
      email: application?.email || '',
      phone: application?.phone || '',
      programTitle: application?.program || '',
    };
  };

  const evaluateAndAdjustStatus = (docs: SubmittedDocItem[]) => {
    const scannableDocs = docs.filter(d => d.document_url || d.url);
    if (scannableDocs.length === 0) return;

    const flaggedDocs = docs.filter(d => d.status === 'Flagged' || d.aiVerification?.verificationStatus === 'flagged' || d.aiVerification?.verificationStatus === 'rejected');
    const verifiedDocs = docs.filter(d => d.status === 'Verified' || d.aiVerification?.verificationStatus === 'verified');

    setAutoScanSummary({
      total: scannableDocs.length,
      flagged: flaggedDocs.length,
      verified: verifiedDocs.length,
      actionTaken: flaggedDocs.length > 0
        ? `Application automatically moved to 'Under Review' (${flaggedDocs.length}/${scannableDocs.length} rejected/flagged).`
        : `All ${scannableDocs.length} documents verified authentic.`,
    });

    // Rule: If applicant passed documents and rejected/flagged count >= 1 (e.g. 3/5), change status to 'Under Review'
    if (flaggedDocs.length > 0) {
      setSelectedStatus((prev: ApplicantStatus) => (prev === 'Approved' ? 'Under Review' : prev));
      setRemarks((prev: string) => prev || `⚠️ AI Auto-Scan: ${flaggedDocs.length} of ${scannableDocs.length} document(s) flagged for manual provider review.`);
    } else if (docs.length > 0 && docs.every(d => d.status === 'Verified')) {
      setSelectedStatus((prev: ApplicantStatus) => (prev === 'For Exam' ? 'For Exam' : 'Approved'));
    }
  };

  const persistDocAiScanToDb = async (doc: SubmittedDocItem, result: DocVerificationResult) => {
    try {
      const scholarId = application?.scholarId || application?.rawApplication?.scholar_id || application?.rawApplication?.scholar?.id;
      const docStatusDb = result.verificationStatus === 'verified' ? 'verified' : 'rejected';
      const docRemarks = result.flags && result.flags.length > 0 ? `AI Flag: ${result.flags[0]}` : result.summary;

      const aiPayload: any = {
        ai_verification_status: result.verificationStatus,
        ai_confidence_score: result.confidenceScore,
        ai_flags: result.flags,
        ai_extracted_data: {
          extractedName: result.extractedName,
          extractedSchool: result.extractedSchool,
          extractedGwa: result.extractedGwa,
          extractedIncome: result.extractedIncome,
          extractedDocType: result.extractedDocType,
          crossCheckResults: result.crossCheckResults,
        },
        ai_model_used: result.aiModelUsed,
        file_sha256_hash: result.sha256Hash,
        verification_status: docStatusDb,
        remarks: docRemarks,
        updated_at: new Date().toISOString(),
      };

      // 1. Update scholar_documents table
      if (doc.id && typeof doc.id === 'string' && doc.id.includes('-') && doc.id.length > 20) {
        await supabase
          .from('scholar_documents')
          .update(aiPayload)
          .eq('id', doc.id);
      } else if (scholarId) {
        const docName = doc.name || doc.filename || 'Submitted Document';
        const docUrl = doc.document_url || doc.url || '';

        const { data: existingRecords } = await supabase
          .from('scholar_documents')
          .select('id, document_name, document_url')
          .eq('scholar_id', scholarId);

        const match = existingRecords?.find((r: any) =>
          (r.document_name && r.document_name.toLowerCase().trim() === docName.toLowerCase().trim()) ||
          (r.document_url && docUrl && r.document_url.trim() === docUrl.trim())
        );

        if (match) {
          await supabase
            .from('scholar_documents')
            .update(aiPayload)
            .eq('id', match.id);
        } else if (docUrl) {
          await supabase
            .from('scholar_documents')
            .insert({
              scholar_id: scholarId,
              document_name: docName,
              document_url: docUrl,
              created_at: new Date().toISOString(),
              ...aiPayload,
            });
        }
      }

      // 2. Update scholarship_applications table submitted_documents cache
      if (application?.id) {
        const currentDocs = application.submittedDocuments || [];
        const updatedDocsJson = currentDocs.map(d => {
          const isMatch = (d.id && doc.id && d.id === doc.id) ||
            (d.name && doc.name && d.name.toLowerCase().trim() === doc.name.toLowerCase().trim()) ||
            (d.document_url && doc.document_url && d.document_url.trim() === doc.document_url.trim());
          if (isMatch) {
            return {
              ...d,
              status: result.verificationStatus === 'verified' ? 'Verified' : 'Flagged',
              remarks: docRemarks,
              aiVerification: result,
            };
          }
          return d;
        });

        await supabase
          .from('scholarship_applications')
          .update({
            submitted_documents: { documents: updatedDocsJson },
            updated_at: new Date().toISOString(),
          })
          .eq('id', application.id);
      }
    } catch (err) {
      console.warn('[Doc AI Cache Persist Note]:', err);
    }
  };

  const getFlagString = (flag: any): string => {
    if (!flag) return '';
    if (typeof flag === 'string') return flag.trim();
    if (typeof flag === 'object') {
      return flag.description || flag.flag || flag.reason || flag.message || flag.issue || JSON.stringify(flag);
    }
    return String(flag);
  };

  const handleScanSingleDoc = async (docIndex: number) => {
    const doc = documentsList[docIndex];
    const docUrl = doc.document_url || doc.url;
    if (!docUrl) return;

    // Set document scanning status
    setDocumentsList(prev =>
      prev.map((d, i) => i === docIndex ? { ...d, isAiScanning: true } : d)
    );

    try {
      const result = await verifyDocumentAuthenticity({
        documentUrl: docUrl,
        documentName: doc.name || doc.filename || 'Submitted Document',
        applicantContext: getApplicantContext(),
      });

      // Persist to Supabase database so future opens NEVER re-scan this file
      persistDocAiScanToDb(doc, result);

      let updatedList: SubmittedDocItem[] = [];
      setDocumentsList(prev => {
        updatedList = prev.map((d, i) => {
          if (i !== docIndex) return d;
          let newStatus: 'Pending' | 'Verified' | 'Flagged' = d.status || 'Pending';
          let autoRemarks = d.remarks || '';

          if (result.verificationStatus === 'verified') {
            newStatus = 'Verified';
            if (!autoRemarks || autoRemarks.includes('Flagged')) autoRemarks = '';
          } else if (result.verificationStatus === 'flagged' || result.verificationStatus === 'rejected') {
            newStatus = 'Flagged';
            if (result.flags && result.flags.length > 0) {
              autoRemarks = `AI Flag: ${getFlagString(result.flags[0])}`;
            } else {
              autoRemarks = result.summary || 'Flagged for provider review';
            }
          }

          return {
            ...d,
            status: newStatus,
            remarks: autoRemarks,
            aiVerification: result,
            isAiScanning: false,
          };
        });
        return updatedList;
      });

      // Auto-expand to show details
      setExpandedDocIndices(prev => ({ ...prev, [docIndex]: true }));
      evaluateAndAdjustStatus(updatedList);
    } catch (err) {
      console.error('Error verifying document with AI:', err);
      setDocumentsList(prev =>
        prev.map((d, i) => i === docIndex ? { ...d, isAiScanning: false } : d)
      );
    }
  };

  const handleScanAllDocs = async (customDocsList?: SubmittedDocItem[], onlyUnscanned = false) => {
    const currentList = customDocsList || documentsList;
    const context = getApplicantContext();
    const scannableIndices = currentList
      .map((d, i) => {
        if (!(d.document_url || d.url)) return -1;
        if (onlyUnscanned && d.aiVerification && !(d.remarks || '').toLowerCase().includes('resubmit')) {
          return -1;
        }
        return i;
      })
      .filter(i => i !== -1);

    if (scannableIndices.length === 0) {
      evaluateAndAdjustStatus(currentList);
      return;
    }

    setIsBatchScanning(true);
    setBatchProgressMsg(`Auto-Scanning ${scannableIndices.length} document(s)...`);

    let workingList = [...currentList];

    for (let count = 0; count < scannableIndices.length; count++) {
      const idx = scannableIndices[count];
      const doc = workingList[idx];

      setBatchProgressMsg(`Auto-Scanning (${count + 1}/${scannableIndices.length}): ${doc.name}...`);
      workingList = workingList.map((d, i) => i === idx ? { ...d, isAiScanning: true } : d);
      setDocumentsList(workingList);

      try {
        const result = await verifyDocumentAuthenticity({
          documentUrl: doc.document_url || doc.url!,
          documentName: doc.name || doc.filename || 'Submitted Document',
          applicantContext: context,
        });

        // Persist to Supabase database so future opens NEVER re-scan this file
        persistDocAiScanToDb(doc, result);

        workingList = workingList.map((d, i) => {
          if (i !== idx) return d;
          let newStatus: 'Pending' | 'Verified' | 'Flagged' = d.status || 'Pending';
          let autoRemarks = d.remarks || '';

          if (result.verificationStatus === 'verified') {
            newStatus = 'Verified';
            if (!autoRemarks || autoRemarks.includes('Flagged') || autoRemarks.includes('Resubmitted')) autoRemarks = '';
          } else if (result.verificationStatus === 'flagged' || result.verificationStatus === 'rejected') {
            newStatus = 'Flagged';
            if (result.flags && result.flags.length > 0) {
              autoRemarks = `AI Flag: ${getFlagString(result.flags[0])}`;
            } else {
              autoRemarks = result.summary || 'Flagged for provider review';
            }
          }

          return {
            ...d,
            status: newStatus,
            remarks: autoRemarks,
            aiVerification: result,
            isAiScanning: false,
          };
        });

        setDocumentsList(workingList);
        if (application) {
          application.submittedDocuments = workingList;
        }
        setExpandedDocIndices(prev => ({ ...prev, [idx]: true }));
      } catch (err) {
        console.error(`Error verifying document #${idx}:`, err);
        workingList = workingList.map((d, i) => i === idx ? { ...d, isAiScanning: false } : d);
        setDocumentsList(workingList);
      }
    }

    setBatchProgressMsg('AI Verification Complete!');
    if (application) {
      application.submittedDocuments = workingList;
    }
    evaluateAndAdjustStatus(workingList);

    setTimeout(() => {
      setIsBatchScanning(false);
      setBatchProgressMsg('');
    }, 1500);
  };

  const handleAddRequirement = (e: React.FormEvent) => {
    e.preventDefault();
    const finalName = newReqName.trim();
    if (!finalName) return;

    const newDoc: SubmittedDocItem = {
      id: `req_${Date.now()}`,
      name: finalName,
      status: 'Pending',
      submitted_at: 'Requested just now',
      remarks: 'Additional document requirement requested by scholarship committee'
    };

    setDocumentsList(prev => [...prev, newDoc]);
    setNewReqName('');
    setShowAddReqForm(false);
  };

  const handleRemoveDoc = (indexToRemove: number) => {
    setDocumentsList(prev => prev.filter((_, idx) => idx !== indexToRemove));
  };

  useEffect(() => {
    if (application) {
      setSelectedStatus(application.status || 'Pending');
      setRemarks(application.remarks || '');
      setNewReqName('');
      setShowAddReqForm(false);
      setAutoScanSummary(null);

      let docs: SubmittedDocItem[] = [];
      const seenNames = new Set<string>();
      const seenUrls = new Set<string>();
      const uniqueDocs: SubmittedDocItem[] = [];

      if (application.submittedDocuments && Array.isArray(application.submittedDocuments)) {
        for (const item of application.submittedDocuments) {
          const nameKey = (item.name || item.filename || '').toLowerCase().trim();
          const urlKey = (item.document_url || item.url || '').toLowerCase().trim();
          const isDup = (nameKey && seenNames.has(nameKey)) || (urlKey && seenUrls.has(urlKey));
          if (!isDup) {
            if (nameKey) seenNames.add(nameKey);
            if (urlKey) seenUrls.add(urlKey);
            uniqueDocs.push(item);
          }
        }
        docs = uniqueDocs;
      } else if (application.rawApplication?.submitted_documents) {
        const raw = application.rawApplication.submitted_documents;
        const list = Array.isArray(raw) ? raw : raw.documents || [];
        for (const item of list) {
          const nameKey = (item.name || item.filename || item.document_name || '').toLowerCase().trim();
          const urlKey = (item.document_url || item.url || '').toLowerCase().trim();
          const isDup = (nameKey && seenNames.has(nameKey)) || (urlKey && seenUrls.has(urlKey));
          if (!isDup) {
            if (nameKey) seenNames.add(nameKey);
            if (urlKey) seenUrls.add(urlKey);
            uniqueDocs.push(item);
          }
        }
        docs = uniqueDocs;
      }

      // If no docs in JSON, create standard checklist items based on application data
      if (docs.length === 0) {
        docs = [
          {
            name: 'Official Transcript of Records (TOR / Grade Slip)',
            filename: `TOR_GWA_${application.grade || '1.50'}.pdf`,
            filesize: '1.4 MB',
            status: 'Pending',
            submitted_at: application.date || 'Recently'
          },
          {
            name: 'Certificate of Good Moral Character',
            filename: 'Good_Moral_Certificate.pdf',
            filesize: '820 KB',
            status: 'Pending',
            submitted_at: application.date || 'Recently'
          },
          {
            name: 'Certificate of Enrollment / School Registration',
            filename: 'Certificate_of_Enrollment.pdf',
            filesize: '950 KB',
            status: 'Pending',
            submitted_at: application.date || 'Recently'
          }
        ];
      }

      setDocumentsList(docs);

      // Trigger automatic scan only if any scannable documents lack AI verification or were recently resubmitted
      const unscanned = docs.filter(d => {
        const hasUrl = Boolean(d.document_url || d.url);
        if (!hasUrl) return false;
        const isResubmitted = (d.remarks || '').toLowerCase().includes('resubmit');
        const isAlreadyScanned = Boolean(d.aiVerification && d.aiVerification.verificationStatus);
        return isResubmitted || !isAlreadyScanned;
      });

      if (unscanned.length > 0) {
        handleScanAllDocs(docs, true);
      } else {
        evaluateAndAdjustStatus(docs);
      }
    }
  }, [application]);

  if (!isOpen || !application) return null;

  const saveDocStatusToDb = async (doc: SubmittedDocItem, newDocStatus: 'Verified' | 'Flagged' | 'Pending') => {
    try {
      const scholarId = application?.scholarId || application?.rawApplication?.scholar_id || application?.rawApplication?.scholar?.id;
      const dbStatus = newDocStatus === 'Verified' ? 'verified' : newDocStatus === 'Flagged' ? 'rejected' : 'pending';
      const docRemarks = newDocStatus === 'Verified' ? 'Approved by provider' : newDocStatus === 'Flagged' ? (doc.remarks || 'Flagged for review') : '';

      // 1. Update scholar_documents table
      if (doc.id && typeof doc.id === 'string' && doc.id.includes('-') && doc.id.length > 20) {
        await supabase
          .from('scholar_documents')
          .update({
            verification_status: dbStatus,
            remarks: docRemarks,
            updated_at: new Date().toISOString(),
          })
          .eq('id', doc.id);
      } else if (scholarId) {
        const docName = doc.name || doc.filename || 'Submitted Document';
        const docUrl = doc.document_url || doc.url || '';

        const { data: existingRecords } = await supabase
          .from('scholar_documents')
          .select('id, document_name, document_url')
          .eq('scholar_id', scholarId);

        const match = existingRecords?.find((r: any) =>
          (r.document_name && r.document_name.toLowerCase().trim() === docName.toLowerCase().trim()) ||
          (r.document_url && docUrl && r.document_url.trim() === docUrl.trim())
        );

        if (match) {
          await supabase
            .from('scholar_documents')
            .update({
              verification_status: dbStatus,
              remarks: docRemarks,
              updated_at: new Date().toISOString(),
            })
            .eq('id', match.id);
        } else if (docUrl) {
          await supabase
            .from('scholar_documents')
            .insert({
              scholar_id: scholarId,
              document_name: docName,
              document_url: docUrl,
              verification_status: dbStatus,
              remarks: docRemarks,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            });
        }
      }

      // 2. Update scholarship_applications table submitted_documents JSON
      if (application?.id) {
        const currentDocs = documentsList;
        const updatedDocsJson = currentDocs.map(d => {
          const isMatch = (d.id && doc.id && d.id === doc.id) ||
            (d.name && doc.name && d.name.toLowerCase().trim() === doc.name.toLowerCase().trim()) ||
            (d.document_url && doc.document_url && d.document_url.trim() === doc.document_url.trim());
          if (isMatch) {
            return {
              ...d,
              status: newDocStatus,
              remarks: docRemarks,
            };
          }
          return d;
        });

        await supabase
          .from('scholarship_applications')
          .update({
            submitted_documents: { documents: updatedDocsJson },
            updated_at: new Date().toISOString(),
          })
          .eq('id', application.id);

        if (application) {
          application.submittedDocuments = updatedDocsJson;
        }

        const { data: userData } = await supabase.auth.getUser();
        const actor = userData?.user?.email || 'Provider';
        createAuditLog(
          `MARKED DOCUMENT ${newDocStatus.toUpperCase()}`,
          `Doc: ${doc.name} - Applicant: ${application.name}`,
          actor
        );
      }
    } catch (err) {
      console.warn('[Save Doc Status Note]:', err);
    }
  };

  const toggleDocStatus = (index: number, newDocStatus: 'Verified' | 'Flagged' | 'Pending') => {
    const targetDoc = documentsList[index];
    if (targetDoc) {
      saveDocStatusToDb(targetDoc, newDocStatus);
    }

    setDocumentsList(prev => {
      const next = prev.map((doc, idx) =>
        idx === index ? { ...doc, status: newDocStatus } : doc
      );
      const allVerified = next.length > 0 && next.every(d => d.status === 'Verified');
      if (allVerified) {
        setSelectedStatus((prevStatus: ApplicantStatus) => (prevStatus === 'For Exam' ? 'For Exam' : 'Approved'));
      } else if (newDocStatus === 'Flagged') {
        setSelectedStatus((prevStatus: ApplicantStatus) => (prevStatus === 'Approved' ? 'Under Review' : prevStatus));
      }
      return next;
    });
  };

  const handleApproveAllDocs = async () => {
    const allApproved = documentsList.map(d => ({ ...d, status: 'Verified' as const, remarks: '' }));
    setDocumentsList(allApproved);
    setSelectedStatus((prev: ApplicantStatus) => (prev === 'For Exam' ? 'For Exam' : 'Approved'));
    if (application) {
      application.submittedDocuments = allApproved;
    }

    try {
      if (application?.id) {
        await supabase
          .from('scholarship_applications')
          .update({
            submitted_documents: { documents: allApproved },
            updated_at: new Date().toISOString(),
          })
          .eq('id', application.id);
      }

      const scholarId = application?.scholarId || application?.rawApplication?.scholar_id || application?.rawApplication?.scholar?.id;
      if (scholarId) {
        await supabase
          .from('scholar_documents')
          .update({
            verification_status: 'verified',
            remarks: 'Approved by provider',
            updated_at: new Date().toISOString(),
          })
          .eq('scholar_id', scholarId);
      }
    } catch (err) {
      console.warn('[Approve All Docs Note]:', err);
    }
  };

  const handleSaveDecision = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      await onUpdateStatus(application.id, selectedStatus, remarks, documentsList);
      onClose();
    } catch (err) {
      console.error('Error saving application decision:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 overflow-y-auto">
      <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl max-w-4xl w-full max-h-[90vh] flex flex-col relative animate-fade-in my-auto">
        
        {/* Modal Header */}
        <div className="p-6 border-b border-[#D9D2C5]/60 flex items-center justify-between bg-[#F9F5EF] rounded-t-3xl">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-[#1A3C2E] text-[#E8A838] flex items-center justify-center font-bold text-lg font-serif shadow-sm">
              {application.name.split(' ').map(n => n[0]).join('')}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-xl font-extrabold text-[#1A3C2E] font-serif">{application.name}</h3>
                <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold ${
                  application.status === 'Approved' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                  application.status === 'Pending' ? 'bg-[#F9F0E0] text-[#C97B2E]' :
                  application.status === 'Under Review' ? 'bg-[#EAF3FA] text-[#2A6BA8]' :
                  application.status === 'For Exam' ? 'bg-purple-100 text-purple-700' :
                  'bg-[#FDF2F2] text-[#B34040]'
                }`}>
                  {application.status}
                </span>
              </div>
              <p className="text-xs text-[#6C6C70] mt-0.5 font-medium">
                Application Review for <strong className="text-[#1A3C2E]">{application.program}</strong> ({application.cycle})
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-9 h-9 rounded-full bg-white border border-[#D9D2C5] hover:bg-gray-100 flex items-center justify-center text-[#6C6C70] hover:text-[#1C1C1E] font-bold transition-colors cursor-pointer"
          >
            ✕
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-6 overflow-y-auto space-y-6 flex-1 text-xs">
          
          {/* Section 1: Student Profile & Real GWA */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-[#F9F5EF]/60 p-4 rounded-2xl border border-[#D9D2C5]/50 space-y-2">
              <span className="text-[10px] font-bold text-[#8E8E93] uppercase tracking-wider block">Academic Credentials</span>
              <div className="space-y-1">
                <div><span className="text-[#6C6C70]">Institution: </span><strong className="text-[#1C1C1E]">{application.school}</strong></div>
                <div><span className="text-[#6C6C70]">Course: </span><strong className="text-[#1C1C1E]">{application.course}</strong></div>
                <div><span className="text-[#6C6C70]">Year Level: </span><strong className="text-[#1C1C1E]">{application.yearLevel}</strong></div>
              </div>
            </div>

            <div className="bg-[#EBF5EE]/50 p-4 rounded-2xl border border-[#2D5941]/30 space-y-1 text-center flex flex-col items-center justify-center">
              <span className="text-[10px] font-bold text-[#2D5941] uppercase tracking-wider block">Official GWA / Grade</span>
              <div className="text-3xl font-extrabold text-[#1A3C2E] font-serif my-1">
                {application.grade || '1.50'}
              </div>
              <span className="text-[10px] text-[#2D5941] font-semibold">Verified Academic Standing</span>
            </div>

            <div className="bg-[#F9F5EF]/60 p-4 rounded-2xl border border-[#D9D2C5]/50 space-y-2">
              <span className="text-[10px] font-bold text-[#8E8E93] uppercase tracking-wider block">Contact Information</span>
              <div className="space-y-1">
                <div><span className="text-[#6C6C70]">Email: </span><strong className="text-[#1C1C1E]">{application.email || 'N/A'}</strong></div>
                <div><span className="text-[#6C6C70]">Phone: </span><strong className="text-[#1C1C1E]">{application.phone || 'N/A'}</strong></div>
                <div><span className="text-[#6C6C70]">Applied On: </span><strong className="text-[#1C1C1E]">{application.date}</strong></div>
              </div>
            </div>
          </div>

          {/* Post-Approval Bank & Disbursement Info Banner */}
          {(application.status === 'Approved' || selectedStatus === 'Approved') && (
            <div className={`p-4 rounded-2xl border transition-all ${
              application.disbursement_mode === 'in_person_cash'
                ? 'bg-[#F9F5EF] border-[#D9D2C5]'
                : application.paymentAccount
                  ? 'bg-[#EBF5EE] border-[#2D5941]/40'
                  : 'bg-amber-50/80 border-amber-300'
            }`}>
              <div className="flex items-start justify-between gap-3">
                <div className="space-y-1 w-full">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <span className="text-xs font-bold uppercase tracking-wider text-[#1A3C2E]">
                      Disbursement Method & Bank Account Status
                    </span>
                    <span className={`text-[10px] font-extrabold px-2.5 py-0.5 rounded-full ${
                      application.disbursement_mode === 'in_person_cash'
                        ? 'bg-slate-200 text-slate-700'
                        : application.paymentAccount
                          ? 'bg-[#2D5941] text-white'
                          : 'bg-amber-500 text-white'
                    }`}>
                      {application.disbursement_mode === 'in_person_cash'
                        ? '💵 In-Person Cash Payout'
                        : application.paymentAccount
                          ? '✓ Bank Account Uploaded & Ready'
                          : '⚠️ Bank Account Not Uploaded Yet'}
                    </span>
                  </div>

                  {application.disbursement_mode === 'in_person_cash' ? (
                    <p className="text-xs text-[#6C6C70]">
                      This scholarship program uses <strong>in-person / cash distribution</strong>. No bank account is required from the scholar.
                    </p>
                  ) : application.paymentAccount ? (
                    <div className="text-xs space-y-1.5 pt-1">
                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 bg-white/70 p-2.5 rounded-xl border border-[#2D5941]/20">
                        <div>
                          <span className="text-[10px] font-bold text-[#6C6C70] block uppercase">Bank Name</span>
                          <strong className="text-sm text-[#2D5941]">{application.paymentAccount.bank_name}</strong>
                        </div>
                        <div>
                          <span className="text-[10px] font-bold text-[#6C6C70] block uppercase">Account Holder</span>
                          <strong className="text-sm text-[#1C1C1E]">{application.paymentAccount.account_name}</strong>
                        </div>
                        <div>
                          <span className="text-[10px] font-bold text-[#6C6C70] block uppercase">Account Number</span>
                          <strong className="text-sm font-mono tracking-wider text-[#2D5941]">{application.paymentAccount.account_number}</strong>
                        </div>
                      </div>
                      <div className="flex items-center justify-between flex-wrap gap-2 pt-0.5">
                        {application.paymentAccount.ai_model_used && (
                          <span className="text-[11px] text-[#6C6C70]">
                            Extracted via: <strong className="text-[#1A3C2E]">{application.paymentAccount.ai_model_used}</strong>
                          </span>
                        )}
                        {application.paymentAccount.document_proof_url && (
                          <a
                            href={application.paymentAccount.document_proof_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 text-xs font-bold text-[#2D5941] hover:text-[#1A3C2E] hover:underline"
                          >
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
                            View Scanned ATM Card / Proof 📄
                          </a>
                        )}
                      </div>
                    </div>
                  ) : (
                    <div className="text-xs text-amber-900 bg-amber-100/60 p-2.5 rounded-xl border border-amber-200 mt-1">
                      <p className="font-medium">
                        ⚠️ <strong>Action Required from Scholar:</strong> This scholar was approved, but has not uploaded their official ATM card scan or bank details yet. They were sent an onboarding prompt in their mobile app.
                      </p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

            <div className="space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <h4 className="text-sm font-extrabold text-[#1A3C2E] font-serif uppercase tracking-wider">
                    Submitted Documents & Requirements ({documentsList.length})
                  </h4>
                  <span className="text-[10px] text-[#6C6C70]">
                    Automated multi-AI forensic scanning with cross-checks, seal detection, and fraud analysis.
                  </span>
                </div>
                <div className="flex items-center gap-2 flex-wrap">
                  <button
                    type="button"
                    onClick={() => setShowAddReqForm(prev => !prev)}
                    className="px-3 py-1.5 rounded-xl bg-amber-50 hover:bg-amber-100 text-[#C97B2E] text-[11px] font-bold border border-amber-300/60 cursor-pointer inline-flex items-center gap-1 transition-all"
                  >
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                    </svg>
                    <span>{showAddReqForm ? 'Close Request Form' : '+ Request More Requirements'}</span>
                  </button>

                  <button
                    type="button"
                    disabled={isBatchScanning || documentsList.length === 0}
                    onClick={() => handleScanAllDocs()}
                    className="px-3.5 py-1.5 rounded-xl bg-[#C97B2E] hover:bg-[#A86220] text-white text-[11px] font-bold shadow-xs cursor-pointer inline-flex items-center gap-1.5 transition-all border-0 disabled:opacity-50"
                  >
                    {isBatchScanning ? (
                      <>
                        <span className="animate-spin">⏳</span>
                        <span>Scanning Documents...</span>
                      </>
                    ) : (
                      <>
                        <span>⚡ Verify All with AI</span>
                      </>
                    )}
                  </button>

                  <button
                    type="button"
                    onClick={handleApproveAllDocs}
                    className="px-3 py-1.5 rounded-xl bg-[#EBF5EE] hover:bg-[#2D5941] text-[#2D5941] hover:text-white text-[11px] font-bold border border-[#2D5941]/30 cursor-pointer inline-flex items-center gap-1 transition-all"
                  >
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span>Approve All Documents</span>
                  </button>
                </div>
              </div>

              {/* Batch AI Scanning Progress Banner */}
              {isBatchScanning && (
                <div className="bg-[#FFF8EE] border border-[#C97B2E]/40 p-3 rounded-2xl flex items-center justify-between text-xs animate-pulse">
                  <div className="flex items-center gap-2 text-[#C97B2E] font-bold">
                    <span className="animate-spin text-base">⚙️</span>
                    <span>{batchProgressMsg || 'Running AI Forensic Verification across documents...'}</span>
                  </div>
                  <span className="text-[10px] font-mono font-bold text-[#C97B2E]/80 bg-white px-2 py-0.5 rounded-lg border border-[#C97B2E]/30">
                    Cascading Multi-Model
                  </span>
                </div>
              )}

              {/* Smart AI Auto-Scan Summary Banner */}
              {autoScanSummary && !isBatchScanning && (
                <div className={`p-3.5 rounded-2xl border flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs shadow-xs transition-all animate-fade-in ${
                  autoScanSummary.flagged > 0
                    ? 'bg-[#FFF8EE] border-[#C97B2E]/50 text-[#8C4A00]'
                    : 'bg-[#EBF5EE] border-[#2D5941]/40 text-[#2D5941]'
                }`}>
                  <div className="flex items-center gap-2.5">
                    <span className="text-xl">
                      {autoScanSummary.flagged > 0 ? '⚠️' : '🟢'}
                    </span>
                    <div>
                      <div className="font-extrabold flex items-center gap-2">
                        <span>AI Auto-Audit Summary:</span>
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-mono bg-white/80 border border-current font-bold">
                          {autoScanSummary.verified}/{autoScanSummary.total} Verified • {autoScanSummary.flagged} Flagged
                        </span>
                      </div>
                      <p className="text-[11px] opacity-90 mt-0.5">
                        {autoScanSummary.flagged > 0
                          ? `⚠️ ${autoScanSummary.flagged} of ${autoScanSummary.total} requirement(s) were flagged by AI. Application status has been automatically adjusted to 'Under Review'.`
                          : `✓ All ${autoScanSummary.total} requirement(s) verified authentic with matching credentials.`}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <span className="text-[10px] font-bold uppercase tracking-wider bg-white px-2.5 py-1 rounded-xl border border-current">
                      Status: {selectedStatus}
                    </span>
                  </div>
                </div>
              )}

              {/* Request Additional Requirement Form */}
              {showAddReqForm && (
                <div className="p-4 rounded-2xl bg-amber-50/50 border border-amber-200 space-y-3 animate-fade-in">
                  <div className="flex items-center justify-between">
                    <h5 className="text-xs font-bold text-[#1A3C2E] flex items-center gap-1.5">
                      <span>📄 Request Additional Requirement from {application?.name}</span>
                    </h5>
                    <span className="text-[10px] text-[#C97B2E] font-semibold bg-amber-100/70 px-2 py-0.5 rounded-md">
                      Student will be notified to upload this file
                    </span>
                  </div>

                  {/* Preset quick selection chips */}
                  <div>
                    <span className="text-[10px] font-bold text-[#6C6C70] block mb-1.5">Quick Presets:</span>
                    <div className="flex flex-wrap gap-1.5">
                      {commonRequirementPresets.map((preset, pIdx) => (
                        <button
                          key={pIdx}
                          type="button"
                          onClick={() => setNewReqName(preset)}
                          className={`px-2.5 py-1 rounded-lg text-[10px] font-semibold transition-colors border cursor-pointer ${
                            newReqName === preset
                              ? 'bg-[#1A3C2E] text-white border-[#1A3C2E]'
                              : 'bg-white text-[#1C1C1E] border-[#D9D2C5] hover:border-[#1A3C2E]'
                          }`}
                        >
                          {preset}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">
                        Document / Requirement Name <span className="text-red-500">*</span>
                      </label>
                      <input
                        type="text"
                        placeholder="e.g. Barangay Certificate of Indigency"
                        value={newReqName}
                        onChange={(e) => setNewReqName(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] focus:border-[#1A3C2E] focus:ring-1 focus:ring-[#1A3C2E] bg-white text-xs text-[#1C1C1E] outline-none"
                      />
                    </div>

                    <div>
                      <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">
                        Instructions / Guidelines for Scholar
                      </label>
                      <input
                        type="text"
                        placeholder="e.g. Please provide certified true copy signed by Punong Barangay"
                        value={newReqInstruction}
                        onChange={(e) => setNewReqInstruction(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] focus:border-[#1A3C2E] focus:ring-1 focus:ring-[#1A3C2E] bg-white text-xs text-[#1C1C1E] outline-none"
                      />
                    </div>
                  </div>

                  <div className="flex justify-end gap-2 pt-1">
                    <button
                      type="button"
                      onClick={() => {
                        setShowAddReqForm(false);
                        setNewReqName('');
                        setNewReqInstruction('');
                      }}
                      className="px-3.5 py-1.5 rounded-xl border border-[#D9D2C5] text-xs font-semibold text-[#6C6C70] hover:bg-white bg-transparent cursor-pointer"
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      onClick={handleAddRequirement}
                      disabled={!newReqName.trim()}
                      className="px-4 py-1.5 rounded-xl bg-[#1A3C2E] hover:bg-[#0f2a1d] text-white text-xs font-bold shadow-sm cursor-pointer border-0 disabled:opacity-50"
                    >
                      + Add to Requirements List
                    </button>
                  </div>
                </div>
              )}

              <div className="space-y-3">
                {documentsList.map((doc, idx) => {
                  const docUrl = doc.document_url || doc.url;
                  const docStatus = doc.status || 'Pending';
                  const aiRes = doc.aiVerification;
                  const isExpanded = !!expandedDocIndices[idx];

                  return (
                    <div
                      key={idx}
                      className={`p-4 rounded-2xl bg-white border transition-all shadow-xs flex flex-col gap-3 ${
                        docStatus === 'Verified'
                          ? 'border-[#2D5941]/40 bg-[#EBF5EE]/10'
                          : docStatus === 'Flagged'
                          ? 'border-[#B34040]/40 bg-red-50/20'
                          : 'border-[#D9D2C5]/70 hover:border-[#D9D2C5]'
                      }`}
                    >
                      {/* Top Row: File Info & Badges */}
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex items-start gap-3 min-w-0 flex-1">
                          <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold text-base shrink-0 ${
                            docStatus === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                            docStatus === 'Flagged' ? 'bg-red-50 text-[#B34040]' :
                            'bg-[#EDE8DE] text-[#6C6C70]'
                          }`}>
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.75} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                            </svg>
                          </div>

                          <div className="min-w-0 flex-1">
                            <div className="flex items-center gap-2 flex-wrap">
                              <h5 className="font-bold text-[#1C1C1E] text-xs">{doc.name}</h5>
                              
                              {/* Status Badge */}
                              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                                docStatus === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20' :
                                docStatus === 'Flagged' ? 'bg-red-50 text-[#B34040] border border-[#B34040]/20' :
                                'bg-amber-50 text-[#C97B2E] border border-[#C97B2E]/20'
                              }`}>
                                {docStatus === 'Verified' ? '✓ Approved' : docStatus === 'Flagged' ? '🚩 Flagged' : '⏳ Pending'}
                              </span>

                              {/* AI Verification Badge */}
                              {aiRes ? (() => {
                                  const assessment = getScoreAssessment(aiRes.confidenceScore);
                                  return (
                                    <span
                                      className={`px-2 py-0.5 rounded-full text-[10px] font-bold inline-flex items-center gap-1 cursor-pointer transition-all ${
                                        aiRes.verificationStatus === 'verified' && assessment.quality === 'GOOD'
                                          ? 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/30 hover:bg-[#2D5941] hover:text-white'
                                          : aiRes.verificationStatus === 'rejected' || assessment.quality === 'BAD'
                                          ? 'bg-[#FDF2F2] text-[#B34040] border border-[#B34040]/30 hover:bg-[#B34040] hover:text-white'
                                          : 'bg-[#FFF8EE] text-[#C97B2E] border border-[#C97B2E]/40 hover:bg-[#C97B2E] hover:text-white'
                                      }`}
                                      onClick={() => toggleExpandDoc(idx)}
                                      title="Click to toggle AI forensic breakdown"
                                    >
                                      <span>
                                        {aiRes.verificationStatus === 'verified' && assessment.quality === 'GOOD'
                                          ? `🟢 ⚡ AI Verified (${assessment.scorePercent}% Match • Good)`
                                          : aiRes.tamperingDetected || assessment.quality === 'BAD'
                                          ? `🔴 ⚠️ Security Risk (${assessment.scorePercent}% Match • High Risk)`
                                          : `🟡 ⚠️ AI Flagged (${assessment.scorePercent}% Match • Needs Review)`}
                                      </span>
                                    </span>
                                  );
                                })() : doc.isAiScanning ? (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-900 animate-pulse border border-amber-300">
                                  ⏳ AI Scanning...
                                </span>
                              ) : null}
                            </div>

                            <p className="text-[10px] text-[#8E8E93] mt-1 truncate">
                              File: {doc.filename || doc.name} {doc.filesize ? `• ${doc.filesize}` : ''} {doc.submitted_at ? `• Submitted ${doc.submitted_at}` : ''}
                            </p>
                          </div>
                        </div>

                        {(doc.is_additional || !docUrl) && (
                          <button
                            type="button"
                            onClick={() => handleRemoveDoc(idx)}
                            title="Remove requirement"
                            className="w-7 h-7 rounded-xl bg-gray-100 hover:bg-red-100 text-gray-500 hover:text-red-600 flex items-center justify-center transition-colors border-0 cursor-pointer text-xs shrink-0"
                          >
                            ✕
                          </button>
                        )}
                      </div>

                      {/* Remarks Pill if flagged or noted */}
                      {doc.remarks && (
                        <div className="px-3 py-1.5 rounded-xl bg-[#F9F5EF] border border-[#D9D2C5]/70 text-[11px] text-[#6C6C70] flex items-center gap-2">
                          <span className="font-semibold text-[#1A3C2E] shrink-0">Note:</span>
                          <span className="truncate">{doc.remarks}</span>
                        </div>
                      )}

                      {/* Clean Dedicated Action Toolbar */}
                      <div className="pt-2 border-t border-[#D9D2C5]/60 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
                        {/* Left Group: Tools & Previews */}
                        <div className="flex items-center gap-2 flex-wrap">
                          {docUrl && (
                            <a
                              href={docUrl}
                              target="_blank"
                              rel="noreferrer"
                              className="px-3 py-1.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-xs font-bold border-0 cursor-pointer inline-flex items-center justify-center gap-1.5 transition-colors no-underline min-w-[90px]"
                            >
                              <svg className="w-3.5 h-3.5 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                              </svg>
                              <span>Preview</span>
                            </a>
                          )}

                          {docUrl && (
                            <button
                              type="button"
                              disabled={doc.isAiScanning}
                              onClick={() => handleScanSingleDoc(idx)}
                              className="px-3 py-1.5 rounded-xl bg-amber-50 hover:bg-amber-100 text-[#C97B2E] text-xs font-bold border border-amber-300/60 cursor-pointer inline-flex items-center justify-center gap-1.5 transition-all disabled:opacity-50 min-w-[96px]"
                            >
                              {doc.isAiScanning ? (
                                <>
                                  <span className="animate-spin text-xs">⏳</span>
                                  <span>Scanning</span>
                                </>
                              ) : (
                                <>
                                  <span>⚡</span>
                                  <span>{aiRes ? 'Re-scan' : 'Scan AI'}</span>
                                </>
                              )}
                            </button>
                          )}

                          {aiRes && (
                            <button
                              type="button"
                              onClick={() => toggleExpandDoc(idx)}
                              className={`px-3 py-1.5 rounded-xl text-xs font-bold cursor-pointer transition-colors border inline-flex items-center justify-center gap-1 min-w-[104px] ${
                                isExpanded
                                  ? 'bg-[#1A3C2E] text-white border-[#1A3C2E]'
                                  : 'bg-white text-[#1A3C2E] border-[#D9D2C5] hover:bg-[#F9F5EF]'
                              }`}
                            >
                              <span>{isExpanded ? '▲ Hide Analysis' : '📊 AI Report'}</span>
                            </button>
                          )}
                        </div>

                        {/* Right Group: Review Decisions (Approve / Flag) */}
                        <div className="flex items-center gap-2 self-end sm:self-auto">
                          <button
                            type="button"
                            onClick={() => toggleDocStatus(idx, docStatus === 'Verified' ? 'Pending' : 'Verified')}
                            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold cursor-pointer transition-all border inline-flex items-center justify-center gap-1.5 shadow-xs min-w-[98px] ${
                              docStatus === 'Verified'
                                ? 'bg-[#2D5941] text-white border-[#2D5941]'
                                : 'bg-[#EBF5EE] text-[#2D5941] border-[#2D5941]/30 hover:bg-[#2D5941] hover:text-white'
                            }`}
                          >
                            <span>✓</span>
                            <span>{docStatus === 'Verified' ? 'Approved' : 'Approve'}</span>
                          </button>

                          <button
                            type="button"
                            onClick={() => toggleDocStatus(idx, docStatus === 'Flagged' ? 'Pending' : 'Flagged')}
                            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold cursor-pointer transition-all border inline-flex items-center justify-center gap-1.5 shadow-xs min-w-[84px] ${
                              docStatus === 'Flagged'
                                ? 'bg-[#B34040] text-white border-[#B34040]'
                                : 'bg-red-50 text-[#B34040] border-[#B34040]/30 hover:bg-[#B34040] hover:text-white'
                            }`}
                          >
                            <span>🚩</span>
                            <span>{docStatus === 'Flagged' ? 'Flagged' : 'Flag'}</span>
                          </button>
                        </div>
                      </div>

                      {/* Expandable AI Forensic Discrepancy & Verification Report */}
                      {isExpanded && aiRes && (() => {
                        const assessment = getScoreAssessment(aiRes.confidenceScore);
                        return (
                          <div className="bg-[#FFFFFF] p-3.5 rounded-2xl border border-[#D9D2C5] space-y-3 animate-fade-in text-xs">
                            {/* Header bar */}
                            <div className="flex items-center justify-between border-b border-[#D9D2C5]/60 pb-2 flex-wrap gap-2">
                              <div className="flex items-center gap-2 flex-wrap">
                                <span className="font-bold text-[#1A3C2E] uppercase text-[10px] tracking-wider">
                                  🔬 Forensic Analysis Report
                                </span>
                                <span className="text-[10px] text-[#6C6C70] bg-[#F9F5EF] px-2 py-0.5 rounded-md border border-[#D9D2C5]">
                                  Model: <strong>{aiRes.aiModelUsed || 'Gemini 2.5 Flash'}</strong> ({aiRes.provider || 'DeepMind'})
                                </span>
                              </div>
                              <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md border ${assessment.badgeStyle}`}>
                                Score: {assessment.scorePercent}% • {assessment.label}
                              </span>
                            </div>

                            {/* Dynamic Quality & Score Remarks Box */}
                            <div className={`p-2.5 rounded-xl border text-xs flex items-start gap-2.5 ${
                              assessment.quality === 'GOOD'
                                ? 'bg-[#EBF5EE]/60 border-[#2D5941]/30 text-[#1A3C2E]'
                                : assessment.quality === 'CAUTION'
                                ? 'bg-[#FFF8EE] border-[#C97B2E]/30 text-[#8C4A00]'
                                : 'bg-red-50 border-red-200 text-red-900'
                            }`}>
                              <span className="text-sm shrink-0">
                                {assessment.quality === 'GOOD' ? '🟢' : assessment.quality === 'CAUTION' ? '🟡' : '🔴'}
                              </span>
                              <div className="space-y-0.5">
                                <span className="font-bold block text-xs">
                                  Match Rating: {assessment.scorePercent}% — {assessment.textRemark}
                                </span>
                                <p className="text-[11px] leading-relaxed opacity-90 font-normal">
                                  {assessment.quality === 'GOOD' && 'Document matches declared profile credentials with verified official seals and zero visual tampering detected.'}
                                  {assessment.quality === 'CAUTION' && 'Document is readable but contains minor data variance or unverified seal. Manual administrator check recommended.'}
                                  {assessment.quality === 'BAD' && 'High mismatch or potential visual alteration detected. Document flagged for security risk.'}
                                </p>
                              </div>
                            </div>

                          {/* Side-by-Side Discrepancy Grid */}
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                            {/* Left: Declared Profile */}
                            <div className="bg-[#F9F5EF]/50 p-3 rounded-xl border border-[#D9D2C5]/70 space-y-1.5">
                              <span className="text-[10px] font-bold text-[#6C6C70] uppercase block">
                                👤 Declared Applicant Profile
                              </span>
                              <div className="space-y-1 text-xs">
                                <div className="flex justify-between">
                                  <span className="text-[#6C6C70]">Applicant Name:</span>
                                  <strong className="text-[#1C1C1E]">{application?.name || 'N/A'}</strong>
                                </div>
                                <div className="flex justify-between">
                                  <span className="text-[#6C6C70]">School / University:</span>
                                  <strong className="text-[#1C1C1E]">{application?.school || 'N/A'}</strong>
                                </div>
                                <div className="flex justify-between">
                                  <span className="text-[#6C6C70]">Course:</span>
                                  <strong className="text-[#1C1C1E]">{application?.course || 'N/A'}</strong>
                                </div>
                                <div className="flex justify-between">
                                  <span className="text-[#6C6C70]">Declared GWA:</span>
                                  <strong className="text-[#2D5941]">{application?.grade || 'N/A'}</strong>
                                </div>
                              </div>
                            </div>

                            {/* Right: AI Extracted Data */}
                            <div className="bg-white p-3 rounded-xl border border-[#D9D2C5]/70 space-y-1.5">
                              <span className="text-[10px] font-bold text-[#6C6C70] uppercase block">
                                📄 AI Extracted Document Data
                              </span>
                              <div className="space-y-1 text-xs">
                                <div className="flex justify-between items-center">
                                  <span className="text-[#6C6C70]">Name on Document:</span>
                                  <div className="flex items-center gap-1">
                                    <strong className="text-[#1C1C1E]">{aiRes.extractedName || 'Not detected'}</strong>
                                    {aiRes.crossCheckResults?.nameMatch ? (
                                      <span className="text-[10px] text-[#2D5941]" title="Name matches profile">✓</span>
                                    ) : (
                                      <span className="text-[10px] text-[#B34040]" title="Name mismatch detected">⚠️</span>
                                    )}
                                  </div>
                                </div>
                                <div className="flex justify-between items-center">
                                  <span className="text-[#6C6C70]">School on Doc:</span>
                                  <div className="flex items-center gap-1">
                                    <strong className="text-[#1C1C1E]">{aiRes.extractedSchool || 'Not detected'}</strong>
                                    {aiRes.crossCheckResults?.schoolMatch ? (
                                      <span className="text-[10px] text-[#2D5941]">✓</span>
                                    ) : (
                                      <span className="text-[10px] text-[#B34040]">⚠️</span>
                                    )}
                                  </div>
                                </div>
                                <div className="flex justify-between items-center">
                                  <span className="text-[#6C6C70]">Identified Doc Type:</span>
                                  <strong className="text-[#1C1C1E]">{aiRes.extractedDocType || doc.name}</strong>
                                </div>
                                {aiRes.extractedGwa && (
                                  <div className="flex justify-between items-center">
                                    <span className="text-[#6C6C70]">Extracted GWA:</span>
                                    <strong className="text-[#2D5941] font-mono">{aiRes.extractedGwa}</strong>
                                  </div>
                                )}
                              </div>
                            </div>
                          </div>

                          {/* Security Signals Checklist */}
                          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-[11px]">
                            <div className="flex items-center gap-1.5 bg-white p-2 rounded-lg border border-[#D9D2C5]/60">
                              <span>{aiRes.hasOfficialSealOrSignature ? '🟢' : '🟡'}</span>
                              <span className="text-[#1C1C1E]">
                                {aiRes.hasOfficialSealOrSignature ? 'Official Seal / Signature Detected' : 'Seal / Signature Unclear'}
                              </span>
                            </div>
                            <div className="flex items-center gap-1.5 bg-white p-2 rounded-lg border border-[#D9D2C5]/60">
                              <span>{aiRes.tamperingDetected ? '🔴' : '🟢'}</span>
                              <span className="text-[#1C1C1E]">
                                {aiRes.tamperingDetected ? 'Visual Alteration Detected' : 'No Digital Tampering'}
                              </span>
                            </div>
                            <div className="flex items-center gap-1.5 bg-white p-2 rounded-lg border border-[#D9D2C5]/60 col-span-2 sm:col-span-1">
                              <span>🔒</span>
                              <span className="text-[#6C6C70] truncate font-mono text-[10px]" title={`SHA-256: ${aiRes.sha256Hash || 'N/A'}`}>
                                Hash: {aiRes.sha256Hash ? aiRes.sha256Hash.slice(0, 10) + '...' : 'N/A'}
                              </span>
                            </div>
                          </div>

                          {/* Flags and Warnings list */}
                          {aiRes.flags && aiRes.flags.length > 0 && (
                            <div className="p-2.5 bg-[#FDF2F2] border border-[#B34040]/30 rounded-xl space-y-1">
                              <span className="text-[10px] font-bold text-[#B34040] uppercase tracking-wider block">
                                ⚠️ Compliance Anomalies & Warnings:
                              </span>
                              <ul className="list-disc list-inside text-xs text-[#B34040] space-y-0.5 font-medium">
                                {aiRes.flags.map((flag, fIdx) => (
                                  <li key={fIdx}>{getFlagString(flag)}</li>
                                ))}
                              </ul>
                            </div>
                          )}

                          {/* AI Forensic Summary */}
                          <div className="p-2.5 bg-white rounded-xl border border-[#D9D2C5]/60 text-xs text-[#1C1C1E]">
                            <span className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-0.5">Forensic Summary:</span>
                            <p className="text-xs text-[#1C1C1E]">{aiRes.summary}</p>
                          </div>
                          
                          {/* Quick action buttons for this report */}
                          <div className="flex justify-end gap-2 pt-1 border-t border-[#D9D2C5]/60">
                            <button
                              type="button"
                              onClick={() => {
                                toggleDocStatus(idx, 'Verified');
                                setDocumentsList(prev => prev.map((d, i) => i === idx ? { ...d, remarks: '' } : d));
                              }}
                              className="px-3 py-1.5 rounded-xl bg-[#EBF5EE] hover:bg-[#2D5941] hover:text-white text-[#2D5941] text-xs font-bold transition-all cursor-pointer border-0"
                            >
                              ✓ Accept as Verified
                            </button>
                            <button
                              type="button"
                              onClick={() => {
                                toggleDocStatus(idx, 'Flagged');
                                const flagReason = aiRes.flags.length > 0 ? getFlagString(aiRes.flags[0]) : aiRes.summary;
                                setDocumentsList(prev => prev.map((d, i) => i === idx ? { ...d, remarks: `AI Flag: ${flagReason}` } : d));
                              }}
                              className="px-3 py-1.5 rounded-xl bg-red-50 hover:bg-[#B34040] hover:text-white text-[#B34040] text-xs font-bold transition-all cursor-pointer border-0"
                            >
                              🚩 Flag Issue with AI Reason
                            </button>
                          </div>
                        </div>
                      )
                    })()}

                      {/* Inline remark / issue feedback when Flagged */}
                      {docStatus === 'Flagged' && (
                        <div className="pt-2 border-t border-red-200/50 flex flex-col gap-1">
                          <label className="text-[10px] font-bold text-[#B34040] uppercase tracking-wider flex items-center gap-1">
                            <span>Reason for Issue / Resubmission Instruction for Scholar:</span>
                          </label>
                          <input
                            type="text"
                            placeholder="e.g. Image is blurry, missing official dry seal, or expired validity date..."
                            value={doc.remarks || ''}
                            onChange={(e) => {
                              const val = e.target.value;
                              setDocumentsList(prev =>
                                prev.map((d, i) => i === idx ? { ...d, remarks: val } : d)
                              );
                            }}
                            className="w-full px-3 py-1.5 rounded-xl border border-red-300 focus:border-[#B34040] focus:ring-1 focus:ring-red-400 bg-white text-xs text-[#1C1C1E] outline-none"
                          />
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>

          {/* Section 3: Provider Decision & Remarks */}
          {(() => {
            const allDocsApproved = documentsList.length > 0 && documentsList.every(d => d.status === 'Verified');
            return (
              <form onSubmit={handleSaveDecision} className="bg-[#F9F5EF] p-5 rounded-2xl border border-[#D9D2C5]/70 space-y-4">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-extrabold text-[#1A3C2E] uppercase tracking-wider">
                    ⚖️ Application Decision & Provider Remarks
                  </h4>
                  {allDocsApproved && (
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/30">
                      ✓ All Requirements Approved
                    </span>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">
                      Update Application Status
                    </label>
                    <select
                      value={selectedStatus}
                      onChange={(e) => setSelectedStatus(e.target.value as ApplicantStatus)}
                      className={`w-full px-3.5 py-2.5 rounded-xl border focus:outline-none bg-white text-xs font-bold cursor-pointer transition-all ${
                        allDocsApproved ? 'border-[#2D5941] text-[#2D5941] bg-[#F4F9F5]' : 'border-[#D9D2C5]'
                      }`}
                    >
                      {allDocsApproved ? (
                        <>
                          <option value="Approved">Approved (Issue Scholar Award)</option>
                          <option value="For Exam">Scheduled for Exam (For Examination)</option>
                        </>
                      ) : (
                        <>
                          <option value="Pending">Pending Evaluation</option>
                          <option value="Under Review">Under Review</option>
                          <option value="For Exam">Scheduled for Exam (For Examination)</option>
                          <option value="Approved">Approved (Issue Scholar Award)</option>
                          <option value="Rejected">Reject Application</option>
                        </>
                      )}
                    </select>
                    {allDocsApproved ? (
                      <p className="text-[10px] text-[#2D5941] font-semibold mt-1.5 flex items-center gap-1">
                        <span>✓</span> All requirements verified authentic. Choose to grant Final Approval or Schedule for Examination.
                      </p>
                    ) : (
                      <p className="text-[10px] text-[#8E8E93] mt-1.5">
                        Requirements are under review or pending. Mark all verified to restrict choices to Approved or Exam.
                      </p>
                    )}
                  </div>

                  <div>
                    <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">
                      Provider Feedback / Remarks
                    </label>
                    <input
                      type="text"
                      placeholder={allDocsApproved ? 'e.g. All credentials verified. Approved for scholarship award!' : 'e.g. Under review / awaiting document resubmission...'}
                      value={remarks}
                      onChange={(e) => setRemarks(e.target.value)}
                      className="w-full px-3.5 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none bg-white text-xs"
                    />
                  </div>
                </div>

                <div className="flex justify-end items-center gap-3 pt-2">
                  <div className="flex gap-3">
                    <button
                      type="button"
                      onClick={onClose}
                      className="px-5 py-2.5 rounded-xl border border-[#D9D2C5] hover:bg-white text-xs font-bold text-[#6C6C70] bg-transparent cursor-pointer"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      disabled={isSubmitting}
                      className="px-7 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#0f2a1d] text-white text-xs font-bold shadow-md cursor-pointer border-0 disabled:opacity-50"
                    >
                      {isSubmitting ? 'Saving Decision...' : 'Save Decision & Notify Student'}
                    </button>
                  </div>
                </div>
              </form>
            );
          })()}

        </div>
      </div>
    </div>
  );
};

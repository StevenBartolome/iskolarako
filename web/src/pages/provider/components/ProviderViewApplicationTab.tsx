import React, { useState, useEffect } from 'react';
import type { ApplicationDetail, SubmittedDocItem, ApplicantStatus } from './ReviewApplicationModal';
import {
  verifyDocumentAuthenticity,
  type DocVerificationResult,
  type ApplicantVerificationContext,
} from '@/services/aiExtractionService';
import { supabase } from '@/services/supabaseClient';

interface ProviderViewApplicationTabProps {
  application: ApplicationDetail | null;
  onBack: () => void;
  onUpdateStatus: (
    appId: string | number,
    newStatus: ApplicantStatus,
    remarks?: string,
    updatedDocs?: SubmittedDocItem[]
  ) => Promise<void>;
}

export const ProviderViewApplicationTab: React.FC<ProviderViewApplicationTabProps> = ({
  application,
  onBack,
  onUpdateStatus,
}) => {
  if (!application) {
    return (
      <div className="p-12 text-center bg-white rounded-3xl border border-[#D9D2C5]/60 shadow-sm my-6">
        <div className="text-4xl mb-3">📄</div>
        <h3 className="text-xl font-bold text-[#1A3C2E]">No Application Selected</h3>
        <p className="text-sm text-[#6C6C70] mt-1 mb-6">Select an applicant from the cycle intake list to view details.</p>
        <button
          onClick={onBack}
          className="px-6 py-2.5 rounded-xl bg-[#1A3C2E] text-white text-sm font-bold border-0 cursor-pointer hover:bg-[#2D5941] transition-all"
        >
          Return to Applicants
        </button>
      </div>
    );
  }

  const [selectedStatus, setSelectedStatus] = useState<ApplicantStatus>(application.status || 'Pending');
  const [remarks, setRemarks] = useState(application.remarks || '');
  const [documentsList, setDocumentsList] = useState<SubmittedDocItem[]>(application.submittedDocuments || []);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [activePreviewDoc, setActivePreviewDoc] = useState<SubmittedDocItem | null>(null);

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

  // Add requirement states
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
    'Proof of Intended College Admission / Entrance Exam Results',
  ];

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
      console.warn('[Doc AI Cache Persist Note in View Tab]:', err);
    }
  };

  useEffect(() => {
    if (application) {
      setSelectedStatus(application.status || 'Pending');
      setRemarks(application.remarks || '');
      const docs = application.submittedDocuments || [];
      setDocumentsList(docs);
      if (docs.length > 0) {
        setActivePreviewDoc(docs[0]);
      }

      // Auto scan only unscanned or resubmitted documents on load
      const unscanned = docs.filter(d => {
        const hasUrl = Boolean(d.url || d.document_url);
        if (!hasUrl) return false;
        const isResubmitted = (d.remarks || '').toLowerCase().includes('resubmit');
        const isAlreadyScanned = Boolean(d.aiVerification && d.aiVerification.verificationStatus);
        return isResubmitted || !isAlreadyScanned;
      });

      if (unscanned.length > 0) {
        handleBatchAiScan(true);
      }
    }
  }, [application]);

  const raw = application.rawApplication || {};
  const isFreshman =
    (application.yearLevel && application.yearLevel.toLowerCase().includes('1st')) ||
    (application.yearLevel && application.yearLevel.toLowerCase().includes('freshm')) ||
    (raw.is_incoming_freshman === true) ||
    Boolean(raw.current_school || raw.intended_school || raw.intended_course);

  const currentSchool = raw.current_school || raw.high_school || (isFreshman ? application.school : null);
  const intendedSchool = raw.intended_school || raw.target_school || (isFreshman ? (application.school !== currentSchool ? application.school : 'Pending Admission') : null);
  const intendedCourse = raw.intended_course || raw.option_course || (isFreshman ? application.course : null);

  const toggleExpandDoc = (idx: number) => {
    setExpandedDocIndices(prev => ({ ...prev, [idx]: !prev[idx] }));
  };

  const getApplicantContext = (): ApplicantVerificationContext => {
    return {
      scholarName: application.name || '',
      school: application.school || '',
      course: application.course || '',
      yearLevel: application.yearLevel || '',
      gwa: application.grade || '',
      email: application.email || '',
      phone: application.phone || '',
      programTitle: application.program || '',
    };
  };

  const saveDocStatusToDb = async (doc: SubmittedDocItem, newDocStatus: 'Verified' | 'Flagged' | 'Pending') => {
    try {
      const scholarId = application?.scholarId || application?.rawApplication?.scholar_id || application?.rawApplication?.scholar?.id;
      const dbStatus = newDocStatus === 'Verified' ? 'verified' : newDocStatus === 'Flagged' ? 'rejected' : 'pending';
      const docRemarks = newDocStatus === 'Verified' ? 'Approved by provider' : newDocStatus === 'Flagged' ? (doc.remarks || 'Flagged for review') : '';

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
      }
    } catch (err) {
      console.warn('[Save Doc Status Note in Tab]:', err);
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
      console.warn('[Approve All Docs Note in Tab]:', err);
    }
  };

  const handleScanSingleDoc = async (docIndex: number) => {
    const doc = documentsList[docIndex];
    if (!doc || (!doc.url && !doc.document_url)) return;
    const fileUrl = doc.url || doc.document_url || '';

    setDocumentsList(prev => prev.map((item, i) => i === docIndex ? { ...item, isAiScanning: true } : item));

    try {
      const result = await verifyDocumentAuthenticity({
        documentUrl: fileUrl,
        documentName: doc.name,
        applicantContext: getApplicantContext(),
      });
      persistDocAiScanToDb(doc, result);
      const isVerified = result.verificationStatus === 'verified';
      setDocumentsList(prev => prev.map((item, i) => {
        if (i === docIndex) {
          return {
            ...item,
            isAiScanning: false,
            status: isVerified ? 'Verified' : 'Flagged',
            remarks: result.summary,
            aiVerification: result,
          };
        }
        return item;
      }));
    } catch (err: any) {
      setDocumentsList(prev => prev.map((item, i) => i === docIndex ? { ...item, isAiScanning: false } : item));
    }
  };

  const handleBatchAiScan = async (onlyUnscanned = false) => {
    if (documentsList.length === 0) return;
    setIsBatchScanning(true);
    let flaggedCount = 0;
    let verifiedCount = 0;
    const updatedDocs = [...documentsList];

    for (let i = 0; i < updatedDocs.length; i++) {
      const doc = updatedDocs[i];
      const fileUrl = doc.url || doc.document_url || '';

      const isResubmitted = (doc.remarks || '').toLowerCase().includes('resubmit');
      const isAlreadyScanned = Boolean(doc.aiVerification && doc.aiVerification.verificationStatus);

      if (onlyUnscanned && isAlreadyScanned && !isResubmitted) {
        if (doc.status === 'Verified' || doc.aiVerification?.verificationStatus === 'verified') {
          verifiedCount++;
        } else {
          flaggedCount++;
        }
        continue;
      }

      setBatchProgressMsg(`Analyzing Document ${i + 1} of ${updatedDocs.length}: "${doc.name}"...`);

      if (!fileUrl) {
        updatedDocs[i] = { ...doc, status: 'Flagged', remarks: 'No accessible document file preview found' };
        flaggedCount++;
        continue;
      }

      try {
        const result = await verifyDocumentAuthenticity({
          documentUrl: fileUrl,
          documentName: doc.name,
          applicantContext: getApplicantContext(),
        });
        persistDocAiScanToDb(doc, result);
        const isVerified = result.verificationStatus === 'verified';
        if (isVerified) {
          verifiedCount++;
        } else {
          flaggedCount++;
        }
        updatedDocs[i] = {
          ...doc,
          status: isVerified ? 'Verified' : 'Flagged',
          remarks: result.summary,
          aiVerification: result,
        };
      } catch (err) {
        flaggedCount++;
        updatedDocs[i] = { ...doc, status: 'Flagged', remarks: 'OCR scanning failed' };
      }
    }

    setDocumentsList(updatedDocs);
    setIsBatchScanning(false);
    setBatchProgressMsg('');

    setAutoScanSummary({
      total: updatedDocs.length,
      flagged: flaggedCount,
      verified: verifiedCount,
      actionTaken: flaggedCount > 0 ? 'Flagged items detected' : 'All documents clear',
    });
  };

  const handleSaveStatus = async (overrideStatus?: ApplicantStatus) => {
    const statusToApply = overrideStatus || selectedStatus;
    setIsSubmitting(true);
    try {
      await onUpdateStatus(application.id, statusToApply, remarks, documentsList);
      onBack();
    } catch (error) {
      console.error('Failed to update application status:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleAddRequirement = () => {
    if (!newReqName.trim()) return;
    const newDoc: SubmittedDocItem = {
      id: `req_${Date.now()}`,
      name: newReqName.trim(),
      status: 'Pending',
      remarks: newReqInstruction.trim() || 'Additional requirement requested by provider',
      is_additional: true,
    };
    setDocumentsList(prev => [...prev, newDoc]);
    setSelectedStatus('Additional Info Required');
    setNewReqName('');
    setNewReqInstruction('');
    setShowAddReqForm(false);
  };

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'Approved': return 'bg-emerald-100 text-emerald-800 border-emerald-300';
      case 'Under Review': return 'bg-amber-100 text-amber-800 border-amber-300';
      case 'Rejected': return 'bg-rose-100 text-rose-800 border-rose-300';
      case 'Additional Info Required': return 'bg-purple-100 text-purple-800 border-purple-300';
      case 'Flagged': return 'bg-red-100 text-red-800 border-red-300';
      default: return 'bg-blue-100 text-blue-800 border-blue-300';
    }
  };

  return (
    <div className="space-y-6 animate-fade-in pb-12">
      {/* Top Header & Breadcrumb */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-6 rounded-3xl border border-[#D9D2C5]/60 shadow-sm">
        <div className="flex items-center gap-4">
          <button
            onClick={onBack}
            className="p-2.5 rounded-2xl bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] font-bold text-sm border-0 cursor-pointer transition-all flex items-center gap-2"
          >
            <span>←</span> Back
          </button>
          <div>
            <div className="flex items-center gap-3">
              <h2 className="text-2xl font-extrabold text-[#1A3C2E] font-serif">{application.name}</h2>
              <span className={`px-3 py-1 rounded-full text-xs font-extrabold border ${getStatusBadgeClass(application.status)}`}>
                {application.status}
              </span>
              {isFreshman && (
                <span className="px-3 py-1 rounded-full text-xs font-bold bg-[#E6F4EA] text-[#137333] border border-[#CEEAD6] flex items-center gap-1">
                  🎓 Freshmen Intake
                </span>
              )}
            </div>
            <p className="text-xs text-[#6C6C70] mt-1 font-medium">
              Application ID: <span className="font-mono text-[#1A3C2E] font-bold">#{application.id}</span> • Program: <span className="font-bold text-[#1A3C2E]">{application.program}</span> ({application.cycle || 'Active Intake'})
            </p>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => handleSaveStatus('Approved')}
            disabled={isSubmitting}
            className="px-5 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer transition-all shadow-md flex items-center gap-1.5"
          >
            <span>✓</span> Approve Scholar
          </button>
          <button
            onClick={() => handleSaveStatus('Under Review')}
            disabled={isSubmitting}
            className="px-4 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold border-0 cursor-pointer transition-all shadow-md"
          >
            Mark Under Review
          </button>
          <button
            onClick={() => handleSaveStatus('Additional Info Required')}
            disabled={isSubmitting}
            className="px-4 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold border-0 cursor-pointer transition-all shadow-md"
          >
            Request Docs
          </button>
          <button
            onClick={() => handleSaveStatus('Rejected')}
            disabled={isSubmitting}
            className="px-4 py-2.5 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold border-0 cursor-pointer transition-all shadow-md"
          >
            Reject
          </button>
        </div>
      </div>

      {/* Main 2-Column Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">

        {/* LEFT COLUMN: Dossier & Academic Background (5 cols) */}
        <div className="lg:col-span-5 space-y-6">

          {/* Incoming Freshmen Alert Banner */}
          {isFreshman && (
            <div className="bg-gradient-to-r from-emerald-900 to-[#1A3C2E] p-5 rounded-3xl text-white shadow-md relative overflow-hidden">
              <div className="relative z-10 space-y-2">
                <div className="flex items-center gap-2 text-amber-300 font-bold text-xs uppercase tracking-wider">
                  <span>✨</span> Incoming Freshmen Applicant
                </div>
                <h4 className="text-lg font-extrabold font-serif">College Freshman Application</h4>
                <p className="text-xs text-[#E2E8F0] leading-relaxed">
                  This student is an upcoming college freshman. High school background, intended target college, and preferred course choices are listed below.
                </p>
              </div>
            </div>
          )}

          {/* Academic & School Info Card */}
          <div className="bg-white p-6 rounded-3xl border border-[#D9D2C5]/60 shadow-sm space-y-5">
            <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif flex items-center justify-between">
              <span>🎓 Academic Dossier</span>
              <span className="text-xs font-mono font-bold bg-[#F9F5EF] text-[#1A3C2E] px-3 py-1 rounded-full border border-[#D9D2C5]">
                GWA: {application.grade || 'N/A'}
              </span>
            </h3>

            {isFreshman ? (
              <div className="space-y-3.5 bg-[#F9F5EF]/70 p-4 rounded-2xl border border-[#D9D2C5]/50">
                <div>
                  <label className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider block">Current / High School Graduated From</label>
                  <p className="text-sm font-bold text-[#1A3C2E] mt-0.5">{currentSchool || 'Not specified'}</p>
                </div>
                <div className="grid grid-cols-2 gap-3 pt-2 border-t border-[#D9D2C5]/40">
                  <div>
                    <label className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider block">Intended / Target College</label>
                    <p className="text-xs font-bold text-[#1A3C2E] mt-0.5">{intendedSchool || application.school || 'Pending Admission'}</p>
                  </div>
                  <div>
                    <label className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider block">Intended / Option Course</label>
                    <p className="text-xs font-bold text-[#1A3C2E] mt-0.5">{intendedCourse || application.course || 'Option Course'}</p>
                  </div>
                </div>
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-4 bg-[#F9F5EF]/50 p-4 rounded-2xl border border-[#D9D2C5]/40">
                <div>
                  <label className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider block">University / School</label>
                  <p className="text-xs font-bold text-[#1A3C2E] mt-0.5">{application.school}</p>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider block">Course & Degree</label>
                  <p className="text-xs font-bold text-[#1A3C2E] mt-0.5">{application.course}</p>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider block">Current Year Level</label>
                  <p className="text-xs font-semibold text-[#1C1C1E] mt-0.5">{application.yearLevel}</p>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider block">Term Intake</label>
                  <p className="text-xs font-semibold text-[#1C1C1E] mt-0.5">{application.semester || 'First Term'}</p>
                </div>
              </div>
            )}

            {/* Applicant Personal Profile */}
            <div className="space-y-3 pt-2">
              <h4 className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">Contact & Demographics</h4>
              <div className="space-y-2 text-xs">
                <div className="flex justify-between py-1.5 border-b border-[#EDE8DE]">
                  <span className="text-[#6C6C70]">Email Address</span>
                  <span className="font-semibold text-[#1A3C2E]">{application.email || 'N/A'}</span>
                </div>
                <div className="flex justify-between py-1.5 border-b border-[#EDE8DE]">
                  <span className="text-[#6C6C70]">Phone Number</span>
                  <span className="font-semibold text-[#1A3C2E]">{application.phone || 'N/A'}</span>
                </div>
                <div className="flex justify-between py-1.5 border-b border-[#EDE8DE]">
                  <span className="text-[#6C6C70]">Citizenship</span>
                  <span className="font-semibold text-[#1A3C2E]">{application.citizenship || 'Filipino'}</span>
                </div>
                <div className="flex justify-between py-1.5">
                  <span className="text-[#6C6C70]">Address / City</span>
                  <span className="font-semibold text-[#1A3C2E] text-right max-w-[200px] truncate">{application.address || 'Metro Manila'}</span>
                </div>
              </div>
            </div>

            {/* Bank / Disbursement Details */}
            {application.paymentAccount && (
              <div className="p-4 rounded-2xl bg-[#EDE8DE]/40 border border-[#D9D2C5]/50 space-y-2">
                <h4 className="text-xs font-bold text-[#1A3C2E] flex items-center gap-1.5">
                  <span>💳</span> Disbursement Account
                </h4>
                <div className="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <span className="text-[10px] text-[#6C6C70] block">Provider / Mode</span>
                    <span className="font-bold text-[#1A3C2E]">{application.paymentAccount.provider || 'GCash'}</span>
                  </div>
                  <div>
                    <span className="text-[10px] text-[#6C6C70] block">Account Number</span>
                    <span className="font-mono font-bold text-[#1A3C2E]">{application.paymentAccount.accountNumber || 'N/A'}</span>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Decision Notes & Remarks */}
          <div className="bg-white p-6 rounded-3xl border border-[#D9D2C5]/60 shadow-sm space-y-4">
            <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">📝 Reviewer Remarks & Audit</h3>
            <div>
              <label className="block text-xs font-bold text-[#6C6C70] uppercase tracking-wide mb-2">
                Internal Remarks / Feedback to Student
              </label>
              <textarea
                rows={3}
                value={remarks}
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Add notes on eligibility, missing documents, or decision reason..."
                className="w-full p-3.5 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] text-xs leading-relaxed"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => handleSaveStatus(selectedStatus)}
                disabled={isSubmitting}
                className="px-5 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer transition-all"
              >
                {isSubmitting ? 'Saving...' : 'Save Decision & Notify Student'}
              </button>
            </div>
          </div>

        </div>

        {/* RIGHT COLUMN: Submitted Documents & AI Authenticity Verification (7 cols) */}
        <div className="lg:col-span-7 space-y-6">

          {/* AI Verification Scanner Box */}
          <div className="bg-white p-6 rounded-3xl border border-[#D9D2C5]/60 shadow-sm space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif flex items-center gap-2">
                  <span>🤖</span> AI Document & Forgery Verification
                </h3>
                <p className="text-xs text-[#6C6C70] mt-0.5">
                  Automatically scans report cards, CORs, and indigency proofs for tampering or GWA mismatch.
                </p>
              </div>

              <button
                onClick={() => handleBatchAiScan(false)}
                disabled={isBatchScanning || documentsList.length === 0}
                className={`px-4 py-2.5 rounded-xl text-xs font-extrabold border-0 cursor-pointer transition-all flex items-center justify-center gap-2 shadow-sm ${
                  isBatchScanning
                    ? 'bg-amber-100 text-amber-800'
                    : 'bg-[#1A3C2E] hover:bg-[#2D5941] text-white'
                }`}
              >
                {isBatchScanning ? 'Scanning Documents...' : '✨ Run AI Scan on All Docs'}
              </button>
            </div>

            {isBatchScanning && (
              <div className="p-4 rounded-2xl bg-amber-50 border border-amber-200 text-amber-900 text-xs font-semibold animate-pulse">
                {batchProgressMsg}
              </div>
            )}

            {autoScanSummary && (
              <div className={`p-4 rounded-2xl border text-xs font-semibold flex items-center justify-between ${
                autoScanSummary.flagged > 0 ? 'bg-rose-50 border-rose-200 text-rose-800' : 'bg-emerald-50 border-emerald-200 text-emerald-800'
              }`}>
                <div>
                  <span className="font-bold">Scan Complete:</span> {autoScanSummary.verified} Verified, {autoScanSummary.flagged} Flagged items out of {autoScanSummary.total} documents.
                </div>
                <span className="px-2.5 py-1 rounded-full text-[10px] uppercase font-bold bg-white shadow-xs">
                  {autoScanSummary.actionTaken}
                </span>
              </div>
            )}

            {/* Document Checklist & Previews */}
            <div className="space-y-3 pt-2">
              <div className="flex items-center justify-between flex-wrap gap-2">
                <h4 className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">
                  Submitted Requirements ({documentsList.length})
                </h4>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={handleApproveAllDocs}
                    className="px-3 py-1.5 rounded-xl bg-[#EBF5EE] hover:bg-[#2D5941] text-[#2D5941] hover:text-white text-xs font-bold border border-[#2D5941]/30 cursor-pointer inline-flex items-center gap-1.5 transition-all"
                  >
                    <span>✓</span> Approve All Documents
                  </button>
                  <button
                    onClick={() => setShowAddReqForm(!showAddReqForm)}
                    className="text-xs font-bold text-[#1A3C2E] hover:underline cursor-pointer border-0 bg-transparent"
                  >
                    {showAddReqForm ? 'Close Add Requirement' : '+ Request Additional Doc'}
                  </button>
                </div>
              </div>

              {/* Add Custom Requirement Form */}
              {showAddReqForm && (
                <div className="p-4 rounded-2xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-3">
                  <h5 className="text-xs font-bold text-[#1A3C2E]">Request New Document from Student</h5>
                  <div className="space-y-2">
                    <label className="text-[10px] font-bold text-[#6C6C70] uppercase block">Presets</label>
                    <div className="flex flex-wrap gap-1.5">
                      {commonRequirementPresets.map((preset, pIdx) => (
                        <button
                          key={pIdx}
                          type="button"
                          onClick={() => setNewReqName(preset)}
                          className="px-2.5 py-1 rounded-lg bg-white hover:bg-[#EDE8DE] text-[#1A3C2E] text-[11px] font-semibold border border-[#D9D2C5] cursor-pointer"
                        >
                          {preset}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div>
                    <input
                      type="text"
                      placeholder="Requirement Document Name"
                      value={newReqName}
                      onChange={(e) => setNewReqName(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none"
                    />
                  </div>
                  <div>
                    <input
                      type="text"
                      placeholder="Instructions for student..."
                      value={newReqInstruction}
                      onChange={(e) => setNewReqInstruction(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none"
                    />
                  </div>
                  <div className="flex justify-end gap-2">
                    <button
                      onClick={handleAddRequirement}
                      className="px-4 py-2 rounded-xl bg-[#1A3C2E] text-white text-xs font-bold border-0 cursor-pointer"
                    >
                      Add & Notify Student
                    </button>
                  </div>
                </div>
              )}

              {/* Document List */}
              <div className="space-y-3">
                {documentsList.length === 0 ? (
                  <div className="p-6 text-center text-xs text-[#6C6C70] bg-[#F9F5EF] rounded-2xl">
                    No documents uploaded yet.
                  </div>
                ) : (
                  documentsList.map((doc, idx) => {
                    const isExpanded = expandedDocIndices[idx];
                    const isSelectedPreview = activePreviewDoc?.name === doc.name;
                    const docStatus = doc.status || 'Pending';
                    const docUrl = doc.url || doc.document_url;
                    const aiRes = doc.aiVerification;
                    return (
                      <div
                        key={idx}
                        className={`p-4 rounded-2xl border transition-all shadow-xs flex flex-col gap-3 ${
                          isSelectedPreview
                            ? 'bg-[#F9F5EF] border-[#1A3C2E]'
                            : docStatus === 'Verified'
                            ? 'bg-[#EBF5EE]/10 border-[#2D5941]/40'
                            : docStatus === 'Flagged'
                            ? 'bg-red-50/20 border-[#B34040]/40'
                            : 'bg-white border-[#D9D2C5]/60 hover:border-[#D9D2C5]'
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
                              📄
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <h5 className="text-xs font-bold text-[#1A3C2E]">{doc.name}</h5>
                                <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                                  docStatus === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20' :
                                  docStatus === 'Flagged' ? 'bg-red-50 text-[#B34040] border border-[#B34040]/20' :
                                  'bg-amber-50 text-[#C97B2E] border border-[#C97B2E]/20'
                                }`}>
                                  {docStatus === 'Verified' ? '✓ Approved' : docStatus === 'Flagged' ? '🚩 Flagged' : '⏳ Pending'}
                                </span>
                                {aiRes && (
                                  <span
                                    className={`px-2 py-0.5 rounded-full text-[10px] font-bold inline-flex items-center gap-1 cursor-pointer transition-all ${
                                      aiRes.verificationStatus === 'verified'
                                        ? 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/30 hover:bg-[#2D5941] hover:text-white'
                                        : aiRes.verificationStatus === 'rejected'
                                        ? 'bg-[#FDF2F2] text-[#B34040] border border-[#B34040]/30 hover:bg-[#B34040] hover:text-white'
                                        : 'bg-[#FFF8EE] text-[#C97B2E] border border-[#C97B2E]/40 hover:bg-[#C97B2E] hover:text-white'
                                    }`}
                                    onClick={() => toggleExpandDoc(idx)}
                                    title="Click to toggle AI breakdown"
                                  >
                                    ⚡ AI Verified ({Math.round(aiRes.confidenceScore * 100)}%)
                                  </span>
                                )}
                                {doc.is_additional && (
                                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-purple-100 text-purple-800">
                                    Requested Requirement
                                  </span>
                                )}
                              </div>
                              <p className="text-[10px] text-[#6C6C70] mt-1 truncate">
                                File: {doc.filename || doc.name} {doc.filesize ? `• ${doc.filesize}` : ''} {doc.submitted_at ? `• Submitted ${doc.submitted_at}` : ''}
                              </p>
                            </div>
                          </div>
                        </div>

                        {/* Remarks Note Pill */}
                        {doc.remarks && (
                          <div className="px-3 py-1.5 rounded-xl bg-[#F9F5EF] border border-[#D9D2C5]/70 text-[11px] text-[#6C6C70] flex items-center gap-2">
                            <span className="font-semibold text-[#1A3C2E] shrink-0">Note:</span>
                            <span className="truncate">{doc.remarks}</span>
                          </div>
                        )}

                        {/* Clean Dedicated Action Toolbar */}
                        <div className="pt-2 border-t border-[#D9D2C5]/60 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
                          {/* Left Group: Preview & AI */}
                          <div className="flex items-center gap-2 flex-wrap">
                            {docUrl && (
                              <button
                                onClick={() => setActivePreviewDoc(doc)}
                                className={`px-3 py-1.5 rounded-xl text-xs font-bold border-0 cursor-pointer transition-all inline-flex items-center justify-center gap-1.5 min-w-[90px] ${
                                  isSelectedPreview
                                    ? 'bg-[#1A3C2E] text-white shadow-xs'
                                    : 'bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E]'
                                }`}
                              >
                                <span>👁️</span>
                                <span>Preview</span>
                              </button>
                            )}

                            {docUrl && (
                              <button
                                onClick={() => handleScanSingleDoc(idx)}
                                disabled={doc.isAiScanning}
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

                          {/* Right Group: Review Decisions */}
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

                        {/* AI Analysis Drawer */}
                        {isExpanded && doc.aiVerification && (
                          <div className="mt-3 p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs space-y-2">
                            <div className="flex justify-between items-center">
                              <span className="font-bold text-slate-800">Authenticity Score</span>
                              <span className="font-mono font-bold text-slate-900">{doc.aiVerification.confidenceScore}%</span>
                            </div>
                            {doc.aiVerification.summary && (
                              <div className="pt-2 border-t border-slate-200">
                                <span className="text-[10px] font-bold text-slate-500 uppercase block mb-1">Extracted OCR Summary</span>
                                <p className="text-[11px] text-slate-700 font-mono bg-white p-2 rounded border border-slate-200 leading-relaxed max-h-28 overflow-y-auto">
                                  {doc.aiVerification.summary}
                                </p>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })
                )}
              </div>
            </div>

            {/* Document Preview Pane */}
            {activePreviewDoc && (activePreviewDoc.url || activePreviewDoc.document_url) && (
              <div className="pt-4 border-t border-[#D9D2C5]/60 space-y-3">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold text-[#1A3C2E] flex items-center gap-2">
                    <span>🔍</span> Document Preview: <span className="font-mono">{activePreviewDoc.name}</span>
                  </h4>
                  <a
                    href={activePreviewDoc.url || activePreviewDoc.document_url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-xs font-bold text-[#1A3C2E] hover:underline"
                  >
                    Open in New Window ↗
                  </a>
                </div>
                <div className="w-full h-[480px] bg-slate-100 rounded-2xl border border-[#D9D2C5] overflow-hidden flex items-center justify-center relative">
                  {(activePreviewDoc.url || activePreviewDoc.document_url)?.endsWith('.pdf') ? (
                    <iframe
                      src={activePreviewDoc.url || activePreviewDoc.document_url}
                      className="w-full h-full border-0"
                      title={activePreviewDoc.name}
                    />
                  ) : (
                    <img
                      src={activePreviewDoc.url || activePreviewDoc.document_url}
                      alt={activePreviewDoc.name}
                      className="max-w-full max-h-full object-contain p-2"
                    />
                  )}
                </div>
              </div>
            )}

          </div>

        </div>

      </div>
    </div>
  );
};

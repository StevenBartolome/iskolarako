import React, { useState, useEffect } from 'react';

import type { ApplicantStatus } from '../types';
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
}

export interface ApplicationDetail {
  id: string | number;
  scholarId?: string;
  name: string;
  email?: string;
  phone?: string;
  program: string;
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

  const handleAddRequirement = (e: React.FormEvent) => {
    e.preventDefault();
    const finalName = newReqName.trim();
    if (!finalName) return;

    const newDoc: SubmittedDocItem = {
      name: finalName,
      filename: 'Awaiting scholar upload',
      filesize: '0 KB',
      status: 'Flagged',
      remarks: newReqInstruction.trim() || 'Additional requirement requested by provider. Please upload this file.',
      submitted_at: 'Requested today',
      is_additional: true,
    };

    setDocumentsList(prev => [...prev, newDoc]);
    setNewReqName('');
    setNewReqInstruction('');
    setShowAddReqForm(false);
  };

  const handleRemoveDoc = (indexToRemove: number) => {
    setDocumentsList(prev => prev.filter((_, idx) => idx !== indexToRemove));
  };

  useEffect(() => {
    if (application) {
      setSelectedStatus(application.status || 'Pending');
      setRemarks(application.remarks || '');
      
      // Parse documents from application or fallback
      let docs: SubmittedDocItem[] = [];
      if (Array.isArray(application.submittedDocuments)) {
        docs = application.submittedDocuments;
      } else if (application.submittedDocuments && typeof application.submittedDocuments === 'object') {
        const docObj: any = application.submittedDocuments;
        if (Array.isArray(docObj.documents)) {
          docs = docObj.documents;
        } else {
          docs = Object.values(docObj).filter((d: any) => typeof d === 'object' && d !== null) as SubmittedDocItem[];
        }
      }

      // Normalize document items so name, filename, and URLs are always populated
      docs = docs.map((d: any) => ({
        ...d,
        name: d.name || d.document_name || d.filename || 'Submitted Document',
        filename: d.filename || d.name || d.document_name,
        document_url: d.document_url || d.url,
        url: d.url || d.document_url,
      }));

      // Strict deduplication by name and document_url / filename
      const uniqueDocs: SubmittedDocItem[] = [];
      const seenNames = new Set<string>();
      const seenUrls = new Set<string>();

      for (const item of docs) {
        const nameKey = (item.name || '').toLowerCase().trim();
        const urlKey = (item.document_url || item.url || item.filename || '').toLowerCase().trim();

        const isDupName = nameKey && seenNames.has(nameKey);
        const isDupUrl = urlKey && seenUrls.has(urlKey);

        if (!isDupName && !isDupUrl) {
          if (nameKey) seenNames.add(nameKey);
          if (urlKey) seenUrls.add(urlKey);
          uniqueDocs.push(item);
        }
      }
      docs = uniqueDocs;

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
    }
  }, [application]);

  if (!isOpen || !application) return null;

  const toggleDocStatus = (index: number, newDocStatus: 'Verified' | 'Flagged' | 'Pending') => {
    setDocumentsList(prev =>
      prev.map((doc, idx) =>
        idx === index ? { ...doc, status: newDocStatus } : doc
      )
    );
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

            <div className="space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <h4 className="text-sm font-extrabold text-[#1A3C2E] font-serif uppercase tracking-wider">
                    Submitted Documents & Requirements ({documentsList.length})
                  </h4>
                  <span className="text-[10px] text-[#6C6C70]">Review and verify applicant requirements, or request additional documents from the student.</span>
                </div>
                <div className="flex items-center gap-2">
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
                    onClick={() => {
                      setDocumentsList(prev => prev.map(d => ({ ...d, status: 'Verified', remarks: '' })));
                    }}
                    className="px-3 py-1.5 rounded-xl bg-[#EBF5EE] hover:bg-[#2D5941] text-[#2D5941] hover:text-white text-[11px] font-bold border border-[#2D5941]/30 cursor-pointer inline-flex items-center gap-1 transition-all"
                  >
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span>Mark All Verified</span>
                  </button>
                </div>
              </div>

              {/* Request Additional Requirement Form */}
              {showAddReqForm && (
                <div className="p-4 rounded-2xl bg-amber-50/50 border border-amber-200 space-y-3 animate-fade-in">
                  <div className="flex items-center justify-between">
                    <h5 className="text-xs font-bold text-[#1A3C2E] flex items-center gap-1.5">
                      <span>📄 Request Additional Requirement from {application.name}</span>
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

              <div className="space-y-2.5">
                {documentsList.map((doc, idx) => {
                  const docUrl = doc.document_url || doc.url;
                  const docStatus = doc.status || 'Pending';
                  return (
                    <div
                      key={idx}
                      className={`p-4 rounded-2xl bg-white border transition-all shadow-sm flex flex-col gap-3 ${
                        docStatus === 'Verified' ? 'border-[#2D5941]/40 bg-[#EBF5EE]/10' :
                        docStatus === 'Flagged' ? 'border-[#B34040]/40 bg-red-50/20' :
                        'border-[#D9D2C5]/70'
                      }`}
                    >
                      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
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
                          <div className="min-w-0">
                            <div className="flex items-center gap-2">
                              <h5 className="font-bold text-[#1C1C1E] text-xs">{doc.name}</h5>
                              <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                                docStatus === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20' :
                                docStatus === 'Flagged' ? 'bg-red-50 text-[#B34040] border border-[#B34040]/20' :
                                'bg-amber-50 text-[#C97B2E] border border-[#C97B2E]/20'
                              }`}>
                                {docStatus === 'Verified' ? '✓ Verified' : docStatus === 'Flagged' ? '🚩 Flagged for Resubmission' : 'Pending Verification'}
                              </span>
                            </div>
                            <p className="text-[10px] text-[#8E8E93] mt-0.5 truncate">
                              File: {doc.filename || doc.name} {doc.filesize ? `• ${doc.filesize}` : ''} {doc.submitted_at ? `• Submitted ${doc.submitted_at}` : ''}
                            </p>
                          </div>
                        </div>

                        <div className="flex items-center gap-2 shrink-0">
                          {docUrl ? (
                            <a
                              href={docUrl}
                              target="_blank"
                              rel="noreferrer"
                              className="px-3 py-1.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-[11px] font-bold border-0 cursor-pointer inline-flex items-center gap-1.5 transition-colors no-underline"
                            >
                              <svg className="w-3.5 h-3.5 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                              </svg>
                              <span>Preview File</span>
                            </a>
                          ) : (
                            <button
                              type="button"
                              onClick={() => alert(`Document file: ${doc.filename || doc.name}\nStatus: ${docStatus}`)}
                              className="px-3 py-1.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-[11px] font-bold border-0 cursor-pointer inline-flex items-center gap-1.5 transition-colors"
                            >
                              <svg className="w-3.5 h-3.5 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                              </svg>
                              <span>Preview File</span>
                            </button>
                          )}

                          <button
                            type="button"
                            onClick={() => toggleDocStatus(idx, docStatus === 'Verified' ? 'Pending' : 'Verified')}
                            className={`px-3 py-1.5 rounded-xl text-[11px] font-bold cursor-pointer transition-colors border-0 ${
                              docStatus === 'Verified'
                                ? 'bg-[#2D5941] text-white shadow-sm'
                                : 'bg-[#EBF5EE] text-[#2D5941] hover:bg-[#2D5941] hover:text-white'
                            }`}
                          >
                            {docStatus === 'Verified' ? '✓ Verified' : 'Mark Verified'}
                          </button>

                          <button
                            type="button"
                            onClick={() => toggleDocStatus(idx, docStatus === 'Flagged' ? 'Pending' : 'Flagged')}
                            className={`px-3 py-1.5 rounded-xl text-[11px] font-bold cursor-pointer transition-colors border-0 ${
                              docStatus === 'Flagged'
                                ? 'bg-[#B34040] text-white shadow-sm'
                                : 'bg-red-50 text-[#B34040] hover:bg-[#B34040] hover:text-white'
                            }`}
                          >
                            {docStatus === 'Flagged' ? '🚩 Flagged' : 'Flag Issue'}
                          </button>

                          {(doc.is_additional || !docUrl) && (
                            <button
                              type="button"
                              onClick={() => handleRemoveDoc(idx)}
                              title="Remove requirement"
                              className="w-8 h-8 rounded-xl bg-gray-100 hover:bg-red-100 text-gray-500 hover:text-red-600 flex items-center justify-center transition-colors border-0 cursor-pointer text-xs"
                            >
                              ✕
                            </button>
                          )}
                        </div>
                      </div>

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
          <form onSubmit={handleSaveDecision} className="bg-[#F9F5EF] p-5 rounded-2xl border border-[#D9D2C5]/70 space-y-4">
            <h4 className="text-xs font-extrabold text-[#1A3C2E] uppercase tracking-wider">
              ⚖️ Application Decision & Provider Remarks
            </h4>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">
                  Update Application Status
                </label>
                <select
                  value={selectedStatus}
                  onChange={(e) => setSelectedStatus(e.target.value as ApplicantStatus)}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none bg-white text-xs font-bold cursor-pointer"
                >
                  <option value="Pending">Pending Evaluation</option>
                  <option value="Under Review">Under Review</option>
                  <option value="For Exam">For Examination</option>
                  <option value="Approved">Approve & Issue Scholar Award</option>
                  <option value="Rejected">Reject Application</option>
                </select>
              </div>

              <div>
                <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">
                  Provider Feedback / Remarks
                </label>
                <input
                  type="text"
                  placeholder="e.g. Approved. Proceed to contract signing..."
                  value={remarks}
                  onChange={(e) => setRemarks(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none bg-white text-xs"
                />
              </div>
            </div>

            <div className="flex justify-end gap-3 pt-2">
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
          </form>

        </div>
      </div>
    </div>
  );
};

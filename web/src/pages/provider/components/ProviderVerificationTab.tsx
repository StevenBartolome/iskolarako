import React from 'react';
import type { ProviderDetails, ProviderProfile } from '../types';
import { supabase } from '@/services/supabaseClient';

interface ProviderVerificationTabProps {
  providerDetails: ProviderDetails | null;
  profile: ProviderProfile | null;
  handleUnsubmitVerification: () => void;
  submittingVerification: boolean;
  requiredDocs: { name: string; description: string; required: boolean }[];
  setProviderDetails: React.Dispatch<React.SetStateAction<any>>;
  showToast: (msg: string) => void;
  uploadingDoc: string | null;
  handleUploadDocument: (docName: string, file: File) => void;
  handleSubmitVerification: () => void;
}

export const ProviderVerificationTab: React.FC<ProviderVerificationTabProps> = ({
  providerDetails,
  profile,
  handleUnsubmitVerification,
  submittingVerification,
  requiredDocs,
  setProviderDetails,
  showToast,
  uploadingDoc,
  handleUploadDocument,
  handleSubmitVerification,
}) => {
  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Organization Verification</h2>
        <p className="text-sm text-[#6C6C70] mt-1 font-medium">Manage and submit organizational documentation required to post scholarship programs.</p>
      </div>

      {/* Status Banner */}
      {providerDetails && (
        <div className={`p-6 rounded-3xl border shadow-sm flex items-start gap-4 ${
          providerDetails.verificationStatus === 'verified'
            ? 'bg-[#EBF5EE] border-[#2D5941]/30 text-[#1A3C2E]'
            : providerDetails.verificationStatus === 'under_review'
              ? 'bg-[#FFF8EE] border-[#C97B2E]/30 text-[#1A3C2E]'
              : providerDetails.verificationStatus === 'rejected'
                ? 'bg-red-50 border-red-200 text-red-900'
                : 'bg-white border-[#D9D2C5]/60 text-[#1C1C1E]'
        }`}>
          <div className={`p-3 rounded-2xl shrink-0 ${
            providerDetails.verificationStatus === 'verified'
              ? 'bg-[#2D5941]/10 text-[#2D5941]'
              : providerDetails.verificationStatus === 'under_review'
                ? 'bg-[#C97B2E]/10 text-[#C97B2E]'
                : providerDetails.verificationStatus === 'rejected'
                  ? 'bg-red-100 text-red-700'
                  : 'bg-[#EDE8DE] text-[#6C6C70]'
          }`}>
            {providerDetails.verificationStatus === 'verified' ? (
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
            ) : providerDetails.verificationStatus === 'under_review' ? (
              <svg className="w-6 h-6 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            ) : providerDetails.verificationStatus === 'rejected' ? (
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            ) : (
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6M9 16h6m2 4H7a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v12a2 2 0 01-2 2z" />
              </svg>
            )}
          </div>

          <div className="space-y-1">
            <h3 className="text-base font-bold">
              {providerDetails.verificationStatus === 'verified' && 'Verified Provider Partner'}
              {providerDetails.verificationStatus === 'under_review' && 'Documents Under Review'}
              {providerDetails.verificationStatus === 'rejected' && 'Verification Rejected'}
              {providerDetails.verificationStatus === 'pending' && 'Verification Incomplete'}
            </h3>
            <p className="text-xs opacity-90 leading-relaxed max-w-2xl font-sans">
              {providerDetails.verificationStatus === 'verified' && 'Your credentials have been successfully reviewed and verified by our system administrators. You are cleared to publish new scholarship programs and manage applications.'}
              {providerDetails.verificationStatus === 'under_review' && 'Your documents are being reviewed by the operations team. The evaluation process usually takes 1-2 business days. You will be notified when your status is updated.'}
              {providerDetails.verificationStatus === 'rejected' && 'Your submitted documents did not meet our verification guidelines. Please review the comments below, re-upload the corrected files, and submit a new request.'}
              {providerDetails.verificationStatus === 'pending' && 'To enable full access to cycle management and student matches, please upload and submit the credentials required for your provider type.'}
            </p>

            {providerDetails.verificationStatus === 'rejected' && providerDetails.requirementsSubmitted['_remarks'] && (
              <div className="mt-3 p-3 bg-red-100/50 border border-red-200/50 rounded-xl text-red-900 text-xs">
                <strong>Remarks: </strong> {providerDetails.requirementsSubmitted['_remarks']}
              </div>
            )}

            {(providerDetails.verificationStatus === 'under_review' || providerDetails.verificationStatus === 'rejected') && profile?.role === 'provider' && (
              <button
                type="button"
                onClick={handleUnsubmitVerification}
                disabled={submittingVerification}
                className="mt-3 bg-white/20 hover:bg-white/30 text-current border border-solid border-current px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer font-sans"
              >
                {submittingVerification ? 'Processing...' : 'Unsubmit & Edit Documents'}
              </button>
            )}
          </div>
        </div>
      )}

      {/* Checklist & Form */}
      <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-8 shadow-sm space-y-6">
        <div className="border-b border-[#D9D2C5]/40 pb-4 flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Required Documents Checklist</h3>
            <p className="text-xs text-[#6C6C70] mt-0.5 font-sans">Requirements for <span className="uppercase font-bold text-[#2D5941]">{providerDetails?.providerType || 'public'}</span> providers:</p>
          </div>
          {profile?.role === 'provider-member' && (
            <span className="px-3.5 py-1.5 rounded-xl bg-slate-100 border border-slate-200 text-slate-600 text-xs font-bold font-sans flex items-center gap-1.5 shrink-0">
              🔒 Read-only (Member View)
            </span>
          )}
        </div>

        {profile?.role === 'provider-member' && (
          <div className="bg-slate-50 border border-slate-200 rounded-2xl p-4 text-slate-600 text-xs font-sans">
            You are viewing this panel as a <strong>Provider Member</strong>. Only the primary <strong>Provider Admin</strong> role is authorized to upload, update, or submit organizational verification requirements.
          </div>
        )}

        <div className="space-y-4">
          {requiredDocs.map((doc, idx) => {
            const isUploaded = !!providerDetails?.requirementsSubmitted[doc.name];
            const docUrl = providerDetails?.requirementsSubmitted[doc.name];
            const isUnderReviewOrVerified = providerDetails?.verificationStatus === 'under_review' || providerDetails?.verificationStatus === 'verified';
            const isReadOnly = isUnderReviewOrVerified || profile?.role === 'provider-member';

            return (
              <div 
                key={idx}
                className="p-5 rounded-2xl border border-[#D9D2C5]/50 flex flex-col md:flex-row md:items-center justify-between gap-4 transition-all hover:bg-slate-50/50"
              >
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <h4 className="font-bold text-sm text-[#1C1C1E]">{doc.name}</h4>
                    {doc.required ? (
                      <span className="text-[9px] bg-red-50 text-red-600 font-bold px-1.5 py-0.5 rounded border border-red-200">REQUIRED</span>
                    ) : (
                      <span className="text-[9px] bg-slate-100 text-slate-500 font-bold px-1.5 py-0.5 rounded">OPTIONAL</span>
                    )}
                  </div>
                  <p className="text-xs text-[#6C6C70] font-sans">{doc.description}</p>
                </div>

                <div className="flex items-center gap-4">
                  {isUploaded ? (
                    <div className="flex items-center gap-3">
                      <span className="flex items-center gap-1 text-xs text-[#2D5941] font-bold font-sans">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                        </svg>
                        Uploaded
                      </span>
                      <a 
                        href={docUrl} 
                        target="_blank" 
                        rel="noreferrer"
                        className="text-xs font-bold text-[#C97B2E] hover:underline"
                      >
                        View File
                      </a>
                      {!isReadOnly && (
                        <button
                          type="button"
                          onClick={async () => {
                            if (!providerDetails) return;
                            const updatedReqs = { ...providerDetails.requirementsSubmitted };
                            delete updatedReqs[doc.name];
                            
                            // Update local state
                            setProviderDetails({
                              ...providerDetails,
                              requirementsSubmitted: updatedReqs
                            });

                            // Update Supabase database immediately
                            try {
                              const { error } = await supabase
                                .from('provider')
                                .update({
                                  requirements_submitted: updatedReqs,
                                  updated_at: new Date().toISOString()
                                })
                                .eq('id', providerDetails.id);
                              if (error) throw error;
                              showToast(`Unsubmitted document: ${doc.name}`);
                            } catch (err: any) {
                              console.error('Error unsubmitting document:', err);
                              showToast(`Failed to update database: ${err.message}`);
                            }
                          }}
                          className="text-xs text-red-500 hover:text-red-700 cursor-pointer bg-transparent border-0 font-sans"
                        >
                          Unsubmit File
                        </button>
                      )}
                    </div>
                  ) : (
                    <div>
                      {isReadOnly ? (
                        <span className="text-xs text-gray-400 italic font-sans">Not Provided</span>
                      ) : (
                        <div>
                          <label className="relative flex items-center justify-center bg-[#EBF5EE] hover:bg-[#d5ebd9] text-[#2D5941] px-4 py-2 rounded-xl text-xs font-bold shadow-sm transition-all cursor-pointer border border-[#2D5941]/10">
                            {uploadingDoc === doc.name ? (
                              <span className="flex items-center gap-1">
                                <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                                </svg>
                                Uploading...
                              </span>
                            ) : (
                              <span>Choose & Upload File</span>
                            )}
                            <input
                              type="file"
                              disabled={uploadingDoc !== null}
                              className="hidden"
                              onChange={(e) => {
                                const file = e.target.files?.[0];
                                if (file) handleUploadDocument(doc.name, file);
                              }}
                            />
                          </label>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Submit Action */}
        {providerDetails && providerDetails.verificationStatus !== 'verified' && providerDetails.verificationStatus !== 'under_review' && profile?.role === 'provider' && (
          <div className="border-t border-[#D9D2C5]/40 pt-6 flex justify-end">
            <button
              type="button"
              onClick={handleSubmitVerification}
              disabled={submittingVerification || uploadingDoc !== null}
              className={`px-8 py-3.5 rounded-xl font-bold text-sm shadow-md transition-all border border-[#1A3C2E]/10 cursor-pointer ${
                submittingVerification || uploadingDoc !== null
                  ? 'bg-gray-300 text-gray-500 cursor-not-allowed border-gray-400'
                  : 'bg-[#2D5941] hover:bg-[#1A3C2E] text-white'
              }`}
            >
              {submittingVerification ? 'Submitting Request...' : 'Submit Verification Request'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

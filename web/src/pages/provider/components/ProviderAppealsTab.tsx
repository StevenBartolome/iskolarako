import React, { useState, useEffect } from 'react';
import { supabase } from '@/services/supabaseClient';
import { createAuditLog } from '@/services/auditLogService';
import { sendDecisionNotification } from '@/services/notificationService';

export interface AppealRecord {
  id: string;
  application_id: string;
  scholar_id: string;
  program_id?: string;
  provider_id?: string;
  reason_category: string;
  statement: string;
  supporting_documents?: any[];
  status: 'pending' | 'under_review' | 'approved' | 'rejected';
  provider_remarks?: string;
  created_at: string;
  // Joined relations
  scholar_name?: string;
  scholar_email?: string;
  program_title?: string;
  original_rejection_remarks?: string;
  application_status?: string;
}

interface ProviderAppealsTabProps {
  providerId?: string;
  showToast?: (msg: string) => void;
}

export const ProviderAppealsTab: React.FC<ProviderAppealsTabProps> = ({
  providerId,
  showToast,
}) => {
  const [appeals, setAppeals] = useState<AppealRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedAppeal, setSelectedAppeal] = useState<AppealRecord | null>(null);
  const [resolutionRemarks, setResolutionRemarks] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [filterStatus, setFilterStatus] = useState<'all' | 'pending' | 'approved' | 'rejected'>('all');

  useEffect(() => {
    fetchAppeals();
  }, [providerId]);

  const fetchAppeals = async () => {
    setIsLoading(true);
    try {
      // 1. Query application_appeals table
      let fetchedAppeals: AppealRecord[] = [];
      try {
        let query = supabase
          .from('application_appeals')
          .select(`
            *,
            application:scholarship_applications (
              id,
              scholar_id,
              status,
              remarks,
              cycle:application_cycles (
                program:scholarship_programs (
                  title,
                  provider_id
                )
              )
            )
          `);

        if (providerId) {
          query = query.eq('provider_id', providerId);
        }

        const { data, error } = await query.order('created_at', { ascending: false });

        if (!error && data) {
          fetchedAppeals = data.map((item: any) => {
            const app = item.application || {};
            const prog = app.cycle?.program || {};
            return {
              id: item.id,
              application_id: item.application_id,
              scholar_id: item.scholar_id,
              program_id: item.program_id,
              provider_id: item.provider_id || prog.provider_id,
              reason_category: item.reason_category || 'General Dispute',
              statement: item.statement || '',
              supporting_documents: item.supporting_documents || [],
              status: item.status || 'pending',
              provider_remarks: item.provider_remarks || '',
              created_at: item.created_at,
              scholar_name: `Scholar (${item.scholar_id.substring(0, 8)})`,
              scholar_email: '',
              program_title: prog.title || 'Scholarship Program',
              original_rejection_remarks: app.remarks || 'No rejection notes recorded.',
              application_status: app.status || 'rejected',
            };
          });
        }
      } catch (dbErr) {
        console.warn('Note fetching application_appeals table:', dbErr);
      }

      // 2. Fallback: Parse scholarship_applications where remarks contains 'Formal Appeal Filed'
      if (fetchedAppeals.length === 0) {
        try {
          const { data: appsData } = await supabase
            .from('scholarship_applications')
            .select(`
              id,
              scholar_id,
              status,
              remarks,
              created_at,
              submitted_documents,
              cycle:application_cycles (
                program:scholarship_programs (
                  title,
                  provider_id
                )
              )
            `)
            .ilike('remarks', '%Formal Appeal Filed%');

          if (appsData && appsData.length > 0) {
            const filteredApps = appsData.filter((app: any) => {
              if (!providerId) return true;
              const prog = app.cycle?.program || {};
              return prog.provider_id === providerId;
            });

            fetchedAppeals = filteredApps.map((app: any) => {
              const prog = app.cycle?.program || {};
              const remarkStr = app.remarks || '';
              const statementMatch = remarkStr.replace('Formal Appeal Filed:', '').trim();
              return {
                id: `fallback_${app.id}`,
                application_id: app.id,
                scholar_id: app.scholar_id,
                reason_category: 'Grade / Requirement Dispute',
                statement: statementMatch || 'Student submitted formal appeal for re-evaluation.',
                supporting_documents: [],
                status: 'pending',
                created_at: app.created_at,
                scholar_name: `Scholar (${app.scholar_id.substring(0, 8)})`,
                program_title: prog.title || 'Scholarship Program',
                original_rejection_remarks: 'Application rejected by committee.',
                application_status: app.status || 'rejected',
              };
            });
          }
        } catch (fErr) {
          console.warn('Note parsing fallback appeals:', fErr);
        }
      }

      // Fetch scholar names and emails
      if (fetchedAppeals.length > 0) {
        const scholarIds = Array.from(new Set(fetchedAppeals.map(a => a.scholar_id)));
        try {
          const { data: scholars } = await supabase
            .from('scholar')
            .select(`
              id,
              user_id,
              first_name,
              last_name,
              users:user_id (
                email
              )
            `)
            .in('id', scholarIds);

          if (scholars) {
            const scholarMap = new Map();
            scholars.forEach((s: any) => {
              const name = [s.first_name, s.last_name].filter(Boolean).join(' ') || 'Scholar';
              const email = (s.users as any)?.email || '';
              scholarMap.set(s.id, { name, email });
              if (s.user_id) scholarMap.set(s.user_id, { name, email });
            });

            fetchedAppeals = fetchedAppeals.map(appeal => {
              const match = scholarMap.get(appeal.scholar_id);
              return {
                ...appeal,
                scholar_name: match ? match.name : appeal.scholar_name,
                scholar_email: match ? match.email : '',
              };
            });
          }
        } catch (sErr) {
          console.warn('Scholar name fetch note:', sErr);
        }
      }

      setAppeals(fetchedAppeals);
    } catch (e) {
      console.error('Error fetching appeals:', e);
    } finally {
      setIsLoading(false);
    }
  };

  const handleResolveAppeal = async (appeal: AppealRecord, newStatus: 'approved' | 'rejected') => {
    setIsSubmitting(true);
    try {
      // 1. Update application_appeals record
      try {
        await supabase
          .from('application_appeals')
          .update({
            status: newStatus,
            provider_remarks: resolutionRemarks || (newStatus === 'approved' ? 'Appeal accepted. Application re-opened for review.' : 'Appeal rejected. Previous decision upheld.'),
            updated_at: new Date().toISOString(),
          })
          .eq('application_id', appeal.application_id);
      } catch (aErr) {
        console.warn('Appeal record update note:', aErr);
      }

      // 2. Update scholarship_applications status if approved
      if (newStatus === 'approved') {
        await supabase
          .from('scholarship_applications')
          .update({
            status: 'under_review',
            remarks: `Appeal Approved: ${resolutionRemarks || 'Re-opened for committee review.'}`,
          })
          .eq('id', appeal.application_id);
      } else {
        await supabase
          .from('scholarship_applications')
          .update({
            remarks: `Appeal Upheld Rejection: ${resolutionRemarks || 'Decision finalized by committee.'}`,
          })
          .eq('id', appeal.application_id);
      }

      // 3. Trigger Push Notification to student
      try {
        await sendDecisionNotification({
          userId: appeal.scholar_id,
          toName: appeal.scholar_name || 'Scholar',
          programTitle: appeal.program_title || 'Scholarship',
          status: newStatus === 'approved' ? 'Under Review' : 'Rejected',
          remarks: newStatus === 'approved'
            ? `Your appeal was ACCEPTED! ${resolutionRemarks}`
            : `Your appeal decision was finalized: ${resolutionRemarks}`,
        });
      } catch (nErr) {
        console.warn('Notification send note:', nErr);
      }

      showToast?.(
        newStatus === 'approved'
          ? `Appeal Accepted! Application re-opened for ${appeal.scholar_name}.`
          : `Appeal decision recorded. Rejection upheld for ${appeal.scholar_name}.`
      );

      const { data: userData } = await supabase.auth.getUser();
      const actor = userData?.user?.email || 'Provider';
      createAuditLog(
        `RESOLVED APPEAL: ${newStatus.toUpperCase()}`,
        `Scholar: ${appeal.scholar_name || 'Scholar'} - Program: ${appeal.program_title || 'Scholarship'}`,
        actor
      );

      setSelectedAppeal(null);
      setResolutionRemarks('');
      fetchAppeals();
    } catch (err) {
      console.error('Error resolving appeal:', err);
      showToast?.('Error saving appeal decision.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const filteredAppeals = appeals.filter(a => {
    if (filterStatus === 'all') return true;
    return a.status === filterStatus;
  });

  const pendingCount = appeals.filter(a => a.status === 'pending').length;
  const approvedCount = appeals.filter(a => a.status === 'approved').length;
  const rejectedCount = appeals.filter(a => a.status === 'rejected').length;

  return (
    <div className="p-6 space-y-6">
      {/* Header Bar */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-white p-5 rounded-2xl border border-[#EDE8DE] shadow-xs">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-xl">⚖️</span>
            <h1 className="text-xl font-extrabold text-[#1A3C2E]">Appeals & Decision Disputes</h1>
          </div>
          <p className="text-xs text-[#6C6C70] mt-1">
            Review formal student appeals for rejected applications, inspect attached proof, and re-evaluate decisions.
          </p>
        </div>

        {/* Filter Chips */}
        <div className="flex gap-2 bg-[#F9F5EF] p-1.5 rounded-xl border border-[#EDE8DE]">
          <button
            onClick={() => setFilterStatus('all')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${filterStatus === 'all' ? 'bg-[#1A3C2E] text-white shadow-xs' : 'text-[#6C6C70] hover:text-[#1A3C2E]'}`}
          >
            All ({appeals.length})
          </button>
          <button
            onClick={() => setFilterStatus('pending')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${filterStatus === 'pending' ? 'bg-[#C97B2E] text-white shadow-xs' : 'text-[#6C6C70] hover:text-[#1A3C2E]'}`}
          >
            Pending ({pendingCount})
          </button>
          <button
            onClick={() => setFilterStatus('approved')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${filterStatus === 'approved' ? 'bg-[#1A3C2E] text-white shadow-xs' : 'text-[#6C6C70] hover:text-[#1A3C2E]'}`}
          >
            Accepted ({approvedCount})
          </button>
          <button
            onClick={() => setFilterStatus('rejected')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${filterStatus === 'rejected' ? 'bg-[#B34040] text-white shadow-xs' : 'text-[#6C6C70] hover:text-[#1A3C2E]'}`}
          >
            Upheld ({rejectedCount})
          </button>
        </div>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-[#EDE8DE] shadow-2xs flex items-center gap-3">
          <div className="p-3 bg-[#F9F5EF] rounded-xl text-lg">⚖️</div>
          <div>
            <div className="text-xl font-extrabold text-[#1A3C2E]">{appeals.length}</div>
            <div className="text-2xs font-bold text-[#8E8E93] uppercase">Total Appeals Filed</div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-[#F5EAD6] shadow-2xs flex items-center gap-3">
          <div className="p-3 bg-[#FFF8EE] rounded-xl text-lg">⏳</div>
          <div>
            <div className="text-xl font-extrabold text-[#C97B2E]">{pendingCount}</div>
            <div className="text-2xs font-bold text-[#8E8E93] uppercase">Pending Review</div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-[#E1EFE6] shadow-2xs flex items-center gap-3">
          <div className="p-3 bg-[#EBF5EE] rounded-xl text-lg">✓</div>
          <div>
            <div className="text-xl font-extrabold text-[#1A3C2E]">{approvedCount}</div>
            <div className="text-2xs font-bold text-[#8E8E93] uppercase">Appeals Accepted</div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-[#FADBD8] shadow-2xs flex items-center gap-3">
          <div className="p-3 bg-[#FDF2F2] rounded-xl text-lg">✕</div>
          <div>
            <div className="text-xl font-extrabold text-[#B34040]">{rejectedCount}</div>
            <div className="text-2xs font-bold text-[#8E8E93] uppercase">Rejections Upheld</div>
          </div>
        </div>
      </div>

      {/* Content List */}
      {isLoading ? (
        <div className="bg-white p-12 rounded-2xl border border-[#EDE8DE] text-center text-xs text-[#6C6C70]">
          Loading student appeals and decision disputes...
        </div>
      ) : filteredAppeals.length === 0 ? (
        <div className="bg-white p-12 rounded-2xl border border-[#EDE8DE] text-center space-y-3">
          <div className="text-3xl">📂</div>
          <div className="text-sm font-bold text-[#1A3C2E]">No appeals found</div>
          <div className="text-xs text-[#6C6C70]">
            There are currently no student application disputes matching the selected filter.
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredAppeals.map(appeal => (
            <div
              key={appeal.id}
              className="bg-white p-5 rounded-2xl border border-[#EDE8DE] shadow-xs hover:border-[#D9D2C5] transition-all space-y-3"
            >
              <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-2">
                <div>
                  <span className="px-2.5 py-1 rounded-md bg-[#F9F5EF] text-[#1A3C2E] text-3xs font-extrabold uppercase tracking-wider">
                    {appeal.program_title}
                  </span>
                  <h3 className="text-sm font-bold text-[#1A3C2E] mt-1">
                    {appeal.scholar_name} {appeal.scholar_email && `(${appeal.scholar_email})`}
                  </h3>
                </div>

                <div className="flex items-center gap-2">
                  <span
                    className={`px-3 py-1 rounded-full text-xs font-bold ${
                      appeal.status === 'pending'
                        ? 'bg-[#FFF8EE] text-[#C97B2E] border border-[#F5EAD6]'
                        : appeal.status === 'approved'
                        ? 'bg-[#EBF5EE] text-[#1A3C2E] border border-[#E1EFE6]'
                        : 'bg-[#FDF2F2] text-[#B34040] border border-[#FADBD8]'
                    }`}
                  >
                    {appeal.status === 'pending'
                      ? '⏳ Pending Review'
                      : appeal.status === 'approved'
                      ? '✓ Appeal Accepted'
                      : '✕ Rejection Upheld'}
                  </span>
                  <span className="text-3xs text-[#8E8E93]">
                    Filed {new Date(appeal.created_at).toLocaleDateString()}
                  </span>
                </div>
              </div>

              {/* Category & Reason Banner */}
              <div className="bg-[#F9F5EF] p-3.5 rounded-xl border border-[#EDE8DE] space-y-1.5">
                <div className="flex items-center gap-2 text-xs font-bold text-[#1A3C2E]">
                  <span>📌 Category:</span>
                  <span className="text-[#C97B2E]">{appeal.reason_category}</span>
                </div>
                <div className="text-xs text-[#2D5941] leading-relaxed">
                  <span className="font-semibold">Scholar Statement:</span> "{appeal.statement}"
                </div>
              </div>

              {/* Original Rejection Remarks */}
              <div className="text-xs text-[#6C6C70] bg-white p-3 rounded-xl border border-[#F0EBE1] flex items-start gap-2">
                <span className="text-sm">💬</span>
                <div>
                  <span className="font-bold text-[#4A4A4A]">Original Provider Rejection Note:</span>{' '}
                  {appeal.original_rejection_remarks}
                </div>
              </div>

              {/* Attached Supporting Documents */}
              {appeal.supporting_documents && appeal.supporting_documents.length > 0 && (
                <div className="pt-1">
                  <div className="text-3xs font-bold text-[#8E8E93] uppercase tracking-wider mb-2">
                    Attached Supporting Proof ({appeal.supporting_documents.length})
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {appeal.supporting_documents.map((doc: any, docIdx: number) => (
                      <a
                        key={docIdx}
                        href={doc.document_url || '#'}
                        target="_blank"
                        rel="noreferrer"
                        className="px-3 py-1.5 rounded-lg bg-[#EBF5EE] hover:bg-[#D4E8DC] text-[#1A3C2E] text-xs font-bold border border-[#D4E8DC] flex items-center gap-1.5 transition-all text-decoration-none"
                      >
                        <span>📎</span> {doc.filename || doc.name || 'View Proof PDF'}
                      </a>
                    ))}
                  </div>
                </div>
              )}

              {/* Provider Resolution Section */}
              {appeal.status === 'pending' ? (
                <div className="pt-3 border-t border-[#F0EBE1] flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
                  <input
                    type="text"
                    placeholder="Enter resolution notes / remarks for scholar..."
                    value={selectedAppeal?.id === appeal.id ? resolutionRemarks : ''}
                    onChange={e => {
                      setSelectedAppeal(appeal);
                      setResolutionRemarks(e.target.value);
                    }}
                    className="flex-1 px-3.5 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white"
                  />
                  <div className="flex gap-2 shrink-0">
                    <button
                      onClick={() => handleResolveAppeal(appeal, 'rejected')}
                      disabled={isSubmitting}
                      className="px-4 py-2 rounded-xl bg-[#FDF2F2] hover:bg-[#FADBD8] text-[#B34040] text-xs font-bold border border-[#FADBD8] cursor-pointer transition-all disabled:opacity-50"
                    >
                      ✕ Uphold Rejection
                    </button>
                    <button
                      onClick={() => handleResolveAppeal(appeal, 'approved')}
                      disabled={isSubmitting}
                      className="px-4 py-2 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer transition-all shadow-sm disabled:opacity-50"
                    >
                      ✓ Accept Appeal & Re-open
                    </button>
                  </div>
                </div>
              ) : (
                appeal.provider_remarks && (
                  <div className="pt-2 border-t border-[#F0EBE1] text-xs text-[#1A3C2E] font-medium">
                    <span className="font-bold">Provider Resolution Remark:</span> {appeal.provider_remarks}
                  </div>
                )
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/services/supabaseClient';

interface AdminDocumentsTabProps {
  showToast?: (msg: string) => void;
}

export const AdminDocumentsTab: React.FC<AdminDocumentsTabProps> = () => {
  const [documents, setDocuments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<'ALL' | 'VERIFIED' | 'FLAGGED' | 'PENDING'>('ALL');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchDocuments();

    const channel = supabase
      .channel('admin-docs-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_applications' },
        () => {
          fetchDocuments();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholar_documents' },
        () => {
          fetchDocuments();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchDocuments = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('scholarship_applications')
        .select(`
          id,
          submitted_documents,
          updated_at,
          scholar:scholar_id (
            first_name,
            last_name
          ),
          cycle:cycle_id (
            program:program_id (
              provider:provider_id (
                name
              )
            )
          )
        `)
        .not('submitted_documents', 'is', null);

      if (!error && data) {
        const extracted: any[] = [];
        data.forEach((app: any) => {
          const scholarName = app.scholar
            ? `${app.scholar.first_name || ''} ${app.scholar.last_name || ''}`.trim()
            : 'Scholar Student';
          const providerName = app.cycle?.program?.provider?.name || 'Scholarship Provider';
          
          let docsList: any[] = [];
          if (app.submitted_documents?.documents && Array.isArray(app.submitted_documents.documents)) {
            docsList = app.submitted_documents.documents;
          } else if (Array.isArray(app.submitted_documents)) {
            docsList = app.submitted_documents;
          } else if (typeof app.submitted_documents === 'object') {
            docsList = Object.entries(app.submitted_documents).map(([k, v]) => ({ name: k, url: v }));
          }

          docsList.forEach((doc: any, index: number) => {
            extracted.push({
              id: `${app.id}-${index}`,
              scholarName,
              providerName,
              docName: doc.name || doc.document_type || doc.type || `Submitted Document #${index + 1}`,
              status: doc.verification_status || doc.status || 'Verified',
              url: doc.url || doc.file_url,
              date: app.updated_at ? new Date(app.updated_at).toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' }) : 'N/A'
            });
          });
        });

        setDocuments(extracted);
      }
    } catch (err) {
      console.error('Error fetching admin documents:', err);
    } finally {
      setLoading(false);
    }
  };

  // Filter documents based on search query and status
  const filteredDocuments = useMemo(() => {
    return documents.filter(doc => {
      const q = searchQuery.toLowerCase().trim();
      const matchesSearch = !q || (
        doc.scholarName.toLowerCase().includes(q) ||
        doc.providerName.toLowerCase().includes(q) ||
        doc.docName.toLowerCase().includes(q) ||
        doc.status.toLowerCase().includes(q) ||
        doc.id.toLowerCase().includes(q)
      );

      if (!matchesSearch) return false;
      if (selectedStatus === 'ALL') return true;

      const stUpper = (doc.status || '').toUpperCase();
      if (selectedStatus === 'VERIFIED') {
        return stUpper.includes('VERIFI') || stUpper.includes('APPROV');
      }
      if (selectedStatus === 'FLAGGED') {
        return stUpper.includes('FLAG') || stUpper.includes('REJECT') || stUpper.includes('ISSUE');
      }
      if (selectedStatus === 'PENDING') {
        return stUpper.includes('PEND') || stUpper.includes('REVIEW') || stUpper.includes('WAIT');
      }

      return true;
    });
  }, [documents, searchQuery, selectedStatus]);

  // Reset page logic & pagination calculations
  const totalPages = Math.max(1, Math.ceil(filteredDocuments.length / itemsPerPage));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const startIndex = (safeCurrentPage - 1) * itemsPerPage;
  const paginatedDocuments = filteredDocuments.slice(startIndex, startIndex + itemsPerPage);

  const handlePageChange = (page: number) => {
    if (page >= 1 && page <= totalPages) {
      setCurrentPage(page);
    }
  };

  const getStatusBadgeStyle = (status: string) => {
    const st = (status || '').toUpperCase();
    if (st.includes('VERIFI') || st.includes('APPROV')) {
      return 'bg-[#EBF5EE] text-[#2D5941] border-[#2D5941]/20';
    }
    if (st.includes('FLAG') || st.includes('REJECT')) {
      return 'bg-red-50 text-[#B34040] border-[#B34040]/20';
    }
    return 'bg-[#FFF8EE] text-[#C97B2E] border-[#C97B2E]/20';
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header Banner */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-[#D9D2C5]">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Document Verification Logs</h3>
              <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                Oversight Registry
              </span>
            </div>
            <p className="text-xs text-[#6C6C70]">
              Track student requirement submissions, verification logs, and provider compliance tracking.
            </p>
          </div>

          <div className="flex items-center gap-3 shrink-0">
            <div className="text-right hidden sm:block">
              <span className="block text-xs font-bold text-[#1A3C2E]">{documents.length} Total Documents</span>
              <span className="block text-[10px] text-[#6C6C70]">10 entries per page</span>
            </div>
          </div>
        </div>

        {/* Toolbar: Search and Filter Pills */}
        <div className="mt-6 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
          {/* Status Filter Pills */}
          <div className="flex flex-wrap items-center gap-1.5 bg-[#F9F5EF] p-1 rounded-xl border border-[#D9D2C5]">
            <button
              type="button"
              onClick={() => { setSelectedStatus('ALL'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'ALL'
                  ? 'bg-[#1A3C2E] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              All Documents ({documents.length})
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('VERIFIED'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'VERIFIED'
                  ? 'bg-[#2D5941] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Verified
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('FLAGGED'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'FLAGGED'
                  ? 'bg-[#B34040] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Flagged / Action Needed
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('PENDING'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'PENDING'
                  ? 'bg-[#C97B2E] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Pending Review
            </button>
          </div>

          {/* Search Box */}
          <div className="relative min-w-[260px]">
            <svg className="w-4 h-4 text-[#8E8E93] absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              placeholder="Search by student, file, provider..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setCurrentPage(1);
              }}
              className="w-full pl-9 pr-4 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF] text-[#1C1C1E]"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => { setSearchQuery(''); setCurrentPage(1); }}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-[#8E8E93] hover:text-[#1C1C1E]"
              >
                ✕
              </button>
            )}
          </div>
        </div>

        {/* Table View */}
        <div className="mt-6 overflow-x-auto text-xs text-[#6C6C70]">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                <th className="py-3 px-2">Doc Ref ID</th>
                <th className="py-3 px-2">Student Scholar</th>
                <th className="py-3 px-2">Requirement / File Name</th>
                <th className="py-3 px-2">Provider Oversight</th>
                <th className="py-3 px-2">Verification Status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-xs text-[#6C6C70] italic">
                    <div className="flex items-center justify-center gap-2">
                      <div className="w-4 h-4 border-2 border-[#2D5941] border-t-transparent rounded-full animate-spin" />
                      <span>Loading verification document logs...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredDocuments.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-xs text-[#6C6C70] italic">
                    No document submission logs match your current search or filter criteria.
                  </td>
                </tr>
              ) : (
                paginatedDocuments.map((doc, idx) => {
                  const globalIdx = startIndex + idx + 1;
                  return (
                    <tr key={doc.id || idx} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50 transition-colors">
                      <td className="py-3.5 px-2 font-mono font-bold text-[#1A3C2E]">
                        DOC-{String(globalIdx).padStart(4, '0')}
                      </td>
                      <td className="py-3.5 px-2 font-semibold text-[#1C1C1E]">
                        {doc.scholarName}
                      </td>
                      <td className="py-3.5 px-2">
                        <div className="flex items-center gap-1.5">
                          <span className="font-medium text-[#1C1C1E]">{doc.docName}</span>
                          {doc.url && (
                            <a
                              href={doc.url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-[#2D5941] hover:text-[#1A3C2E] p-1 rounded-md hover:bg-[#EBF5EE] transition-colors"
                              title="View Document"
                            >
                              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                              </svg>
                            </a>
                          )}
                        </div>
                      </td>
                      <td className="py-3.5 px-2 text-[#48484A]">
                        {doc.providerName}
                      </td>
                      <td className="py-3.5 px-2">
                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-extrabold border ${getStatusBadgeStyle(doc.status)}`}>
                          {doc.status || 'Verified'}
                        </span>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer Controls (Identical to AdminLogsTab) */}
        {!loading && filteredDocuments.length > 0 && (
          <div className="mt-6 pt-4 border-t border-[#D9D2C5] flex flex-col sm:flex-row items-center justify-between gap-4">
            <span className="text-xs text-[#6C6C70]">
              Showing <strong className="text-[#1C1C1E]">{startIndex + 1}</strong> to{' '}
              <strong className="text-[#1C1C1E]">{Math.min(startIndex + itemsPerPage, filteredDocuments.length)}</strong> of{' '}
              <strong className="text-[#1C1C1E]">{filteredDocuments.length}</strong> document entries
            </span>

            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={() => handlePageChange(safeCurrentPage - 1)}
                disabled={safeCurrentPage === 1}
                className="px-3 py-1.5 text-xs font-bold rounded-xl border border-[#D9D2C5] bg-white text-[#1C1C1E] hover:bg-[#F9F5EF] disabled:opacity-40 disabled:cursor-not-allowed transition-all cursor-pointer flex items-center gap-1"
              >
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 19l-7-7 7-7" />
                </svg>
                Prev
              </button>

              {/* Page Numbers */}
              <div className="flex items-center gap-1 px-1">
                {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => {
                  if (
                    totalPages > 7 &&
                    page !== 1 &&
                    page !== totalPages &&
                    Math.abs(page - safeCurrentPage) > 1
                  ) {
                    if (
                      (page === 2 && safeCurrentPage > 3) ||
                      (page === totalPages - 1 && safeCurrentPage < totalPages - 2)
                    ) {
                      return (
                        <span key={page} className="px-1 text-[#8E8E93] text-xs">
                          ...
                        </span>
                      );
                    }
                    return null;
                  }

                  return (
                    <button
                      key={page}
                      type="button"
                      onClick={() => handlePageChange(page)}
                      className={`w-7 h-7 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center ${
                        safeCurrentPage === page
                          ? 'bg-[#1A3C2E] text-white shadow-sm'
                          : 'bg-white border border-[#D9D2C5] text-[#1C1C1E] hover:bg-[#F9F5EF]'
                      }`}
                    >
                      {page}
                    </button>
                  );
                })}
              </div>

              <button
                type="button"
                onClick={() => handlePageChange(safeCurrentPage + 1)}
                disabled={safeCurrentPage === totalPages}
                className="px-3 py-1.5 text-xs font-bold rounded-xl border border-[#D9D2C5] bg-white text-[#1C1C1E] hover:bg-[#F9F5EF] disabled:opacity-40 disabled:cursor-not-allowed transition-all cursor-pointer flex items-center gap-1"
              >
                Next
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" />
                </svg>
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};


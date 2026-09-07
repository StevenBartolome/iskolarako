import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/services/supabaseClient';

export const AdminApplicationsTab: React.FC = () => {
  const [applications, setApplications] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<'ALL' | 'PENDING' | 'UNDER_REVIEW' | 'APPROVED' | 'REJECTED' | 'WITHDRAWN'>('ALL');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchApplications();

    const channel = supabase
      .channel('admin-apps-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_applications' },
        () => {
          fetchApplications();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'application_appeals' },
        () => {
          fetchApplications();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchApplications = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('scholarship_applications')
        .select(`
          id,
          status,
          created_at,
          updated_at,
          scholar:scholar_id (
            first_name,
            last_name
          ),
          cycle:cycle_id (
            cycle_name,
            program:program_id (
              title,
              provider:provider_id (
                name
              )
            )
          )
        `)
        .order('created_at', { ascending: false });

      if (!error && data) {
        setApplications(data);
      }
    } catch (err) {
      console.error('Error fetching admin applications:', err);
    } finally {
      setLoading(false);
    }
  };

  const counts = {
    total: applications.length,
    pending: applications.filter(a => (a.status || '').toLowerCase() === 'pending').length,
    underReview: applications.filter(a => (a.status || '').toLowerCase() === 'under_review' || (a.status || '').toLowerCase() === 'for_exam').length,
    approved: applications.filter(a => (a.status || '').toLowerCase() === 'approved').length,
    rejected: applications.filter(a => (a.status || '').toLowerCase() === 'rejected').length,
    withdrawn: applications.filter(a => (a.status || '').toLowerCase() === 'withdrawn').length,
  };

  // Filter applications based on search query and pipeline status
  const filteredApplications = useMemo(() => {
    return applications.filter(app => {
      const q = searchQuery.toLowerCase().trim();
      const studentName = app.scholar
        ? `${app.scholar.first_name || ''} ${app.scholar.last_name || ''}`.trim()
        : '';
      const programTitle = app.cycle?.program?.title || '';
      const providerName = app.cycle?.program?.provider?.name || '';
      const statusStr = (app.status || '').toLowerCase();
      const idStr = String(app.id);

      const matchesSearch = !q || (
        studentName.toLowerCase().includes(q) ||
        programTitle.toLowerCase().includes(q) ||
        providerName.toLowerCase().includes(q) ||
        statusStr.includes(q) ||
        idStr.includes(q)
      );

      if (!matchesSearch) return false;
      if (selectedStatus === 'ALL') return true;

      if (selectedStatus === 'PENDING') return statusStr === 'pending';
      if (selectedStatus === 'UNDER_REVIEW') return statusStr === 'under_review' || statusStr === 'for_exam';
      if (selectedStatus === 'APPROVED') return statusStr === 'approved';
      if (selectedStatus === 'REJECTED') return statusStr === 'rejected';
      if (selectedStatus === 'WITHDRAWN') return statusStr === 'withdrawn';

      return true;
    });
  }, [applications, searchQuery, selectedStatus]);

  // Reset page logic & pagination calculations
  const totalPages = Math.max(1, Math.ceil(filteredApplications.length / itemsPerPage));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const startIndex = (safeCurrentPage - 1) * itemsPerPage;
  const paginatedApplications = filteredApplications.slice(startIndex, startIndex + itemsPerPage);

  const handlePageChange = (page: number) => {
    if (page >= 1 && page <= totalPages) {
      setCurrentPage(page);
    }
  };

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-[#D9D2C5]">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Application Monitor & Pipelines</h3>
              <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
                Real-Time Tracking
              </span>
            </div>
            <p className="text-xs text-[#6C6C70]">
              Monitor applicant status pipelines, document review progress, and provider award allocations platform-wide.
            </p>
          </div>

          <div className="flex items-center gap-3 shrink-0">
            <div className="text-right hidden sm:block">
              <span className="block text-xs font-bold text-[#1A3C2E]">{counts.total} Applications</span>
              <span className="block text-[10px] text-[#6C6C70]">10 entries per page</span>
            </div>
          </div>
        </div>
        
        {/* Dynamic Pipeline Counter Cards (Interactive Filters) */}
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 my-6 text-center">
          <button
            type="button"
            onClick={() => { setSelectedStatus('PENDING'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'PENDING' ? 'bg-gray-200 border-gray-400 shadow-sm' : 'bg-gray-50 border-[#D9D2C5]/50 hover:bg-gray-100'
            }`}
          >
            <span className="text-xl font-black text-gray-700 block">{counts.pending}</span>
            <span className="text-[10px] text-gray-500 font-bold uppercase tracking-wider block mt-0.5">Pending</span>
          </button>
          
          <button
            type="button"
            onClick={() => { setSelectedStatus('UNDER_REVIEW'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'UNDER_REVIEW' ? 'bg-amber-100 border-[#C97B2E] shadow-sm' : 'bg-amber-50 border-[#C97B2E]/20 hover:bg-amber-100/70'
            }`}
          >
            <span className="text-xl font-black text-[#C97B2E] block">{counts.underReview}</span>
            <span className="text-[10px] text-[#C97B2E] font-bold uppercase tracking-wider block mt-0.5">Under Review</span>
          </button>

          <button
            type="button"
            onClick={() => { setSelectedStatus('APPROVED'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'APPROVED' ? 'bg-[#D5EBDC] border-[#2D5941] shadow-sm' : 'bg-[#EBF5EE] border-[#2D5941]/20 hover:bg-[#EBF5EE]/80'
            }`}
          >
            <span className="text-xl font-black text-[#2D5941] block">{counts.approved}</span>
            <span className="text-[10px] text-[#2D5941] font-bold uppercase tracking-wider block mt-0.5">Approved</span>
          </button>

          <button
            type="button"
            onClick={() => { setSelectedStatus('REJECTED'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'REJECTED' ? 'bg-red-100 border-[#B34040] shadow-sm' : 'bg-red-50 border-[#B34040]/20 hover:bg-red-100/70'
            }`}
          >
            <span className="text-xl font-black text-[#B34040] block">{counts.rejected}</span>
            <span className="text-[10px] text-[#B34040] font-bold uppercase tracking-wider block mt-0.5">Rejected</span>
          </button>

          <button
            type="button"
            onClick={() => { setSelectedStatus('WITHDRAWN'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'WITHDRAWN' ? 'bg-blue-100 border-blue-400 shadow-sm' : 'bg-blue-50 border-blue-200 hover:bg-blue-100/70'
            }`}
          >
            <span className="text-xl font-black text-blue-700 block">{counts.withdrawn}</span>
            <span className="text-[10px] text-blue-500 font-bold uppercase tracking-wider block mt-0.5">Withdrawn</span>
          </button>
        </div>

        {/* Toolbar: Search and Filter Pills */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 mb-6">
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
              All Applications ({counts.total})
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('PENDING'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'PENDING'
                  ? 'bg-gray-700 text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Pending
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('UNDER_REVIEW'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'UNDER_REVIEW'
                  ? 'bg-[#C97B2E] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Under Review
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('APPROVED'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'APPROVED'
                  ? 'bg-[#2D5941] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Approved
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('REJECTED'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'REJECTED'
                  ? 'bg-[#B34040] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Rejected
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('WITHDRAWN'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'WITHDRAWN'
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Withdrawn
            </button>
          </div>

          {/* Search Box */}
          <div className="relative min-w-[260px]">
            <svg className="w-4 h-4 text-[#8E8E93] absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              placeholder="Search student, program, provider..."
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
        <div className="overflow-x-auto text-xs text-[#6C6C70]">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                <th className="py-3 px-2">App Ref ID</th>
                <th className="py-3 px-2">Student Scholar</th>
                <th className="py-3 px-2">Scholarship Program & Provider</th>
                <th className="py-3 px-2">Pipeline Status</th>
                <th className="py-3 px-2">Last Update</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-xs text-[#6C6C70] italic">
                    <div className="flex items-center justify-center gap-2">
                      <div className="w-4 h-4 border-2 border-[#2D5941] border-t-transparent rounded-full animate-spin" />
                      <span>Loading pipeline applications from database...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredApplications.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-xs text-[#6C6C70] italic">
                    No applications match your current search or status filter.
                  </td>
                </tr>
              ) : (
                paginatedApplications.map((app, idx) => {
                  const studentName = app.scholar
                    ? `${app.scholar.first_name || ''} ${app.scholar.last_name || ''}`.trim()
                    : 'Scholar Student';
                  const programTitle = app.cycle?.program?.title || 'Scholarship Program';
                  const providerName = app.cycle?.program?.provider?.name || 'Provider';
                  const status = (app.status || 'pending').toLowerCase();
                  const globalIdx = startIndex + idx + 1;

                  let statusBadge = (
                    <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-extrabold bg-gray-100 text-gray-700 border border-gray-200">
                      Pending
                    </span>
                  );
                  if (status === 'approved') {
                    statusBadge = (
                      <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-extrabold bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
                        Approved
                      </span>
                    );
                  } else if (status === 'under_review' || status === 'for_exam') {
                    statusBadge = (
                      <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-extrabold bg-amber-50 text-[#C97B2E] border border-[#C97B2E]/20">
                        Under Review
                      </span>
                    );
                  } else if (status === 'rejected') {
                    statusBadge = (
                      <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-extrabold bg-red-50 text-[#B34040] border border-[#B34040]/20">
                        Rejected
                      </span>
                    );
                  } else if (status === 'withdrawn') {
                    statusBadge = (
                      <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-extrabold bg-blue-50 text-blue-700 border border-blue-200">
                        Withdrawn
                      </span>
                    );
                  }

                  const dateStr = app.updated_at
                    ? new Date(app.updated_at).toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' })
                    : 'Recently';

                  return (
                    <tr key={app.id} className="border-b border-[#D9D2C5]/40 hover:bg-[#F9F5EF]/50 transition-colors">
                      <td className="py-3.5 px-2 font-mono font-bold text-[#1A3C2E]">
                        APP-{String(globalIdx).padStart(4, '0')}
                      </td>
                      <td className="py-3.5 px-2 font-bold text-[#1C1C1E]">{studentName}</td>
                      <td className="py-3.5 px-2">
                        <span className="font-semibold text-[#1C1C1E]">{programTitle}</span>{' '}
                        <span className="text-[10px] text-[#6C6C70] font-medium">({providerName})</span>
                      </td>
                      <td className="py-3.5 px-2">{statusBadge}</td>
                      <td className="py-3.5 px-2 text-[#6C6C70]">{dateStr}</td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer Controls (Identical to AdminLogsTab) */}
        {!loading && filteredApplications.length > 0 && (
          <div className="mt-6 pt-4 border-t border-[#D9D2C5] flex flex-col sm:flex-row items-center justify-between gap-4">
            <span className="text-xs text-[#6C6C70]">
              Showing <strong className="text-[#1C1C1E]">{startIndex + 1}</strong> to{' '}
              <strong className="text-[#1C1C1E]">{Math.min(startIndex + itemsPerPage, filteredApplications.length)}</strong> of{' '}
              <strong className="text-[#1C1C1E]">{filteredApplications.length}</strong> application entries
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


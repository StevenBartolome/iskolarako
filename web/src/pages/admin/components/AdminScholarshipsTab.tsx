import React, { useState, useMemo } from 'react';
import type { ScholarshipAdminView } from '../types';
import { supabase } from '@/services/supabaseClient';

interface AdminScholarshipsTabProps {
  loadingScholarships: boolean;
  scholarships: ScholarshipAdminView[];
  setSelectedScholarshipDetails: (prog: any) => void;
  handleScholarshipAction: (id: any, action: 'Approved' | 'Rejected' | 'Suspended') => void;
}

export const AdminScholarshipsTab: React.FC<AdminScholarshipsTabProps> = ({
  loadingScholarships,
  scholarships,
  setSelectedScholarshipDetails,
  handleScholarshipAction,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<'ALL' | 'PENDING' | 'PUBLISHED' | 'SUSPENDED' | 'REJECTED'>('ALL');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  const counts = {
    total: scholarships.length,
    pending: scholarships.filter(s => (s.status || '').toLowerCase().includes('pending')).length,
    published: scholarships.filter(s => (s.status || '').toLowerCase() === 'published' || (s.status || '').toLowerCase() === 'approved').length,
    suspended: scholarships.filter(s => (s.status || '').toLowerCase() === 'suspended').length,
    rejected: scholarships.filter(s => (s.status || '').toLowerCase() === 'rejected').length,
  };

  const filteredScholarships = useMemo(() => {
    return scholarships.filter(s => {
      const q = searchQuery.toLowerCase().trim();
      const matchesSearch = !q || (
        s.title.toLowerCase().includes(q) ||
        s.providerName.toLowerCase().includes(q) ||
        s.category.toLowerCase().includes(q) ||
        s.status.toLowerCase().includes(q) ||
        String(s.amount).includes(q)
      );

      if (!matchesSearch) return false;
      if (selectedStatus === 'ALL') return true;

      const stLower = (s.status || '').toLowerCase();
      if (selectedStatus === 'PENDING') return stLower.includes('pending');
      if (selectedStatus === 'PUBLISHED') return stLower === 'published' || stLower === 'approved';
      if (selectedStatus === 'SUSPENDED') return stLower === 'suspended';
      if (selectedStatus === 'REJECTED') return stLower === 'rejected';

      return true;
    });
  }, [scholarships, searchQuery, selectedStatus]);

  const totalPages = Math.max(1, Math.ceil(filteredScholarships.length / itemsPerPage));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const startIndex = (safeCurrentPage - 1) * itemsPerPage;
  const paginatedScholarships = filteredScholarships.slice(startIndex, startIndex + itemsPerPage);

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
              <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Scholarship Governance</h3>
              <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 14l9-5-9-5-9 5 9 5z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0112 20.055a11.952 11.952 0 01-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" />
                </svg>
                Program Moderation
              </span>
            </div>
            <p className="text-xs text-[#6C6C70]">
              Review and moderate scholarships created by providers. All programs must be approved before publishing.
            </p>
          </div>

          <div className="flex items-center gap-3 shrink-0">
            <div className="text-right hidden sm:block">
              <span className="block text-xs font-bold text-[#1A3C2E]">{counts.total} Total Scholarships</span>
              <span className="block text-[10px] text-[#6C6C70]">10 entries per page</span>
            </div>
          </div>
        </div>

        {/* Dynamic Governance Stat Cards (Interactive Filters) */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 my-6 text-center">
          <button
            type="button"
            onClick={() => { setSelectedStatus('PENDING'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'PENDING' ? 'bg-amber-100 border-[#C97B2E] shadow-sm' : 'bg-[#FFF8EE] border-[#C97B2E]/20 hover:bg-amber-100/70'
            }`}
          >
            <span className="text-xl font-black text-[#C97B2E] block">{counts.pending}</span>
            <span className="text-[10px] text-[#C97B2E] font-bold uppercase tracking-wider block mt-0.5">Pending Review</span>
          </button>

          <button
            type="button"
            onClick={() => { setSelectedStatus('PUBLISHED'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'PUBLISHED' ? 'bg-[#D5EBDC] border-[#2D5941] shadow-sm' : 'bg-[#EBF5EE] border-[#2D5941]/20 hover:bg-[#EBF5EE]/80'
            }`}
          >
            <span className="text-xl font-black text-[#2D5941] block">{counts.published}</span>
            <span className="text-[10px] text-[#2D5941] font-bold uppercase tracking-wider block mt-0.5">Published / Active</span>
          </button>

          <button
            type="button"
            onClick={() => { setSelectedStatus('SUSPENDED'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'SUSPENDED' ? 'bg-red-100 border-[#B34040] shadow-sm' : 'bg-red-50 border-[#B34040]/20 hover:bg-red-100/70'
            }`}
          >
            <span className="text-xl font-black text-[#B34040] block">{counts.suspended}</span>
            <span className="text-[10px] text-[#B34040] font-bold uppercase tracking-wider block mt-0.5">Suspended</span>
          </button>

          <button
            type="button"
            onClick={() => { setSelectedStatus('REJECTED'); setCurrentPage(1); }}
            className={`p-3 rounded-xl border transition-all cursor-pointer text-left ${
              selectedStatus === 'REJECTED' ? 'bg-gray-200 border-gray-400 shadow-sm' : 'bg-gray-50 border-[#D9D2C5]/50 hover:bg-gray-100'
            }`}
          >
            <span className="text-xl font-black text-gray-700 block">{counts.rejected}</span>
            <span className="text-[10px] text-gray-500 font-bold uppercase tracking-wider block mt-0.5">Rejected</span>
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
              All Programs ({counts.total})
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
            <button
              type="button"
              onClick={() => { setSelectedStatus('PUBLISHED'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'PUBLISHED'
                  ? 'bg-[#2D5941] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Published
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('SUSPENDED'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'SUSPENDED'
                  ? 'bg-[#B34040] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Suspended
            </button>
            <button
              type="button"
              onClick={() => { setSelectedStatus('REJECTED'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedStatus === 'REJECTED'
                  ? 'bg-gray-700 text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Rejected
            </button>
          </div>

          {/* Search Box */}
          <div className="relative min-w-[260px]">
            <svg className="w-4 h-4 text-[#8E8E93] absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              placeholder="Search title, provider, category..."
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
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-[#6C6C70]">
            <thead>
              <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                <th className="py-3">Title</th>
                <th>Provider</th>
                <th>Category</th>
                <th>Grant Value</th>
                <th>Status</th>
                <th>Submitted</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loadingScholarships ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-xs text-[#6C6C70] italic">
                    <div className="flex items-center justify-center gap-2">
                      <div className="w-4 h-4 border-2 border-[#2D5941] border-t-transparent rounded-full animate-spin" />
                      <span>Loading scholarships governance list...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredScholarships.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-xs text-[#6C6C70] italic">
                    No scholarship programs match your current search or status filter.
                  </td>
                </tr>
              ) : (
                paginatedScholarships.map(s => (
                  <tr key={s.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50 transition-colors">
                    <td className="py-4 font-bold text-[#1C1C1E]">{s.title}</td>
                    <td>{s.providerName}</td>
                    <td>{s.category}</td>
                    <td className="font-semibold text-[#2D5941]">₱{s.amount.toLocaleString()}</td>
                    <td>
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                        s.status === 'Published' || s.status === 'Approved' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                        s.status === 'Pending Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                        'bg-red-50 text-[#B34040]'
                      }`}>
                        {s.status}
                      </span>
                    </td>
                    <td>{s.dateCreated}</td>
                    <td className="text-right">
                      <div className="flex justify-end gap-1.5">
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
                                .eq('id', s.id)
                                .single();
                              if (fullProg) {
                                setSelectedScholarshipDetails(fullProg);
                              }
                            } catch (e) {
                              console.error(e);
                            }
                          }}
                          className="bg-[#EDE8DE] text-[#1A3C2E] hover:bg-[#D9D2C5] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                        >
                          View
                        </button>
                        {s.status === 'Pending Review' && (
                          <>
                            <button
                              type="button"
                              onClick={() => handleScholarshipAction(s.id, 'Approved')}
                              className="bg-[#2D5941] text-white hover:bg-[#1A3C2E] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                            >
                              Approve
                            </button>
                            <button
                              type="button"
                              onClick={() => handleScholarshipAction(s.id, 'Rejected')}
                              className="bg-[#B34040] text-white hover:bg-[#8E2F2F] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                            >
                              Reject
                            </button>
                          </>
                        )}
                        {s.status === 'Published' && (
                          <button
                            type="button"
                            onClick={() => handleScholarshipAction(s.id, 'Suspended')}
                            className="bg-red-50 text-[#B34040] border border-solid border-[#B34040]/30 px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer hover:bg-red-100"
                          >
                            Suspend
                          </button>
                        )}
                        {s.status === 'Suspended' && (
                          <button
                            type="button"
                            onClick={() => handleScholarshipAction(s.id, 'Approved')}
                            className="bg-[#EBF5EE] text-[#2D5941] border border-solid border-[#2D5941]/30 px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer hover:bg-green-100"
                          >
                            Unsuspend / Publish
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer Controls (Identical to AdminLogsTab) */}
        {!loadingScholarships && filteredScholarships.length > 0 && (
          <div className="mt-6 pt-4 border-t border-[#D9D2C5] flex flex-col sm:flex-row items-center justify-between gap-4">
            <span className="text-xs text-[#6C6C70]">
              Showing <strong className="text-[#1C1C1E]">{startIndex + 1}</strong> to{' '}
              <strong className="text-[#1C1C1E]">{Math.min(startIndex + itemsPerPage, filteredScholarships.length)}</strong> of{' '}
              <strong className="text-[#1C1C1E]">{filteredScholarships.length}</strong> scholarship entries
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


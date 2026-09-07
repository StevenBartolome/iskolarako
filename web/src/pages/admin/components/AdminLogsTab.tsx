import React, { useState, useMemo } from 'react';
import type { AuditLogEntry } from '../types';

interface AdminLogsTabProps {
  auditLogs: AuditLogEntry[];
}

export const AdminLogsTab: React.FC<AdminLogsTabProps> = ({ auditLogs }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<'ALL' | 'APPROVAL' | 'UPDATE' | 'SECURITY'>('ALL');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  // Filter logs based on search query and category
  const filteredLogs = useMemo(() => {
    return auditLogs.filter(log => {
      const q = searchQuery.toLowerCase().trim();
      const matchesSearch = !q || (
        log.admin.toLowerCase().includes(q) ||
        log.action.toLowerCase().includes(q) ||
        log.target.toLowerCase().includes(q) ||
        log.date.toLowerCase().includes(q) ||
        log.time.toLowerCase().includes(q) ||
        (log.ip && log.ip.toLowerCase().includes(q))
      );

      if (!matchesSearch) return false;

      if (selectedCategory === 'ALL') return true;

      const actUpper = log.action.toUpperCase();
      if (selectedCategory === 'APPROVAL') {
        return (
          actUpper.includes('APPROV') ||
          actUpper.includes('VERIFI') ||
          actUpper.includes('PUBLISH') ||
          actUpper.includes('RESOLV') ||
          actUpper.includes('ACCEPT')
        );
      }
      if (selectedCategory === 'SECURITY') {
        return (
          actUpper.includes('SUSPEND') ||
          actUpper.includes('REJECT') ||
          actUpper.includes('DISMISS') ||
          actUpper.includes('REVOK') ||
          actUpper.includes('DELETE') ||
          actUpper.includes('DENY')
        );
      }
      if (selectedCategory === 'UPDATE') {
        return (
          actUpper.includes('UPDATE') ||
          actUpper.includes('EDIT') ||
          actUpper.includes('OPEN') ||
          actUpper.includes('CLOSE') ||
          actUpper.includes('CHANGE') ||
          actUpper.includes('SUBMIT')
        );
      }

      return true;
    });
  }, [auditLogs, searchQuery, selectedCategory]);

  // Reset to page 1 when search or filter changes
  const totalPages = Math.max(1, Math.ceil(filteredLogs.length / itemsPerPage));
  const safeCurrentPage = Math.min(currentPage, totalPages);

  const startIndex = (safeCurrentPage - 1) * itemsPerPage;
  const paginatedLogs = filteredLogs.slice(startIndex, startIndex + itemsPerPage);

  const getActionBadgeStyle = (action: string) => {
    const act = action.toUpperCase();
    if (
      act.includes('APPROVED') ||
      act.includes('VERIFIED') ||
      act.includes('PUBLISHED') ||
      act.includes('RESOLVED') ||
      act.includes('ACCEPTED')
    ) {
      return 'bg-[#EBF5EE] text-[#2D5941] border-[#2D5941]/20';
    }
    if (
      act.includes('SUSPENDED') ||
      act.includes('REJECTED') ||
      act.includes('DISMISSED') ||
      act.includes('REVOKED') ||
      act.includes('DELETED')
    ) {
      return 'bg-red-50 text-[#B34040] border-[#B34040]/20';
    }
    if (
      act.includes('UPDATED') ||
      act.includes('EDITED') ||
      act.includes('OPENED') ||
      act.includes('CLOSED') ||
      act.includes('RENEWED')
    ) {
      return 'bg-[#FFF8EE] text-[#C97B2E] border-[#C97B2E]/20';
    }
    return 'bg-[#F0F4F8] text-[#334E68] border-[#334E68]/20';
  };

  const handlePageChange = (page: number) => {
    if (page >= 1 && page <= totalPages) {
      setCurrentPage(page);
    }
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header Banner */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-[#D9D2C5]">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Platform Audit Trail</h3>
              <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
                Immutable Security Log
              </span>
            </div>
            <p className="text-xs text-[#6C6C70]">
              Complete chronological audit history of administrative actions, compliance verifications, and system modifications.
            </p>
          </div>

          <div className="flex items-center gap-3 shrink-0">
            <div className="text-right hidden sm:block">
              <span className="block text-xs font-bold text-[#1A3C2E]">{auditLogs.length} Total Logs</span>
              <span className="block text-[10px] text-[#6C6C70]">Max 10 entries per page</span>
            </div>
          </div>
        </div>

        {/* Toolbar: Search and Filter Pills */}
        <div className="mt-6 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
          {/* Category Filter Pills */}
          <div className="flex flex-wrap items-center gap-1.5 bg-[#F9F5EF] p-1 rounded-xl border border-[#D9D2C5]">
            <button
              type="button"
              onClick={() => { setSelectedCategory('ALL'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedCategory === 'ALL'
                  ? 'bg-[#1A3C2E] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              All Logs ({auditLogs.length})
            </button>
            <button
              type="button"
              onClick={() => { setSelectedCategory('APPROVAL'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedCategory === 'APPROVAL'
                  ? 'bg-[#2D5941] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Approvals & Proofs
            </button>
            <button
              type="button"
              onClick={() => { setSelectedCategory('UPDATE'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedCategory === 'UPDATE'
                  ? 'bg-[#C97B2E] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Modifications
            </button>
            <button
              type="button"
              onClick={() => { setSelectedCategory('SECURITY'); setCurrentPage(1); }}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                selectedCategory === 'SECURITY'
                  ? 'bg-[#B34040] text-white shadow-sm'
                  : 'text-[#6C6C70] hover:text-[#1C1C1E] hover:bg-white/60'
              }`}
            >
              Flags & Suspensions
            </button>
          </div>

          {/* Search Box */}
          <div className="relative min-w-[260px]">
            <svg className="w-4 h-4 text-[#8E8E93] absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              placeholder="Search by admin, action, target, IP..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setCurrentPage(1);
              }}
              className="w-full pl-9 pr-8 py-2 text-xs rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] focus:ring-1 focus:ring-[#2D5941] bg-white transition-all"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setCurrentPage(1);
                }}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[#8E8E93] hover:text-[#1C1C1E] text-xs font-bold"
              >
                ✕
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Main Audit Trail Table Card */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5] text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wider">
                <th className="py-3.5 px-4 w-44">Timestamp</th>
                <th className="py-3.5 px-4 w-48">Administrator</th>
                <th className="py-3.5 px-4 w-64">Action Executed</th>
                <th className="py-3.5 px-4">Target Object / Details</th>
                <th className="py-3.5 px-4 w-36 text-right">IP Address</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#D9D2C5]/40 text-xs">
              {paginatedLogs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 px-4 text-center">
                    <div className="max-w-xs mx-auto space-y-2">
                      <div className="w-12 h-12 rounded-full bg-[#F9F5EF] border border-[#D9D2C5] flex items-center justify-center mx-auto text-[#8E8E93]">
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                      </div>
                      <p className="font-bold text-sm text-[#1C1C1E]">No audit logs found</p>
                      <p className="text-xs text-[#6C6C70]">
                        {searchQuery || selectedCategory !== 'ALL'
                          ? 'Try adjusting your search query or category filter.'
                          : 'No recorded system activity yet.'}
                      </p>
                      {(searchQuery || selectedCategory !== 'ALL') && (
                        <button
                          type="button"
                          onClick={() => {
                            setSearchQuery('');
                            setSelectedCategory('ALL');
                            setCurrentPage(1);
                          }}
                          className="mt-2 text-xs font-bold text-[#2D5941] hover:underline cursor-pointer"
                        >
                          Clear Filters
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedLogs.map((log) => (
                  <tr key={log.id} className="hover:bg-[#F9F5EF]/60 transition-colors">
                    {/* Timestamp */}
                    <td className="py-3.5 px-4 whitespace-nowrap">
                      <div className="flex items-center gap-2">
                        <svg className="w-3.5 h-3.5 text-[#8E8E93] shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <div>
                          <span className="font-semibold text-[#1C1C1E] block text-xs">{log.date}</span>
                          <span className="text-[10px] text-[#6C6C70] block">{log.time}</span>
                        </div>
                      </div>
                    </td>

                    {/* Administrator */}
                    <td className="py-3.5 px-4 whitespace-nowrap">
                      <div className="flex items-center gap-2.5">
                        <div className="w-7 h-7 rounded-full bg-[#1A3C2E] text-white flex items-center justify-center text-[10px] font-bold uppercase shrink-0">
                          {log.admin.slice(0, 2)}
                        </div>
                        <span className="font-bold text-[#1C1C1E]">{log.admin}</span>
                      </div>
                    </td>

                    {/* Action Executed */}
                    <td className="py-3.5 px-4">
                      <span className={`inline-block px-2.5 py-1 rounded-lg text-[10px] font-bold border ${getActionBadgeStyle(log.action)}`}>
                        {log.action}
                      </span>
                    </td>

                    {/* Target Object */}
                    <td className="py-3.5 px-4">
                      <span className="font-medium text-[#1C1C1E] break-words text-xs">
                        {log.target}
                      </span>
                    </td>

                    {/* IP Address */}
                    <td className="py-3.5 px-4 whitespace-nowrap text-right">
                      <span className="font-mono text-[11px] px-2 py-0.5 rounded bg-[#F9F5EF] border border-[#D9D2C5] text-[#6C6C70]">
                        {log.ip || '192.168.1.1'}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="p-4 bg-[#F9F5EF]/50 border-t border-[#D9D2C5] flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="text-xs text-[#6C6C70] text-center sm:text-left">
            Showing{' '}
            <span className="font-bold text-[#1C1C1E]">
              {filteredLogs.length === 0 ? 0 : startIndex + 1}
            </span>{' '}
            to{' '}
            <span className="font-bold text-[#1C1C1E]">
              {Math.min(startIndex + itemsPerPage, filteredLogs.length)}
            </span>{' '}
            of <span className="font-bold text-[#1C1C1E]">{filteredLogs.length}</span> entries
            {filteredLogs.length !== auditLogs.length && (
              <span className="ml-1 text-[11px] text-[#8E8E93]">
                (filtered from {auditLogs.length} total)
              </span>
            )}
          </div>

          {/* Page Controls */}
          {totalPages > 1 && (
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
                  // Show max 5 page buttons around current page
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
          )}
        </div>
      </div>
    </div>
  );
};


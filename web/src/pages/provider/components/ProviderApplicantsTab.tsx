import React, { useState } from 'react';
import type { ScholarAward, ApplicantStatus } from '../types';
import { normalizeGwa, rankCandidates } from '../utils/gwaUtils';
import { SelectTopCandidatesModal } from './SelectTopCandidatesModal';

interface ProviderApplicantsTabProps {
  subTab: 'applicants' | 'scholars';
  setSubTab: (tab: 'applicants' | 'scholars') => void;
  statusFilter: string;
  setStatusFilter: (status: string) => void;
  searchQuery: string;
  setSearchQuery: (q: string) => void;
  applicantsList: any[];
  scholarsList: ScholarAward[];
  filteredApplicants: any[];
  filteredScholars: ScholarAward[];
  setSelectedAppForReview: (app: any) => void;
  setIsReviewModalOpen: (open: boolean) => void;
  onOpenViewTab?: (app: any) => void;
  handleUpdateStatus: (id: any, newStatus: ApplicantStatus) => void;
  showToast?: (message: string) => void;
  triggerQuotaFilledModal?: (cycleId: string, programTitle: string, cycleName: string, totalSlots: number, excludeAppIds: (string | number)[]) => Promise<void>;
  setQuotaPendingApproveIds?: (ids: string[]) => void;
  onNavigateToAppeals?: () => void;
}

export const ProviderApplicantsTab: React.FC<ProviderApplicantsTabProps> = ({
  subTab,
  setSubTab,
  statusFilter,
  setStatusFilter,
  searchQuery,
  setSearchQuery,
  applicantsList,
  scholarsList,
  filteredApplicants,
  filteredScholars,
  setSelectedAppForReview,
  setIsReviewModalOpen,
  onOpenViewTab,
  handleUpdateStatus,
  showToast,
  triggerQuotaFilledModal,
  setQuotaPendingApproveIds,
  onNavigateToAppeals: _onNavigateToAppeals,
}) => {
  const [selectedProgramFilter, setSelectedProgramFilter] = useState<string>('All');
  const [selectedBatchFilter, setSelectedBatchFilter] = useState<string>('All');
  const [sortBy, setSortBy] = useState<string>('gwa_asc');
  const [selectedAppIds, setSelectedAppIds] = useState<string[]>([]);

  // Top Candidates Auto-Selection Modal State
  const [isTopCandidatesModalOpen, setIsTopCandidatesModalOpen] = useState(false);
  const [topCandidatesModalData, setTopCandidatesModalData] = useState<{
    programTitle: string;
    cycleName?: string;
    totalSlots: number;
    alreadyApprovedCount: number;
    remainingSlots: number;
    topApplicants: any[];
  }>({
    programTitle: '',
    totalSlots: 0,
    alreadyApprovedCount: 0,
    remainingSlots: 0,
    topApplicants: [],
  });

  const handleSelectTopCandidates = () => {
    let targetProgram = selectedProgramFilter;
    if (targetProgram === 'All') {
      const uniquePrograms = Array.from(new Set(applicantsList.map(a => a.program).filter(Boolean)));
      if (uniquePrograms.length === 1) {
        targetProgram = uniquePrograms[0];
      } else if (uniquePrograms.length > 1) {
        const msg = `Please select a specific Scholarship Program from the program dropdown filter first.`;
        if (showToast) showToast(msg);
        else alert(msg);
        return;
      } else {
        const msg = `No scholarship programs available to evaluate.`;
        if (showToast) showToast(msg);
        else alert(msg);
        return;
      }
    }

    const programApps = applicantsList.filter(a => a.program === targetProgram);
    if (programApps.length === 0) {
      const msg = `No applicants found for program "${targetProgram}".`;
      if (showToast) showToast(msg);
      else alert(msg);
      return;
    }

    const sampleApp = programApps[0];
    const totalSlots = sampleApp.rawApplication?.cycle?.program?.total_slots ||
                       sampleApp.rawApplication?.cycle?.slots_available || 0;

    const alreadyApprovedCount = scholarsList.filter(sch => sch.programTitle === targetProgram).length;
    const remainingSlots = Math.max(0, totalSlots - alreadyApprovedCount);

    if (totalSlots === 0) {
      const msg = `No maximum slot capacity set for "${targetProgram}".`;
      if (showToast) showToast(msg);
      else alert(msg);
      return;
    }

    if (remainingSlots <= 0) {
      const msg = `All ${totalSlots} available slots for "${targetProgram}" are already filled (${alreadyApprovedCount} approved).`;
      if (showToast) showToast(msg);
      else alert(msg);
      return;
    }

    const eligiblePending = programApps.filter(app => {
      const st = (app.status || '').toLowerCase();
      const isExcluded = st === 'approved' || st === 'rejected' || st === 'barred';
      const matchesBatch = selectedBatchFilter === 'All' || app.cycle === selectedBatchFilter;
      return !isExcluded && matchesBatch;
    });

    if (eligiblePending.length === 0) {
      const msg = `No eligible pending candidates available for selection in "${targetProgram}".`;
      if (showToast) showToast(msg);
      else alert(msg);
      return;
    }

    const ranked = rankCandidates(eligiblePending);
    const topSelected = ranked.slice(0, remainingSlots);
    const topIds = topSelected.map(a => a.id);

    setSelectedAppIds(topIds);
    setTopCandidatesModalData({
      programTitle: targetProgram,
      cycleName: sampleApp.cycle,
      totalSlots: totalSlots,
      alreadyApprovedCount: alreadyApprovedCount,
      remainingSlots: remainingSlots,
      topApplicants: topSelected,
    });
    setIsTopCandidatesModalOpen(true);
  };

  const handleConfirmTopApproval = async (confirmedIds: string[]) => {
    for (const id of confirmedIds) {
      await handleUpdateStatus(id, 'Approved');
    }
    setSelectedAppIds([]);
    if (showToast) {
      showToast(`Successfully approved ${confirmedIds.length} top candidates!`);
    }
  };

  // Dynamic Options for Applicants
  const applicantProgramOptions = ['All', ...Array.from(new Set(applicantsList.map(a => a.program).filter(Boolean)))];
  const applicantBatchOptions = ['All', ...Array.from(new Set(applicantsList.map(a => a.cycle).filter(Boolean)))];

  // Dynamic Options for Scholars
  const scholarProgramOptions = ['All', ...Array.from(new Set(scholarsList.map(s => s.programTitle).filter(Boolean)))];
  const scholarBatchOptions = ['All', ...Array.from(new Set(scholarsList.map(s => s.cycleJoined || s.batchName).filter(Boolean)))];

  // Process Applicants with Program, Batch, and Sorting
  const processedApplicants = filteredApplicants.filter(app => {
    const matchesProgram = selectedProgramFilter === 'All' || app.program === selectedProgramFilter;
    const matchesBatch = selectedBatchFilter === 'All' || app.cycle === selectedBatchFilter;
    return matchesProgram && matchesBatch;
  }).sort((a, b) => {
    if (sortBy === 'newest') return new Date(b.date || b.created_at || 0).getTime() - new Date(a.date || a.created_at || 0).getTime();
    if (sortBy === 'oldest') return new Date(a.date || a.created_at || 0).getTime() - new Date(b.date || b.created_at || 0).getTime();
    if (sortBy === 'name_asc') return (a.name || '').localeCompare(b.name || '');
    if (sortBy === 'gwa_asc') {
      const scoreA = normalizeGwa(a.grade, a.gpa_scale || a.gpaScale);
      const scoreB = normalizeGwa(b.grade, b.gpa_scale || b.gpaScale);
      return scoreB - scoreA; // Highest Normalized Score First
    }
    if (sortBy === 'gwa_desc') {
      const scoreA = normalizeGwa(a.grade, a.gpa_scale || a.gpaScale);
      const scoreB = normalizeGwa(b.grade, b.gpa_scale || b.gpaScale);
      return scoreA - scoreB; // Lowest Normalized Score First
    }
    return 0;
  });

  // Process Scholars with Search, Program, Batch, and Sorting
  const processedScholars = filteredScholars.filter(sch => {
    const query = searchQuery.toLowerCase();
    const matchesSearch = !query ||
      (sch.scholarName || '').toLowerCase().includes(query) ||
      (sch.programTitle || '').toLowerCase().includes(query) ||
      (sch.school || '').toLowerCase().includes(query);
    const matchesProgram = selectedProgramFilter === 'All' || sch.programTitle === selectedProgramFilter;
    const matchesBatch = selectedBatchFilter === 'All' || (sch.cycleJoined === selectedBatchFilter || sch.batchName === selectedBatchFilter);
    return matchesSearch && matchesProgram && matchesBatch;
  }).sort((a, b) => {
    if (sortBy === 'name_asc') return (a.scholarName || '').localeCompare(b.scholarName || '');
    if (sortBy === 'name_desc') return (b.scholarName || '').localeCompare(a.scholarName || '');
    if (sortBy === 'program') return (a.programTitle || '').localeCompare(b.programTitle || '');
    return 0;
  });

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Header and Toggle Button between Applicants and Scholars */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">
            {subTab === 'applicants' ? 'Cycle Applicants' : 'Scholars'}
          </h2>
          <p className="text-sm text-[#6C6C70] mt-1 font-medium">
            {subTab === 'applicants'
              ? 'Review incoming entries for active intake cycles. Approving them awards the scholar grant.'
              : 'Monitor active scholars, program batches, GWA requirements, and renewal conditions.'
            }
          </p>
        </div>

        {/* Toggle Selector */}
        <div className="flex bg-[#EDE8DE]/60 p-1 rounded-xl text-xs font-semibold gap-1">
          <button
            onClick={() => {
              setSubTab('applicants');
              setStatusFilter('All');
              setSelectedProgramFilter('All');
              setSelectedBatchFilter('All');
            }}
            className={`px-4 py-2 rounded-lg cursor-pointer transition-all ${subTab === 'applicants' ? 'bg-[#1A3C2E] text-white shadow-sm' : 'text-[#6C6C70] hover:text-[#1A3C2E]'
              }`}
          >
            Applicants ({filteredApplicants.length})
          </button>
          <button
            onClick={() => {
              setSubTab('scholars');
              setStatusFilter('All');
              setSelectedProgramFilter('All');
              setSelectedBatchFilter('All');
            }}
            className={`px-4 py-2 rounded-lg cursor-pointer transition-all ${subTab === 'scholars' ? 'bg-[#1A3C2E] text-white shadow-sm' : 'text-[#6C6C70] hover:text-[#1A3C2E]'
              }`}
          >
            Scholars ({scholarsList.length})
          </button>
        </div>
      </div>

      {/* Filter and Control Bar for Applicants */}
      {subTab === 'applicants' && (
        <div className="space-y-3 bg-white p-4 rounded-2xl border border-[#D9D2C5]/60 shadow-sm">
          <div className="flex flex-wrap items-center gap-3">
            {/* Search Bar */}
            <div className="relative flex-1 min-w-[220px]">
              <svg className="absolute left-3.5 top-2.5 w-4 h-4 text-[#8E8E93]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
              <input
                type="text" placeholder="Search applicant, school, program, cycle..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-2 rounded-xl border border-[#D9D2C5]/60 focus:outline-none focus:border-[#2D5941] text-xs font-sans"
              />
            </div>

            {/* Program Filter Dropdown */}
            <div className="flex items-center gap-1.5 bg-[#F9F5EF] px-3 py-1.5 rounded-xl border border-[#D9D2C5]/60">
              <span className="text-[11px] font-bold text-[#6C6C70]">Program:</span>
              <select
                value={selectedProgramFilter}
                onChange={(e) => setSelectedProgramFilter(e.target.value)}
                className="bg-transparent text-xs font-bold text-[#1C1C1E] outline-none cursor-pointer"
              >
                {applicantProgramOptions.map(prog => (
                  <option key={prog} value={prog}>{prog}</option>
                ))}
              </select>
            </div>

            {/* Batch / Cycle Filter Dropdown */}
            <div className="flex items-center gap-1.5 bg-[#F9F5EF] px-3 py-1.5 rounded-xl border border-[#D9D2C5]/60">
              <span className="text-[11px] font-bold text-[#6C6C70]">Batch:</span>
              <select
                value={selectedBatchFilter}
                onChange={(e) => setSelectedBatchFilter(e.target.value)}
                className="bg-transparent text-xs font-bold text-[#1C1C1E] outline-none cursor-pointer"
              >
                {applicantBatchOptions.map(batch => (
                  <option key={batch} value={batch}>{batch}</option>
                ))}
              </select>
            </div>

            {/* Sort Dropdown */}
            <div className="flex items-center gap-1.5 bg-[#F9F5EF] px-3 py-1.5 rounded-xl border border-[#D9D2C5]/60">
              <span className="text-[11px] font-bold text-[#6C6C70]">Sort:</span>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="bg-transparent text-xs font-bold text-[#1C1C1E] outline-none cursor-pointer"
              >
                <option value="newest">Date (Newest First)</option>
                <option value="oldest">Date (Oldest First)</option>
                <option value="name_asc">Name (A-Z)</option>
                <option value="gwa_asc">GWA (Highest First)</option>
                <option value="gwa_desc">GWA (Lowest First)</option>
              </select>
            </div>

            {/* Select Top Candidates Button */}
            <button
              type="button"
              onClick={handleSelectTopCandidates}
              className="bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold px-3.5 py-2 rounded-xl transition-all shadow-xs flex items-center gap-1.5 cursor-pointer ml-auto"
              title="Automatically rank and select top pending candidates up to maximum program slots"
            >
              <span>✨ Select Top Candidates</span>
            </button>
          </div>

          {/* Needs Attention Alert Banner for AI Flags */}
          {(() => {
            const flaggedCount = applicantsList.filter(a => a.status === 'under_review' || a.status === 'Under Review').length;
            if (flaggedCount === 0) return null;

            return (
              <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex flex-wrap items-center justify-between shadow-sm gap-3 mb-2">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-amber-100 text-amber-800 flex items-center justify-center text-xl font-bold">⚠️</div>
                  <div>
                    <h4 className="text-sm font-bold text-amber-900">Needs Provider Attention ({flaggedCount})</h4>
                    <p className="text-xs text-amber-700">
                      {flaggedCount} flagged doc(s) under review
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setStatusFilter('Under Review')}
                    className="bg-amber-800 hover:bg-amber-900 text-white text-xs font-bold px-3.5 py-2 rounded-xl transition-all cursor-pointer"
                  >
                    Review Flags ({flaggedCount})
                  </button>
                </div>
              </div>
            );
          })()}

          {/* Status Filter Buttons */}
          <div className="flex flex-wrap gap-1 bg-[#EDE8DE]/45 p-1 rounded-lg text-[10px] font-bold">
            {['All', 'New Applicants', 'Renewals', 'Pending', 'Pending for Ranking', 'Under Review', 'For Exam', 'Waitlisted', 'Rejected', 'Barred'].map(st => (
              <button
                key={st} onClick={() => setStatusFilter(st)}
                className={`px-3 py-1.5 rounded cursor-pointer transition-colors ${statusFilter === st ? 'bg-[#1A3C2E] text-white' : 'text-[#6C6C70] hover:text-[#1A3C2E]'}`}
              >
                {st}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Filter and Control Bar for Scholars */}
      {subTab === 'scholars' && (
        <div className="flex flex-wrap items-center gap-3 bg-white p-4 rounded-2xl border border-[#D9D2C5]/60 shadow-sm">
          {/* Search Bar */}
          <div className="relative flex-1 min-w-[220px]">
            <svg className="absolute left-3.5 top-2.5 w-4 h-4 text-[#8E8E93]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            <input
              type="text" placeholder="Search scholar, school, course..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2 rounded-xl border border-[#D9D2C5]/60 focus:outline-none focus:border-[#2D5941] text-xs font-sans"
            />
          </div>

          {/* Program Filter Dropdown */}
          <div className="flex items-center gap-1.5 bg-[#F9F5EF] px-3 py-1.5 rounded-xl border border-[#D9D2C5]/60">
            <span className="text-[11px] font-bold text-[#6C6C70]">Program:</span>
            <select
              value={selectedProgramFilter}
              onChange={(e) => setSelectedProgramFilter(e.target.value)}
              className="bg-transparent text-xs font-bold text-[#1C1C1E] outline-none cursor-pointer"
            >
              {scholarProgramOptions.map(prog => (
                <option key={prog} value={prog}>{prog}</option>
              ))}
            </select>
          </div>

          {/* Batch / Cycle Filter Dropdown */}
          <div className="flex items-center gap-1.5 bg-[#F9F5EF] px-3 py-1.5 rounded-xl border border-[#D9D2C5]/60">
            <span className="text-[11px] font-bold text-[#6C6C70]">Batch:</span>
            <select
              value={selectedBatchFilter}
              onChange={(e) => setSelectedBatchFilter(e.target.value)}
              className="bg-transparent text-xs font-bold text-[#1C1C1E] outline-none cursor-pointer"
            >
              {scholarBatchOptions.map(batch => (
                <option key={batch} value={batch}>{batch}</option>
              ))}
            </select>
          </div>

          {/* Sort Dropdown */}
          <div className="flex items-center gap-1.5 bg-[#F9F5EF] px-3 py-1.5 rounded-xl border border-[#D9D2C5]/60">
            <span className="text-[11px] font-bold text-[#6C6C70]">Sort:</span>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="bg-transparent text-xs font-bold text-[#1C1C1E] outline-none cursor-pointer"
            >
              <option value="name_asc">Name (A-Z)</option>
              <option value="name_desc">Name (Z-A)</option>
              <option value="program">Program Title</option>
            </select>
          </div>
        </div>
      )}

      {/* Render table based on toggle */}
      {subTab === 'applicants' ? (
        <div className="space-y-3">
          {/* Floating Batch Action Bar */}
          {selectedAppIds.length > 0 && (
            <div className="bg-[#1A3C2E] text-white px-5 py-3 rounded-2xl flex flex-wrap items-center justify-between shadow-lg text-xs animate-fade-in gap-3">
              <div className="flex items-center gap-2 font-bold">
                <span>✓ Selected {selectedAppIds.length} candidate{selectedAppIds.length > 1 ? 's' : ''}</span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => {
                    const selectedApps = applicantsList.filter(app => selectedAppIds.includes(app.id));
                    if (selectedApps.length === 0) return;

                    // 1. Validate that all selected applicants belong to the same program
                    const programNames = Array.from(new Set(selectedApps.map(app => app.program)));
                    if (programNames.length > 1) {
                      const msg = "Batch approval is only allowed for candidates of the same program. Please filter by program or adjust your selection.";
                      if (showToast) showToast(msg);
                      else alert(msg);
                      return;
                    }

                    // 2. Validate that the selection count does not exceed remaining slots
                    const targetProgramTitle = programNames[0];
                    const activeApp = selectedApps[0];
                    const totalSlots = activeApp.rawApplication?.cycle?.program?.total_slots || 
                                       activeApp.rawApplication?.cycle?.slots_available || 0;

                    if (totalSlots > 0) {
                      const alreadyApprovedCount = scholarsList.filter(sch => sch.programTitle === targetProgramTitle).length;
                      const remainingSlots = totalSlots - alreadyApprovedCount;

                      if (selectedAppIds.length > remainingSlots) {
                        const errorMsg = `Cannot approve: you selected ${selectedAppIds.length} applicants, but there are only ${remainingSlots} slots remaining for "${targetProgramTitle}" (${alreadyApprovedCount}/${totalSlots} filled).`;
                        if (showToast) showToast(errorMsg);
                        else alert(errorMsg);
                        return; // Block batch approval!
                      }

                      // Check if the selection exactly fills the remaining slots
                      if (selectedAppIds.length === remainingSlots && triggerQuotaFilledModal && setQuotaPendingApproveIds) {
                        const cycleId = activeApp.rawApplication?.cycle_id;
                        const cycleName = activeApp.cycle || activeApp.rawApplication?.cycle?.cycle_name || 'Current Cycle';
                        setQuotaPendingApproveIds(selectedAppIds);
                        triggerQuotaFilledModal(cycleId, targetProgramTitle, cycleName, totalSlots, selectedAppIds);
                        setSelectedAppIds([]); // Clear selection so the floating action bar disappears
                        return; // Abort direct approval!
                      }
                    }

                    // Run status updates sequentially to prevent race conditions
                    const approveAll = async () => {
                      for (const id of selectedAppIds) {
                        await handleUpdateStatus(id, 'Approved');
                      }
                      setSelectedAppIds([]);
                    };
                    approveAll();
                  }}
                  className="bg-[#2D5941] hover:bg-[#3D7355] text-white px-3.5 py-1.5 rounded-xl font-bold border-0 cursor-pointer shadow-sm text-xs transition-all"
                >
                  🎓 Batch Approve ({selectedAppIds.length})
                </button>
                <button
                  type="button"
                  onClick={() => {
                    selectedAppIds.forEach(id => handleUpdateStatus(id, 'For Exam'));
                    setSelectedAppIds([]);
                  }}
                  className="bg-purple-700 hover:bg-purple-800 text-white px-3 py-1.5 rounded-xl font-bold border-0 cursor-pointer text-xs transition-all"
                >
                  📋 Set For Exam ({selectedAppIds.length})
                </button>
                <button
                  type="button"
                  onClick={() => {
                    selectedAppIds.forEach(id => handleUpdateStatus(id, 'Pending for Ranking'));
                    setSelectedAppIds([]);
                  }}
                  className="bg-sky-700 hover:bg-sky-800 text-white px-3 py-1.5 rounded-xl font-bold border-0 cursor-pointer text-xs transition-all"
                >
                  📊 Set Pending for Ranking ({selectedAppIds.length})
                </button>
                <button
                  type="button"
                  onClick={() => setSelectedAppIds([])}
                  className="text-gray-300 hover:text-white px-2 py-1 text-xs cursor-pointer bg-transparent border-0 underline"
                >
                  Clear Selection
                </button>
              </div>
            </div>
          )}

          <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 overflow-hidden shadow-sm">
            <table className="w-full border-collapse text-left text-sm">
              <thead>
                <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-xs font-bold text-[#6C6C70] uppercase tracking-wider">
                  <th className="px-4 py-4 w-10 text-center">
                    <input
                      type="checkbox"
                      checked={
                        processedApplicants.length > 0 &&
                        processedApplicants.filter(a => a.status !== 'Rejected').length > 0 &&
                        selectedAppIds.length === processedApplicants.filter(a => a.status !== 'Rejected').length
                      }
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedAppIds(processedApplicants.filter(a => a.status !== 'Rejected').map(a => a.id));
                        } else {
                          setSelectedAppIds([]);
                        }
                      }}
                      className="w-4 h-4 text-[#2D5941] rounded focus:ring-[#2D5941] cursor-pointer"
                    />
                  </th>
                  <th className="px-6 py-4">Applicant Name</th>
                <th className="px-6 py-4">Target Program</th>
                <th className="px-6 py-4">Active Cycle / Batch</th>
                <th className="px-6 py-4 text-center">GWA / Score %</th>
                <th className="px-6 py-4">Current Status</th>
                <th className="px-6 py-4 text-center">Actions / Decision</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
              {processedApplicants.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-[#8E8E93]">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <div className="w-12 h-12 bg-[#EDE8DE] rounded-full flex items-center justify-center text-[#2D5941] text-xl mb-1">
                        📋
                      </div>
                      <p className="font-bold text-sm text-[#1C1C1E] font-serif">No cycle applicants found</p>
                      <p className="text-xs text-[#8E8E93] max-w-sm">
                        {applicantsList.length === 0
                          ? 'No student applications have been submitted for your active intake cycles yet.'
                          : 'No applicants match your current search and filter criteria.'}
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                processedApplicants.map((app) => {
                const isRenewal = app.cycle_type === 'renewal' || (app.cycle && app.cycle.toLowerCase().includes('renewal'));
                return (
                  <tr key={app.id} className="hover:bg-[#F9F5EF]/30 transition-colors">
                    <td className="px-4 py-4 text-center">
                      <input
                        type="checkbox"
                        checked={selectedAppIds.includes(app.id)}
                        disabled={app.status === 'Rejected'}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedAppIds(prev => [...prev, app.id]);
                          } else {
                            setSelectedAppIds(prev => prev.filter(id => id !== app.id));
                          }
                        }}
                        className="w-4 h-4 text-[#2D5941] rounded focus:ring-[#2D5941] cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed"
                      />
                    </td>
                    <td className="px-6 py-4 flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-[#1A3C2E] text-white flex items-center justify-center font-bold text-xs uppercase">
                        {app.name.split(' ').map((n: string) => n[0]).join('')}
                      </div>
                      <div>
                        <span className="block font-bold text-[#1C1C1E]">{app.name}</span>
                        <span className="text-[10px] text-[#8E8E93]">{app.school} • {app.course} ({app.yearLevel}) • Applied {app.date}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-[#1C1C1E]">
                      <div className="flex flex-col items-start gap-1">
                        <span>{app.program}</span>
                        {app.isContinuingScholar && (
                          <span className="inline-flex items-center gap-1 text-[9px] font-bold px-2 py-0.5 rounded bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/30">
                            🔄 Continuing Scholar
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col items-start gap-1">
                        <span className="text-xs font-bold text-[#2D5941]">{app.cycle}</span>
                        {isRenewal && (
                          <span className="inline-flex items-center gap-1 text-[9px] font-extrabold text-[#8C5216] bg-amber-100/90 border border-amber-300/60 px-2 py-0.5 rounded-full">
                            🔄 Semestral Renewal
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <div className="flex flex-col items-center gap-0.5">
                        {(() => {
                          const scale = app.gpa_scale || app.gpaScale || app.scholar?.gpa_scale || 'scale_5';
                          const normScore = normalizeGwa(app.grade, scale);
                          const scaleLabel = scale === 'scale_4' ? 'Scale 4.0' : scale === 'percentage' ? 'Percentage' : 'Scale 5.0';

                          return (
                            <>
                              <div className="flex items-center gap-1.5 justify-center">
                                <span className="font-serif font-bold text-[#1C1C1E] text-xs">{app.grade}</span>
                                <span className="text-[9px] font-bold text-[#6C6C70] bg-[#EDE8DE]/70 px-1.5 py-0.5 rounded border border-[#D9D2C5]/60" title={`Grading System: ${scaleLabel}`}>
                                  {scaleLabel}
                                </span>
                              </div>
                              <span className="text-[9px] font-extrabold text-[#2D5941] bg-[#EBF5EE] px-1.5 py-0.5 rounded-md border border-[#2D5941]/20 mt-0.5" title={`Normalized Score: ${normScore}% (${scaleLabel})`}>
                                Score: {normScore}%
                              </span>
                            </>
                          );
                        })()}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col items-start gap-1">
                        <span
                          className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${
                            app.status === 'Approved'
                              ? 'bg-[#EBF5EE] text-[#2D5941]'
                              : (app.status === 'Under Review' || app.status === 'under_review')
                              ? 'bg-amber-100 text-amber-900 border border-amber-300'
                              : (app.status === 'Appealed' || app.status === 'appealed' || app.status === 'Appeals')
                              ? 'bg-purple-100 text-purple-900 border border-purple-300'
                              : (app.status === 'Barred' || app.status === 'barred')
                              ? 'bg-red-950 text-white font-extrabold'
                              : app.status === 'Pending'
                              ? 'bg-[#F9F0E0] text-[#C97B2E]'
                              : app.status === 'For Exam'
                              ? 'bg-purple-100 text-purple-700'
                              : app.status === 'Waitlisted'
                              ? 'bg-amber-100 text-amber-800 border border-amber-300'
                              : 'bg-[#FDF2F2] text-[#B34040] border border-[#B34040]/20'
                          }`}
                          title={app.remarks ? `Remarks: ${app.remarks}` : undefined}
                        >
                          {app.status === 'Rejected'
                            ? '✕ Rejected'
                            : app.status === 'Waitlisted'
                            ? '⏳ Waitlisted'
                            : (app.status === 'Under Review' || app.status === 'under_review')
                            ? '⚠️ Under Review'
                            : (app.status === 'Appealed' || app.status === 'appealed' || app.status === 'Appeals')
                            ? '📋 Appealed'
                            : (app.status === 'Barred' || app.status === 'barred')
                            ? '🚫 Barred'
                            : app.status}
                        </span>

                        {(app.status === 'Rejected' || app.status === 'Waitlisted') && app.remarks && (
                          <span className={`text-[9px] italic max-w-[150px] truncate ${app.status === 'Waitlisted' ? 'text-amber-700 font-bold' : 'text-[#B34040]'}`} title={app.remarks}>
                            "{app.remarks}"
                          </span>
                        )}

                        {/* Post-Approval Bank Account Badge */}
                        {app.status === 'Approved' && (
                          <div>
                            {app.disbursement_mode === 'in_person_cash' ? (
                              <span className="inline-flex items-center gap-1 text-[9px] font-semibold text-slate-600 bg-slate-100 px-2 py-0.5 rounded">
                                💵 Cash Payout
                              </span>
                            ) : app.paymentAccount ? (
                              <span className="inline-flex items-center gap-1 text-[9px] font-bold text-[#2D5941] bg-[#EBF5EE] border border-[#2D5941]/30 px-2 py-0.5 rounded" title={`${app.paymentAccount.bank_name} (${app.paymentAccount.account_number})`}>
                                💳 {app.paymentAccount.bank_name?.replace('of the Philippines', '')} •••• {app.paymentAccount.account_number?.slice(-4)}
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 text-[9px] font-bold text-amber-800 bg-amber-100 border border-amber-300 px-2 py-0.5 rounded">
                                ⚠️ Bank Proof Pending
                              </span>
                            )}
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center whitespace-nowrap">
                      <div className="inline-flex items-center justify-center gap-2">
                        {/* View Application Button */}
                        <button
                          type="button"
                          onClick={() => {
                            const matchSch = scholarsList.find(s => (s.appDetail?.scholarId && app.scholarId && String(s.appDetail.scholarId) === String(app.scholarId)) || s.scholarName === app.name);
                            const appWithHistory = {
                              ...app,
                              payoutHistory: app.payoutHistory || matchSch?.payoutHistory || matchSch?.appDetail?.payoutHistory || []
                            };
                            setSelectedAppForReview(appWithHistory);
                            if (onOpenViewTab) {
                              onOpenViewTab(appWithHistory);
                            } else {
                              setIsReviewModalOpen(true);
                            }
                          }}
                          className="bg-[#1A3C2E] hover:bg-[#2D5941] text-white px-3.5 py-2 rounded-xl text-xs font-semibold shadow-sm hover:shadow cursor-pointer border-0 inline-flex items-center gap-1.5 transition-all duration-150 active:scale-[0.98]"
                        >
                          <svg className="w-3.5 h-3.5 opacity-90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                          </svg>
                          <span>View Application</span>
                        </button>

                        {/* Styled Decision Dropdown */}
                        <div className="relative inline-block text-left">
                          <select
                            value={app.status}
                            disabled={app.status === 'Rejected'}
                            onChange={(e) => handleUpdateStatus(app.id, e.target.value as ApplicantStatus)}
                            className="appearance-none bg-white hover:bg-[#F9F5EF]/60 text-[#1C1C1E] font-semibold text-xs border border-[#D9D2C5] hover:border-[#2D5941] focus:border-[#2D5941] focus:ring-2 focus:ring-[#2D5941]/20 rounded-xl pl-3.5 pr-8 py-2 cursor-pointer outline-none transition-all shadow-sm disabled:opacity-60 disabled:cursor-not-allowed"
                          >
                            <option value="Pending">Pending</option>
                            <option value="Pending for Ranking">Pending for Ranking</option>
                            <option value="Under Review">Under Review</option>
                            <option value="For Exam">For Exam</option>
                            <option value="Waitlisted">Waitlisted</option>
                            <option value="Approved">Approve & Issue Award</option>
                            <option value="Rejected">Rejected</option>
                          </select>
                          <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2.5 text-[#6C6C70]">
                            <svg className="w-3.5 h-3.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                            </svg>
                          </div>
                        </div>
                      </div>
                    </td>
                  </tr>
                );
              }))}
            </tbody>
          </table>
        </div>
      </div>
      ) : (
        /* Scholars Monitoring View */
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 overflow-hidden shadow-sm">
          <table className="w-full border-collapse text-left text-sm">
            <thead>
              <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-xs font-bold text-[#6C6C70] uppercase tracking-wider">
                <th className="px-6 py-4">Scholar Name</th>
                <th className="px-6 py-4">Awarded Program</th>
                <th className="px-6 py-4">Batch / Intake Cycle</th>
                <th className="px-6 py-4 text-center">Latest GWA</th>
                <th className="px-6 py-4">Monitoring Status</th>
                <th className="px-6 py-4 text-center">Award Date</th>
                <th className="px-6 py-4 text-center">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
              {processedScholars.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-12 text-center text-[#8E8E93]">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <div className="w-12 h-12 bg-[#EDE8DE] rounded-full flex items-center justify-center text-[#2D5941] text-xl mb-1">
                        🎓
                      </div>
                      <p className="font-bold text-sm text-[#1C1C1E] font-serif">No awarded scholars found</p>
                      <p className="text-xs text-[#8E8E93] max-w-sm">
                        {scholarsList.length === 0
                          ? 'Once you approve applicants, they will automatically be enrolled into scholar monitoring.'
                          : 'No scholars match your current search and filter criteria.'}
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                processedScholars.map((sch) => (
                <tr key={sch.id} className="hover:bg-[#F9F5EF]/30 transition-colors">
                  <td className="px-6 py-4 flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full bg-[#C97B2E] text-white flex items-center justify-center font-bold text-xs uppercase">
                      {sch.scholarName.split(' ').map((n: string) => n[0]).join('')}
                    </div>
                    <span className="font-bold text-[#1C1C1E]">{sch.scholarName}</span>
                  </td>
                  <td className="px-6 py-4 text-[#1C1C1E]">
                    <div className="flex flex-col items-start gap-1">
                      <span className="font-semibold">{sch.programTitle}</span>
                      {(() => {
                        const cycleStr = (sch.cycleJoined || sch.appDetail?.cycle || '').toLowerCase();
                        const isRenewal = cycleStr.includes('renewal') || cycleStr.includes('sem');
                        if (!isRenewal && !cycleStr.includes('ay')) return null;

                        // Extract semester
                        let semLabel = '';
                        if (cycleStr.includes('2nd sem') || cycleStr.includes('2nd semester') || cycleStr.includes('second')) {
                          semLabel = '2nd Semester';
                        } else if (cycleStr.includes('1st sem') || cycleStr.includes('1st semester') || cycleStr.includes('first')) {
                          semLabel = '1st Semester';
                        } else if (cycleStr.includes('summer')) {
                          semLabel = 'Summer Term';
                        }

                        // Extract AY
                        const ayMatch = (sch.cycleJoined || sch.appDetail?.cycle || '').match(/AY\s*20\d{2}[-–]20\d{2}|AY\s*20\d{2}[-–]\d{2}|20\d{2}[-–]20\d{2}|20\d{2}[-–]\d{2}/i);
                        const ayLabel = ayMatch ? (ayMatch[0].toUpperCase().startsWith('AY') ? ayMatch[0].toUpperCase() : `AY ${ayMatch[0]}`) : '';

                        if (isRenewal) {
                          const badgeText = semLabel 
                            ? (ayLabel ? `🔄 ${semLabel} Renewal • ${ayLabel}` : `🔄 ${semLabel} Renewal`)
                            : (ayLabel ? `🔄 Renewal • ${ayLabel}` : '🔄 Renewal');
                          return (
                            <span className="inline-flex items-center gap-1 text-[9px] font-bold px-2 py-0.5 rounded bg-emerald-50 text-emerald-800 border border-emerald-200">
                              {badgeText}
                            </span>
                          );
                        }

                        return null;
                      })()}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-xs font-semibold text-[#6C6C70]">{sch.cycleJoined || sch.batchName || 'Default Batch'}</td>
                  <td className="px-6 py-4 text-center font-serif font-bold text-[#2D5941]">{sch.gwa}</td>
                  <td className="px-6 py-4">
                    <div className="flex flex-col items-start gap-1.5">
                      <div className="flex items-center gap-1.5">
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${sch.status === 'Maintaining' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                          sch.status === 'Awaiting Grades' ? 'bg-amber-50 text-[#C97B2E]' :
                            sch.status === 'Requirements Warning' ? 'bg-[#FDF2F2] text-[#B34040]' :
                              'bg-gray-100 text-gray-700'
                          }`}>
                          {sch.status === 'Maintaining' ? 'Continuing' : sch.status}
                        </span>
                        {sch.disbursement_mode === 'in_person_cash' ? (
                          <span className="inline-flex items-center gap-1 text-[9px] font-semibold text-slate-600 bg-slate-100 px-2 py-0.5 rounded">
                            💵 Cash
                          </span>
                        ) : sch.paymentAccount ? (
                          <span className="inline-flex items-center gap-1 text-[9px] font-bold text-[#2D5941] bg-[#EBF5EE] border border-[#2D5941]/30 px-2 py-0.5 rounded" title={`${sch.paymentAccount.bank_name} (${sch.paymentAccount.account_number})`}>
                            💳 {sch.paymentAccount.bank_name?.replace('of the Philippines', '')} •••• {sch.paymentAccount.account_number?.slice(-4)}
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-[9px] font-bold text-amber-800 bg-amber-100 border border-amber-300 px-2 py-0.5 rounded">
                            ⚠️ Bank Proof Missing
                          </span>
                        )}
                      </div>

                      {/* Semestral Payout Release Status */}
                      {(() => {
                        const freq = sch.appDetail?.rawApplication?.cycle?.program?.funding_frequency;
                        const isPerSemester = freq === 'Per Semester';

                        const expectedSems = isPerSemester ? ['1st Sem', '2nd Sem'] : [sch.cycleJoined || 'Payout'];
                        
                        // Filter payout history to the scholar's CURRENT academic year / cycle batch so new AY resets to pending
                        const currentCycleId = sch.appDetail?.rawApplication?.cycle_id || sch.appDetail?.rawApplication?.cycle?.id;
                        const currentAppId = sch.id || sch.appDetail?.id;
                        const currentCycleName = sch.cycleJoined || sch.appDetail?.cycle || '';
                        
                        const extractAY = (str: string) => {
                          if (!str) return '';
                          const m = str.match(/AY\s*20\d{2}[-–]20\d{2}|AY\s*20\d{2}[-–]\d{2}|20\d{2}[-–]20\d{2}|20\d{2}[-–]\d{2}/i);
                          if (m) {
                            const val = m[0].trim();
                            return val.toUpperCase().startsWith('AY') ? val.toUpperCase() : `AY ${val}`;
                          }
                          return '';
                        };

                        const currentAY = extractAY(currentCycleName) || sch.appDetail?.rawApplication?.cycle?.academic_year || '';

                        return (
                          <div className="flex flex-col gap-1">
                            {expectedSems.map((sem, semIdx) => {
                              const match = (sch.payoutHistory || []).find((p: any) => {
                                const payoutCycleName = p.cycleName || '';
                                const payoutAY = extractAY(payoutCycleName) || p.academicYear || '';

                                // Match payouts that belong to the same application/cycle OR same Academic Year
                                const isSameAppOrCycle = 
                                  (currentAppId && p.applicationId && String(p.applicationId) === String(currentAppId)) ||
                                  (currentCycleId && p.cycleId && String(p.cycleId) === String(currentCycleId)) ||
                                  (currentCycleName && payoutCycleName && currentCycleName === payoutCycleName);

                                const isSameAcademicYear = currentAY && payoutAY && currentAY === payoutAY;

                                if (!isSameAppOrCycle && !isSameAcademicYear) return false;

                                if (isPerSemester) {
                                  const pSemLower = (p.semester || payoutCycleName).toLowerCase();
                                  let pSemLabel = '1st Sem';
                                  if (pSemLower.includes('2nd') || pSemLower.includes('second')) {
                                    pSemLabel = '2nd Sem';
                                  } else if (pSemLower.includes('1st') || pSemLower.includes('first')) {
                                    pSemLabel = '1st Sem';
                                  } else {
                                    pSemLabel = (p.semester?.includes('2nd') || (!pSemLower.includes('1st') && p.isRenewal && !pSemLower.includes('annual'))) ? '2nd Sem' : '1st Sem';
                                  }
                                  return pSemLabel === sem;
                                }
                                return true;
                              });

                              const displaySem = isPerSemester ? sem : (sch.cycleJoined || 'Payout');

                              if (match) {
                                const isReleased = match.status === 'released' || match.status === 'Completed' || match.blockchain_verified;
                                const isRefunded = match.status === 'returned' || match.status === 'failed' || match.paymongoStatus === 'refunded' || String(match.status).toLowerCase().includes('refund');
                                
                                if (isRefunded) {
                                  return (
                                    <span
                                      key={semIdx}
                                      className="inline-flex items-center gap-1 text-[9px] font-bold px-2 py-0.5 rounded border bg-rose-50 text-rose-800 border-rose-300"
                                    >
                                      🔄 {displaySem} Payout: Refunded
                                    </span>
                                  );
                                }
                                
                                return (
                                  <span
                                    key={semIdx}
                                    className={`inline-flex items-center gap-1 text-[9px] font-bold px-2 py-0.5 rounded border ${
                                      isReleased
                                        ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
                                        : 'bg-amber-50 text-amber-800 border-amber-300'
                                    }`}
                                  >
                                    {isReleased ? '✅' : '⏳'} {displaySem} Payout: {isReleased ? `₱${match.amount?.toLocaleString()} (Released)` : 'Pending Release'}
                                  </span>
                                );
                              } else {
                                return (
                                  <span
                                    key={semIdx}
                                    className="inline-flex items-center gap-1 text-[9px] font-semibold text-slate-500 bg-slate-50 border border-slate-200 px-2 py-0.5 rounded"
                                  >
                                    ⏳ {displaySem} Payout Pending
                                  </span>
                                );
                              }
                            })}
                          </div>
                        );
                      })()}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-[#8E8E93] text-center text-xs">{sch.dateAwarded}</td>
                  <td className="px-6 py-4 text-center whitespace-nowrap">
                    <button
                      type="button"
                      onClick={() => {
                        if (sch.appDetail) {
                          const appDetailWithHistory = {
                            ...sch.appDetail,
                            payoutHistory: sch.payoutHistory || sch.appDetail.payoutHistory || []
                          };
                          setSelectedAppForReview(appDetailWithHistory);
                          setIsReviewModalOpen(true);
                        }
                      }}
                      className="bg-[#1A3C2E] hover:bg-[#2D5941] text-white px-3.5 py-2 rounded-xl text-xs font-semibold shadow-sm hover:shadow cursor-pointer border-0 inline-flex items-center gap-1.5 mx-auto transition-all duration-150 active:scale-[0.98]"
                    >
                      <svg className="w-3.5 h-3.5 opacity-90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                      <span>View Application</span>
                    </button>
                  </td>
                </tr>
              )))}
            </tbody>
          </table>
        </div>
      )}

      {/* Select Top Candidates Pre-Approval Confirmation Modal */}
      <SelectTopCandidatesModal
        isOpen={isTopCandidatesModalOpen}
        onClose={() => setIsTopCandidatesModalOpen(false)}
        programTitle={topCandidatesModalData.programTitle}
        cycleName={topCandidatesModalData.cycleName}
        totalSlots={topCandidatesModalData.totalSlots}
        alreadyApprovedCount={topCandidatesModalData.alreadyApprovedCount}
        remainingSlots={topCandidatesModalData.remainingSlots}
        topApplicants={topCandidatesModalData.topApplicants}
        onConfirmApprove={handleConfirmTopApproval}
        showToast={showToast}
      />
    </div>
  );
};

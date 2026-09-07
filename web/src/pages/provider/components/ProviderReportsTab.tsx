import React, { useState, useMemo } from 'react';
import type { Program, ScholarAward, DisbursementTx, Announcement } from '../types';
import type { ApplicationDetail, SubmittedDocItem } from './ReviewApplicationModal';
import { downloadCsv, dateStampedFilename } from '@/utils/csvExport';
import { normalizeGwa } from '../utils/gwaUtils';

// `DisbursementTx` is a loose/`any`-keyed type because it's shared across screens that
// populate it differently. The live data this tab actually receives (see ProviderPortal's
// fetchDisbursements) uses `scholar` / `program` / `method` and a pre-formatted currency
// string for `amount` (with the raw number kept separately in `numericAmount`) — not the
// `scholarName` / `programTitle` / `type` / numeric-`amount` shape one might expect from
// the field names alone. These helpers read whichever shape is actually present so the
// KPIs, table, and CSV export all agree with what's on screen instead of silently reading
// undefined fields.
const getDisbursementScholarName = (d: DisbursementTx): string => d.scholarName || d.scholar || 'Scholar';
const getDisbursementProgram = (d: DisbursementTx): string => d.programTitle || d.program || '';
const getDisbursementType = (d: DisbursementTx): string => d.type || d.method || 'Stipend';
const getDisbursementRef = (d: DisbursementTx): string => d.batchRef || d.reference_number || String(d.id ?? '');
const getDisbursementAmount = (d: DisbursementTx): number => {
  if (typeof d.numericAmount === 'number' && !isNaN(d.numericAmount)) return d.numericAmount;
  if (typeof d.amount === 'number') return d.amount;
  // Strings may come pre-formatted as currency, e.g. "₱50,000" — strip non-numeric chars.
  const parsed = Number(String(d.amount ?? '').replace(/[^0-9.-]/g, ''));
  return isNaN(parsed) ? 0 : parsed;
};

// Schools grade on different scales (PH Standard 1.00–5.00, NU/DLSU/Ateneo 0–4.00, straight
// percentage, etc.), so a raw `grade` number is not comparable across applicants and can't be
// meaningfully averaged or bucketed as-is — the same 1.75 GWA is "Dean's List" on a 5.0 scale
// but failing on a 4.0 scale. `normalizeGwa` (also used for candidate ranking elsewhere in this
// portal, e.g. ProviderApplicantsTab) converts any scale to a common 0–100 percentage so reports
// are scale-independent. Returns null when there's no usable grade, mirroring the previous
// `!isNaN(g) && g > 0` guard.
const getScaleForApplicant = (a: ApplicationDetail): string =>
  a.gpa_scale || a.gpaScale || a.rawApplication?.scholar?.gpa_scale || a.rawApplication?.cycle?.program?.gpa_scale || 'scale_5';

const getNormalizedGradePercent = (a: ApplicationDetail): number | null => {
  if (a.grade === null || a.grade === undefined || String(a.grade).trim() === '') return null;
  const percent = normalizeGwa(a.grade, getScaleForApplicant(a));
  return percent > 0 ? percent : null;
};

interface ProviderReportsTabProps {
  programs?: Program[];
  applicants?: ApplicationDetail[];
  scholars?: ScholarAward[];
  disbursements?: DisbursementTx[];
  announcements?: Announcement[];
  providerDetails?: {
    id: string;
    name: string;
    provider_type?: string;
    verification_status?: string;
  } | null;
  showToast?: (msg: string) => void;
}

export const ProviderReportsTab: React.FC<ProviderReportsTabProps> = ({
  programs = [],
  applicants = [],
  scholars = [],
  disbursements = [],
  announcements: _announcements = [],
  providerDetails,
  showToast,
}) => {
  const [selectedProgramId, setSelectedProgramId] = useState<string>('all');
  const [selectedTimeframe, setSelectedTimeframe] = useState<string>('all');
  const [activeDataTab, setActiveDataTab] = useState<'applicants' | 'disbursements' | 'aiAudits'>('applicants');
  const [searchQuery, setSearchQuery] = useState('');

  // Helper to get unique student key (prevents double-counting renewals or multiple program applications)
  const getScholarKey = (app: ApplicationDetail) => app.scholarId || app.email || app.name.toLowerCase().trim();

  // Timeframe filter cutoff. `date` fields on applicants/disbursements are pre-formatted
  // display strings (e.g. "Jan 05, 2026"), which `Date` can parse directly — no raw ISO
  // timestamp is available on the disbursement records this tab receives.
  const timeframeCutoff = useMemo(() => {
    const now = new Date();
    if (selectedTimeframe === '30d') return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    if (selectedTimeframe === '90d') return new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
    if (selectedTimeframe === 'ay') return new Date('2025-08-01'); // AY 2025-2026 start
    return null;
  }, [selectedTimeframe]);

  const isWithinTimeframe = (dateStr: string | undefined): boolean => {
    if (!timeframeCutoff || !dateStr) return true;
    const parsed = new Date(dateStr);
    if (isNaN(parsed.getTime())) return true; // unparseable ("Recently"/"N/A") — don't drop it
    return parsed >= timeframeCutoff;
  };

  // Filter applicants based on selected program, timeframe and search
  const filteredApplicants = useMemo(() => {
    return applicants.filter(app => {
      const matchProg = selectedProgramId === 'all' ||
        (app.program && app.program.toLowerCase().includes(selectedProgramId.toLowerCase())) ||
        (app.program_id && app.program_id === selectedProgramId) ||
        (app.rawApplication?.cycle?.program_id === selectedProgramId);
      const matchSearch = !searchQuery ||
        app.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        app.school.toLowerCase().includes(searchQuery.toLowerCase()) ||
        app.course.toLowerCase().includes(searchQuery.toLowerCase()) ||
        String(app.id).toLowerCase().includes(searchQuery.toLowerCase());
      const matchTimeframe = isWithinTimeframe(app.rawApplication?.created_at || app.date);
      return matchProg && matchSearch && matchTimeframe;
    });
  }, [applicants, selectedProgramId, searchQuery, timeframeCutoff]);

  // Filter disbursements based on selected program, timeframe and search
  const filteredDisbursements = useMemo(() => {
    return disbursements.filter(tx => {
      const program = getDisbursementProgram(tx);
      const matchProg = selectedProgramId === 'all' ||
        (program && program.toLowerCase().includes(selectedProgramId.toLowerCase())) ||
        (tx.program_id && tx.program_id === selectedProgramId);
      const matchSearch = !searchQuery ||
        getDisbursementScholarName(tx).toLowerCase().includes(searchQuery.toLowerCase()) ||
        getDisbursementRef(tx).toLowerCase().includes(searchQuery.toLowerCase());
      const matchTimeframe = isWithinTimeframe(tx.date);
      return matchProg && matchSearch && matchTimeframe;
    });
  }, [disbursements, selectedProgramId, searchQuery, timeframeCutoff]);

  // Filter scholars list
  const filteredScholars = useMemo(() => {
    return scholars.filter(sch => {
      const matchProg = selectedProgramId === 'all' || 
        (sch.programTitle && sch.programTitle.toLowerCase().includes(selectedProgramId.toLowerCase()));
      return matchProg;
    });
  }, [scholars, selectedProgramId]);

  // Total Applications vs Unique Students Metric Computation
  const {
    totalApplicationsCount,
    uniqueApplicantsCount,
    uniqueApprovedScholarsCount,
    uniqueUnderReviewCount,
    uniqueForExamCount,
    uniqueRejectedCount,
    approvedSubmissionsCount,
  } = useMemo(() => {
    const totalApps = filteredApplicants.length;

    // Distinct set of all applicants
    const allApplicantKeys = new Set(filteredApplicants.map(getScholarKey));
    
    // Distinct set of approved scholars
    const approvedApps = filteredApplicants.filter(a => a.status === 'Approved');
    const approvedKeys = new Set(approvedApps.map(getScholarKey));

    // Distinct set of under review students
    const underReviewApps = filteredApplicants.filter(a => a.status === 'Under Review' || a.status === 'Pending');
    const underReviewKeys = new Set(underReviewApps.map(getScholarKey));

    // Distinct set of exam students
    const forExamApps = filteredApplicants.filter(a => a.status === 'For Exam');
    const forExamKeys = new Set(forExamApps.map(getScholarKey));

    // Distinct set of rejected students
    const rejectedApps = filteredApplicants.filter(a => a.status === 'Rejected');
    const rejectedKeys = new Set(rejectedApps.map(getScholarKey));

    return {
      totalApplicationsCount: totalApps,
      uniqueApplicantsCount: allApplicantKeys.size,
      uniqueApprovedScholarsCount: approvedKeys.size,
      uniqueUnderReviewCount: underReviewKeys.size,
      uniqueForExamCount: forExamKeys.size,
      uniqueRejectedCount: rejectedKeys.size,
      approvedSubmissionsCount: approvedApps.length,
    };
  }, [filteredApplicants]);

  // Unique Scholars Count (combining scholar awards list + approved applications)
  const activeScholarsCount = useMemo(() => {
    if (filteredScholars.length > 0) {
      return new Set(filteredScholars.map(s => s.email || s.scholarName || s.id)).size;
    }
    return uniqueApprovedScholarsCount;
  }, [filteredScholars, uniqueApprovedScholarsCount]);

  // Approval Rate calculated per UNIQUE STUDENT
  const approvalRate = uniqueApplicantsCount > 0 
    ? ((uniqueApprovedScholarsCount / uniqueApplicantsCount) * 100).toFixed(1) 
    : '0.0';

  // Budget vs Disbursed Calculation
  const totalBudget = useMemo(() => {
    return programs.reduce((acc, prog) => {
      const budgetNum = Number(prog.totalBudget || prog.budget_total) || (Number(prog.stipendAmount || prog.stipend_amount || 0) * Number(prog.totalSlots || prog.total_slots || 10) * 2);
      return acc + (isNaN(budgetNum) ? 0 : budgetNum);
    }, 0);
  }, [programs]);

  const totalDisbursed = useMemo(() => {
    return filteredDisbursements.reduce((acc, d) => acc + getDisbursementAmount(d), 0);
  }, [filteredDisbursements]);

  const budgetUtilization = totalBudget > 0 ? ((totalDisbursed / totalBudget) * 100).toFixed(1) : '0.0';

  // Average Grade % calculated across UNIQUE STUDENTS (no duplicates for semestral renewals).
  // Uses the normalized 0–100 percentage (not raw GWA) so scholars from schools on different
  // grading scales (5.0 / 4.0 / percentage) can be averaged together meaningfully.
  const avgGradePercent = useMemo(() => {
    const scholarGradeMap = new Map<string, number>();
    filteredApplicants.forEach(a => {
      const percent = getNormalizedGradePercent(a);
      if (percent !== null) {
        scholarGradeMap.set(getScholarKey(a), percent);
      }
    });

    const validGrades = Array.from(scholarGradeMap.values());
    if (validGrades.length === 0) return null;
    const sum = validGrades.reduce((a, b) => a + b, 0);
    return sum / validGrades.length;
  }, [filteredApplicants]);

  // Year Level Breakdown (Deduplicated per Unique Student)
  const yearLevelDistribution = useMemo(() => {
    const counts: Record<string, number> = {
      '1st Year': 0,
      '2nd Year': 0,
      '3rd Year': 0,
      '4th Year': 0,
      '5th Year / Postgrad': 0,
    };

    const scholarYearMap = new Map<string, string>();
    filteredApplicants.forEach(a => {
      scholarYearMap.set(getScholarKey(a), a.yearLevel || '');
    });

    scholarYearMap.forEach(yrRaw => {
      const yr = (yrRaw || '').toLowerCase();
      if (yr.includes('1') || yr.includes('fresh')) counts['1st Year']++;
      else if (yr.includes('2') || yr.includes('soph')) counts['2nd Year']++;
      else if (yr.includes('3') || yr.includes('jun')) counts['3rd Year']++;
      else if (yr.includes('4') || yr.includes('sen')) counts['4th Year']++;
      else counts['5th Year / Postgrad']++;
    });

    return counts;
  }, [filteredApplicants]);

  // Top Feeder Universities (Deduplicated per Unique Student)
  const topSchools = useMemo(() => {
    const counts: Record<string, { totalScholars: number; approvedScholars: number }> = {};

    const scholarSchoolMap = new Map<string, { school: string; isApproved: boolean }>();
    filteredApplicants.forEach(a => {
      const key = getScholarKey(a);
      const existing = scholarSchoolMap.get(key);
      if (!existing || a.status === 'Approved') {
        scholarSchoolMap.set(key, {
          school: a.school || 'Unspecified University',
          isApproved: a.status === 'Approved' || existing?.isApproved || false,
        });
      }
    });

    scholarSchoolMap.forEach(({ school, isApproved }) => {
      if (!counts[school]) counts[school] = { totalScholars: 0, approvedScholars: 0 };
      counts[school].totalScholars++;
      if (isApproved) counts[school].approvedScholars++;
    });

    return Object.entries(counts)
      .map(([school, stats]) => ({ school, ...stats }))
      .sort((a, b) => b.totalScholars - a.totalScholars)
      .slice(0, 5);
  }, [filteredApplicants]);

  // Grade Performance Spectrum (Deduplicated per Unique Student).
  // Bucketed by normalized grade PERCENTAGE rather than raw GWA, since applicants come from
  // schools on different scales (5.0 / 4.0 / percentage) and their raw grade numbers aren't
  // comparable — e.g. 1.75 is "Dean's List" on a 5.0 scale but failing on a 4.0 scale.
  const gwaDistribution = useMemo(() => {
    const ranges = {
      '95% – 100% (Summa/High Honors)': 0,
      '90% – 94.9% (Magna/Honors)': 0,
      '85% – 89.9% (Dean\'s List)': 0,
      '80% – 84.9% (Good Standing)': 0,
      'Below 80% (Passed)': 0,
    };

    const scholarGradeMap = new Map<string, number>();
    filteredApplicants.forEach(a => {
      const percent = getNormalizedGradePercent(a);
      if (percent !== null) {
        scholarGradeMap.set(getScholarKey(a), percent);
      }
    });

    scholarGradeMap.forEach(percent => {
      if (percent >= 95) ranges['95% – 100% (Summa/High Honors)']++;
      else if (percent >= 90) ranges['90% – 94.9% (Magna/Honors)']++;
      else if (percent >= 85) ranges['85% – 89.9% (Dean\'s List)']++;
      else if (percent >= 80) ranges['80% – 84.9% (Good Standing)']++;
      else ranges['Below 80% (Passed)']++;
    });

    return ranges;
  }, [filteredApplicants]);

  // AI Verification Audit Statistics
  const aiAuditSummary = useMemo(() => {
    let totalDocs = 0;
    let verifiedCount = 0;
    let flaggedCount = 0;
    let pendingCount = 0;

    filteredApplicants.forEach(app => {
      const docs = app.submittedDocuments || [];
      totalDocs += docs.length;
      docs.forEach((d: SubmittedDocItem) => {
        if (d.aiVerification?.verificationStatus === 'verified' || d.status === 'Verified') {
          verifiedCount++;
        } else if (d.aiVerification?.verificationStatus === 'flagged' || d.status === 'Flagged') {
          flaggedCount++;
        } else {
          pendingCount++;
        }
      });
    });

    const authenticityRate = totalDocs > 0 ? ((verifiedCount / totalDocs) * 100).toFixed(1) : '100.0';

    return { totalDocs, verifiedCount, flaggedCount, pendingCount, authenticityRate };
  }, [filteredApplicants]);

  // CSV Exporters
  const exportApplicantsCsv = () => {
    if (filteredApplicants.length === 0) {
      showToast?.('No applicants to export');
      return;
    }

    const headers = ['Application ID', 'Scholar ID', 'Name', 'Email', 'Phone', 'Program', 'University', 'Course', 'Year Level', 'GWA', 'Status', 'Date Applied', 'Remarks'];
    const rows = filteredApplicants.map(a => [
      a.id,
      a.scholarId || '',
      a.name,
      a.email || '',
      a.phone || '',
      a.program,
      a.school,
      a.course,
      a.yearLevel || '',
      a.grade,
      a.status,
      a.date,
      a.remarks || '',
    ]);

    downloadCsv(dateStampedFilename('IskoAko_Applicant_Report'), headers, rows);
    showToast?.(`Exported ${filteredApplicants.length} applicant record(s) to CSV!`);
  };

  const exportDisbursementsCsv = () => {
    if (filteredDisbursements.length === 0) {
      showToast?.('No disbursements to export');
      return;
    }

    const headers = ['Transaction ID', 'Batch Ref', 'Scholar Name', 'Program', 'Amount (PHP)', 'Disbursement Type', 'Status', 'Date Released'];
    const rows = filteredDisbursements.map(d => [
      d.id,
      getDisbursementRef(d),
      getDisbursementScholarName(d),
      getDisbursementProgram(d),
      getDisbursementAmount(d),
      getDisbursementType(d),
      d.status,
      d.date,
    ]);

    downloadCsv(dateStampedFilename('IskoAko_Disbursements_Ledger'), headers, rows);
    showToast?.(`Exported ${filteredDisbursements.length} disbursement record(s) to CSV!`);
  };

  return (
    <div className="space-y-8 animate-fade-in pb-16">
      {/* Header & Controls Bar */}
      <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-sm flex flex-col lg:flex-row lg:items-center justify-between gap-6">
        <div>
          <div className="flex items-center gap-2.5">
            <span className="p-2 rounded-2xl bg-[#EBF5EE] text-[#2D5941] text-lg font-bold">📊</span>
            <div>
              <h2 className="text-2xl font-extrabold text-[#1A3C2E] font-serif tracking-tight">
                Analytics, Reports & Audit Hub
              </h2>
              <p className="text-xs text-[#6C6C70] mt-0.5 font-medium">
                Accurate scholar demographics, unique applicant counts, and fund utilization for {providerDetails?.name || 'Your Organization'}
              </p>
            </div>
          </div>
        </div>

        {/* Global Filter Bar & Action Exports */}
        <div className="flex flex-wrap items-center gap-3">
          {/* Program Filter */}
          <div className="flex items-center gap-1.5 bg-[#F9F5EF] border border-[#D9D2C5] rounded-2xl px-3 py-1.5">
            <span className="text-[11px] font-bold text-[#6C6C70]">Program:</span>
            <select
              value={selectedProgramId}
              onChange={(e) => setSelectedProgramId(e.target.value)}
              aria-label="Filter reports by scholarship program"
              className="bg-transparent text-xs font-bold text-[#1A3C2E] outline-none cursor-pointer border-0"
            >
              <option value="all">All Programs ({programs.length})</option>
              {programs.map((p) => (
                <option key={p.id} value={p.id}>{p.title}</option>
              ))}
            </select>
          </div>

          {/* Timeframe Filter */}
          <div className="flex items-center gap-1.5 bg-[#F9F5EF] border border-[#D9D2C5] rounded-2xl px-3 py-1.5">
            <span className="text-[11px] font-bold text-[#6C6C70]">Timeframe:</span>
            <select
              value={selectedTimeframe}
              onChange={(e) => setSelectedTimeframe(e.target.value)}
              aria-label="Filter reports by timeframe"
              className="bg-transparent text-xs font-bold text-[#1A3C2E] outline-none cursor-pointer border-0"
            >
              <option value="all">All Time</option>
              <option value="ay">Academic Year 2025-2026</option>
              <option value="90d">Last 90 Days</option>
              <option value="30d">Last 30 Days</option>
            </select>
          </div>

          {/* Quick Export Actions */}
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={exportApplicantsCsv}
              className="px-4 py-2 rounded-2xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold shadow-xs cursor-pointer border-0 transition-all flex items-center gap-1.5"
            >
              <span>📥</span>
              <span>Export Applicants CSV</span>
            </button>
            <button
              type="button"
              onClick={exportDisbursementsCsv}
              className="px-4 py-2 rounded-2xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-xs font-bold cursor-pointer border-0 transition-all flex items-center gap-1.5"
            >
              <span>💳</span>
              <span>Export Ledger</span>
            </button>
          </div>
        </div>
      </div>

      {/* 4 Executive KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Card 1: Fund Allocation */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs relative overflow-hidden flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">Fund Released</span>
            <span className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold text-sm">₱</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              ₱{totalDisbursed.toLocaleString()}
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5">
              of ₱{totalBudget.toLocaleString()} Total Program Allocation
            </p>
          </div>
          <div>
            <div className="w-full bg-[#F2EDE4] h-2 rounded-full overflow-hidden">
              <div
                className="bg-[#2D5941] h-full rounded-full transition-all duration-500"
                style={{ width: `${Math.min(100, Number(budgetUtilization))}%` }}
              />
            </div>
            <div className="flex justify-between items-center text-[10px] font-bold text-[#2D5941] mt-1.5">
              <span>{budgetUtilization}% Disbursed</span>
              <span className="text-[#6C6C70]">{(100 - Number(budgetUtilization)).toFixed(1)}% Remaining</span>
            </div>
          </div>
        </div>

        {/* Card 2: Applicants Conversion (Deduplicated per Unique Student) */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">Approval Rate</span>
            <span className="w-8 h-8 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center font-bold text-sm">🎯</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              {approvalRate}%
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5 font-medium">
              {uniqueApprovedScholarsCount} Approved Scholars of {uniqueApplicantsCount} Unique Students
            </p>
          </div>
          <div className="flex items-center gap-1.5 text-[10px] font-bold text-[#6C6C70] flex-wrap">
            <span className="px-2 py-0.5 rounded-lg bg-emerald-100/80 text-emerald-800 font-mono">
              {approvedSubmissionsCount}/{totalApplicationsCount} Submissions Approved
            </span>
          </div>
        </div>

        {/* Card 3: Academic Index */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">Avg. Grade %</span>
            <span className="w-8 h-8 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center font-bold text-sm">🎓</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              {avgGradePercent !== null ? `${avgGradePercent.toFixed(1)}%` : 'N/A'}
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5">
              Normalized grade %, scale-independent, across {activeScholarsCount} unique scholars
            </p>
          </div>
          <div className="text-[11px] font-bold text-emerald-700 flex items-center gap-1">
            <span>✨</span> Verified Academic Standing
          </div>
        </div>

        {/* Card 4: AI Forensic Trust Score */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">AI Trust Score</span>
            <span className="w-8 h-8 rounded-xl bg-purple-50 text-purple-700 flex items-center justify-center font-bold text-sm">🛡️</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              {aiAuditSummary.authenticityRate}%
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5">
              {aiAuditSummary.verifiedCount} Verified • {aiAuditSummary.flaggedCount} Flagged ({aiAuditSummary.totalDocs} Docs)
            </p>
          </div>
          <div className="text-[11px] font-bold text-[#6C6C70] flex items-center gap-1">
            <span className="text-emerald-600 font-bold">✓ Multi-AI</span> Forensic Verification
          </div>
        </div>
      </div>

      {/* Visual Analytics Grid (2 Columns) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Left Column: Application Pipeline Funnel & Demographic Split (7 cols) */}
        <div className="lg:col-span-7 space-y-6">
          {/* Application Review Funnel */}
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-5">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                  Application Processing Funnel
                </h3>
                <p className="text-xs text-[#6C6C70]">Unique student volume across each evaluation stage</p>
              </div>
              <div className="flex flex-col items-end">
                <span className="text-xs font-mono font-bold text-[#1A3C2E] bg-[#F9F5EF] px-3 py-1 rounded-xl border border-[#D9D2C5]">
                  {uniqueApplicantsCount} Unique Students
                </span>
                <span className="text-[10px] text-[#8E8E93] mt-0.5 font-mono">
                  ({totalApplicationsCount} total submissions)
                </span>
              </div>
            </div>

            <div className="space-y-3.5">
              {/* Stage 1: Received / Pending */}
              <div>
                <div className="flex justify-between text-xs font-bold mb-1">
                  <span className="text-[#6C6C70] flex items-center gap-1.5">
                    <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                    Pending & Under Review
                  </span>
                  <span className="text-[#1A3C2E] font-mono">
                    {uniqueUnderReviewCount} students ({uniqueApplicantsCount > 0 ? ((uniqueUnderReviewCount / uniqueApplicantsCount) * 100).toFixed(0) : 0}%)
                  </span>
                </div>
                <div className="w-full bg-[#F2EDE4] h-2.5 rounded-full overflow-hidden">
                  <div 
                    className="bg-amber-500 h-full rounded-full transition-all duration-500" 
                    style={{ width: `${uniqueApplicantsCount > 0 ? (uniqueUnderReviewCount / uniqueApplicantsCount) * 100 : 0}%` }}
                  />
                </div>
              </div>

              {/* Stage 2: For Exam */}
              <div>
                <div className="flex justify-between text-xs font-bold mb-1">
                  <span className="text-[#6C6C70] flex items-center gap-1.5">
                    <span className="w-2.5 h-2.5 rounded-full bg-purple-600" />
                    Shortlisted for Examination
                  </span>
                  <span className="text-[#1A3C2E] font-mono">
                    {uniqueForExamCount} students ({uniqueApplicantsCount > 0 ? ((uniqueForExamCount / uniqueApplicantsCount) * 100).toFixed(0) : 0}%)
                  </span>
                </div>
                <div className="w-full bg-[#F2EDE4] h-2.5 rounded-full overflow-hidden">
                  <div 
                    className="bg-purple-600 h-full rounded-full transition-all duration-500" 
                    style={{ width: `${uniqueApplicantsCount > 0 ? (uniqueForExamCount / uniqueApplicantsCount) * 100 : 0}%` }}
                  />
                </div>
              </div>

              {/* Stage 3: Approved / Awarded */}
              <div>
                <div className="flex justify-between text-xs font-bold mb-1">
                  <span className="text-[#6C6C70] flex items-center gap-1.5">
                    <span className="w-2.5 h-2.5 rounded-full bg-emerald-600" />
                    Approved & Awarded Scholars
                  </span>
                  <span className="text-emerald-700 font-mono font-extrabold">
                    {uniqueApprovedScholarsCount} scholars ({uniqueApplicantsCount > 0 ? ((uniqueApprovedScholarsCount / uniqueApplicantsCount) * 100).toFixed(0) : 0}%)
                  </span>
                </div>
                <div className="w-full bg-[#F2EDE4] h-2.5 rounded-full overflow-hidden">
                  <div 
                    className="bg-emerald-600 h-full rounded-full transition-all duration-500" 
                    style={{ width: `${uniqueApplicantsCount > 0 ? (uniqueApprovedScholarsCount / uniqueApplicantsCount) * 100 : 0}%` }}
                  />
                </div>
              </div>

              {/* Stage 4: Rejected / Ineligible */}
              <div>
                <div className="flex justify-between text-xs font-bold mb-1">
                  <span className="text-[#6C6C70] flex items-center gap-1.5">
                    <span className="w-2.5 h-2.5 rounded-full bg-rose-500" />
                    Ineligible / Did Not Meet Criteria
                  </span>
                  <span className="text-rose-700 font-mono">
                    {uniqueRejectedCount} students ({uniqueApplicantsCount > 0 ? ((uniqueRejectedCount / uniqueApplicantsCount) * 100).toFixed(0) : 0}%)
                  </span>
                </div>
                <div className="w-full bg-[#F2EDE4] h-2.5 rounded-full overflow-hidden">
                  <div 
                    className="bg-rose-500 h-full rounded-full transition-all duration-500" 
                    style={{ width: `${uniqueApplicantsCount > 0 ? (uniqueRejectedCount / uniqueApplicantsCount) * 100 : 0}%` }}
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Demographic & Year Level Distribution (Deduplicated) */}
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                Year Level Distribution
              </h3>
              <span className="text-xs text-[#6C6C70] font-medium">Deduplicated per unique student</span>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 pt-1">
              {Object.entries(yearLevelDistribution).map(([year, count]) => {
                const pct = uniqueApplicantsCount > 0 ? ((count / uniqueApplicantsCount) * 100).toFixed(0) : '0';
                return (
                  <div key={year} className="bg-[#F9F5EF] p-4 rounded-2xl border border-[#D9D2C5]/60 flex flex-col justify-between">
                    <span className="text-xs font-bold text-[#6C6C70]">{year}</span>
                    <div className="mt-2 flex items-baseline justify-between">
                      <span className="text-xl font-extrabold text-[#1A3C2E] font-serif">{count}</span>
                      <span className="text-xs font-mono font-bold text-[#2D5941] bg-white px-2 py-0.5 rounded-lg border border-[#D9D2C5]/40">{pct}%</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Right Column: Feeder Universities & Grade Spectrum (5 cols) */}
        <div className="lg:col-span-5 space-y-6">
          {/* Top Feeder Universities (Deduplicated) */}
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                Top Feeder Universities
              </h3>
              <span className="text-xs text-[#6C6C70] font-medium">Unique students by school</span>
            </div>

            <div className="space-y-3">
              {topSchools.length === 0 ? (
                <p className="text-xs text-[#8E8E93] text-center py-4">No institution data available.</p>
              ) : (
                topSchools.map((item, idx) => (
                  <div key={idx} className="p-3 rounded-2xl bg-[#F9F5EF] border border-[#D9D2C5]/60 flex items-center justify-between gap-2">
                    <div className="truncate">
                      <h4 className="text-xs font-extrabold text-[#1A3C2E] truncate">{item.school}</h4>
                      <p className="text-[10px] text-[#6C6C70] mt-0.5">
                        {item.approvedScholars} approved scholars
                      </p>
                    </div>
                    <span className="text-xs font-mono font-bold px-2.5 py-1 rounded-xl bg-white text-[#1A3C2E] border border-[#D9D2C5]/50 shrink-0">
                      {item.totalScholars} Students
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Grade Spectrum Histogram (Deduplicated) */}
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                Grade Performance Spectrum
              </h3>
              <span className="text-xs text-[#6C6C70] font-medium">Normalized %, deduplicated per student</span>
            </div>

            <div className="space-y-2.5">
              {Object.entries(gwaDistribution).map(([range, count]) => {
                const pct = uniqueApplicantsCount > 0 ? ((count / uniqueApplicantsCount) * 100).toFixed(0) : '0';
                return (
                  <div key={range}>
                    <div className="flex justify-between text-[11px] font-bold text-[#6C6C70] mb-1">
                      <span>{range}</span>
                      <span className="font-mono text-[#1A3C2E]">{count} ({pct}%)</span>
                    </div>
                    <div className="w-full bg-[#F2EDE4] h-2 rounded-full overflow-hidden">
                      <div
                        className="bg-[#1A3C2E] h-full rounded-full transition-all duration-500"
                        style={{ width: `${uniqueApplicantsCount > 0 ? (count / uniqueApplicantsCount) * 100 : 0}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {/* Interactive Data Explorer & Audit Table */}
      <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
              Real-Time Audit Records & Data Explorer
            </h3>
            <p className="text-xs text-[#6C6C70] mt-0.5">
              Drill down into individual student records, fund releases, and AI document forensic logs
            </p>
          </div>

          <div className="flex items-center gap-3">
            {/* Search Input */}
            <div className="relative">
              <input
                type="text"
                placeholder="Search by name, ID, school..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-8 pr-3 py-1.5 text-xs rounded-xl bg-[#F9F5EF] border border-[#D9D2C5] text-[#1A3C2E] outline-none focus:border-[#1A3C2E] w-56"
              />
              <span className="absolute left-2.5 top-2 text-xs text-[#8E8E93]">🔍</span>
            </div>

            {/* View Switcher Tabs */}
            <div className="flex items-center p-1 bg-[#F9F5EF] rounded-xl border border-[#D9D2C5]/60">
              <button
                type="button"
                onClick={() => setActiveDataTab('applicants')}
                className={`px-3 py-1 rounded-lg text-xs font-bold cursor-pointer border-0 transition-all ${
                  activeDataTab === 'applicants' ? 'bg-[#1A3C2E] text-white shadow-xs' : 'bg-transparent text-[#6C6C70] hover:text-[#1A3C2E]'
                }`}
              >
                Applications ({filteredApplicants.length})
              </button>
              <button
                type="button"
                onClick={() => setActiveDataTab('disbursements')}
                className={`px-3 py-1 rounded-lg text-xs font-bold cursor-pointer border-0 transition-all ${
                  activeDataTab === 'disbursements' ? 'bg-[#1A3C2E] text-white shadow-xs' : 'bg-transparent text-[#6C6C70] hover:text-[#1A3C2E]'
                }`}
              >
                Disbursements ({filteredDisbursements.length})
              </button>
            </div>
          </div>
        </div>

        {/* Data Table */}
        <div className="overflow-x-auto">
          {activeDataTab === 'applicants' && (
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-[#D9D2C5] bg-[#F9F5EF]/60 text-[#6C6C70] uppercase font-bold text-[10px]">
                  <th className="py-3 px-4">Applicant</th>
                  <th className="py-3 px-4">Program</th>
                  <th className="py-3 px-4">University & Course</th>
                  <th className="py-3 px-4 text-center">GWA</th>
                  <th className="py-3 px-4 text-center">Docs Status</th>
                  <th className="py-3 px-4 text-center">Decision</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#D9D2C5]/40 text-[#1A3C2E]">
                {filteredApplicants.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-8 text-center text-[#8E8E93]">No matching applicants found.</td>
                  </tr>
                ) : (
                  filteredApplicants.slice(0, 10).map((app) => (
                    <tr key={app.id} className="hover:bg-[#F9F5EF]/40 transition-colors">
                      <td className="py-3 px-4">
                        <span className="font-bold block">{app.name}</span>
                        <span className="text-[10px] text-[#8E8E93] font-mono">{app.id}</span>
                      </td>
                      <td className="py-3 px-4 font-semibold">{app.program}</td>
                      <td className="py-3 px-4">
                        <span className="block truncate max-w-xs font-medium">{app.school}</span>
                        <span className="text-[10px] text-[#6C6C70]">{app.course} ({app.yearLevel || '1st Year'})</span>
                      </td>
                      <td className="py-3 px-4 text-center font-mono font-bold text-[#2D5941]">
                        {app.grade}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#EBF5EE] text-[#2D5941]">
                          {app.submittedDocuments?.filter((d: SubmittedDocItem) => d.status === 'Verified').length || 0}/{app.submittedDocuments?.length || 0} Verified
                        </span>
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${
                          app.status === 'Approved' ? 'bg-emerald-100 text-emerald-800' :
                          app.status === 'For Exam' ? 'bg-purple-100 text-purple-800' :
                          app.status === 'Under Review' ? 'bg-amber-100 text-amber-800' :
                          app.status === 'Rejected' ? 'bg-rose-100 text-rose-800' :
                          'bg-blue-100 text-blue-800'
                        }`}>
                          {app.status}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}

          {activeDataTab === 'disbursements' && (
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-[#D9D2C5] bg-[#F9F5EF]/60 text-[#6C6C70] uppercase font-bold text-[10px]">
                  <th className="py-3 px-4">Batch / Reference</th>
                  <th className="py-3 px-4">Scholar</th>
                  <th className="py-3 px-4">Program</th>
                  <th className="py-3 px-4 text-right">Amount</th>
                  <th className="py-3 px-4 text-center">Release Date</th>
                  <th className="py-3 px-4 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#D9D2C5]/40 text-[#1A3C2E]">
                {filteredDisbursements.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-8 text-center text-[#8E8E93]">No disbursement records found.</td>
                  </tr>
                ) : (
                  filteredDisbursements.slice(0, 10).map((tx) => (
                    <tr key={tx.id} className="hover:bg-[#F9F5EF]/40 transition-colors">
                      <td className="py-3 px-4 font-mono font-bold">{getDisbursementRef(tx)}</td>
                      <td className="py-3 px-4 font-bold">{getDisbursementScholarName(tx)}</td>
                      <td className="py-3 px-4 text-[#6C6C70]">{getDisbursementProgram(tx)}</td>
                      <td className="py-3 px-4 text-right font-mono font-bold text-[#2D5941]">
                        ₱{getDisbursementAmount(tx).toLocaleString()}
                      </td>
                      <td className="py-3 px-4 text-center text-[#6C6C70]">{tx.date}</td>
                      <td className="py-3 px-4 text-center">
                        <span className="px-2.5 py-1 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                          {tx.status || 'Released'}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}
        </div>

        {filteredApplicants.length > 10 && activeDataTab === 'applicants' && (
          <div className="text-center pt-2">
            <span className="text-xs text-[#6C6C70]">Showing top 10 of {filteredApplicants.length} applications. Export full list using the button above.</span>
          </div>
        )}
      </div>
    </div>
  );
};

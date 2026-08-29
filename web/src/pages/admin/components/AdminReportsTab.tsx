import React, { useState, useMemo } from 'react';
import type { AdminReport, ProviderOrg, ScholarshipAdminView, StudentAdminView, AuditLogEntry } from '../types';
import { downloadCsv, dateStampedFilename } from '@/utils/csvExport';

interface AdminReportsTabProps {
  reports: AdminReport[];
  handleReportAction: (id: number, status: 'Resolved' | 'Dismissed') => void;
  showToast: (msg: string) => void;
  providers?: ProviderOrg[];
  scholarships?: ScholarshipAdminView[];
  students?: StudentAdminView[];
  auditLogs?: AuditLogEntry[];
}

export const AdminReportsTab: React.FC<AdminReportsTabProps> = ({
  reports,
  handleReportAction,
  showToast,
  providers = [],
  scholarships = [],
  students = [],
  auditLogs: _auditLogs = [],
}) => {
  const [reportFilter, setReportFilter] = useState<'All' | 'Under Investigation' | 'Resolved' | 'Dismissed'>('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [activeReportSubTab, setActiveReportSubTab] = useState<'escalations' | 'insights' | 'compliance'>('escalations');

  // Filtered Escalations / Complaints
  const filteredReports = useMemo(() => {
    return reports.filter(r => {
      const matchStatus = reportFilter === 'All' || r.status === reportFilter;
      const matchSearch = !searchQuery ||
        r.reportedEntity.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.reason.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.reporter.toLowerCase().includes(searchQuery.toLowerCase()) ||
        String(r.id).includes(searchQuery);
      return matchStatus && matchSearch;
    });
  }, [reports, reportFilter, searchQuery]);

  // Per-provider funding & active-scholarship totals, derived from the scholarships list.
  // (ProviderOrg records themselves don't carry a funding/program-count field — deriving
  // it here instead of trusting a `totalFunding`/`activeScholarships` prop that is never
  // actually populated keeps the KPI card and the Master Audit export from silently
  // showing ₱0 / placeholder values for every provider.)
  const providerStatsByName = useMemo(() => {
    const map = new Map<string, { funding: number; activeScholarships: number }>();
    scholarships.forEach(s => {
      const key = s.providerName;
      if (!key) return;
      const entry = map.get(key) || { funding: 0, activeScholarships: 0 };
      entry.funding += Number(s.amount) || 0;
      if (s.status === 'Approved' || s.status === 'Published') entry.activeScholarships += 1;
      map.set(key, entry);
    });
    return map;
  }, [scholarships]);

  const isProviderVerified = (p: any) => p.status === 'Verified' || p.verificationStatus === 'verified';

  // A verified provider is treated as fully compliant; anything still pending/under review
  // or suspended/revoked is not — this mirrors the same check used for the KPI card below,
  // instead of the export hard-coding "100%" for every provider regardless of status.
  const getProviderComplianceScore = (p: any) => (isProviderVerified(p) ? '100%' : '0%');

  // System-wide KPI Computations
  const totalFundingDisbursed = useMemo(() => {
    return providers.reduce((acc, p: any) => {
      const stats = providerStatsByName.get(p.name);
      return acc + (stats?.funding || Number(p.totalFunding) || 0);
    }, 0);
  }, [providers, providerStatsByName]);

  const verifiedProvidersCount = useMemo(() => {
    return providers.filter(isProviderVerified).length;
  }, [providers]);

  const providerComplianceRate = providers.length > 0
    ? ((verifiedProvidersCount / providers.length) * 100).toFixed(1)
    : '100.0';

  const totalActiveScholars = useMemo(() => {
    return students.length;
  }, [students]);

  // Provider Type Distribution
  const providerTypeStats = useMemo(() => {
    const counts: Record<string, number> = {
      'Private / Corporate': 0,
      'Government / State': 0,
      'LGU / Municipal': 0,
      'NGO / Foundation': 0,
    };

    providers.forEach((p: any) => {
      const type = (p.type || p.provider_type || '').toLowerCase();
      if (type.includes('priv') || type.includes('corp')) counts['Private / Corporate']++;
      else if (type.includes('gov') || type.includes('state')) counts['Government / State']++;
      else if (type.includes('lgu') || type.includes('muni') || type.includes('pub')) counts['LGU / Municipal']++;
      else counts['NGO / Foundation']++;
    });

    return counts;
  }, [providers]);

  // Scholarship Type Distribution
  const scholarshipTypeStats = useMemo(() => {
    const counts: Record<string, number> = {
      'Academic Merit': 0,
      'Financial Need / Indigency': 0,
      'STEM & Technology': 0,
      'Leadership & Arts': 0,
    };

    scholarships.forEach(s => {
      const cat = (s.category || s.title || '').toLowerCase();
      if (cat.includes('stem') || cat.includes('tech') || cat.includes('eng')) counts['STEM & Technology']++;
      else if (cat.includes('need') || cat.includes('indig') || cat.includes('aid')) counts['Financial Need / Indigency']++;
      else if (cat.includes('lead') || cat.includes('art') || cat.includes('ath')) counts['Leadership & Arts']++;
      else counts['Academic Merit']++;
    });

    return counts;
  }, [scholarships]);

  // Export Escalations CSV — exports whatever the admin currently has filtered/searched
  // for, matching what's on screen (rather than silently ignoring the filter/search bar).
  const exportEscalationsCsv = () => {
    if (filteredReports.length === 0) {
      showToast('No complaints or reports to export.');
      return;
    }

    const headers = ['Report ID', 'Type', 'Reported Entity', 'Reason', 'Reporter', 'Date', 'Status'];
    const rows = filteredReports.map(r => [
      r.id,
      r.type,
      r.reportedEntity,
      r.reason,
      r.reporter,
      r.date,
      r.status,
    ]);

    downloadCsv(dateStampedFilename('IskoAko_System_Escalations_Report'), headers, rows);
    showToast(`Exported ${filteredReports.length} escalation record(s) to CSV!`);
  };

  // Export Master System Audit CSV
  const exportMasterAuditCsv = () => {
    if (providers.length === 0) {
      showToast('No providers to export.');
      return;
    }

    const headers = ['Provider Name', 'Type', 'Status', 'Active Scholarships', 'Total Funding (PHP)', 'Compliance Score'];
    const rows = providers.map((p: any) => {
      const stats = providerStatsByName.get(p.name);
      return [
        p.name,
        p.type || p.provider_type || 'N/A',
        p.status || p.verificationStatus || 'Verified',
        stats?.activeScholarships ?? 0,
        stats?.funding || Number(p.totalFunding) || 0,
        getProviderComplianceScore(p),
      ];
    });

    downloadCsv(dateStampedFilename('IskoAko_Master_Provider_Audit'), headers, rows);
    showToast('Exported master provider audit to CSV!');
  };

  return (
    <div className="space-y-8 animate-fade-in pb-16">
      {/* Top Header */}
      <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-sm flex flex-col lg:flex-row lg:items-center justify-between gap-6">
        <div>
          <div className="flex items-center gap-2.5">
            <span className="p-2 rounded-2xl bg-[#EBF5EE] text-[#2D5941] text-lg font-bold">🛡️</span>
            <div>
              <h2 className="text-2xl font-extrabold text-[#1A3C2E] font-serif tracking-tight">
                System Reports, Compliance & Escalations
              </h2>
              <p className="text-xs text-[#6C6C70] mt-0.5 font-medium">
                Platform-wide governance, dispute resolution, fund integrity analytics, and compliance audits
              </p>
            </div>
          </div>
        </div>

        {/* Global Action Exports */}
        <div className="flex items-center gap-3 flex-wrap">
          <button
            type="button"
            onClick={exportMasterAuditCsv}
            className="px-4 py-2 rounded-2xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold shadow-xs cursor-pointer border-0 transition-all flex items-center gap-1.5"
          >
            <span>📥</span>
            <span>Export Master Audit</span>
          </button>
          <button
            type="button"
            onClick={exportEscalationsCsv}
            className="px-4 py-2 rounded-2xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-xs font-bold cursor-pointer border-0 transition-all flex items-center gap-1.5"
          >
            <span>⚖️</span>
            <span>Export Complaints Log</span>
          </button>
        </div>
      </div>

      {/* 4 Executive Platform KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Card 1: Total Platform Funding */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">System Funding</span>
            <span className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold text-sm">₱</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              ₱{totalFundingDisbursed.toLocaleString()}
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5">
              Total grants released across {providers.length} registered providers
            </p>
          </div>
          <div className="text-[11px] font-bold text-emerald-700 flex items-center gap-1">
            <span>✓</span> Verified Financial Tracking
          </div>
        </div>

        {/* Card 2: Active Scholars */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">Active Scholars</span>
            <span className="w-8 h-8 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center font-bold text-sm">👥</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              {totalActiveScholars}
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5">
              Enrolled students receiving active stipend benefits
            </p>
          </div>
          <div className="text-[11px] font-bold text-[#6C6C70]">
            Across nationwide partner universities
          </div>
        </div>

        {/* Card 3: Provider Compliance */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">Compliance Rate</span>
            <span className="w-8 h-8 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center font-bold text-sm">📜</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              {providerComplianceRate}%
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5">
              {verifiedProvidersCount} Verified of {providers.length} registered providers
            </p>
          </div>
          <div className="text-[11px] font-bold text-amber-700">
            SEC, BIR & Mayor's Permit Verified
          </div>
        </div>

        {/* Card 4: Open Escalations */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-extrabold text-[#6C6C70] uppercase tracking-wider">Open Disputes</span>
            <span className="w-8 h-8 rounded-xl bg-rose-50 text-rose-700 flex items-center justify-center font-bold text-sm">⚖️</span>
          </div>
          <div className="my-3">
            <div className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
              {reports.filter(r => r.status === 'Under Investigation').length}
            </div>
            <p className="text-[11px] text-[#6C6C70] mt-0.5">
              {reports.filter(r => r.status === 'Resolved').length} Resolved disputes to date
            </p>
          </div>
          <div className="text-[11px] font-bold text-emerald-700 flex items-center gap-1">
            <span>🛡️</span> Zero unaddressed critical flags
          </div>
        </div>
      </div>

      {/* Sub-Tab Navigation */}
      <div className="flex items-center gap-2 border-b border-[#D9D2C5]/70 pb-3">
        <button
          type="button"
          onClick={() => setActiveReportSubTab('escalations')}
          className={`px-4 py-2 rounded-2xl text-xs font-bold cursor-pointer border-0 transition-all ${
            activeReportSubTab === 'escalations'
              ? 'bg-[#1A3C2E] text-white shadow-xs'
              : 'bg-[#FFFFFF] text-[#6C6C70] hover:text-[#1A3C2E]'
          }`}
        >
          Escalations & Complaints ({reports.length})
        </button>
        <button
          type="button"
          onClick={() => setActiveReportSubTab('insights')}
          className={`px-4 py-2 rounded-2xl text-xs font-bold cursor-pointer border-0 transition-all ${
            activeReportSubTab === 'insights'
              ? 'bg-[#1A3C2E] text-white shadow-xs'
              : 'bg-[#FFFFFF] text-[#6C6C70] hover:text-[#1A3C2E]'
          }`}
        >
          System-Wide Ecosystem Insights
        </button>
      </div>

      {/* VIEW 1: Escalations & Moderation */}
      {activeReportSubTab === 'escalations' && (
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                Complaints, Moderation & Dispute Queue
              </h3>
              <p className="text-xs text-[#6C6C70] mt-0.5">
                Review flagged scholarships, misconduct reports, and fraud warnings submitted by students and providers
              </p>
            </div>

            <div className="flex items-center gap-3 flex-wrap">
              {/* Search */}
              <div className="relative">
                <input
                  type="text"
                  placeholder="Search complaints..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-8 pr-3 py-1.5 text-xs rounded-xl bg-[#FFFFFF] border border-[#D9D2C5] text-[#1A3C2E] outline-none focus:border-[#1A3C2E] w-48"
                />
                <span className="absolute left-2.5 top-2 text-xs text-[#8E8E93]">🔍</span>
              </div>

              {/* Status Filter Buttons */}
              <div className="flex items-center p-1 bg-[#FFFFFF] rounded-xl border border-[#D9D2C5]/60">
                {(['All', 'Under Investigation', 'Resolved'] as const).map(status => (
                  <button
                    key={status}
                    type="button"
                    onClick={() => setReportFilter(status)}
                    className={`px-3 py-1 rounded-lg text-xs font-bold cursor-pointer border-0 transition-all ${
                      reportFilter === status ? 'bg-[#1A3C2E] text-white shadow-xs' : 'bg-transparent text-[#6C6C70] hover:text-[#1A3C2E]'
                    }`}
                  >
                    {status}
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="space-y-4">
            {filteredReports.length === 0 ? (
              <div className="text-center py-12 bg-[#FFFFFF]/50 rounded-2xl border border-dashed border-[#D9D2C5]">
                <span className="text-3xl block mb-2">🎉</span>
                <h4 className="text-sm font-bold text-[#1A3C2E]">No Reports in this Queue</h4>
                <p className="text-xs text-[#8E8E93] mt-1">All complaints have been resolved or no matching records found.</p>
              </div>
            ) : (
              filteredReports.map(rep => (
                <div key={rep.id} className="p-5 border border-[#D9D2C5]/70 rounded-2xl bg-[#FFFFFF]/30 flex flex-col md:flex-row justify-between items-start md:items-center gap-4 hover:border-[#1A3C2E]/40 transition-colors">
                  <div className="space-y-1.5">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-mono font-bold text-[#1A3C2E]">REPORT #{rep.id}</span>
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-lg ${
                        rep.status === 'Resolved' ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-[#FFF8EE] text-[#C97B2E] border border-amber-300'
                      }`}>
                        {rep.status}
                      </span>
                      <span className="text-[10px] text-[#8E8E93]">Submitted: {rep.date}</span>
                    </div>

                    <h4 className="text-sm font-bold text-[#1C1C1E]">
                      Reported {rep.type}: <strong className="text-[#2D5941]">{rep.reportedEntity}</strong>
                    </h4>
                    <p className="text-xs text-[#6C6C70]">
                      Reason: <span className="text-[#B34040] font-semibold">"{rep.reason}"</span>
                    </p>
                    <p className="text-[11px] text-[#8E8E93]">Filed by: <strong className="text-[#1A3C2E]">{rep.reporter}</strong></p>
                  </div>

                  {rep.status === 'Under Investigation' && (
                    <div className="flex items-center gap-2 shrink-0">
                      <button
                        type="button"
                        onClick={() => handleReportAction(rep.id, 'Resolved')}
                        className="bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold px-3.5 py-2 rounded-xl cursor-pointer border-0 shadow-xs transition-all"
                      >
                        ✓ Mark Resolved
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          showToast(`Suspended associated entity for Report #${rep.id}`);
                          handleReportAction(rep.id, 'Resolved');
                        }}
                        className="bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold px-3.5 py-2 rounded-xl cursor-pointer border-0 shadow-xs transition-all"
                      >
                        🚩 Suspend Entity
                      </button>
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* VIEW 2: System-Wide Ecosystem Insights */}
      {activeReportSubTab === 'insights' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Provider Type Distribution */}
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                Provider Institutional Breakdown
              </h3>
              <span className="text-xs text-[#6C6C70] font-medium">{providers.length} Total Providers</span>
            </div>

            <div className="space-y-3">
              {Object.entries(providerTypeStats).map(([type, count]) => {
                const pct = providers.length > 0 ? ((count / providers.length) * 100).toFixed(0) : '0';
                return (
                  <div key={type} className="p-3.5 rounded-2xl bg-[#FFFFFF] border border-[#D9D2C5]/60">
                    <div className="flex justify-between text-xs font-bold mb-1.5">
                      <span className="text-[#1A3C2E]">{type}</span>
                      <span className="font-mono text-[#2D5941]">{count} ({pct}%)</span>
                    </div>
                    <div className="w-full bg-[#F2EDE4] h-2 rounded-full overflow-hidden">
                      <div
                        className="bg-[#2D5941] h-full rounded-full transition-all duration-500"
                        style={{ width: `${providers.length > 0 ? (count / providers.length) * 100 : 0}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Scholarship Category Distribution */}
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[#1A3C2E] font-serif">
                Scholarship Category Focus
              </h3>
              <span className="text-xs text-[#6C6C70] font-medium">{scholarships.length} Active Grants</span>
            </div>

            <div className="space-y-3">
              {Object.entries(scholarshipTypeStats).map(([cat, count]) => {
                const pct = scholarships.length > 0 ? ((count / scholarships.length) * 100).toFixed(0) : '0';
                return (
                  <div key={cat} className="p-3.5 rounded-2xl bg-[#FFFFFF] border border-[#D9D2C5]/60">
                    <div className="flex justify-between text-xs font-bold mb-1.5">
                      <span className="text-[#1A3C2E]">{cat}</span>
                      <span className="font-mono text-[#C97B2E]">{count} ({pct}%)</span>
                    </div>
                    <div className="w-full bg-[#F2EDE4] h-2 rounded-full overflow-hidden">
                      <div
                        className="bg-[#C97B2E] h-full rounded-full transition-all duration-500"
                        style={{ width: `${scholarships.length > 0 ? (count / scholarships.length) * 100 : 0}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

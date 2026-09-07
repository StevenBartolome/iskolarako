import React from 'react';
import type { AuditLogEntry, AdminTab } from '../types';

interface AdminDashboardTabProps {
  setActiveTab: (tab: AdminTab) => void;
  auditLogs: AuditLogEntry[];
  totalStudents: number;
  totalProviders: number;
  verifiedProviders: number;
  pendingVerifications: number;
  activeScholarships: number;
  pendingApplications: number;
  approvedScholars: number;
  flaggedReports: number;
  totalReleased: number;
  pendingDisbursements: number;
}

export const AdminDashboardTab: React.FC<AdminDashboardTabProps> = ({
  setActiveTab,
  auditLogs,
  totalStudents,
  totalProviders,
  verifiedProviders,
  pendingVerifications,
  activeScholarships,
  pendingApplications,
  approvedScholars,
  flaggedReports,
  totalReleased,
  pendingDisbursements,
}) => {
  return (
    <div className="space-y-6">
      {/* Metric Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Total Registered Students</span>
          <span className="text-3xl font-extrabold font-serif text-[#1A3C2E] mt-2">{totalStudents.toLocaleString()}</span>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Scholarship Providers</span>
          <div className="flex items-baseline justify-between mt-2">
            <span className="text-3xl font-extrabold font-serif text-[#1A3C2E]">{totalProviders}</span>
            <span className="text-[10px] text-[#2D5941] bg-[#EBF5EE] font-bold px-2 py-0.5 rounded">{verifiedProviders} Verified</span>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Pending Verifications</span>
          <div className="flex items-baseline justify-between mt-2">
            <span className="text-3xl font-extrabold font-serif text-[#C97B2E]">{pendingVerifications}</span>
            <span className="text-[10px] text-[#C97B2E] bg-[#FFF8EE] font-bold px-2 py-0.5 rounded">Requires Review</span>
          </div>
        </div>
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
          <span className="text-xs font-bold text-[#6C6C70] uppercase">Active Scholarships</span>
          <span className="text-3xl font-extrabold font-serif text-[#2D5941] mt-2">{activeScholarships}</span>
        </div>
      </div>

      {/* Sub-Metrics Section */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
          <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Application Pipeline</h3>
          <div className="space-y-3">
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Pending Applications:</span>
              <span className="font-bold text-[#1C1C1E]">{pendingApplications.toLocaleString()}</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Approved Scholars:</span>
              <span className="font-bold text-[#2D5941]">{approvedScholars.toLocaleString()}</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Reported/Scam Flagged:</span>
              <span className="font-bold text-[#B34040]">{flaggedReports}</span>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
          <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Finances</h3>
          <div className="space-y-3">
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Total Released:</span>
              <span className="font-extrabold text-[#2D5941]">₱{totalReleased.toLocaleString()}</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-[#6C6C70]">Pending Disbursements:</span>
              <span className="font-bold text-[#C97B2E]">₱{pendingDisbursements.toLocaleString()}</span>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
          <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Provider Management Panel</h3>
          <div className="flex gap-2">
            <button
              onClick={() => setActiveTab('providers')}
              className="flex-1 text-center bg-[#2D5941] text-white text-xs font-bold py-2 px-3 rounded-xl hover:bg-[#1A3C2E] transition-colors cursor-pointer"
            >
              Pending List
            </button>
            <button
              onClick={() => setActiveTab('reports')}
              className="flex-1 text-center bg-[#C97B2E] text-white text-xs font-bold py-2 px-3 rounded-xl hover:bg-[#B56D24] transition-colors cursor-pointer"
            >
              View Reports
            </button>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-[#1A3C2E]/5 via-transparent to-[#C97B2E]/5" />
        <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-6 relative z-10 flex items-center gap-2">
          <span className="w-1.5 h-1.5 rounded-full bg-gradient-to-r from-[#1A3C2E] to-[#2D5941]" />
          Quick Actions
        </h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 relative z-10">
          <QuickActionCard
            onClick={() => setActiveTab('providers')}
            title="Verify Providers"
            subtitle={`${pendingVerifications} pending review`}
            icon={<ProviderIcon />}
            gradient="from-[#1A3C2E] to-[#2D5941]"
            bgGradient="from-[#ECF4ED] to-[#E8F0E8]"
            accentColor="#2D5941"
            hoverBorder="#2D5941"
            delay={0}
          />
          <QuickActionCard
            onClick={() => setActiveTab('scholarships')}
            title="Review Scholarships"
            subtitle={`${activeScholarships} active programs`}
            icon={<ScholarshipIcon />}
            gradient="from-[#1A3C2E] to-[#2D5941]"
            bgGradient="from-[#ECF4ED] to-[#E8F0E8]"
            accentColor="#1A3C2E"
            hoverBorder="#1A3C2E"
            delay={50}
          />
          <QuickActionCard
            onClick={() => setActiveTab('applications')}
            title="Monitor Applications"
            subtitle={`${pendingApplications} pending review`}
            icon={<ApplicationsIcon />}
            gradient="from-[#C97B2E] to-[#E8A838]"
            bgGradient="from-[#FFF8EE] to-[#FEF3E7]"
            accentColor="#C97B2E"
            hoverBorder="#C97B2E"
            delay={100}
          />
          <QuickActionCard
            onClick={() => setActiveTab('reports')}
            title="View Reports"
            subtitle={`${flaggedReports} flagged items`}
            icon={<ReportIcon />}
            gradient="from-[#B34040] to-[#D65A5A]"
            bgGradient="from-[#FEF2F2] to-[#FEE2E2]"
            accentColor="#B34040"
            hoverBorder="#B34040"
            delay={150}
          />
        </div>
      </div>

      {/* Recent System Activity */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <h3 className="text-base font-bold text-[#1A3C2E] font-serif mb-4">Recent Audit Activity</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-[#6C6C70]">
            <thead>
              <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                <th className="py-2.5">Time</th>
                <th>Admin</th>
                <th>Action</th>
                <th>Target Entity</th>
              </tr>
            </thead>
            <tbody>
              {auditLogs.slice(0, 5).map(log => (
                <tr key={log.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                  <td className="py-2">{log.date} {log.time}</td>
                  <td className="font-semibold text-[#1C1C1E]">{log.admin}</td>
                  <td>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                      log.action.includes('APPROVED') ? 'bg-[#EBF5EE] text-[#2D5941]' :
                      log.action.includes('SUSPENDED') ? 'bg-red-50 text-[#B34040]' :
                      'bg-[#EDE8DE] text-[#6C6C70]'
                    }`}>
                      {log.action}
                    </span>
                  </td>
                  <td>{log.target}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

interface QuickActionCardProps {
  onClick: () => void;
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  gradient: string;
  bgGradient: string;
  accentColor: string;
  hoverBorder: string;
  delay: number;
}

const QuickActionCard: React.FC<QuickActionCardProps> = ({
  onClick,
  title,
  subtitle,
  icon,
  gradient,
  bgGradient,
  accentColor,
  hoverBorder,
  delay,
}) => {
  return (
    <button
      onClick={onClick}
      className="group relative p-5 rounded-2xl border transition-all duration-300 cursor-pointer overflow-hidden animate-fade-slide-up"
      style={{
        borderColor: '#D9D2C5',
        background: bgGradient,
        animationDelay: `${delay}ms`,
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.borderColor = hoverBorder;
        e.currentTarget.style.boxShadow = `0 12px 40px -12px ${accentColor}40, 0 4px 16px -4px ${accentColor}20`;
        e.currentTarget.style.transform = 'translateY(-4px)';
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.borderColor = '#D9D2C5';
        e.currentTarget.style.boxShadow = 'none';
        e.currentTarget.style.transform = 'translateY(0)';
      }}
    >
      <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300" style={{ background: `linear-gradient(135deg, ${gradient.replace('from-', '').replace('to-', '')})` }} />
      <div className="absolute inset-0 bg-gradient-to-br from-white/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
      <div className="relative z-10 flex flex-col items-center gap-3 text-center">
        <div className="relative w-14 h-14 rounded-2xl flex items-center justify-center transition-all duration-300 group-hover:scale-110" style={{ background: bgGradient }}>
          <div className="absolute inset-0 rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-300" style={{ background: gradient }} />
          <span className="relative z-10 text-3xl">{icon}</span>
        </div>
        <div>
          <p className="text-sm font-bold text-[#1A3C2E] leading-tight">{title}</p>
          <p className="text-[11px] font-medium mt-1" style={{ color: accentColor }}>{subtitle}</p>
        </div>
        <div className="absolute bottom-4 right-4 w-8 h-8 rounded-xl opacity-0 group-hover:opacity-100 group-hover:translate-x-1 transition-all duration-300" style={{ background: gradient }}>
          <svg className="w-5 h-5 text-white mx-auto my-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M17 8l4 4m0 0l-4 4m4-4H3" />
          </svg>
        </div>
      </div>
    </button>
  );
};

// SVG Icons
const ProviderIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#1A3C2E' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
  </svg>
);

const ScholarshipIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#1A3C2E' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
  </svg>
);

const ApplicationsIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#C97B2E' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
  </svg>
);

const ReportIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#B34040' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
  </svg>
);

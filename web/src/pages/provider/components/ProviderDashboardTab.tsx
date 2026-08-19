import React from 'react';
import type { Program, ScholarAward } from '../types';

interface ProviderDashboardTabProps {
  programsList: Program[];
  scholarsList: ScholarAward[];
  applicantsList: any[];
  totalCredited: number;
  totalPending: number;
  setActiveTab?: (tab: any) => void;
  onOpenCreateProgram?: () => void;
}

export const ProviderDashboardTab: React.FC<ProviderDashboardTabProps> = ({
  programsList,
  scholarsList,
  applicantsList,
  totalCredited,
  totalPending,
  setActiveTab,
  onOpenCreateProgram,
}) => {
  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Dashboard</h2>
        <p className="text-sm text-[#6C6C70] mt-1 font-medium">Real-time Scholarship Monitoring</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Permanent Programs</span>
          <h3 className="text-3xl font-bold text-[#1A3C2E] font-serif mt-1">{programsList.length}</h3>
          <span className="text-xs text-[#2D5941] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#2D5941]" /> Fully Lifecycle Managed
          </span>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Active Scholars (Awards)</span>
          <h3 className="text-3xl font-bold text-[#C97B2E] font-serif mt-1">{scholarsList.length}</h3>
          <span className="text-xs text-[#C97B2E] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#C97B2E]" /> Undergoing renewal checks
          </span>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Active Cycle Applicants</span>
          <h3 className="text-3xl font-bold text-[#B34040] font-serif mt-1">{applicantsList.length}</h3>
          <span className="text-xs text-[#B34040] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#B34040]" /> In active intake cycles
          </span>
        </div>
        <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
          <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Funds Released</span>
          <h3 className="text-3xl font-bold text-[#2D5941] font-serif mt-1">₱{(totalCredited / 1000000).toFixed(2)}M</h3>
          <span className="text-xs text-[#2D5941] font-semibold flex items-center gap-1 mt-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#2D5941]" /> ₱{(totalPending / 1000).toFixed(0)}K pending release
          </span>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 shadow-sm p-6 relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-[#2D5941]/5 via-transparent to-[#C97B2E]/5" />
        <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5]/60 pb-3 mb-6 relative z-10 flex items-center gap-2">
          <span className="w-1.5 h-1.5 rounded-full bg-gradient-to-r from-[#2D5941] to-[#C97B2E]" />
          Quick Actions
        </h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 relative z-10">
          <ProviderQuickActionCard
            title="Create Program"
            subtitle="Launch new scholarship"
            icon={<PlusIcon />}
            gradient="from-[#2D5941] to-[#1A3C2E]"
            bgGradient="from-[#ECF4ED] to-[#E8F0E8]"
            accentColor="#2D5941"
            hoverBorder="#2D5941"
            delay={0}
            onClick={() => {
              if (onOpenCreateProgram) {
                onOpenCreateProgram();
              } else if (setActiveTab) {
                setActiveTab('create-program');
              }
            }}
          />
          <ProviderQuickActionCard
            title="Review Applications"
            subtitle={`${applicantsList.length} pending review`}
            icon={<ClipboardIcon />}
            gradient="from-[#C97B2E] to-[#E8A838]"
            bgGradient="from-[#FFF8EE] to-[#FEF3E7]"
            accentColor="#C97B2E"
            hoverBorder="#C97B2E"
            delay={50}
            onClick={() => {
              if (setActiveTab) setActiveTab('applicants');
            }}
          />
          <ProviderQuickActionCard
            title="Manage Scholars"
            subtitle={`${scholarsList.length} active scholars`}
            icon={<UsersIcon />}
            gradient="from-[#1A3C2E] to-[#2D5941]"
            bgGradient="from-[#ECF4ED] to-[#E8F0E8]"
            accentColor="#1A3C2E"
            hoverBorder="#1A3C2E"
            delay={100}
            onClick={() => {
              if (setActiveTab) setActiveTab('applicants');
            }}
          />
          <ProviderQuickActionCard
            title="Release Funds"
            subtitle={`₱${(totalPending / 1000).toFixed(0)}K pending`}
            icon={<WalletIcon />}
            gradient="from-[#C97B2E] to-[#E8A838]"
            bgGradient="from-[#FFF8EE] to-[#FEF3E7]"
            accentColor="#C97B2E"
            hoverBorder="#C97B2E"
            delay={150}
            onClick={() => {
              if (setActiveTab) setActiveTab('disbursements');
            }}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm lg:col-span-2 space-y-6">
          <div className="flex justify-between items-center">
            <h4 className="font-bold text-[#1A3C2E] font-serif">Fund Allocation Distribution</h4>
            <span className="text-xs font-semibold text-[#8E8E93]">AY 2026-2027</span>
          </div>
          <div className="space-y-4 pt-2">
            {programsList.map(prog => (
              <div key={prog.id}>
                <div className="flex justify-between text-xs font-semibold text-[#1C1C1E] mb-1.5">
                  <span>{prog.title}</span>
                  <span>{prog.budgetUsed} / {prog.budgetTotal}</span>
                </div>
                <div className="w-full bg-[#EDE8DE] h-3.5 rounded-full overflow-hidden">
                  <div className="bg-[#2D5941] h-full rounded-full" style={{ width: '65%' }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-5">
          <h4 className="font-bold text-[#1A3C2E] font-serif">Recent System Events</h4>
          <div className="space-y-4 text-xs">
            <div className="flex gap-3 pb-3 border-b border-[#D9D2C5]/40">
              <div className="w-8 h-8 rounded-full bg-[#EBF5EE] text-[#2D5941] flex items-center justify-center font-bold shrink-0">IA</div>
              <div>
                <p className="font-semibold text-[#1C1C1E]">Scholar Award Issued</p>
                <p className="text-[10px] text-[#6C6C70] mt-0.5">Applicant upgraded to continuing status</p>
              </div>
            </div>
            <div className="flex gap-3 pb-3 border-b border-[#D9D2C5]/40">
              <div className="w-8 h-8 rounded-full bg-[#F9F0E0] text-[#C97B2E] flex items-center justify-center font-bold shrink-0">RC</div>
              <div>
                <p className="font-semibold text-[#1C1C1E]">Renewal Policy Warning</p>
                <p className="text-[10px] text-[#6C6C70] mt-0.5">Marcus Vian flagged (GWA 2.10 under Conditional Policy)</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

interface ProviderQuickActionCardProps {
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  gradient: string;
  bgGradient: string;
  accentColor: string;
  hoverBorder: string;
  delay: number;
  onClick?: () => void;
}

const ProviderQuickActionCard: React.FC<ProviderQuickActionCardProps> = ({
  title,
  subtitle,
  icon,
  gradient,
  bgGradient,
  accentColor,
  hoverBorder,
  delay,
  onClick,
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

// SVG Icons for Provider
const PlusIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#2D5941' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 4v16m8-8H4" />
  </svg>
);

const ClipboardIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#C97B2E' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
  </svg>
);

const UsersIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#1A3C2E' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
  </svg>
);

const WalletIcon = () => (
  <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24" style={{ stroke: '#C97B2E' }}>
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2h2m-2-4h.01M17 20h4a2 2 0 002-2v-6a2 2 0 00-2-2h-4" />
  </svg>
);

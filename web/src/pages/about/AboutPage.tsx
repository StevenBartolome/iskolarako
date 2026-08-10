import React from 'react';
import { Card } from '@/components/common/Card';

export const AboutPage: React.FC = () => {
  return (
    <div className="max-w-7xl mx-auto px-6 py-16 space-y-20 font-sans select-none">
      
      {/* Hero Section */}
      <section className="text-center max-w-3xl mx-auto space-y-6">
        <span className="inline-block px-4 py-1.5 rounded-full bg-[#EBF5EE] text-[#2D5941] text-xs font-semibold tracking-wide border border-[#2D5941]/20">
          Our Mission & Vision
        </span>
        <h1 className="text-4xl md:text-5xl font-extrabold text-[#1A3C2E] font-serif leading-tight">
          Bridging the Gap in Filipino Educational Opportunities
        </h1>
        <p className="text-lg text-[#6C6C70] leading-relaxed">
          IskolarAko is a unified web and mobile platform designed to streamline scholarship administration and access. By connecting students, scholarship providers, and administrators, we aim to ensure that no Filipino student is left behind due to financial constraints.
        </p>
      </section>

      {/* Core Values / Pillars */}
      <section className="space-y-8">
        <div className="text-center space-y-2">
          <h2 className="text-3xl font-bold text-[#1A3C2E] font-serif">Our Core Pillars</h2>
          <p className="text-sm text-[#6C6C70]">The foundational concepts driving our ecosystem forward</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          <Card className="p-8 space-y-4 hover:shadow-lg transition-all duration-300 border border-[#EDE8DE]">
            <div className="w-12 h-12 rounded-xl bg-[#2D5941]/10 flex items-center justify-center text-[#2D5941]">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </div>
            <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Absolute Transparency</h3>
            <p className="text-sm text-[#6C6C70] leading-relaxed">
              Every stipend release, application phase, and verification audit is logged with clarity. Providers and students can track payouts in real-time, eliminating administrative bottlenecks and uncertainty.
            </p>
          </Card>

          <Card className="p-8 space-y-4 hover:shadow-lg transition-all duration-300 border border-[#EDE8DE]">
            <div className="w-12 h-12 rounded-xl bg-[#C97B2E]/10 flex items-center justify-center text-[#C97B2E]">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
            </div>
            <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Unified Mobile First Access</h3>
            <p className="text-sm text-[#6C6C70] leading-relaxed">
              Through the companion IskoAko Flutter application, students can upload documents, check statuses, and receive instant push notifications directly on their smartphones, even with minimal connectivity.
            </p>
          </Card>

          <Card className="p-8 space-y-4 hover:shadow-lg transition-all duration-300 border border-[#EDE8DE]">
            <div className="w-12 h-12 rounded-xl bg-[#2D5941]/10 flex items-center justify-center text-[#2D5941]">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
            </div>
            <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Secure Verification</h3>
            <p className="text-sm text-[#6C6C70] leading-relaxed">
              Our automated and human-in-the-loop auditing checks prevent double-grants and confirm student enrollment records safely, building high trust for both government agencies and private partners.
            </p>
          </Card>
        </div>
      </section>

      {/* How it works */}
      <section className="bg-gradient-to-br from-[#2D5941] to-[#1A3C2E] rounded-[32px] p-8 md:p-12 text-white space-y-8 relative overflow-hidden shadow-xl">
        <div className="absolute inset-0 opacity-[0.05] pointer-events-none" style={{ backgroundImage: 'radial-gradient(#ffffff 1.5px, transparent 1.5px)', backgroundSize: '24px 24px' }}></div>
        
        <div className="max-w-2xl space-y-3">
          <h2 className="text-3xl font-bold font-serif">How the Ecosystem Works</h2>
          <p className="text-sm text-[#9BA89F]">Connecting the dots between scholarship institutions and academic success</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 relative z-10 pt-4">
          <div className="space-y-2">
            <span className="text-xs font-extrabold uppercase tracking-wider text-[#C97B2E]">Step 01</span>
            <h4 className="font-bold font-serif text-lg">Provider Onboarding</h4>
            <p className="text-xs text-[#9BA89F] leading-relaxed">Institutions configure eligibility criteria and deposit cycles on the web portal.</p>
          </div>
          <div className="space-y-2">
            <span className="text-xs font-extrabold uppercase tracking-wider text-[#C97B2E]">Step 02</span>
            <h4 className="font-bold font-serif text-lg">Student Application</h4>
            <p className="text-xs text-[#9BA89F] leading-relaxed">Scholars apply and upload academic credentials using the unified mobile app.</p>
          </div>
          <div className="space-y-2">
            <span className="text-xs font-extrabold uppercase tracking-wider text-[#C97B2E]">Step 03</span>
            <h4 className="font-bold font-serif text-lg">Smart Matching & Audit</h4>
            <p className="text-xs text-[#9BA89F] leading-relaxed">System automates matching while admin reviews verification audits to approve recipients.</p>
          </div>
          <div className="space-y-2">
            <span className="text-xs font-extrabold uppercase tracking-wider text-[#C97B2E]">Step 04</span>
            <h4 className="font-bold font-serif text-lg">Secure Disbursement</h4>
            <p className="text-xs text-[#9BA89F] leading-relaxed">Funds are tracked and disbursed with instant ledger verification updates on both platforms.</p>
          </div>
        </div>
      </section>

    </div>
  );
};

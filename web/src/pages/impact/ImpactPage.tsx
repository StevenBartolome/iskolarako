import React from 'react';
import { Card } from '@/components/common/Card';

export const ImpactPage: React.FC = () => {
  return (
    <div className="max-w-7xl mx-auto px-6 py-16 space-y-20 font-sans select-none">
      
      {/* Hero / Header */}
      <section className="text-center max-w-3xl mx-auto space-y-6">
        <span className="inline-block px-4 py-1.5 rounded-full bg-[#EDE8DE] text-[#C97B2E] text-xs font-semibold tracking-wide border border-[#C97B2E]/20">
          Our Live Performance & Reach
        </span>
        <h1 className="text-4xl md:text-5xl font-extrabold text-[#1A3C2E] font-serif leading-tight">
          Quantifying the Change in Scholarship Programs
        </h1>
        <p className="text-lg text-[#6C6C70] leading-relaxed">
          Through transparent metric reporting, we observe real-world trends in grants accessibility, disbursement speed, and student support. Take a look at the verified metrics recorded on our platform.
        </p>
      </section>

      {/* Numerical Stats Grid */}
      <section className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <Card className="text-center p-8 bg-gradient-to-br from-white to-[#F9F5EF] border border-[#EDE8DE]">
          <span className="text-xs font-bold text-[#8E8E93] uppercase tracking-wider block">Total Disbursed Funds</span>
          <h3 className="text-4xl font-extrabold text-[#2D5941] font-serif mt-2">₱2,548,200</h3>
          <p className="text-xs text-[#6C6C70] mt-2">Across 12 cycles</p>
        </Card>
        
        <Card className="text-center p-8 bg-gradient-to-br from-white to-[#F9F5EF] border border-[#EDE8DE]">
          <span className="text-xs font-bold text-[#8E8E93] uppercase tracking-wider block">Verified Active Scholars</span>
          <h3 className="text-4xl font-extrabold text-[#C97B2E] font-serif mt-2">1,248</h3>
          <p className="text-xs text-[#6C6C70] mt-2">Enrolled nationwide</p>
        </Card>

        <Card className="text-center p-8 bg-gradient-to-br from-white to-[#F9F5EF] border border-[#EDE8DE]">
          <span className="text-xs font-bold text-[#8E8E93] uppercase tracking-wider block">Disbursement Accuracy</span>
          <h3 className="text-4xl font-extrabold text-[#1A3C2E] font-serif mt-2">99.98%</h3>
          <p className="text-xs text-[#6C6C70] mt-2">Audited by System Admin</p>
        </Card>

        <Card className="text-center p-8 bg-gradient-to-br from-white to-[#F9F5EF] border border-[#EDE8DE]">
          <span className="text-xs font-bold text-[#8E8E93] uppercase tracking-wider block">Average Processing Speed</span>
          <h3 className="text-4xl font-extrabold text-[#2D5941] font-serif mt-2">1.8 Days</h3>
          <p className="text-xs text-[#6C6C70] mt-2">From submission to verify</p>
        </Card>
      </section>

      {/* Visual Distribution and Graph simulation */}
      <section className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <Card className="p-8 space-y-6 border border-[#EDE8DE]">
          <div>
            <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">Scholarship Category Share</h3>
            <p className="text-xs text-[#6C6C70]">Current distribution of fund releases by program type</p>
          </div>

          <div className="space-y-4">
            <div className="space-y-1">
              <div className="flex justify-between text-xs font-semibold">
                <span className="text-[#1C1C1E]">Government Grants (DOST, CHED)</span>
                <span className="text-[#2D5941]">65%</span>
              </div>
              <div className="w-full bg-[#EDE8DE] h-2 rounded-full overflow-hidden">
                <div className="bg-[#2D5941] h-full" style={{ width: '65%' }}></div>
              </div>
            </div>

            <div className="space-y-1">
              <div className="flex justify-between text-xs font-semibold">
                <span className="text-[#1C1C1E]">Private & Foundation Grants</span>
                <span className="text-[#C97B2E]">25%</span>
              </div>
              <div className="w-full bg-[#EDE8DE] h-2 rounded-full overflow-hidden">
                <div className="bg-[#C97B2E] h-full" style={{ width: '25%' }}></div>
              </div>
            </div>

            <div className="space-y-1">
              <div className="flex justify-between text-xs font-semibold">
                <span className="text-[#1C1C1E]">Community & NGO Support</span>
                <span className="text-[#1A3C2E]">10%</span>
              </div>
              <div className="w-full bg-[#EDE8DE] h-2 rounded-full overflow-hidden">
                <div className="bg-[#1A3C2E] h-full" style={{ width: '10%' }}></div>
              </div>
            </div>
          </div>
        </Card>

        {/* Scholar Impact Story */}
        <Card className="p-8 flex flex-col justify-between border border-[#EDE8DE] bg-[#EBF5EE]/30">
          <div className="space-y-4">
            <span className="text-[40px] text-[#2D5941] font-serif leading-none block">“</span>
            <p className="text-sm italic text-[#4A4A4F] leading-relaxed">
              Using the mobile app, I upload my grades every end of the semester and track when the next stipend will land. I no longer have to travel back and forth to the regional office just to submit photocopies or inquire about updates.
            </p>
          </div>
          <div className="flex items-center gap-3 pt-6 border-t border-[#D9D2C5]/40 mt-6">
            <div className="w-10 h-10 rounded-full bg-[#2D5941] text-white flex items-center justify-center font-bold text-sm">
              MB
            </div>
            <div>
              <h4 className="text-xs font-bold text-[#1C1C1E]">Mark Angelo B.</h4>
              <p className="text-[10px] text-[#6C6C70]">DOST-SEI Scholar, BS Computer Science</p>
            </div>
          </div>
        </Card>
      </section>

    </div>
  );
};

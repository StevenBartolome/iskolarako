import React from 'react';
import { Card } from '@/components/common/Card';
import { Button } from '@/components/common/Button';
import { Badge } from '@/components/common/Badge';
import { MOCK_SCHOLARSHIPS } from '@/services/api';
import { formatCurrency, formatDate } from '@/utils/formatters';

export const HomePage: React.FC = () => {
  return (
    <div className="space-y-16 py-10">
      {/* Hero Section */}
      <section className="text-center max-w-4xl mx-auto px-6 space-y-6">
        <span className="inline-block px-4 py-1.5 rounded-full bg-[#EBF5EE] text-[#2D5941] text-xs font-semibold tracking-wide border border-[#2D5941]/20">
          Philippine Scholar Empowerment Platform
        </span>
        <h1 className="text-4xl md:text-6xl font-extrabold text-[#1A3C2E] font-serif leading-tight">
          Transparent & Accessible <br />
          Scholarships for Filipino Youth
        </h1>
        <p className="text-lg text-[#6C6C70] leading-relaxed max-w-2xl mx-auto">
          Manage, apply, and track your educational grants seamlessly across both Web and Mobile platforms with real-time status updates.
        </p>
        <div className="flex flex-wrap justify-center gap-4 pt-2">
          <Button variant="primary">Explore Scholarships</Button>
          <Button variant="outline">Learn More</Button>
        </div>
      </section>

      {/* Stats Section */}
      <section id="stats" className="max-w-7xl mx-auto px-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <Card className="text-center bg-gradient-to-br from-white to-[#F9F5EF]">
            <h3 className="text-4xl font-bold text-[#1A3C2E] font-serif">₱2.5M+</h3>
            <p className="text-sm text-[#6C6C70] mt-1 font-medium">Disbursed Funds Tracked</p>
          </Card>
          <Card className="text-center bg-gradient-to-br from-white to-[#F9F5EF]">
            <h3 className="text-4xl font-bold text-[#C97B2E] font-serif">1,200+</h3>
            <p className="text-sm text-[#6C6C70] mt-1 font-medium">Verified Scholars</p>
          </Card>
          <Card className="text-center bg-gradient-to-br from-white to-[#F9F5EF]">
            <h3 className="text-4xl font-bold text-[#2D5941] font-serif">99.8%</h3>
            <p className="text-sm text-[#6C6C70] mt-1 font-medium">Verification Accuracy</p>
          </Card>
        </div>
      </section>

      {/* Available Grants Section */}
      <section id="scholarships" className="max-w-7xl mx-auto px-6 space-y-8">
        <div className="flex justify-between items-end">
          <div>
            <h2 className="text-3xl font-bold text-[#1A3C2E] font-serif">Available Grants & Programs</h2>
            <p className="text-sm text-[#6C6C70] mt-1">Browse active government and private partner scholarships</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {MOCK_SCHOLARSHIPS.map((scholarship) => (
            <Card key={scholarship.id} className="flex flex-col justify-between h-full">
              <div className="space-y-4">
                <div className="flex justify-between items-start gap-2">
                  <Badge status={scholarship.status} />
                  <span className="text-xs text-[#8E8E93] font-medium">{scholarship.category}</span>
                </div>
                <div>
                  <h3 className="text-xl font-bold text-[#1A3C2E] font-serif">{scholarship.title}</h3>
                  <p className="text-xs text-[#6C6C70] mt-1">{scholarship.provider}</p>
                </div>
                <p className="text-sm text-[#6C6C70] line-clamp-3 leading-relaxed">
                  {scholarship.description}
                </p>
              </div>

              <div className="mt-6 pt-4 border-t border-[#D9D2C5]/50 flex justify-between items-center">
                <div>
                  <span className="text-xs text-[#8E8E93] block">Grant Amount</span>
                  <span className="text-lg font-bold text-[#2D5941]">
                    {formatCurrency(scholarship.amount)}
                  </span>
                </div>
                <div className="text-right">
                  <span className="text-xs text-[#8E8E93] block">Deadline</span>
                  <span className="text-xs font-semibold text-[#1C1C1E]">
                    {formatDate(scholarship.deadline)}
                  </span>
                </div>
              </div>
            </Card>
          ))}
        </div>
      </section>
    </div>
  );
};

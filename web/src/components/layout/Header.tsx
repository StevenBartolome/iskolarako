import React from 'react';
import { APP_INFO } from '@/constants/theme';
import { Button } from '@/components/common/Button';

export const Header: React.FC = () => {
  return (
    <header className="sticky top-0 z-50 bg-[#F9F5EF]/90 backdrop-blur-md border-b border-[#D9D2C5]">
      <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[#1A3C2E] flex items-center justify-center text-white font-bold text-lg shadow-md font-serif">
            IA
          </div>
          <div>
            <h1 className="text-xl font-bold text-[#1A3C2E] tracking-tight font-serif">
              {APP_INFO.name}
            </h1>
            <p className="text-xs text-[#6C6C70] hidden sm:block">Web Portal</p>
          </div>
        </div>

        <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-[#1C1C1E]">
          <a href="#scholarships" className="hover:text-[#2D5941] transition-colors">
            Scholarships
          </a>
          <a href="#stats" className="hover:text-[#2D5941] transition-colors">
            Impact
          </a>
          <a href="#about" className="hover:text-[#2D5941] transition-colors">
            About
          </a>
        </nav>

        <div className="flex items-center gap-3">
          <Button variant="outline" className="py-2 px-4 text-xs">
            Sign In
          </Button>
          <Button variant="primary" className="py-2 px-4 text-xs">
            Apply Now
          </Button>
        </div>
      </div>
    </header>
  );
};

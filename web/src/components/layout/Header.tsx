import React from 'react';
import { APP_INFO } from '@/constants/theme';
import { Button } from '@/components/common/Button';
import LogoSvg from '@/assets/logo/iskolarakologo.svg';

interface HeaderProps {
  onSignInClick?: () => void;
  onHomeClick?: () => void;
  onAboutClick?: () => void;
  onImpactClick?: () => void;
  onScholarshipsClick?: () => void;
}

export const Header: React.FC<HeaderProps> = ({ 
  onSignInClick, 
  onHomeClick, 
  onAboutClick,
  onImpactClick,
  onScholarshipsClick
}) => {
  return (
    <header className="sticky top-0 z-50 bg-[#F9F5EF]/90 backdrop-blur-md border-b border-[#D9D2C5]">
      <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
        <div 
          className="flex items-center gap-3 cursor-pointer select-none"
          onClick={onHomeClick}
        >
          <img src={LogoSvg} alt="IskolarAko Logo" className="w-14 h-14 object-contain" />
          <div>
            <h1 className="text-xl font-bold text-[#1A3C2E] tracking-tight font-serif">
              {APP_INFO.name}
            </h1>
            <p className="text-xs text-[#6C6C70] hidden sm:block">Web Portal</p>
          </div>
        </div>

        <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-[#1C1C1E]">
          <button 
            type="button"
            onClick={onHomeClick} 
            className="hover:text-[#2D5941] transition-colors border-0 bg-transparent cursor-pointer font-medium text-sm text-[#1C1C1E] p-0"
          >
            Home
          </button>
          <button 
            type="button"
            onClick={onScholarshipsClick} 
            className="hover:text-[#2D5941] transition-colors border-0 bg-transparent cursor-pointer font-medium text-sm text-[#1C1C1E] p-0"
          >
            Scholarships
          </button>
          <button 
            type="button"
            onClick={onImpactClick} 
            className="hover:text-[#2D5941] transition-colors border-0 bg-transparent cursor-pointer font-medium text-sm text-[#1C1C1E] p-0"
          >
            Impact
          </button>
          <button 
            type="button"
            onClick={onAboutClick} 
            className="hover:text-[#2D5941] transition-colors border-0 bg-transparent cursor-pointer font-medium text-sm text-[#1C1C1E] p-0"
          >
            About
          </button>
        </nav>

        <div className="flex items-center gap-3">
          <Button variant="outline" className="py-2 px-4 text-xs cursor-pointer" onClick={onSignInClick}>
            Sign In
          </Button>
          <Button variant="primary" className="py-2 px-4 text-xs cursor-pointer">
            Apply Now
          </Button>
        </div>
      </div>
    </header>
  );
};

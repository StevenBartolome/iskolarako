import React from 'react';
import { APP_INFO } from '@/constants/theme';

export const Footer: React.FC = () => {
  return (
    <footer className="bg-[#1A3C2E] text-[#F4F0E8] py-12 border-t border-[#3D7A58]">
      <div className="max-w-7xl mx-auto px-6 grid grid-cols-1 md:grid-cols-3 gap-8">
        <div>
          <h2 className="text-2xl font-bold font-serif mb-2">{APP_INFO.name}</h2>
          <p className="text-sm text-[#9BA89F] leading-relaxed">
            {APP_INFO.tagline}
          </p>
        </div>
        <div>
          <h3 className="font-semibold mb-3 text-sm text-[#E8A838] uppercase tracking-wider">
            Quick Links
          </h3>
          <ul className="space-y-2 text-sm text-[#9BA89F]">
            <li><a href="#scholarships" className="hover:text-white transition-colors">Browse Grants</a></li>
            <li><a href="#about" className="hover:text-white transition-colors">Verification Process</a></li>
            <li><a href="#faq" className="hover:text-white transition-colors">Scholar Portal FAQ</a></li>
          </ul>
        </div>
        <div>
          <h3 className="font-semibold mb-3 text-sm text-[#E8A838] uppercase tracking-wider">
            Mobile & Web Ecosystem
          </h3>
          <p className="text-sm text-[#9BA89F]">
            Connected with the IskoAko Flutter Mobile App for seamless tracking on Android & iOS.
          </p>
        </div>
      </div>
      <div className="max-w-7xl mx-auto px-6 mt-12 pt-6 border-t border-[#3D7A58]/50 text-center text-xs text-[#9BA89F]">
        &copy; {new Date().getFullYear()} IskoAko. All rights reserved.
      </div>
    </footer>
  );
};

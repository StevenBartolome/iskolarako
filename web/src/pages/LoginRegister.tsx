import React, { useState } from 'react';
import { Button } from '@/components/common/Button';

interface LoginRegisterProps {
  onLogin: () => void;
  onBackToHome: () => void;
}

export const LoginRegister: React.FC<LoginRegisterProps> = ({ onLogin, onBackToHome }) => {
  const [activeTab, setActiveTab] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('admin@dost.gov.ph');
  const [password, setPassword] = useState('••••••••');
  const [fullName, setFullName] = useState('');
  const [providerType, setProviderType] = useState('public');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onLogin();
  };

  return (
    <div className="min-h-screen relative flex items-center justify-center bg-[#F9F5EF] overflow-hidden px-4 py-12">
      {/* Dynamic Background Gradients */}
      <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[60%] rounded-full bg-gradient-to-br from-[#2D5941]/10 to-transparent blur-3xl" />
      <div className="absolute bottom-[-20%] right-[-10%] w-[60%] h-[60%] rounded-full bg-gradient-to-tr from-[#C97B2E]/10 to-transparent blur-3xl" />

      {/* Floating back button */}
      <button
        onClick={onBackToHome}
        className="absolute top-6 left-6 flex items-center gap-2 text-sm font-medium text-[#2D5941] hover:text-[#1A3C2E] transition-colors cursor-pointer group animate-fade-in"
      >
        <svg
          className="w-4 h-4 transform group-hover:-translate-x-1 transition-transform"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to Home
      </button>

      {/* Main Glassmorphic Card */}
      <div className="w-full max-w-md bg-white/80 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/50 p-8 md:p-10 relative z-10">
        
        {/* Logo and Tagline */}
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-[#1A3C2E] text-white flex items-center justify-center font-serif text-2xl font-bold mx-auto mb-4 shadow-lg shadow-[#1A3C2E]/20">
            IA
          </div>
          <h2 className="text-2xl font-bold font-serif text-[#1A3C2E]">ISKOLARAKO</h2>
          <p className="text-xs text-[#6C6C70] mt-1 uppercase tracking-wider font-semibold">
            Admin & Provider Portal
          </p>
        </div>

        {/* Custom Tabs */}
        <div className="flex bg-[#EDE8DE]/50 p-1 rounded-xl mb-8">
          <button
            type="button"
            onClick={() => setActiveTab('login')}
            className={`flex-1 py-2.5 text-xs font-semibold rounded-lg transition-all duration-200 cursor-pointer ${
              activeTab === 'login'
                ? 'bg-white text-[#2D5941] shadow-sm'
                : 'text-[#6C6C70] hover:text-[#2D5941]'
            }`}
          >
            Sign In
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('register')}
            className={`flex-1 py-2.5 text-xs font-semibold rounded-lg transition-all duration-200 cursor-pointer ${
              activeTab === 'register'
                ? 'bg-white text-[#2D5941] shadow-sm'
                : 'text-[#6C6C70] hover:text-[#2D5941]'
            }`}
          >
            Register Provider
          </button>
        </div>

        {/* Forms */}
        <form onSubmit={handleSubmit} className="space-y-5">
          {activeTab === 'register' && (
            <>
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Full Name / Institution Name
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. DOST-SEI Admin"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl bg-white border border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Provider Type
                </label>
                <select
                  value={providerType}
                  onChange={(e) => setProviderType(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl bg-white border border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm"
                >
                  <option value="public">Public Provider (Government)</option>
                  <option value="private">Private Partner</option>
                  <option value="ngo">NGO / Foundation</option>
                </select>
              </div>
            </>
          )}

          <div>
            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
              Email Address
            </label>
            <input
              type="email"
              required
              placeholder="admin@dost.gov.ph"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 rounded-xl bg-white border border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm"
            />
          </div>

          <div>
            <div className="flex justify-between items-center mb-2">
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide">
                Password
              </label>
              {activeTab === 'login' && (
                <a href="#forgot" className="text-xs text-[#C97B2E] hover:underline font-medium">
                  Forgot Password?
                </a>
              )}
            </div>
            <input
              type="password"
              required
              placeholder="Enter password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 rounded-xl bg-white border border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm"
            />
          </div>

          {activeTab === 'register' && (
            <div className="flex items-start gap-2 pt-1">
              <input
                type="checkbox"
                required
                id="terms"
                className="mt-1 accent-[#2D5941] rounded"
              />
              <label htmlFor="terms" className="text-xs text-[#6C6C70] leading-relaxed">
                I agree to the Terms of Service and Privacy Policy for scholarship providers.
              </label>
            </div>
          )}

          <Button
            type="submit"
            variant={activeTab === 'login' ? 'primary' : 'secondary'}
            className="w-full py-3.5 mt-2 rounded-xl text-sm font-semibold tracking-wide shadow-md cursor-pointer"
          >
            {activeTab === 'login' ? 'Sign In as Admin' : 'Submit Registration'}
          </Button>
        </form>

        {/* Visual Tip */}
        <div className="mt-8 text-center pt-6 border-t border-[#D9D2C5]/50">
          <p className="text-xs text-[#6C6C70]">
            Demo Mode: Click <strong className="text-[#2D5941]">Sign In as Admin</strong> directly to access the dashboard.
          </p>
        </div>

      </div>
    </div>
  );
};

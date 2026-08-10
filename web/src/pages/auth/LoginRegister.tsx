import React, { useState } from 'react';
import { Button } from '@/components/common/Button';
import { supabase } from '@/services/supabaseClient';

interface LoginRegisterProps {
  onLogin: (role: 'provider' | 'admin') => void;
  onBackToHome: () => void;
}

export const LoginRegister: React.FC<LoginRegisterProps> = ({ onLogin, onBackToHome }) => {
  const [activeTab, setActiveTab] = useState<'login' | 'register'>('login');
  const [role, setRole] = useState<'provider' | 'admin'>('provider');
  const [email, setEmail] = useState('provider@dost.gov.ph');
  const [password, setPassword] = useState('••••••••');
  const [fullName, setFullName] = useState('');
  const [providerType, setProviderType] = useState('public');
  const [isTermsModalOpen, setIsTermsModalOpen] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<string | null>(null);

  const checkSupabaseConnection = async () => {
    setConnectionStatus('Testing connection...');
    try {
      const { error } = await supabase.from('test_connection').select('*').limit(1);
      if (error && error.message.includes('Failed to fetch')) {
        setConnectionStatus('Connection Failed: Network unreachable or CORS blocked.');
      } else {
        setConnectionStatus('Success: Connected to Supabase!');
      }
    } catch (err: any) {
      setConnectionStatus(`Connection Failed: ${err.message}`);
    }
  };

  const handleRoleChange = (selectedRole: 'provider' | 'admin') => {
    setRole(selectedRole);
    if (selectedRole === 'admin') {
      setEmail('admin@iskoako.gov.ph');
    } else {
      setEmail('provider@dost.gov.ph');
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onLogin(role);
  };

  return (
    <div className="min-h-screen relative flex items-center justify-center bg-[#F9F5EF] overflow-hidden px-4 py-12">
      {/* Dynamic Background Gradients */}
      <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[60%] rounded-full bg-gradient-to-br from-[#2D5941]/10 to-transparent blur-3xl" />
      <div className="absolute bottom-[-20%] right-[-10%] w-[60%] h-[60%] rounded-full bg-gradient-to-tr from-[#C97B2E]/10 to-transparent blur-3xl" />

      {/* Floating back button */}
      <button
        onClick={onBackToHome}
        className="absolute top-6 left-6 flex items-center gap-2 text-sm font-medium text-[#2D5941] hover:text-[#1A3C2E] transition-colors cursor-pointer group animate-fade-in border-0 bg-transparent"
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
      <div className="w-full max-w-md bg-white/80 backdrop-blur-xl rounded-3xl shadow-2xl border border-solid border-white/50 p-8 md:p-10 relative z-10">
        
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
        <div className="flex bg-[#EDE8DE]/50 p-1 rounded-xl mb-8 border border-solid border-[#D9D2C5]/30">
          <button
            type="button"
            onClick={() => setActiveTab('login')}
            className={`flex-1 py-2.5 text-xs font-semibold rounded-lg transition-all duration-200 cursor-pointer border-0 ${
              activeTab === 'login'
                ? 'bg-[#2D5941] text-white shadow-sm'
                : 'text-[#6C6C70] hover:text-[#2D5941]'
            }`}
          >
            Sign In
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('register')}
            className={`flex-1 py-2.5 text-xs font-semibold rounded-lg transition-all duration-200 cursor-pointer border-0 ${
              activeTab === 'register'
                ? 'bg-[#2D5941] text-white shadow-sm'
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
                  className="w-full px-4 py-3 rounded-xl bg-white border border-solid border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Provider Type
                </label>
                <select
                  value={providerType}
                  onChange={(e) => setProviderType(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl bg-white border border-solid border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm cursor-pointer"
                >
                  <option value="public">Public Provider (Government)</option>
                  <option value="private">Private Partner</option>
                  <option value="ngo">NGO / Foundation</option>
                </select>
              </div>
            </>
          )}

          {activeTab === 'login' && (
            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                Sign In As
              </label>
              <div className="flex bg-[#EDE8DE]/55 p-1 rounded-xl mb-4 border border-solid border-[#D9D2C5]/30">
                <button
                  type="button"
                  onClick={() => handleRoleChange('provider')}
                  className={`flex-1 py-2 text-xs font-semibold rounded-lg transition-all cursor-pointer border-0 ${
                    role === 'provider'
                      ? 'bg-[#2D5941] text-white shadow-sm'
                      : 'text-[#6C6C70] hover:text-[#2D5941] bg-transparent'
                  }`}
                >
                  Scholarship Provider
                </button>
                <button
                  type="button"
                  onClick={() => handleRoleChange('admin')}
                  className={`flex-1 py-2 text-xs font-semibold rounded-lg transition-all cursor-pointer border-0 ${
                    role === 'admin'
                      ? 'bg-[#2D5941] text-white shadow-sm'
                      : 'text-[#6C6C70] hover:text-[#2D5941] bg-transparent'
                  }`}
                >
                  System Admin
                </button>
              </div>
            </div>
          )}

          <div>
            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
              Email Address
            </label>
            <input
              type="email"
              required
              placeholder="provider@dost.gov.ph"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 rounded-xl bg-white border border-solid border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm"
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
              className="w-full px-4 py-3 rounded-xl bg-white border border-solid border-[#D9D2C5] focus:outline-none focus:ring-2 focus:ring-[#2D5941]/20 focus:border-[#2D5941] transition-all text-sm"
            />
          </div>

          {activeTab === 'register' && (
            <div className="flex items-start gap-2 pt-1">
              <input
                type="checkbox"
                required
                id="terms"
                className="mt-1 accent-[#2D5941] rounded cursor-pointer"
              />
              <label htmlFor="terms" className="text-xs text-[#6C6C70] leading-relaxed">
                I agree to the{' '}
                <button
                  type="button"
                  onClick={() => setIsTermsModalOpen(true)}
                  className="text-[#2D5941] hover:text-[#1A3C2E] font-semibold hover:underline cursor-pointer bg-transparent border-0 p-0 inline-block align-baseline"
                >
                  Terms and Conditions
                </button>{' '}
                and Privacy Policy for scholarship providers.
              </label>
            </div>
          )}

          <Button
            type="submit"
            variant={activeTab === 'login' ? 'primary' : 'secondary'}
            className="w-full py-3.5 mt-2 rounded-xl text-sm font-semibold tracking-wide shadow-md cursor-pointer border-0"
          >
            {activeTab === 'login' 
              ? (role === 'admin' ? 'Sign In as System Admin' : 'Sign In as Provider') 
              : 'Submit Registration'}
          </Button>
        </form>

        {/* Visual Tip */}
        <div className="mt-8 text-center pt-6 border-t border-solid border-[#D9D2C5]/50">
          <p className="text-xs text-[#6C6C70]">
            Demo Mode: Click the Sign In button directly to access the selected portal.
          </p>
        </div>

        {/* Connection Tester */}
        <div className="mt-4 pt-4 border-t border-dashed border-[#D9D2C5]/50 text-center">
          <button
            type="button"
            onClick={checkSupabaseConnection}
            className="px-3 py-1.5 bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#2D5941] text-[10px] font-bold rounded-lg border border-solid border-[#D9D2C5]/30 cursor-pointer transition-all uppercase tracking-wider bg-transparent"
          >
            🔌 Test Supabase Connection
          </button>
          {connectionStatus && (
            <p className={`text-[10px] mt-2 font-semibold ${connectionStatus.includes('Success') ? 'text-[#2D5941]' : 'text-[#B34040]'}`}>
              {connectionStatus}
            </p>
          )}
        </div>

        {/* Terms and Conditions Modal */}
        {isTermsModalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
            <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-8 max-w-lg w-full space-y-4 relative animate-fade-in text-left">
              <button 
                type="button"
                onClick={() => setIsTermsModalOpen(false)} 
                className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer bg-transparent border-0"
              >
                ✕
              </button>
              <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">Terms & Conditions</h3>
              <div className="max-h-72 overflow-y-auto pr-2 text-xs text-[#6C6C70] space-y-3 leading-relaxed">
                <p>Welcome to <strong>IskolarAko</strong>. By registering as a Scholarship Provider, you agree to comply with the following Terms and Conditions:</p>
                <h4 className="font-bold text-[#1C1C1E]">1. Provider Verification</h4>
                <p>All providers must submit valid organizational credentials. Access to cycle management and scholar matching is subject to verification approval by the System Admin layer.</p>
                <h4 className="font-bold text-[#1C1C1E]">2. Data Privacy & Student Records</h4>
                <p>You agree to handle all student data (including transcript documents, GWA grades, and contact details) with strict confidentiality and in compliance with the Data Privacy Act of 2012.</p>
                <h4 className="font-bold text-[#1C1C1E]">3. Fund Disbursements</h4>
                <p>Providers are responsible for ensuring that payouts, stipends, and grants are disbursed to matched scholars in a timely manner. System Admin monitoring of fund releases is strictly for compliance auditing.</p>
                <h4 className="font-bold text-[#1C1C1E]">4. Account Responsibility</h4>
                <p>You are solely responsible for maintaining the confidentiality of your login credentials and for all actions carried out under your organization portal.</p>
              </div>
              <div className="flex justify-end pt-2">
                <button 
                  type="button" 
                  onClick={() => setIsTermsModalOpen(false)}
                  className="px-6 py-2 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold cursor-pointer border-0"
                >
                  I Understand
                </button>
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
};

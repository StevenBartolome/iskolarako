import React, { useState } from 'react';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import LogoNoTextSvg from '@/assets/logo/iskolarakologo-notext.svg';
import { supabase } from '@/services/supabaseClient';
import emailjs from '@emailjs/browser';

interface LoginRegisterProps {
  onLogin: (role: 'provider' | 'admin') => void;
  onBackToHome: () => void;
  onNavigate?: (view: 'home' | 'about' | 'impact' | 'scholarships') => void;
}

export const LoginRegister: React.FC<LoginRegisterProps> = ({ onLogin, onBackToHome, onNavigate }) => {
  const [activeTab, setActiveTab] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  
  // Registration fields corresponding to Supabase tables
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [suffix, setSuffix] = useState('');
  const [providerName, setProviderName] = useState('');
  const [providerType, setProviderType] = useState('public');
  
  const [isTermsModalOpen, setIsTermsModalOpen] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Email Verification States
  const [showVerificationModal, setShowVerificationModal] = useState(false);
  const [verificationCode, setVerificationCode] = useState('');
  const [codeDigits, setCodeDigits] = useState<string[]>(Array(6).fill(''));
  const [errorMessage, setErrorMessage] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Toast message state
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' } | null>(null);

  const showToastMessage = (msg: string, type: 'success' | 'error' = 'error') => {
    setToast({ message: msg, type });
    setTimeout(() => {
      setToast(null);
    }, 4000);
  };





  // Generate and send verification code via EmailJS
  const sendVerificationEmail = async () => {
    setIsSubmitting(true);
    setErrorMessage('');
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    setVerificationCode(code);
    setCodeDigits(Array(6).fill(''));

    const serviceId = import.meta.env.VITE_EMAILJS_SERVICE_ID;
    const templateId = import.meta.env.VITE_EMAILJS_TEMPLATE_ID;
    const publicKey = import.meta.env.VITE_EMAILJS_PUBLIC_KEY;

    if (!serviceId || !templateId || !publicKey) {
      console.warn("EmailJS credentials are not configured in .env. Simulating email send. Code:", code);
      // For development fallback if not configured yet
      setIsSubmitting(false);
      setShowVerificationModal(true);
      return;
    }

    try {
      await emailjs.send(
        serviceId,
        templateId,
        {
          to_name: firstName || 'User',
          to_email: email,
          verification_code: code,
        },
        publicKey
      );
      setIsSubmitting(false);
      setShowVerificationModal(true);
    } catch (err: any) {
      console.error("EmailJS Error:", err);
      setErrorMessage(err?.text || 'Failed to send verification email. Please check your network or credentials.');
      setIsSubmitting(false);
    }
  };

  const handleVerifyCode = async () => {
    const enteredCode = codeDigits.join('');
    if (enteredCode.length < 6) {
      setErrorMessage('Please enter all 6 digits.');
      return;
    }

    if (enteredCode !== verificationCode && verificationCode !== '') {
      setErrorMessage('Incorrect verification code. Please try again.');
      return;
    }

    setIsSubmitting(true);
    setErrorMessage('');

    try {
      // Sign up user in Supabase Auth passing registration metadata
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            first_name: firstName,
            last_name: lastName,
            suffix: suffix || null,
            role: 'provider',
            provider_name: providerName,
            provider_type: providerType,
          }
        }
      });

      if (authError) throw authError;
      if (!authData.user) throw new Error('User sign up failed.');

      setIsSubmitting(false);
      setShowVerificationModal(false);
      onLogin('provider');
    } catch (err: any) {
      console.error("Supabase Error:", err);
      setErrorMessage(err?.message || 'Failed to complete registration.');
      setIsSubmitting(false);
    }
  };

  const handleLogin = async () => {
    setIsSubmitting(true);
    setErrorMessage('');

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error || !data.user) {
        showToastMessage('the email/password is incorrect');
        setIsSubmitting(false);
        return;
      }

      // Fetch profile details to confirm role, name, and existence
      const { data: userData, error: userErr } = await supabase
        .from('users')
        .select('first_name, role')
        .eq('id', data.user.id)
        .single();

      if (userErr || !userData) {
        showToastMessage('the email/password is incorrect');
        await supabase.auth.signOut();
        setIsSubmitting(false);
        return;
      }

      // Check if user role matches valid entry roles
      const isProviderRole = userData.role === 'provider' || userData.role === 'provider-member';
      const isAdminRole = userData.role === 'admin';

      if (!isProviderRole && !isAdminRole) {
        showToastMessage('the email/password is incorrect');
        await supabase.auth.signOut();
        setIsSubmitting(false);
        return;
      }

      const targetRole = isAdminRole ? 'admin' : 'provider';

      setIsSubmitting(false);
      onLogin(targetRole);
    } catch (err) {
      showToastMessage('the email/password is incorrect');
      setIsSubmitting(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (activeTab === 'register') {
      sendVerificationEmail();
    } else {
      handleLogin();
    }
  };



  const handleDigitChange = (index: number, value: string) => {
    if (!/^\d*$/.test(value)) return;
    const newDigits = [...codeDigits];
    newDigits[index] = value.slice(-1);
    setCodeDigits(newDigits);

    if (value && index < 5) {
      const nextInput = document.getElementById(`digit-${index + 1}`);
      nextInput?.focus();
    }
  };

  const handleDigitKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace') {
      if (!codeDigits[index] && index > 0) {
        const prevInput = document.getElementById(`digit-${index - 1}`);
        prevInput?.focus();
      }
    }
  };



  return (
    <div className="min-h-screen flex flex-col bg-[#F9F5EF]">
      {/* Header component */}
      <Header
        onSignInClick={() => setActiveTab('login')}
        onHomeClick={onBackToHome}
        onAboutClick={() => onNavigate?.('about')}
        onImpactClick={() => onNavigate?.('impact')}
        onScholarshipsClick={() => onNavigate?.('scholarships')}
      />

      {/* Main Content Area */}
      <div className="flex-1 w-full flex items-center justify-center p-8 md:p-12 relative overflow-hidden">
        {/* Background design */}
        <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[60%] rounded-full bg-gradient-to-br from-[#2D5941]/10 to-transparent blur-3xl pointer-events-none" />
        <div className="absolute bottom-[-20%] right-[-10%] w-[60%] h-[60%] rounded-full bg-gradient-to-tr from-[#C97B2E]/10 to-transparent blur-3xl pointer-events-none" />
        <div className="absolute inset-0 opacity-[0.15] pointer-events-none" style={{ backgroundImage: 'radial-gradient(#2D5941 1.5px, transparent 1.5px)', backgroundSize: '24px 24px' }}></div>

        {/* Custom Styles for active tab notches and animations */}
        <style>{`
          .tab-slider {
            position: absolute;
            right: 0;
            width: 85%;
            height: 56px;
            background-color: #ffffff;
            border-radius: 30px 0 0 30px;
            transition: all 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
            z-index: 5;
          }
          /* Top notch - smooth curve */
          .tab-slider::before {
            content: '';
            position: absolute;
            right: 0;
            top: -30px;
            width: 30px;
            height: 30px;
            background-color: transparent;
            border-bottom-right-radius: 30px;
            box-shadow: 15px 15px 0 15px #ffffff;
            pointer-events: none;
          }
          /* Bottom notch - smooth curve */
          .tab-slider::after {
            content: '';
            position: absolute;
            right: 0;
            bottom: -30px;
            width: 30px;
            height: 30px;
            background-color: transparent;
            border-top-right-radius: 30px;
            box-shadow: 15px -15px 0 15px #ffffff;
            pointer-events: none;
          }
        `}</style>

        {/* Login Card Container */}
        <div className="w-full max-w-4xl bg-white rounded-[32px] shadow-[0_20px_60px_rgba(45,89,65,0.08)] flex overflow-hidden h-[600px] z-10 border border-solid border-[#EDE8DE]">

          {/* Left Side: Dark Green Gradient with Layered Shapes */}
          <div className="w-[35%] bg-gradient-to-br from-[#2D5941] via-[#224A34] to-[#1A3C2E] relative overflow-hidden flex flex-col justify-center items-end py-12 pr-0 select-none">
            {/* Layered Geometric Shapes */}
            <div className="absolute inset-0 pointer-events-none z-0">
              <div className="absolute -left-10 top-[-20%] w-[200px] h-[350px] bg-white/5 rounded-[40px] transform rotate-[35deg] shadow-lg"></div>
              <div className="absolute -left-16 top-[15%] w-[220px] h-[380px] bg-white/10 rounded-[45px] transform rotate-[35deg] shadow-2xl"></div>
              <div className="absolute -left-20 top-[50%] w-[240px] h-[400px] bg-white/5 rounded-[50px] transform rotate-[35deg] shadow-xl"></div>
            </div>

            {/* Navigation Tabs */}
            <div className="w-full flex flex-col items-end gap-3 relative z-10 pl-6">
              {/* Sliding backdrop */}
              <div
                className="tab-slider"
                style={{ top: activeTab === 'login' ? '0px' : '68px' }}
              />

              <button
                type="button"
                onClick={() => setActiveTab('login')}
                className={`w-[85%] py-4 pl-8 pr-4 text-left text-sm font-bold tracking-wider uppercase transition-colors duration-300 border-0 cursor-pointer relative z-10 ${activeTab === 'login' ? 'text-[#2D5941]' : 'text-white opacity-80 hover:opacity-100'
                  }`}
              >
                Login
              </button>
              <button
                type="button"
                onClick={() => setActiveTab('register')}
                className={`w-[85%] py-4 pl-8 pr-4 text-left text-sm font-bold tracking-wider uppercase transition-colors duration-300 border-0 cursor-pointer relative z-10 ${activeTab === 'register' ? 'text-[#2D5941]' : 'text-white opacity-80 hover:opacity-100'
                  }`}
              >
                Sign In
              </button>
            </div>
          </div>

          {/* Right Side: White Panel with Forms */}
          <div className="w-[65%] bg-white p-8 md:p-12 flex flex-col justify-between">
            <div className="w-full max-w-md mx-auto">
              {/* Custom Logo (New SVG Logo) - Dynamic size to maintain height */}
              <div className="flex flex-col items-center mb-4">
                <img 
                  src={LogoNoTextSvg} 
                  alt="IskolarAko Logo" 
                  className={`object-contain transition-all duration-300 drop-shadow-sm ${activeTab === 'login' ? 'w-32 h-32 md:w-36 md:h-36' : 'w-16 h-16'}`} 
                />
                <h2 className="text-xl font-bold tracking-widest text-[#2D5941] mt-2 uppercase font-serif">
                  {activeTab === 'login' ? 'LOGIN' : 'SIGN UP'}
                </h2>
              </div>
              {/* Input Forms */}
              <form onSubmit={handleSubmit} className="space-y-4">
                {activeTab === 'register' ? (
                  <div className="grid grid-cols-2 gap-x-4 gap-y-3">
                    {/* First Name */}
                    <div className="flex items-center border-b border-solid border-[#EDE8DE] py-1.5 focus-within:border-[#2D5941] transition-all">
                      <span className="text-[#8e8e93] mr-2">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                      </span>
                      <input
                        type="text"
                        required
                        placeholder="First Name"
                        value={firstName}
                        onChange={(e) => setFirstName(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-xs text-[#495057] placeholder-[#adb5bd] py-0.5"
                      />
                    </div>

                    {/* Last Name */}
                    <div className="flex items-center border-b border-solid border-[#EDE8DE] py-1.5 focus-within:border-[#2D5941] transition-all">
                      <span className="text-[#8e8e93] mr-2">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                      </span>
                      <input
                        type="text"
                        required
                        placeholder="Last Name"
                        value={lastName}
                        onChange={(e) => setLastName(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-xs text-[#495057] placeholder-[#adb5bd] py-0.5"
                      />
                    </div>

                    {/* Suffix (Optional) */}
                    <div className="flex items-center border-b border-solid border-[#EDE8DE] py-1.5 focus-within:border-[#2D5941] transition-all">
                      <span className="text-[#8e8e93] mr-2">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V5a2 2 0 114 0v1m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm0 0c1.37 0 2.49.83 2.87 2H7.13c.38-1.17 1.5-2 2.87-2z" />
                        </svg>
                      </span>
                      <input
                        type="text"
                        placeholder="Suffix (e.g. Jr, III)"
                        value={suffix}
                        onChange={(e) => setSuffix(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-xs text-[#495057] placeholder-[#adb5bd] py-0.5"
                      />
                    </div>

                    {/* Provider Type */}
                    <div className="flex items-center border-b border-solid border-[#EDE8DE] py-1.5 focus-within:border-[#2D5941] transition-all">
                      <span className="text-[#8e8e93] mr-2">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                        </svg>
                      </span>
                      <select
                        value={providerType}
                        onChange={(e) => setProviderType(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-xs text-[#495057] py-0.5 cursor-pointer"
                      >
                        <option value="public">Government</option>
                        <option value="private">Private Partner</option>
                        <option value="ngo">NGO / Foundation</option>
                      </select>
                    </div>

                    {/* Provider Name */}
                    <div className="col-span-2 flex items-center border-b border-solid border-[#EDE8DE] py-1.5 focus-within:border-[#2D5941] transition-all">
                      <span className="text-[#8e8e93] mr-2">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                        </svg>
                      </span>
                      <input
                        type="text"
                        required
                        placeholder="Provider Name (e.g. DOST, CHED, Foundation)"
                        value={providerName}
                        onChange={(e) => setProviderName(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-xs text-[#495057] placeholder-[#adb5bd] py-0.5"
                      />
                    </div>


                    {/* Email Input */}
                    <div className="col-span-2 flex items-center border-b border-solid border-[#EDE8DE] py-1.5 focus-within:border-[#2D5941] transition-all">
                      <span className="text-[#8e8e93] mr-2">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                        </svg>
                      </span>
                      <input
                        type="email"
                        required
                        placeholder="Email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-xs text-[#495057] placeholder-[#adb5bd] py-0.5"
                      />
                    </div>

                    {/* Password Input */}
                    <div className="col-span-2 flex items-center border-b border-solid border-[#EDE8DE] py-1.5 focus-within:border-[#2D5941] transition-all relative">
                      <span className="text-[#8e8e93] mr-2">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                        </svg>
                      </span>
                      <input
                        type={showPassword ? "text" : "password"}
                        required
                        placeholder="Password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-xs text-[#495057] placeholder-[#adb5bd] py-0.5 pr-8"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-0 text-[#8e8e93] hover:text-[#2D5941] transition-colors border-0 bg-transparent cursor-pointer p-0.5 flex items-center justify-center"
                      >
                        {showPassword ? (
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18" />
                          </svg>
                        ) : (
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                          </svg>
                        )}
                      </button>
                    </div>
                  </div>
                ) : (
                  <>
                    {/* Email Input */}
                    <div className="flex items-center border-b border-solid border-[#EDE8DE] py-2 focus-within:border-[#2D5941] transition-all">
                      <span className="text-[#8e8e93] mr-3">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                      </span>
                      <input
                        type="email"
                        required
                        placeholder="Email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-sm text-[#495057] placeholder-[#adb5bd] py-1"
                      />
                    </div>

                    {/* Password Input */}
                    <div className="flex items-center border-b border-solid border-[#EDE8DE] py-2 focus-within:border-[#2D5941] transition-all relative">
                      <span className="text-[#8e8e93] mr-3">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                        </svg>
                      </span>
                      <input
                        type={showPassword ? "text" : "password"}
                        required
                        placeholder="Password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        className="w-full bg-transparent border-0 outline-none text-sm text-[#495057] placeholder-[#adb5bd] py-1 pr-10"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-0 text-[#8e8e93] hover:text-[#2D5941] transition-colors border-0 bg-transparent cursor-pointer p-1 flex items-center justify-center"
                      >
                        {showPassword ? (
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18" />
                          </svg>
                        ) : (
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.8} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                          </svg>
                        )}
                      </button>
                    </div>
                  </>
                )}

                {/* Terms Checkbox for Register */}
                {activeTab === 'register' && (
                  <div className="flex items-start gap-2 pt-0.5">
                    <input
                      type="checkbox"
                      required
                      id="terms"
                      className="mt-0.5 accent-[#2D5941] rounded cursor-pointer"
                    />
                    <label htmlFor="terms" className="text-[10px] text-[#8e8e93] leading-relaxed">
                      I agree to the{' '}
                      <button
                        type="button"
                        onClick={() => setIsTermsModalOpen(true)}
                        className="text-[#2D5941] hover:text-[#1A3C2E] font-semibold hover:underline cursor-pointer bg-transparent border-0 p-0 inline-block align-baseline"
                      >
                        Terms and Conditions
                      </button>
                    </label>
                  </div>
                )}

                {/* Buttons and Forgot Password */}
                <div className="flex items-center justify-between pt-2">
                  <div>
                    {activeTab === 'login' && (
                      <a href="#forgot" className="text-xs text-[#C97B2E] hover:underline font-medium">
                        Forgot Password?
                      </a>
                    )}
                  </div>
                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className="px-8 py-2.5 rounded-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold uppercase tracking-wider transition-all duration-300 shadow-md hover:shadow-lg hover:scale-105 active:scale-95 disabled:opacity-50 cursor-pointer border-0"
                  >
                    {isSubmitting ? 'Processing...' : (activeTab === 'login' ? 'Login' : 'Submit')}
                  </button>
                </div>
              </form>
            </div>

            {/* Social / Alternative Login Footer */}
            <div className="w-full border-t border-solid border-[#EDE8DE] pt-4 flex items-center justify-center gap-6 mt-4">
              <span className="text-xs text-[#8e8e93] font-semibold">Or Login with</span>
              <button
                type="button"
                className="flex items-center gap-2.5 px-4 py-1.5 border border-solid border-[#EDE8DE] rounded-xl hover:bg-[#F9F5EF] transition-all hover:scale-105 active:scale-95 cursor-pointer bg-white"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
                  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l3.66-2.85z" fill="#FBBC05" />
                  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.85c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
                </svg>
                <span className="text-xs font-bold text-[#495057]">Google</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Email Verification Modal */}
      {showVerificationModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
          <div className="bg-white rounded-[32px] border border-[#EDE8DE] shadow-2xl p-8 max-w-md w-full space-y-6 relative text-center">
            <h3 className="text-2xl font-bold font-serif text-[#2D5941]">Verify Your Email</h3>
            <p className="text-xs text-[#8e8e93] leading-relaxed">
              We sent a 6-digit verification code to <br/>
              <span className="font-semibold text-[#495057]">{email}</span>.
            </p>
            
            {errorMessage && (
              <p className="text-xs text-red-500 font-semibold bg-red-50 p-2 rounded-lg border border-red-200">
                {errorMessage}
              </p>
            )}

            {/* 6 Digit Inputs */}
            <div className="flex justify-center gap-2">
              {codeDigits.map((digit, idx) => (
                <input
                  key={idx}
                  id={`digit-${idx}`}
                  type="text"
                  maxLength={1}
                  value={digit}
                  onChange={(e) => handleDigitChange(idx, e.target.value)}
                  onKeyDown={(e) => handleDigitKeyDown(idx, e)}
                  className="w-10 h-12 text-center text-lg font-bold border border-solid border-[#EDE8DE] rounded-xl focus:border-[#2D5941] focus:ring-1 focus:ring-[#2D5941] outline-none bg-[#F9F5EF] text-[#495057]"
                />
              ))}
            </div>

            <div className="flex flex-col gap-3 pt-2">
              <button
                type="button"
                disabled={isSubmitting}
                onClick={handleVerifyCode}
                className="w-full py-3 rounded-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold uppercase tracking-wider transition-all duration-300 shadow-md hover:shadow-lg disabled:opacity-50 cursor-pointer border-0"
              >
                {isSubmitting ? 'Verifying...' : 'Verify & Register'}
              </button>
              <button
                type="button"
                onClick={() => setShowVerificationModal(false)}
                className="text-xs text-[#8e8e93] hover:text-[#2D5941] hover:underline cursor-pointer bg-transparent border-0"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Terms and Conditions Modal */}
      {isTermsModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
          <div className="bg-white rounded-3xl border border-[#EDE8DE] shadow-2xl p-8 max-w-lg w-full space-y-4 relative text-left">
            <button
              type="button"
              onClick={() => setIsTermsModalOpen(false)}
              className="absolute top-6 right-6 text-[#8e8e93] hover:text-[#2D5941] font-bold text-lg cursor-pointer bg-transparent border-0"
            >
              ✕
            </button>
            <h3 className="text-2xl font-bold font-serif text-[#2D5941]">Terms & Conditions</h3>
            <div className="max-h-72 overflow-y-auto pr-2 text-xs text-[#6c757d] space-y-3 leading-relaxed">
              <p>Welcome to <strong>IskolarAko</strong>. By registering as a Scholarship Provider, you agree to comply with the following Terms and Conditions:</p>
              <h4 className="font-bold text-[#1c1c1e]">1. Provider Verification</h4>
              <p>All providers must submit valid organizational credentials. Access to cycle management and scholar matching is subject to verification approval by the System Admin layer.</p>
              <h4 className="font-bold text-[#1c1c1e]">2. Data Privacy & Student Records</h4>
              <p>You agree to handle all student data (including transcript documents, GWA grades, and contact details) with strict confidentiality and in compliance with the Data Privacy Act of 2012.</p>
              <h4 className="font-bold text-[#1c1c1e]">3. Fund Disbursements</h4>
              <p>Providers are responsible for ensuring that payouts, stipends, and grants are disbursed to matched scholars in a timely manner. System Admin monitoring of fund releases is strictly for compliance auditing.</p>
              <h4 className="font-bold text-[#1c1c1e]">4. Account Responsibility</h4>
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

      {/* Toast Notification */}
      {toast && (
        <div className={`fixed bottom-6 right-6 z-50 animate-bounce text-white px-6 py-3 rounded-xl shadow-lg border text-xs font-semibold flex items-center gap-2 transition-all duration-300 ${
          toast.type === 'success' 
            ? 'bg-[#2D5941] border-[#1A3C2E]' 
            : 'bg-[#B34040] border-[#8E2F2F]'
        }`}>
          {toast.type === 'success' ? (
            <svg className="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          ) : (
            <svg className="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          )}
          {toast.message}
        </div>
      )}


      {/* Footer component */}
      <Footer />
    </div>
  );
};



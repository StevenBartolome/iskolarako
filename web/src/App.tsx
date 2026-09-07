import { useState, useEffect } from 'react';
import { Routes, Route, useNavigate, useLocation, Navigate } from 'react-router-dom';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { HomePage } from '@/pages/home/HomePage';
import { LoginRegister } from '@/pages/auth/LoginRegister';
import { ProviderPortal } from '@/pages/provider/ProviderPortal';
import { SystemAdminPortal } from '@/pages/admin/SystemAdminPortal';
import { AboutPage } from '@/pages/about/AboutPage';
import { ImpactPage } from '@/pages/impact/ImpactPage';
import { supabase } from '@/services/supabaseClient';

function App() {
  const navigate = useNavigate();
  const location = useLocation();
  const [isCheckingSession, setIsCheckingSession] = useState(true);
  const [showWelcome, setShowWelcome] = useState(false);

  // On mount: restore session so refresh keeps the user in their portal
  useEffect(() => {
    const restoreSession = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
          const { data: userData } = await supabase
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single();

          if (userData?.role === 'admin') {
            if (!location.pathname.startsWith('/admin')) {
              navigate('/admin/dashboard', { replace: true });
            }
          } else if (userData?.role === 'provider' || userData?.role === 'provider-member') {
            if (!location.pathname.startsWith('/provider')) {
              navigate('/provider/dashboard', { replace: true });
            }
          }
        }
      } catch (err) {
        console.error('Session restore error:', err);
      } finally {
        setIsCheckingSession(false);
      }
    };

    restoreSession();
  }, []);

  // Clear any stale URL hash (e.g. #stats) on every view change
  useEffect(() => {
    if (window.location.hash) {
      history.replaceState(null, '', window.location.pathname + window.location.search);
    }
  }, [location.pathname]);

  // Show a spinner while checking session to avoid flash of home page
  if (isCheckingSession) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#F9F5EF]">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 rounded-full border-4 border-[#2D5941] border-t-transparent animate-spin" />
          <span className="text-sm text-[#6C6C70] font-medium">Loading...</span>
        </div>
      </div>
    );
  }

  const handleScholarshipsClick = () => {
    navigate('/');
    setTimeout(() => {
      const el = document.getElementById('scholarships');
      if (el) el.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  };

  const handleLogout = async () => {
    try {
      await supabase.auth.signOut();
    } catch (err) {
      console.error('Error signing out:', err);
    }
    setShowWelcome(false);
    navigate('/', { replace: true });
  };

  return (
    <Routes>
      {/* Admin Portal */}
      <Route
        path="/admin/*"
        element={<SystemAdminPortal onLogout={handleLogout} showWelcome={showWelcome} />}
      />

      {/* Provider Portal */}
      <Route
        path="/provider/*"
        element={<ProviderPortal onLogout={handleLogout} showWelcome={showWelcome} />}
      />

      {/* Auth */}
      <Route
        path="/auth"
        element={
          <LoginRegister
            onLogin={(role) => {
              setShowWelcome(true);
              if (role === 'admin') {
                navigate('/admin/dashboard');
              } else {
                navigate('/provider/dashboard');
              }
            }}
            onBackToHome={() => navigate('/')}
            onNavigate={(targetView) => {
              if (targetView === 'scholarships') {
                handleScholarshipsClick();
              } else if (targetView === 'home') {
                navigate('/');
              } else {
                navigate(`/${targetView}`);
              }
            }}
          />
        }
      />

      {/* Public Pages with Layout */}
      <Route
        path="/*"
        element={
          <div className="min-h-screen flex flex-col bg-[#F9F5EF] text-[#1C1C1E]">
            <Header
              onSignInClick={() => navigate('/auth')}
              onHomeClick={() => navigate('/')}
              onAboutClick={() => navigate('/about')}
              onImpactClick={() => navigate('/impact')}
              onScholarshipsClick={handleScholarshipsClick}
            />
            <main className="flex-1">
              <Routes>
                <Route path="/" element={<HomePage />} />
                <Route path="/about" element={<AboutPage />} />
                <Route path="/impact" element={<ImpactPage />} />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </main>
            <Footer />
          </div>
        }
      />
    </Routes>
  );
}

export default App;


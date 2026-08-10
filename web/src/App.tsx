import { useState } from 'react';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { HomePage } from '@/pages/home/HomePage';
import { LoginRegister } from '@/pages/auth/LoginRegister';
import { ProviderPortal } from '@/pages/provider/ProviderPortal';
import { SystemAdminPortal } from '@/pages/admin/SystemAdminPortal';

function App() {
  const [view, setView] = useState<'home' | 'auth' | 'provider' | 'admin'>('home');

  if (view === 'admin') {
    return <SystemAdminPortal onLogout={() => setView('home')} />;
  }

  if (view === 'provider') {
    return <ProviderPortal onLogout={() => setView('home')} />;
  }

  if (view === 'auth') {
    return (
      <LoginRegister
        onLogin={(role) => setView(role)}
        onBackToHome={() => setView('home')}
      />
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-[#F9F5EF] text-[#1C1C1E]">
      <Header onSignInClick={() => setView('auth')} />
      <main className="flex-1">
        <HomePage />
      </main>
      <Footer />
    </div>
  );
}

export default App;


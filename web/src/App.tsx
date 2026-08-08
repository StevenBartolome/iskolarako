import { useState } from 'react';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { HomePage } from '@/pages/HomePage';
import { LoginRegister } from '@/pages/LoginRegister';
import { AdminPortal } from '@/pages/AdminPortal';

function App() {
  const [view, setView] = useState<'home' | 'auth' | 'admin'>('home');

  if (view === 'admin') {
    return <AdminPortal onLogout={() => setView('home')} />;
  }

  if (view === 'auth') {
    return (
      <LoginRegister
        onLogin={() => setView('admin')}
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


import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { HomePage } from '@/pages/HomePage';

function App() {
  return (
    <div className="min-h-screen flex flex-col bg-[#F9F5EF] text-[#1C1C1E]">
      <Header />
      <main className="flex-1">
        <HomePage />
      </main>
      <Footer />
    </div>
  );
}

export default App;

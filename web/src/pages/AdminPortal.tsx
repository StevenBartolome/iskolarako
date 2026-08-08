import React, { useState } from 'react';
import { GoogleMap, useJsApiLoader, Marker, Autocomplete } from '@react-google-maps/api';

interface AdminPortalProps {
  onLogout: () => void;
}

type TabType = 'dashboard' | 'applicants' | 'programs' | 'disbursements' | 'announcements' | 'reports';
type AnnType = 'Examination Schedule' | 'Release of Funds' | 'General Notice' | 'Requirements Update';
type ApplicantStatus = 'Pending' | 'Under Review' | 'Approved' | 'Rejected' | 'For Exam';

type FundingFreq = 'Per Semester' | 'Once a Year' | 'One-time';
type RenewalPolicy = 'No Renewal' | 'Automatic Renewal' | 'Conditional Renewal' | 'Annual Reapplication' | 'Semester Renewal';

interface ApplicationCycle {
  id: number;
  name: string; // e.g. "AY 2026-2027"
  startDate: string;
  endDate: string;
  status: 'Open' | 'Closed' | 'Evaluating';
}

interface Program {
  id: number;
  provider: string;
  status: string;
  statusType: 'success' | 'draft' | 'closing';
  title: string;
  description: string;
  renewalPolicy: RenewalPolicy;
  fundingFrequency: FundingFreq;
  cycles: ApplicationCycle[];
  budgetUsed: string;
  budgetTotal: string;
}

interface DisbursementTx {
  id: string;
  scholar: string;
  program: string;
  method: string;
  amount: string;
  numericAmount: number;
  status: 'Completed' | 'Processing' | 'Failed';
  date: string;
}

interface ScholarAward {
  id: number;
  scholarName: string;
  programTitle: string;
  cycleJoined: string;
  status: 'Maintaining' | 'Awaiting Grades' | 'Requirements Warning' | 'Graduated' | 'Suspended';
  gwa: string;
  dateAwarded: string;
}

export const AdminPortal: React.FC<AdminPortalProps> = ({ onLogout }) => {
  const [activeTab, setActiveTab] = useState<TabType>('programs');

  // Search & filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  // Sub-tab toggles under Applicants view: 'applicants' vs 'scholars'
  const [subTab, setSubTab] = useState<'applicants' | 'scholars'>('applicants');

  // Toast indicator
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Modal states
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isPayoutModalOpen, setIsPayoutModalOpen] = useState(false);

  // New program form inputs
  const [formTitle, setFormTitle] = useState('');
  const [formDesc, setFormDesc] = useState('');
  const [formProvider, setFormProvider] = useState('SEI');
  const [formFundingFreq, setFormFundingFreq] = useState<FundingFreq>('Per Semester');
  const [formRenewalPolicy, setFormRenewalPolicy] = useState<RenewalPolicy>('Conditional Renewal');
  const [formCycleName, setFormCycleName] = useState('AY 2026-2027');

  // New payout form inputs
  const [selectedPayoutProgram, setSelectedPayoutProgram] = useState('DOST-SEI Undergraduate Scholarship');

  // Google Maps simulation states
  const [selectedExamLocation, setSelectedExamLocation] = useState('UP Diliman Examination Hall');
  const [examCoords, setExamCoords] = useState({
    lat: 14.6538,
    lng: 121.0685,
    address: 'University of the Philippines, Diliman, Quezon City'
  });
  const [mapZoom, setMapZoom] = useState(14);
  const [autocomplete, setAutocomplete] = useState<google.maps.places.Autocomplete | null>(null);

  const [libraries] = useState<"places"[]>(['places']);

  // Load live Google Maps
  const { isLoaded } = useJsApiLoader({
    googleMapsApiKey: import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '',
    id: 'google-map-script',
    libraries
  });

  const onAutocompleteLoad = (autocompleteInstance: google.maps.places.Autocomplete) => {
    setAutocomplete(autocompleteInstance);
  };

  const onPlaceChanged = () => {
    if (autocomplete !== null) {
      const place = autocomplete.getPlace();
      const name = place.name || '';
      const address = place.formatted_address || '';
      const lat = place.geometry?.location?.lat() || 14.6538;
      const lng = place.geometry?.location?.lng() || 121.0685;

      setSelectedExamLocation(name || address);
      setExamCoords({ lat, lng, address });
      showToast(`Selected: ${name || address}`);
    }
  };

  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  // Announcements mock state
  const [announcements, setAnnouncements] = useState([
    {
      id: 1,
      title: 'Undergraduate Screening Examination Schedule',
      body: 'Qualifying exams for new DOST-SEI applicants will be conducted on September 5, 2026. Testing venues and seat assignments have been dispatched to your portal accounts.',
      type: 'Examination Schedule' as AnnType,
      audience: 'DOST-SEI Only',
      date: 'Aug 8, 2026',
      author: 'Testing Committee',
      location: 'UP Diliman Examination Hall'
    },
    {
      id: 2,
      title: '1st Semester Stipend Release Schedule',
      body: 'Stipends for Tulong Dunong scholars are currently processing. Expect bank transfers to credit by August 18, 2026.',
      type: 'Release of Funds' as AnnType,
      audience: 'CHED Only',
      date: 'Aug 5, 2026',
      author: 'Finance Unit',
      location: null
    }
  ]);

  const [newAnnTitle, setNewAnnTitle] = useState('');
  const [newAnnBody, setNewAnnBody] = useState('');
  const [newAnnType, setNewAnnType] = useState<AnnType>('General Notice');
  const [newAnnAudience, setNewAnnAudience] = useState('All Scholars');

  const handleAddAnnouncement = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAnnTitle || !newAnnBody) return;
    const newAnn = {
      id: Date.now(),
      title: newAnnTitle,
      body: newAnnBody,
      type: newAnnType,
      audience: newAnnAudience,
      date: 'Just Now',
      author: 'DOST-SEI Admin',
      location: newAnnType === 'Examination Schedule' ? selectedExamLocation : null
    };
    setAnnouncements([newAnn, ...announcements]);
    setNewAnnTitle('');
    setNewAnnBody('');
    showToast(`Successfully broadcasted: "${newAnnTitle}"`);
  };

  // Programs Mock State (Standardized to the new architecture)
  const [programsList, setProgramsList] = useState<Program[]>([
    {
      id: 1,
      provider: 'SEI',
      status: 'Active',
      statusType: 'success',
      title: 'DOST-SEI Undergraduate Scholarship',
      description: 'Full tuition • Monthly stipend • STEM only',
      renewalPolicy: 'Conditional Renewal',
      fundingFrequency: 'Per Semester',
      cycles: [
        { id: 101, name: '2026 Intake', startDate: '2026-06-01', endDate: '2026-07-31', status: 'Evaluating' },
        { id: 102, name: '2025 Intake', startDate: '2025-06-01', endDate: '2025-07-31', status: 'Closed' }
      ],
      budgetUsed: '₱2.1M',
      budgetTotal: '₱2.6M'
    },
    {
      id: 2,
      provider: 'CHED',
      status: 'Active',
      statusType: 'success',
      title: 'Tulong Dunong Financial Assistance',
      description: 'Need-based • One-time grant',
      renewalPolicy: 'No Renewal',
      fundingFrequency: 'One-time',
      cycles: [
        { id: 201, name: 'AY 2026-2027', startDate: '2026-05-15', endDate: '2026-08-15', status: 'Open' },
        { id: 202, name: 'AY 2025-2026', startDate: '2025-05-15', endDate: '2025-08-15', status: 'Closed' }
      ],
      budgetUsed: '₱3.1M',
      budgetTotal: '₱4.5M'
    },
    {
      id: 3,
      provider: 'SEI',
      status: 'Draft',
      statusType: 'draft',
      title: 'DOST-SEI Graduate Fellowship',
      description: 'Full tuition • Research allowance • MS/PhD',
      renewalPolicy: 'Semester Renewal',
      fundingFrequency: 'Per Semester',
      cycles: [
        { id: 301, name: 'AY 2026-2027 Cycle', startDate: '2026-09-01', endDate: '2026-10-31', status: 'Open' }
      ],
      budgetUsed: '₱0',
      budgetTotal: '₱1.8M'
    },
    {
      id: 4,
      provider: 'SEI',
      status: 'Active',
      statusType: 'success',
      title: 'DOST-SEI Merit Renewal 2026',
      description: 'Renewal grant for existing scholars',
      renewalPolicy: 'Conditional Renewal',
      fundingFrequency: 'Once a Year',
      cycles: [
        { id: 401, name: 'AY 2026-2027', startDate: '2026-06-15', endDate: '2026-07-24', status: 'Closed' }
      ],
      budgetUsed: '₱3.9M',
      budgetTotal: '₱4.0M'
    }
  ]);

  // Interactive Applicants Mock State (Students in an active application cycle)
  const [applicantsList, setApplicantsList] = useState([
    { id: 2, name: 'Juan Dela Cruz', program: 'DOST-SEI Undergraduate', cycle: '2026 Intake', school: 'Ateneo de Manila University', grade: '1.40', status: 'Under Review' as ApplicantStatus, date: 'Aug 08, 2026' },
    { id: 3, name: 'Ethan Gomez', program: 'Tulong Dunong Assistance', cycle: 'AY 2026-2027', school: 'De La Salle University', grade: '1.75', status: 'Pending' as ApplicantStatus, date: 'Aug 06, 2026' },
    { id: 5, name: 'Angelo Reyes', program: 'DOST-SEI Graduate Fellowship', cycle: 'AY 2026-2027 Cycle', school: 'Mapua University', grade: '1.10', status: 'For Exam' as ApplicantStatus, date: 'Aug 09, 2026' },
    { id: 6, name: 'Sofia Lopez', program: 'Tulong Dunong Assistance', cycle: 'AY 2026-2027', school: 'Polytechnic University of the Philippines', grade: '1.90', status: 'Rejected' as ApplicantStatus, date: 'Aug 03, 2026' }
  ]);

  // Active Scholars (Awarded students under requirements monitoring)
  const [scholarsList, setScholarsList] = useState<ScholarAward[]>([
    { id: 10, scholarName: 'Maria Santos', programTitle: 'DOST-SEI Undergraduate', cycleJoined: '2025 Intake', status: 'Maintaining', gwa: '1.25', dateAwarded: 'Aug 07, 2025' },
    { id: 11, scholarName: 'Princess Diaz', programTitle: 'DOST-SEI Merit Renewal', cycleJoined: 'AY 2026-2027', status: 'Maintaining', gwa: '1.30', dateAwarded: 'Aug 05, 2026' },
    { id: 12, scholarName: 'Jessica Alva', programTitle: 'DOST-SEI Undergraduate', cycleJoined: '2025 Intake', status: 'Awaiting Grades', gwa: '1.65', dateAwarded: 'Sep 10, 2025' },
    { id: 13, scholarName: 'Marcus Vian', programTitle: 'DOST-SEI Graduate Fellowship', cycleJoined: 'AY 2025-2026', status: 'Requirements Warning', gwa: '2.10', dateAwarded: 'Oct 02, 2025' }
  ]);

  // Handle applicant status update
  const handleUpdateStatus = (id: number, nextStatus: ApplicantStatus) => {
    const applicant = applicantsList.find(a => a.id === id);
    if (!applicant) return;

    if (nextStatus === 'Approved') {
      // Transition from applicant to awarded scholar
      const newScholar: ScholarAward = {
        id: Date.now(),
        scholarName: applicant.name,
        programTitle: applicant.program,
        cycleJoined: applicant.cycle,
        status: 'Maintaining',
        gwa: applicant.grade,
        dateAwarded: 'Today'
      };
      setScholarsList([...scholarsList, newScholar]);
      setApplicantsList(prev => prev.filter(app => app.id !== id));
      showToast(`Approved ${applicant.name}! Transitioned them into Active Scholars monitoring.`);
    } else {
      // Just change status within application
      setApplicantsList(prev =>
        prev.map(app => (app.id === id ? { ...app, status: nextStatus } : app))
      );
      showToast(`Updated ${applicant.name}'s status to: ${nextStatus}`);
    }
  };

  // Interactive Disbursements Mock State
  const [disbursementsList, setDisbursementsList] = useState<DisbursementTx[]>([
    { id: 'TXN-9081', scholar: 'Maria Santos', program: 'DOST-SEI Undergraduate Scholarship', method: 'Landbank', amount: '₱40,000', numericAmount: 40000, status: 'Completed', date: 'Aug 07, 2026' },
    { id: 'TXN-9082', scholar: 'Princess Diaz', program: 'DOST-SEI Merit Renewal 2026', method: 'GCash', amount: '₱25,000', numericAmount: 25000, status: 'Completed', date: 'Aug 06, 2026' },
    { id: 'TXN-9083', scholar: 'Juan Dela Cruz', program: 'DOST-SEI Undergraduate Scholarship', method: 'Landbank', amount: '₱40,000', numericAmount: 40000, status: 'Processing', date: 'Aug 08, 2026' },
    { id: 'TXN-9084', scholar: 'Ethan Gomez', program: 'Tulong Dunong Financial Assistance', method: 'PayMaya', amount: '₱15,000', numericAmount: 15000, status: 'Processing', date: 'Aug 08, 2026' },
    { id: 'TXN-9085', scholar: 'Sofia Lopez', program: 'Tulong Dunong Financial Assistance', method: 'GCash', amount: '₱15,000', numericAmount: 15000, status: 'Failed', date: 'Aug 04, 2026' }
  ]);

  const totalCredited = disbursementsList
    .filter(tx => tx.status === 'Completed')
    .reduce((sum, tx) => sum + tx.numericAmount, 0);

  const totalPending = disbursementsList
    .filter(tx => tx.status === 'Processing')
    .reduce((sum, tx) => sum + tx.numericAmount, 0);

  // Handle program payout release first
  const handleReleaseProgramFunds = (e: React.FormEvent) => {
    e.preventDefault();
    let updatedCount = 0;
    setDisbursementsList(prev =>
      prev.map(tx => {
        if (tx.program === selectedPayoutProgram && tx.status === 'Processing') {
          updatedCount++;
          return { ...tx, status: 'Completed' };
        }
        return tx;
      })
    );
    setIsPayoutModalOpen(false);
    if (updatedCount > 0) {
      showToast(`Released funds! Completed ${updatedCount} transactions for "${selectedPayoutProgram}".`);
    } else {
      showToast(`No pending transactions in queue for "${selectedPayoutProgram}".`);
    }
  };

  const handleCreateProgram = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formTitle || !formDesc) return;
    const newProg: Program = {
      id: Date.now(),
      provider: formProvider,
      status: 'Draft',
      statusType: 'draft',
      title: formTitle,
      description: formDesc,
      renewalPolicy: formRenewalPolicy,
      fundingFrequency: formFundingFreq,
      cycles: [
        { id: Date.now() + 1, name: formCycleName, startDate: '2026-09-01', endDate: '2026-12-31', status: 'Open' }
      ],
      budgetUsed: '₱0',
      budgetTotal: '₱1.8M'
    };
    setProgramsList([...programsList, newProg]);
    setIsCreateModalOpen(false);
    setFormTitle('');
    setFormDesc('');
    showToast(`Created program: "${formTitle}" with cycle "${formCycleName}"!`);
  };

  const filteredApplicants = applicantsList.filter(app => {
    const matchesSearch = app.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
                          app.school.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          app.program.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === 'All' || app.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const filteredScholars = scholarsList.filter(sch => {
    const matchesSearch = sch.scholarName.toLowerCase().includes(searchQuery.toLowerCase()) || 
                          sch.programTitle.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesSearch;
  });

  const renderSidebarItem = (tab: TabType, label: string, icon: React.ReactNode) => {
    const isActive = activeTab === tab;
    return (
      <button
        onClick={() => setActiveTab(tab)}
        className={`w-full flex items-center gap-3.5 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 cursor-pointer ${
          isActive
            ? 'bg-white/10 text-white font-semibold shadow-sm'
            : 'text-[#9BA89F] hover:bg-white/5 hover:text-white'
        }`}
      >
        {icon}
        {label}
      </button>
    );
  };

  return (
    <div className="min-h-screen bg-[#F9F5EF] flex font-sans relative">
      
      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-[#1A3C2E] text-[#F9F5EF] border border-[#2D5941] px-5 py-3 rounded-xl shadow-2xl flex items-center gap-2 animate-bounce">
          <svg className="w-5 h-5 text-[#E8A838]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="text-xs font-semibold">{toastMessage}</span>
        </div>
      )}

      {/* Program Creation Modal */}
      {isCreateModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
          <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-8 max-w-lg w-full space-y-6 relative animate-fade-in">
            <button onClick={() => setIsCreateModalOpen(false)} className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer">✕</button>
            <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">Configure Permanent Program</h3>
            <p className="text-xs text-[#6C6C70]">Design program-wide renewal policies and register the first Application Cycle.</p>
            <form onSubmit={handleCreateProgram} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1">Provider Partner</label>
                  <select
                    value={formProvider}
                    onChange={(e) => setFormProvider(e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer"
                  >
                    <option value="SEI">DOST-SEI</option>
                    <option value="CHED">CHED</option>
                    <option value="NGO">NGO Partner</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1">Program Title</label>
                  <input
                    type="text" required placeholder="e.g. Merit Scholarship Program"
                    value={formTitle} onChange={(e) => setFormTitle(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                  />
                </div>
              </div>
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1">Description / Benefits</label>
                <input
                  type="text" required placeholder="Full tuition • Monthly stipend"
                  value={formDesc} onChange={(e) => setFormDesc(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                />
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1">Initial Application Cycle</label>
                  <input
                    type="text" required placeholder="e.g. AY 2026-2027"
                    value={formCycleName} onChange={(e) => setFormCycleName(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1">Funding Frequency</label>
                  <select
                    value={formFundingFreq} onChange={(e) => setFormFundingFreq(e.target.value as FundingFreq)}
                    className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer"
                  >
                    <option value="Per Semester">Per Semester</option>
                    <option value="Once a Year">Once a Year</option>
                    <option value="One-time">One-time Grant</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1">Scholar Renewal Policy</label>
                <select
                  value={formRenewalPolicy} onChange={(e) => setFormRenewalPolicy(e.target.value as RenewalPolicy)}
                  className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer"
                >
                  <option value="No Renewal">No Renewal (One-time Financial Help)</option>
                  <option value="Automatic Renewal">Automatic Renewal (Continuing award)</option>
                  <option value="Conditional Renewal">Conditional Renewal (Maintains requirements/GWA)</option>
                  <option value="Annual Reapplication">Annual Reapplication (Must apply every cycle)</option>
                  <option value="Semester Renewal">Semester Renewal (Verify semestral grades)</option>
                </select>
              </div>

              <button type="submit" className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white py-3 rounded-xl text-sm font-bold shadow-md cursor-pointer">Create Program Lifecycle</button>
            </form>
          </div>
        </div>
      )}

      {/* Disbursements Payout Release Modal */}
      {isPayoutModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
          <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-8 max-w-md w-full space-y-6 relative animate-fade-in">
            <button onClick={() => setIsPayoutModalOpen(false)} className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer">✕</button>
            
            <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">Release Program Payouts</h3>
            <p className="text-xs text-[#6C6C70]">Select the target program whose pending fund releases should be processed first.</p>
            
            <form onSubmit={handleReleaseProgramFunds} className="space-y-5">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Select Scholarship Program</label>
                <select
                  value={selectedPayoutProgram}
                  onChange={(e) => setSelectedPayoutProgram(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm font-semibold cursor-pointer bg-white"
                >
                  <option value="DOST-SEI Undergraduate Scholarship">DOST-SEI Undergraduate Scholarship</option>
                  <option value="Tulong Dunong Financial Assistance">Tulong Dunong Financial Assistance</option>
                  <option value="DOST-SEI Merit Renewal 2026">DOST-SEI Merit Renewal 2026</option>
                  <option value="DOST-SEI Graduate Fellowship">DOST-SEI Graduate Fellowship</option>
                </select>
              </div>

              <div className="bg-[#F9F5EF] p-4 rounded-2xl border border-[#D9D2C5]/50 space-y-2 text-xs">
                <div className="flex justify-between font-medium">
                  <span className="text-[#6C6C70]">Pending Transactions:</span>
                  <span className="font-bold text-[#1C1C1E]">
                    {disbursementsList.filter(tx => tx.program === selectedPayoutProgram && tx.status === 'Processing').length} items
                  </span>
                </div>
                <div className="flex justify-between font-medium">
                  <span className="text-[#6C6C70]">Total Batch Cost:</span>
                  <span className="font-bold text-[#2D5941]">
                    ₱{disbursementsList
                      .filter(tx => tx.program === selectedPayoutProgram && tx.status === 'Processing')
                      .reduce((sum, tx) => sum + tx.numericAmount, 0)
                      .toLocaleString()}
                  </span>
                </div>
              </div>

              <button
                type="submit"
                className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white py-3.5 rounded-xl text-sm font-bold shadow-md cursor-pointer transition-all"
              >
                Confirm Payout & Release Funds
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Sidebar */}
      <aside className="w-72 bg-[#1A3C2E] text-white flex flex-col justify-between p-6 border-r border-[#2D5941]/30 shrink-0">
        <div className="space-y-8">
          <div className="pt-2">
            <h1 className="text-2xl font-bold font-serif text-[#E8A838] tracking-wide">ISKOLARAKO</h1>
            <p className="text-xs text-[#9BA89F] mt-1 font-semibold uppercase tracking-wider">DOST-SEI Portal</p>
          </div>

          <nav className="space-y-1.5">
            {renderSidebarItem('dashboard', 'Dashboard', <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>)}
            {renderSidebarItem('applicants', 'Applicants & Scholars', <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" /></svg>)}
            {renderSidebarItem('programs', 'Programs', <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" /></svg>)}
            {renderSidebarItem('disbursements', 'Disbursements', <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 8h6m-5 0a3 3 0 110 6H9l3 3m-3-6h6m6 1a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>)}
            {renderSidebarItem('announcements', 'Announcements', <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" /></svg>)}
            {renderSidebarItem('reports', 'Reports', <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>)}
          </nav>
        </div>

        <div className="space-y-4">
          <div className="flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 border border-white/10">
            <div className="w-10 h-10 rounded-xl bg-[#E8A838] flex items-center justify-center font-bold text-[#1A3C2E]">DS</div>
            <div className="min-w-0 flex-1">
              <h4 className="text-sm font-semibold truncate text-white">DOST-SEI</h4>
              <p className="text-xs text-[#9BA89F] truncate">Public Provider</p>
            </div>
          </div>
          <button
            onClick={onLogout}
            className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl border border-white/20 text-[#9BA89F] hover:text-white hover:bg-white/5 transition-all text-xs font-semibold cursor-pointer"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto p-10 max-w-7xl mx-auto">
        
        {/* ==================== 1. DASHBOARD VIEW ==================== */}
        {activeTab === 'dashboard' && (
          <div className="space-y-8 animate-fade-in">
            <div>
              <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Dashboard</h2>
              <p className="text-sm text-[#6C6C70] mt-1 font-medium">Real-time Scholarship Monitoring</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
                <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Permanent Programs</span>
                <h3 className="text-3xl font-bold text-[#1A3C2E] font-serif mt-1">{programsList.length}</h3>
                <span className="text-xs text-[#2D5941] font-semibold flex items-center gap-1 mt-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#2D5941]" /> Fully Lifecycle Managed
                </span>
              </div>
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
                <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Active Scholars (Awards)</span>
                <h3 className="text-3xl font-bold text-[#C97B2E] font-serif mt-1">{scholarsList.length}</h3>
                <span className="text-xs text-[#C97B2E] font-semibold flex items-center gap-1 mt-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#C97B2E]" /> Undergoing renewal checks
                </span>
              </div>
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
                <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Active Cycle Applicants</span>
                <h3 className="text-3xl font-bold text-[#B34040] font-serif mt-1">{applicantsList.length}</h3>
                <span className="text-xs text-[#B34040] font-semibold flex items-center gap-1 mt-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#B34040]" /> In active intake cycles
                </span>
              </div>
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm">
                <span className="text-[10px] uppercase tracking-wider font-bold text-[#8E8E93]">Funds Released</span>
                <h3 className="text-3xl font-bold text-[#2D5941] font-serif mt-1">₱{(totalCredited / 1000000).toFixed(2)}M</h3>
                <span className="text-xs text-[#2D5941] font-semibold flex items-center gap-1 mt-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#2D5941]" /> ₱{(totalPending / 1000).toFixed(0)}K pending release
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm lg:col-span-2 space-y-6">
                <div className="flex justify-between items-center">
                  <h4 className="font-bold text-[#1A3C2E] font-serif">Fund Allocation Distribution</h4>
                  <span className="text-xs font-semibold text-[#8E8E93]">AY 2026-2027</span>
                </div>
                <div className="space-y-4 pt-2">
                  {programsList.map(prog => (
                    <div key={prog.id}>
                      <div className="flex justify-between text-xs font-semibold text-[#1C1C1E] mb-1.5">
                        <span>{prog.title}</span>
                        <span>{prog.budgetUsed} / {prog.budgetTotal}</span>
                      </div>
                      <div className="w-full bg-[#EDE8DE] h-3.5 rounded-full overflow-hidden">
                        <div className="bg-[#2D5941] h-full rounded-full" style={{ width: '65%' }} />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-5">
                <h4 className="font-bold text-[#1A3C2E] font-serif">Recent System Events</h4>
                <div className="space-y-4 text-xs">
                  <div className="flex gap-3 pb-3 border-b border-[#D9D2C5]/40">
                    <div className="w-8 h-8 rounded-full bg-[#EBF5EE] text-[#2D5941] flex items-center justify-center font-bold shrink-0">IA</div>
                    <div>
                      <p className="font-semibold text-[#1C1C1E]">Scholar Award Issued</p>
                      <p className="text-[10px] text-[#6C6C70] mt-0.5">Applicant upgraded to continuing status</p>
                    </div>
                  </div>
                  <div className="flex gap-3 pb-3 border-b border-[#D9D2C5]/40">
                    <div className="w-8 h-8 rounded-full bg-[#F9F0E0] text-[#C97B2E] flex items-center justify-center font-bold shrink-0">RC</div>
                    <div>
                      <p className="font-semibold text-[#1C1C1E]">Renewal Policy Warning</p>
                      <p className="text-[10px] text-[#6C6C70] mt-0.5">Marcus Vian flagged (GWA 2.10 under Conditional Policy)</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ==================== 2. APPLICANTS & SCHOLARS VIEW (SPLIT SECTIONS) ==================== */}
        {activeTab === 'applicants' && (
          <div className="space-y-8 animate-fade-in">
            
            {/* Header and Toggle Button between Applicants and Scholars */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
              <div>
                <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">
                  {subTab === 'applicants' ? 'Cycle Applicants' : 'Continuing Scholars'}
                </h2>
                <p className="text-sm text-[#6C6C70] mt-1 font-medium">
                  {subTab === 'applicants' 
                    ? 'Review incoming entries for active intake cycles. Approving them creates a continuing Scholar Award.'
                    : 'Monitor active scholar awards, GWA requirements, and renewal conditions.'
                  }
                </p>
              </div>

              {/* Toggle Selector */}
              <div className="flex bg-[#EDE8DE]/60 p-1 rounded-xl text-xs font-semibold gap-1">
                <button
                  onClick={() => { setSubTab('applicants'); setStatusFilter('All'); }}
                  className={`px-4 py-2 rounded-lg cursor-pointer transition-all ${
                    subTab === 'applicants' ? 'bg-[#1A3C2E] text-white shadow-sm' : 'text-[#6C6C70] hover:text-[#1A3C2E]'
                  }`}
                >
                  Applicants ({applicantsList.length})
                </button>
                <button
                  onClick={() => { setSubTab('scholars'); setStatusFilter('All'); }}
                  className={`px-4 py-2 rounded-lg cursor-pointer transition-all ${
                    subTab === 'scholars' ? 'bg-[#1A3C2E] text-white shadow-sm' : 'text-[#6C6C70] hover:text-[#1A3C2E]'
                  }`}
                >
                  Continuing Scholars ({scholarsList.length})
                </button>
              </div>
            </div>

            {/* Filter bar for Applicants */}
            {subTab === 'applicants' && (
              <div className="flex flex-wrap items-center justify-between gap-4 bg-white p-4 rounded-2xl border border-[#D9D2C5]/60 shadow-sm">
                <div className="relative flex-1 max-w-md">
                  <svg className="absolute left-4 top-3 w-4 h-4 text-[#8E8E93]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
                  <input
                    type="text" placeholder="Search applicants..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-11 pr-4 py-2 rounded-xl border border-[#D9D2C5]/60 focus:outline-none focus:border-[#2D5941] text-xs"
                  />
                </div>
                
                <div className="flex gap-1 bg-[#EDE8DE]/45 p-1 rounded-lg text-[10px] font-bold">
                  {['All', 'Pending', 'Under Review', 'For Exam', 'Rejected'].map(st => (
                    <button
                      key={st} onClick={() => setStatusFilter(st)}
                      className={`px-3 py-1.5 rounded cursor-pointer ${statusFilter === st ? 'bg-[#1A3C2E] text-white' : 'text-[#6C6C70]'}`}
                    >
                      {st}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Render table based on toggle */}
            {subTab === 'applicants' ? (
              <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 overflow-hidden shadow-sm">
                <table className="w-full border-collapse text-left text-sm">
                  <thead>
                    <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-xs font-bold text-[#6C6C70] uppercase tracking-wider">
                      <th className="px-6 py-4">Applicant Name</th>
                      <th className="px-6 py-4">Target Program</th>
                      <th className="px-6 py-4">Active Cycle</th>
                      <th className="px-6 py-4 text-center">GWA</th>
                      <th className="px-6 py-4">Current Status</th>
                      <th className="px-6 py-4 text-center">Actions / Decision</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
                    {filteredApplicants.map((app) => (
                      <tr key={app.id} className="hover:bg-[#F9F5EF]/30 transition-colors">
                        <td className="px-6 py-4 flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-[#1A3C2E] text-white flex items-center justify-center font-bold text-xs uppercase">
                            {app.name.split(' ').map(n => n[0]).join('')}
                          </div>
                          <div>
                            <span className="block font-bold text-[#1C1C1E]">{app.name}</span>
                            <span className="text-[10px] text-[#8E8E93]">{app.date}</span>
                          </div>
                        </td>
                        <td className="px-6 py-4 text-[#1C1C1E]">{app.program}</td>
                        <td className="px-6 py-4 text-xs font-bold text-[#2D5941]">{app.cycle}</td>
                        <td className="px-6 py-4 text-center font-serif text-[#1C1C1E]">{app.grade}</td>
                        <td className="px-6 py-4">
                          <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${
                            app.status === 'Approved' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                            app.status === 'Pending' ? 'bg-[#F9F0E0] text-[#C97B2E]' :
                            app.status === 'Under Review' ? 'bg-[#EAF3FA] text-[#2A6BA8]' :
                            app.status === 'For Exam' ? 'bg-purple-100 text-purple-700' :
                            'bg-[#FDF2F2] text-[#B34040]'
                          }`}>
                            {app.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-center">
                          <select
                            value={app.status}
                            onChange={(e) => handleUpdateStatus(app.id, e.target.value as ApplicantStatus)}
                            className="bg-white border border-[#D9D2C5] rounded-xl px-2 py-1.5 text-xs font-semibold focus:outline-none cursor-pointer"
                          >
                            <option value="Pending">Pending</option>
                            <option value="Under Review">Under Review</option>
                            <option value="For Exam">For Exam</option>
                            <option value="Approved">Approve & Issue Award</option>
                            <option value="Rejected">Rejected</option>
                          </select>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              // Active Scholars Monitoring View
              <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 overflow-hidden shadow-sm">
                <table className="w-full border-collapse text-left text-sm">
                  <thead>
                    <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-xs font-bold text-[#6C6C70] uppercase tracking-wider">
                      <th className="px-6 py-4">Scholar Name</th>
                      <th className="px-6 py-4">Awarded Program</th>
                      <th className="px-6 py-4">Intake Cycle</th>
                      <th className="px-6 py-4 text-center">Latest GWA</th>
                      <th className="px-6 py-4">Monitoring Status</th>
                      <th className="px-6 py-4 text-right">Award Date</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
                    {filteredScholars.map((sch) => (
                      <tr key={sch.id} className="hover:bg-[#F9F5EF]/30 transition-colors">
                        <td className="px-6 py-4 flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-[#C97B2E] text-white flex items-center justify-center font-bold text-xs uppercase">
                            {sch.scholarName.split(' ').map(n => n[0]).join('')}
                          </div>
                          <span className="font-bold text-[#1C1C1E]">{sch.scholarName}</span>
                        </td>
                        <td className="px-6 py-4 text-[#1C1C1E]">{sch.programTitle}</td>
                        <td className="px-6 py-4 text-xs font-semibold text-[#6C6C70]">{sch.cycleJoined}</td>
                        <td className="px-6 py-4 text-center font-serif font-bold text-[#2D5941]">{sch.gwa}</td>
                        <td className="px-6 py-4">
                          <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold ${
                            sch.status === 'Maintaining' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                            sch.status === 'Awaiting Grades' ? 'bg-amber-50 text-[#C97B2E]' :
                            sch.status === 'Requirements Warning' ? 'bg-[#FDF2F2] text-[#B34040]' :
                            'bg-gray-100 text-gray-700'
                          }`}>
                            {sch.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-right text-xs text-[#8E8E93]">{sch.dateAwarded}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* ==================== 3. PROGRAMS VIEW (LIFECYCLE SCHEMAS SHOWN) ==================== */}
        {activeTab === 'programs' && (
          <div className="space-y-8 animate-fade-in">
            <div className="flex justify-between items-center">
              <div>
                <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Scholarship Programs</h2>
                <p className="text-sm text-[#6C6C70] mt-1 font-medium">Permanent scholarship schemas, active application cycles, and renewal rules</p>
              </div>
              <button
                onClick={() => setIsCreateModalOpen(true)}
                className="flex items-center gap-2 bg-[#E8A838] hover:bg-[#cfa532] text-[#1A3C2E] px-5 py-2.5 rounded-xl font-bold text-sm shadow-md transition-all cursor-pointer border border-[#1A3C2E]/10"
              >
                <span>+</span> New program
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              {programsList.map((prog) => (
                <div
                  key={prog.id}
                  className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-7 shadow-sm hover:shadow-md transition-all flex flex-col justify-between h-[340px] animate-fade-in"
                >
                  <div className="space-y-3.5">
                    <div className="flex justify-between items-center">
                      <span className="px-3.5 py-1.5 rounded-xl bg-[#1A3C2E] text-white text-xs font-bold tracking-wider">
                        {prog.provider}
                      </span>
                      <span className="px-3 py-1 rounded-lg text-[10px] font-bold bg-[#EDE8DE] text-[#6C6C70] border border-[#D9D2C5]">
                        ⚙️ Policy: {prog.renewalPolicy}
                      </span>
                    </div>

                    <div>
                      <h3 className="text-xl font-bold text-[#1A3C2E] font-serif leading-snug truncate">
                        {prog.title}
                      </h3>
                      <p className="text-xs text-[#6C6C70] mt-0.5 font-medium line-clamp-1">
                        {prog.description}
                      </p>
                    </div>

                    {/* Application Cycles checklist sub-layout */}
                    <div className="space-y-1.5 pt-1">
                      <span className="text-[10px] uppercase font-bold text-[#8E8E93] tracking-wide block">Registered Cycles</span>
                      <div className="flex flex-col gap-1 max-h-24 overflow-y-auto">
                        {prog.cycles.map((cyc) => (
                          <div key={cyc.id} className="flex justify-between items-center bg-[#F9F5EF] px-3 py-1.5 rounded-lg border border-[#D9D2C5]/30 text-xs">
                            <span className="font-bold text-[#1C1C1E]">{cyc.name}</span>
                            <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                              cyc.status === 'Open' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                              cyc.status === 'Evaluating' ? 'bg-amber-100 text-amber-700' :
                              'bg-gray-200 text-gray-600'
                            }`}>
                              {cyc.status}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>

                  <div className="border-t border-[#D9D2C5]/50 pt-4 flex justify-between items-center text-xs">
                    <div>
                      <span className="text-[#8E8E93] font-bold block uppercase tracking-wider text-[9px]">Funding Frequency</span>
                      <span className="text-[#1C1C1E] font-bold text-xs mt-0.5 block">{prog.fundingFrequency}</span>
                    </div>
                    <div className="text-right">
                      <span className="text-[#8E8E93] font-bold block uppercase tracking-wider text-[9px]">Fund Utilization</span>
                      <span className="text-[#1C1C1E] font-bold text-xs mt-0.5 block">
                        {prog.budgetUsed} <span className="text-[#8E8E93]">/ {prog.budgetTotal}</span>
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ==================== 4. DISBURSEMENTS VIEW ==================== */}
        {activeTab === 'disbursements' && (
          <div className="space-y-8 animate-fade-in">
            <div className="flex justify-between items-center">
              <div>
                <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Disbursements</h2>
                <p className="text-sm text-[#6C6C70] mt-1 font-medium">Release specific program batch payouts using the batch wizard</p>
              </div>
              <button
                onClick={() => setIsPayoutModalOpen(true)}
                className="bg-[#2D5941] hover:bg-[#1A3C2E] text-white px-5 py-2.5 rounded-xl text-sm font-bold shadow-md cursor-pointer transition-all"
              >
                Process Payouts Batch
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6">
                <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Current Cash Allocation</span>
                <h4 className="text-3xl font-bold text-[#1A3C2E] font-serif mt-1">₱11,100,000</h4>
                <p className="text-[11px] text-[#6C6C70] mt-2">DOST-SEI provider balance</p>
              </div>
              <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6">
                <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Total Credited</span>
                <h4 className="text-3xl font-bold text-[#2D5941] font-serif mt-1">₱{totalCredited.toLocaleString()}</h4>
                <p className="text-[11px] text-[#2D5941] mt-2">Credited to linked student accounts</p>
              </div>
              <div className="bg-[#EDE8DE]/40 border border-[#D9D2C5] rounded-2xl p-6">
                <span className="text-[10px] uppercase font-bold text-[#6C6C70]">Pending Release</span>
                <h4 className="text-3xl font-bold text-[#C97B2E] font-serif mt-1">₱{totalPending.toLocaleString()}</h4>
                <p className="text-[11px] text-[#C97B2E] mt-2">Waiting in payouts queue</p>
              </div>
            </div>

            <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 overflow-hidden shadow-sm">
              <div className="p-5 border-b border-[#D9D2C5]/40 bg-[#F9F5EF]/20">
                <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Transaction Ledger</h3>
              </div>
              <table className="w-full border-collapse text-left text-sm">
                <thead>
                  <tr className="bg-[#F9F5EF] border-b border-[#D9D2C5]/60 text-xs font-bold text-[#6C6C70] uppercase tracking-wider">
                    <th className="px-6 py-4">Transaction ID</th>
                    <th className="px-6 py-4">Scholar</th>
                    <th className="px-6 py-4">Target Program</th>
                    <th className="px-6 py-4">Method</th>
                    <th className="px-6 py-4">Amount</th>
                    <th className="px-6 py-4">Status</th>
                    <th className="px-6 py-4 text-right">Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#D9D2C5]/40 font-medium">
                  {disbursementsList.map((tx) => (
                    <tr key={tx.id} className="hover:bg-[#F9F5EF]/30 transition-colors">
                      <td className="px-6 py-4 text-xs font-bold text-[#2D5941]">{tx.id}</td>
                      <td className="px-6 py-4 font-bold text-[#1C1C1E]">{tx.scholar}</td>
                      <td className="px-6 py-4 text-[#6C6C70]">{tx.program}</td>
                      <td className="px-6 py-4 text-[#1C1C1E]">{tx.method}</td>
                      <td className="px-6 py-4 text-[#2D5941] font-bold">{tx.amount}</td>
                      <td className="px-6 py-4">
                        <span
                          className={`px-3 py-1 rounded-full text-xs font-bold ${
                            tx.status === 'Completed'
                              ? 'bg-[#EBF5EE] text-[#2D5941]'
                              : tx.status === 'Processing'
                              ? 'bg-[#F9F0E0] text-[#C97B2E]'
                              : 'bg-[#FDF2F2] text-[#B34040]'
                          }`}
                        >
                          {tx.status}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-right text-xs text-[#8E8E93]">{tx.date}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ==================== 5. ANNOUNCEMENTS VIEW ==================== */}
        {activeTab === 'announcements' && (
          <div className="space-y-8 animate-fade-in">
            <div>
              <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Announcements</h2>
              <p className="text-sm text-[#6C6C70] mt-1 font-medium">Broadcast notices and search exam venues with live Google Maps Autocomplete</p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
              
              {/* Broadcast Announcement Form */}
              <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-5">
                <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Broadcast Announcement</h3>
                <form onSubmit={handleAddAnnouncement} className="space-y-4">
                  <div>
                    <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Announcement Type</label>
                    <select
                      value={newAnnType}
                      onChange={(e) => setNewAnnType(e.target.value as AnnType)}
                      className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-sm font-semibold cursor-pointer"
                    >
                      <option value="General Notice">General Notice</option>
                      <option value="Examination Schedule">Examination Schedule</option>
                      <option value="Release of Funds">Release of Funds</option>
                      <option value="Requirements Update">Requirements Update</option>
                    </select>
                  </div>

                  {/* Google Maps Autocomplete Search Input */}
                  {newAnnType === 'Examination Schedule' && (
                    <div className="space-y-3 p-3 rounded-2xl border border-[#D9D2C5] bg-[#F9F5EF]/50 animate-fade-in">
                      <label className="block text-xs font-bold text-[#1A3C2E] uppercase tracking-wide">🔍 Search Exam Location (Google Places)</label>
                      
                      {isLoaded ? (
                        <Autocomplete
                          onLoad={onAutocompleteLoad}
                          onPlaceChanged={onPlaceChanged}
                        >
                          <input
                            type="text"
                            placeholder="Type venue e.g. UP Diliman..."
                            className="w-full px-3 py-2 rounded-lg border border-[#D9D2C5] text-xs font-semibold bg-white focus:outline-none focus:border-[#2D5941]"
                          />
                        </Autocomplete>
                      ) : (
                        <div className="text-xs font-medium text-[#6C6C70]">Loading search script...</div>
                      )}

                      {/* Google Maps live viewport */}
                      <div className="w-full h-44 rounded-xl border border-[#D9D2C5] overflow-hidden relative flex flex-col justify-between shadow-inner bg-slate-100">
                        {isLoaded ? (
                          <GoogleMap
                            mapContainerStyle={{ width: '100%', height: '100%' }}
                            center={{ lat: examCoords.lat, lng: examCoords.lng }}
                            zoom={mapZoom}
                            options={{
                              disableDefaultUI: true,
                              zoomControl: false,
                            }}
                          >
                            <Marker position={{ lat: examCoords.lat, lng: examCoords.lng }} />
                          </GoogleMap>
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-xs font-semibold text-[#6C6C70]">
                            Loading Live Google Maps...
                          </div>
                        )}
                        
                        <div className="absolute top-2 left-2 z-10 bg-white/90 backdrop-blur px-2 py-1 rounded text-[8px] text-[#6C6C70] font-semibold border border-[#D9D2C5]/50 shadow-sm">
                          <span>
                            {examCoords.lat.toFixed(4)}° N, {examCoords.lng.toFixed(4)}° E
                          </span>
                        </div>

                        <div className="absolute bottom-2 left-2 right-2 z-10 flex justify-between items-center">
                          <span className="text-[7px] text-[#2D5941] bg-white/90 px-1.5 py-0.5 rounded font-bold uppercase tracking-wider shadow">
                            Google Maps Live ({mapZoom}x)
                          </span>
                          <div className="flex gap-1">
                            <button type="button" onClick={() => setMapZoom(prev => Math.min(prev + 1, 18))} className="w-5 h-5 bg-white border border-[#D9D2C5] hover:bg-slate-50 text-[10px] font-bold rounded flex items-center justify-center cursor-pointer shadow-sm">+</button>
                            <button type="button" onClick={() => setMapZoom(prev => Math.max(prev - 1, 10))} className="w-5 h-5 bg-white border border-[#D9D2C5] hover:bg-slate-50 text-[10px] font-bold rounded flex items-center justify-center cursor-pointer shadow-sm">-</button>
                          </div>
                        </div>
                      </div>
                      
                      <p className="text-[10px] text-[#6C6C70] leading-relaxed italic">
                        <strong>Address:</strong> {examCoords.address}
                      </p>
                    </div>
                  )}

                  <div>
                    <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Announcement Title</label>
                    <input
                      type="text" required placeholder="e.g. Schedule of Qualifying Examinations"
                      value={newAnnTitle} onChange={(e) => setNewAnnTitle(e.target.value)}
                      className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-sm"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Target Audience</label>
                    <select
                      value={newAnnAudience} onChange={(e) => setNewAnnAudience(e.target.value)}
                      className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-sm cursor-pointer"
                    >
                      <option value="All Scholars">All Scholars</option>
                      <option value="DOST-SEI Only">DOST-SEI Only</option>
                      <option value="CHED Only">CHED Only</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Message / Details</label>
                    <textarea
                      required rows={4} placeholder="Specify date, times, venues or step-by-step info here..."
                      value={newAnnBody} onChange={(e) => setNewAnnBody(e.target.value)}
                      className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-sm"
                    />
                  </div>

                  <button
                    type="submit"
                    className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white py-3 rounded-xl text-sm font-semibold tracking-wide shadow-md transition-all cursor-pointer"
                  >
                    Publish Announcement
                  </button>
                </form>
              </div>

              <div className="lg:col-span-2 space-y-6">
                <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Active Broadcast Board</h3>
                <div className="space-y-4">
                  {announcements.map((ann) => (
                    <div key={ann.id} className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-4 animate-fade-in">
                      <div className="flex justify-between items-start gap-4">
                        <div>
                          <span
                            className={`inline-block px-3 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider ${
                              ann.type === 'Examination Schedule'
                                ? 'bg-amber-100 text-[#C97B2E] border border-amber-200'
                                : ann.type === 'Release of Funds'
                                ? 'bg-blue-100 text-blue-700 border border-blue-200'
                                : ann.type === 'Requirements Update'
                                ? 'bg-purple-100 text-purple-700 border border-purple-200'
                                : 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20'
                            }`}
                          >
                            {ann.type}
                          </span>
                          <h4 className="text-lg font-bold text-[#1A3C2E] font-serif mt-2">{ann.title}</h4>
                          <span className="text-[10px] text-[#6C6C70] font-medium block mt-1">
                            Published by {ann.author} on {ann.date}
                          </span>
                        </div>
                        <span className="px-3 py-1 rounded-full text-[10px] font-bold bg-[#EDE8DE] text-[#6C6C70]">
                          {ann.audience}
                        </span>
                      </div>
                      
                      <p className="text-sm text-[#6C6C70] leading-relaxed">{ann.body}</p>
                      
                      {ann.location && (
                        <div className="pt-2 flex items-center gap-1.5 text-xs font-bold text-[#C97B2E]">
                          <span>📍 Venue:</span>
                          <span className="underline">{ann.location}</span>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ==================== 6. REPORTS VIEW ==================== */}
        {activeTab === 'reports' && (
          <div className="space-y-8 animate-fade-in">
            <div className="flex justify-between items-center">
              <div>
                <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Reports & Audits</h2>
                <p className="text-sm text-[#6C6C70] mt-1 font-medium">Export system utilization and compliance audit logs</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm flex flex-col justify-between">
                <div>
                  <h4 className="text-base font-bold text-[#1A3C2E] font-serif">Fund Utilization Summary</h4>
                  <p className="text-xs text-[#6C6C70] mt-1">Full breakdown of disbursement ratios and budget balances.</p>
                </div>
                <div className="mt-6 flex justify-between items-center border-t border-[#D9D2C5]/40 pt-4">
                  <span className="text-[10px] text-[#8E8E93] font-bold">PDF / EXCEL</span>
                  <button className="text-xs font-bold text-[#C97B2E] hover:underline cursor-pointer">Download</button>
                </div>
              </div>
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm flex flex-col justify-between">
                <div>
                  <h4 className="text-base font-bold text-[#1A3C2E] font-serif">Scholar Performance Audit</h4>
                  <p className="text-xs text-[#6C6C70] mt-1">Summary of scholars\' GWAs, grade sheet validation, and failures.</p>
                </div>
                <div className="mt-6 flex justify-between items-center border-t border-[#D9D2C5]/40 pt-4">
                  <span className="text-[10px] text-[#8E8E93] font-bold">CSV / XLSX</span>
                  <button className="text-xs font-bold text-[#C97B2E] hover:underline cursor-pointer">Download</button>
                </div>
              </div>
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/60 p-6 shadow-sm flex flex-col justify-between">
                <div>
                  <h4 className="text-base font-bold text-[#1A3C2E] font-serif">Announcements Engagement</h4>
                  <p className="text-xs text-[#6C6C70] mt-1">Metrics on student read acknowledgments and message reach.</p>
                </div>
                <div className="mt-6 flex justify-between items-center border-t border-[#D9D2C5]/40 pt-4">
                  <span className="text-[10px] text-[#8E8E93] font-bold">PDF</span>
                  <button className="text-xs font-bold text-[#C97B2E] hover:underline cursor-pointer">Download</button>
                </div>
              </div>
            </div>
          </div>
        )}

      </main>

    </div>
  );
};

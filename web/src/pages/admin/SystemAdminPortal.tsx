import React, { useState } from 'react';

interface SystemAdminPortalProps {
  onLogout: () => void;
}

type AdminTab =
  | 'dashboard'
  | 'providers'
  | 'scholarships'
  | 'students'
  | 'applications'
  | 'documents'
  | 'reports'
  | 'funds'
  | 'notifications'
  | 'users'
  | 'logs'
  | 'settings';

interface ProviderOrg {
  id: number;
  name: string;
  representative: string;
  email: string;
  type: 'Government' | 'Private' | 'NGO';
  status: 'Pending' | 'Under Review' | 'Verified' | 'Active' | 'Suspended' | 'Revoked';
  documents: { name: string; url: string; verified: boolean }[];
  dateRegistered: string;
}

interface ScholarshipAdminView {
  id: number;
  title: string;
  providerName: string;
  category: string;
  amount: number;
  status: 'Pending Review' | 'Approved' | 'Rejected' | 'Published' | 'Suspended';
  dateCreated: string;
}

interface StudentAdminView {
  id: number;
  name: string;
  email: string;
  school: string;
  gpa: string;
  verificationStatus: 'Verified' | 'Pending' | 'Flagged';
  accountStatus: 'Active' | 'Suspended';
}

interface AdminReport {
  id: number;
  reportedEntity: string;
  type: 'Provider' | 'Scholarship';
  reason: string;
  reporter: string;
  status: 'Under Investigation' | 'Resolved' | 'Dismissed';
  date: string;
}

interface TransactionRecord {
  id: string;
  provider: string;
  scholar: string;
  amount: number;
  status: 'COMPLETED' | 'PENDING' | 'FAILED';
  reference: string;
  date: string;
}

interface AuditLogEntry {
  id: number;
  admin: string;
  action: string;
  target: string;
  date: string;
  time: string;
  ip: string;
}

export const SystemAdminPortal: React.FC<SystemAdminPortalProps> = ({ onLogout }) => {
  const [activeTab, setActiveTab] = useState<AdminTab>('dashboard');
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [collapsedGroups, setCollapsedGroups] = useState<Record<string, boolean>>({
    operations: false,
    oversight: false,
    control: false
  });

  const toggleGroup = (group: string) => {
    if (isCollapsed) return;
    setCollapsedGroups(prev => ({ ...prev, [group]: !prev[group] }));
  };

  // Search/Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [providerFilter, setProviderFilter] = useState('All');
  
  // Modals / Details states
  const [selectedProvider, setSelectedProvider] = useState<ProviderOrg | null>(null);
  const [selectedStudent, setSelectedStudent] = useState<StudentAdminView | null>(null);

  const renderSidebarBtn = (tab: AdminTab, label: string, emoji: string) => {
    const isActive = activeTab === tab;
    return (
      <button
        onClick={() => setActiveTab(tab)}
        title={label}
        className={`w-full flex items-center rounded-xl text-xs font-semibold transition-all duration-200 cursor-pointer border-0 ${
          isCollapsed ? 'justify-center p-2.5' : 'gap-3 px-4 py-2.5'
        } ${
          isActive
            ? 'bg-[#2D5941] text-white shadow-md'
            : 'text-[#9BA89F] hover:bg-white/5 hover:text-white bg-transparent'
        }`}
      >
        <span className="text-sm">{emoji}</span>
        {!isCollapsed && <span>{label}</span>}
      </button>
    );
  };

  // MOCK STATES WITH INTERACTION
  const [providers, setProviders] = useState<ProviderOrg[]>([
    {
      id: 1,
      name: 'ABC Foundation',
      representative: 'Arianne Cruz',
      email: 'contact@abcfoundation.org',
      type: 'NGO',
      status: 'Pending',
      dateRegistered: 'Aug 09, 2026',
      documents: [
        { name: 'SEC Registration.pdf', url: '#', verified: false },
        { name: 'BIR Certificate.pdf', url: '#', verified: false },
        { name: 'Representative ID.pdf', url: '#', verified: false }
      ]
    },
    {
      id: 2,
      name: 'Department of Science and Technology',
      representative: 'Dr. Renato Solidum',
      email: 'sei@dost.gov.ph',
      type: 'Government',
      status: 'Verified',
      dateRegistered: 'Jun 10, 2025',
      documents: [
        { name: 'Government Charter.pdf', url: '#', verified: true },
        { name: 'DOST Authorization.pdf', url: '#', verified: true }
      ]
    },
    {
      id: 3,
      name: 'Megaworld Foundation',
      representative: 'Jose Mari Lim',
      email: 'grants@megaworld.com',
      type: 'Private',
      status: 'Under Review',
      dateRegistered: 'Aug 05, 2026',
      documents: [
        { name: 'SEC Registration.pdf', url: '#', verified: true },
        { name: 'Articles of Incorporation.pdf', url: '#', verified: false }
      ]
    },
    {
      id: 4,
      name: 'Starlight Grants Inc.',
      representative: 'Mark Robles',
      email: 'support@starlightgrants.xyz',
      type: 'Private',
      status: 'Suspended',
      dateRegistered: 'Feb 14, 2026',
      documents: [
        { name: 'SEC Registration.pdf', url: '#', verified: true }
      ]
    }
  ]);

  const [scholarships, setScholarships] = useState<ScholarshipAdminView[]>([
    { id: 101, title: 'DOST Merit Scholarship 2026', providerName: 'Department of Science and Technology', category: 'STEM', amount: 40000, status: 'Published', dateCreated: 'Aug 01, 2026' },
    { id: 102, title: 'ABC Tech Innovators Grant', providerName: 'ABC Foundation', category: 'Engineering & IT', amount: 25000, status: 'Pending Review', dateCreated: 'Aug 09, 2026' },
    { id: 103, title: 'Megaworld Leadership Scholarship', providerName: 'Megaworld Foundation', category: 'General Academic', amount: 50000, status: 'Pending Review', dateCreated: 'Aug 08, 2026' },
    { id: 104, title: 'Starlight Dreamer Grant', providerName: 'Starlight Grants Inc.', category: 'Arts', amount: 15000, status: 'Suspended', dateCreated: 'Feb 20, 2026' }
  ]);

  const [students, setStudents] = useState<StudentAdminView[]>([
    { id: 201, name: 'Juan Dela Cruz', email: 'juan.delacruz@up.edu.ph', school: 'University of the Philippines', gpa: '1.25', verificationStatus: 'Verified', accountStatus: 'Active' },
    { id: 202, name: 'Maria Santos', email: 'maria.santos@dlsu.edu.ph', school: 'De La Salle University', gpa: '1.40', verificationStatus: 'Verified', accountStatus: 'Active' },
    { id: 203, name: 'Ethan Gomez', email: 'ethan.gomez@ust.edu.ph', school: 'University of Santo Tomas', gpa: '1.85', verificationStatus: 'Pending', accountStatus: 'Active' },
    { id: 204, name: 'Angelo Reyes', email: 'angelo.reyes@mapua.edu.ph', school: 'Mapua University', gpa: '2.10', verificationStatus: 'Flagged', accountStatus: 'Suspended' }
  ]);

  const [reports, setReports] = useState<AdminReport[]>([
    { id: 1001, reportedEntity: 'Starlight Grants Inc.', type: 'Provider', reason: 'Suspicious fees requested during interview', reporter: 'Student #28491', status: 'Under Investigation', date: 'Aug 08, 2026' },
    { id: 1002, reportedEntity: 'ABC Tech Innovators Grant', type: 'Scholarship', reason: 'Misleading description of benefits', reporter: 'Student #11054', status: 'Under Investigation', date: 'Aug 09, 2026' }
  ]);

  const [transactions] = useState<TransactionRecord[]>([
    { id: 'TXN-82931', provider: 'Department of Science and Technology', scholar: 'Maria Santos', amount: 5000, status: 'COMPLETED', reference: 'REF-DOST-99281', date: 'Aug 09, 2026' },
    { id: 'TXN-82932', provider: 'Department of Science and Technology', scholar: 'Juan Dela Cruz', amount: 5000, status: 'COMPLETED', reference: 'REF-DOST-99282', date: 'Aug 09, 2026' },
    { id: 'TXN-82933', provider: 'ABC Foundation', scholar: 'Ethan Gomez', amount: 3500, status: 'PENDING', reference: 'REF-ABC-44120', date: 'Aug 08, 2026' },
    { id: 'TXN-82934', provider: 'Starlight Grants Inc.', scholar: 'Angelo Reyes', amount: 6000, status: 'FAILED', reference: 'REF-STAR-11029', date: 'Aug 04, 2026' }
  ]);

  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>([
    { id: 901, admin: 'admin01', action: 'LOGIN', target: 'System', date: 'Aug 09, 2026', time: '06:30 PM', ip: '192.168.1.45' },
    { id: 902, admin: 'admin01', action: 'SUSPENDED PROVIDER', target: 'Starlight Grants Inc.', date: 'Aug 09, 2026', time: '04:12 PM', ip: '192.168.1.45' },
    { id: 903, admin: 'admin02', action: 'APPROVED PROVIDER', target: 'Department of Science and Technology', date: 'Aug 08, 2026', time: '02:45 PM', ip: '192.168.1.99' }
  ]);

  // System Config States
  const [categories, setCategories] = useState(['STEM', 'Engineering & IT', 'General Academic', 'Arts', 'Sports', 'Agriculture']);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [announcementTarget, setAnnouncementTarget] = useState<'Students' | 'Providers' | 'Both'>('Both');
  const [announcementTitle, setAnnouncementTitle] = useState('');
  const [announcementBody, setAnnouncementBody] = useState('');

  const [adminsList, setAdminsList] = useState([
    { id: 1, username: 'admin01', role: 'Super Admin', status: 'Active' },
    { id: 2, username: 'admin02', role: 'Moderator', status: 'Active' },
    { id: 3, username: 'compliance_officer', role: 'Auditor', status: 'Active' }
  ]);

  const [newAdminUser, setNewAdminUser] = useState('');
  const [newAdminRole, setNewAdminRole] = useState('Moderator');

  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const addAuditLog = (action: string, target: string) => {
    const newLog: AuditLogEntry = {
      id: Date.now(),
      admin: 'admin01',
      action,
      target,
      date: 'Aug 09, 2026',
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      ip: '192.168.1.45'
    };
    setAuditLogs(prev => [newLog, ...prev]);
  };

  // HANDLERS
  const handleVerifyProvider = (id: number, nextStatus: ProviderOrg['status']) => {
    setProviders(prev =>
      prev.map(p => {
        if (p.id === id) {
          const updated = { ...p, status: nextStatus };
          if (selectedProvider && selectedProvider.id === id) {
            setSelectedProvider(updated);
          }
          return updated;
        }
        return p;
      })
    );
    const providerName = providers.find(p => p.id === id)?.name || 'Unknown';
    addAuditLog(`UPDATED PROVIDER STATUS: ${nextStatus}`, providerName);
    showToast(`Provider "${providerName}" status updated to ${nextStatus}.`);
  };

  const handleScholarshipAction = (id: number, action: 'Approved' | 'Rejected' | 'Suspended') => {
    setScholarships(prev =>
      prev.map(s => (s.id === id ? { ...s, status: action === 'Approved' ? 'Published' : action } : s))
    );
    const title = scholarships.find(s => s.id === id)?.title || 'Scholarship';
    addAuditLog(`${action.toUpperCase()} SCHOLARSHIP`, title);
    showToast(`Scholarship "${title}" is now ${action === 'Approved' ? 'Published' : action}.`);
  };

  const handleStudentStatus = (id: number, nextStatus: 'Active' | 'Suspended') => {
    setStudents(prev =>
      prev.map(s => {
        const updated = { ...s, accountStatus: nextStatus };
        if (selectedStudent && selectedStudent.id === id) {
          setSelectedStudent(updated);
        }
        return s.id === id ? updated : s;
      })
    );
    const name = students.find(s => s.id === id)?.name || 'Student';
    addAuditLog(`${nextStatus.toUpperCase()} STUDENT ACCOUNT`, name);
    showToast(`Student "${name}" account is now ${nextStatus}.`);
  };

  const handleReportAction = (id: number, action: 'Resolved' | 'Dismissed') => {
    setReports(prev => prev.map(r => (r.id === id ? { ...r, status: action } : r)));
    const report = reports.find(r => r.id === id);
    addAuditLog(`RESOLVED REPORT #${id}`, `${action} - ${report?.reportedEntity}`);
    showToast(`Report #${id} has been ${action}.`);
  };

  const handleSendAnnouncement = (e: React.FormEvent) => {
    e.preventDefault();
    if (!announcementTitle || !announcementBody) return;
    addAuditLog(`BROADCAST ANNOUNCEMENT`, `Target: ${announcementTarget} - Title: ${announcementTitle}`);
    showToast(`Announcement successfully sent to ${announcementTarget}!`);
    setAnnouncementTitle('');
    setAnnouncementBody('');
  };

  const handleCreateAdmin = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAdminUser) return;
    const newAdmin = {
      id: Date.now(),
      username: newAdminUser,
      role: newAdminRole,
      status: 'Active'
    };
    setAdminsList([...adminsList, newAdmin]);
    addAuditLog(`CREATED ADMIN ACCOUNT`, `${newAdminUser} (${newAdminRole})`);
    showToast(`Admin account "${newAdminUser}" created.`);
    setNewAdminUser('');
  };

  const handleToggleAdminStatus = (id: number) => {
    setAdminsList(prev =>
      prev.map(a => {
        if (a.id === id) {
          const nextStatus = a.status === 'Active' ? 'Disabled' : 'Active';
          addAuditLog(`TOGGLED ADMIN STATUS`, `${a.username} to ${nextStatus}`);
          showToast(`Admin "${a.username}" is now ${nextStatus}.`);
          return { ...a, status: nextStatus };
        }
        return a;
      })
    );
  };

  const handleAddCategory = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      const val = e.currentTarget.value.trim();
      if (val && !categories.includes(val)) {
        setCategories([...categories, val]);
        addAuditLog(`ADDED SCHOLARSHIP CATEGORY`, val);
        showToast(`Category "${val}" added.`);
        e.currentTarget.value = '';
      }
    }
  };

  return (
    <div className="min-h-screen bg-[#F9F5EF] flex font-sans relative">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-[#1A3C2E] text-[#F9F5EF] border border-[#2D5941] px-5 py-3 rounded-xl shadow-2xl flex items-center gap-2 animate-bounce">
          <svg className="w-5 h-5 text-[#E8A838]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="text-xs font-semibold">{toastMessage}</span>
        </div>
      )}

      {/* Sidebar Navigation */}
      <aside className={`transition-all duration-300 bg-[#1A3C2E] text-white flex flex-col justify-between shrink-0 shadow-xl border-r border-[#2D5941]/30 ${isCollapsed ? 'w-20' : 'w-64'}`}>
        <div className="p-4 overflow-y-auto">
          {/* Sidebar Header */}
          <div className={`flex items-center justify-between mb-8 ${isCollapsed ? 'flex-col gap-4' : ''}`}>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-[#2D5941] flex items-center justify-center text-white font-bold text-lg shadow-md font-serif shrink-0">
                IA
              </div>
              {!isCollapsed && (
                <div>
                  <h2 className="text-lg font-bold font-serif leading-none tracking-tight">IskolarAko</h2>
                  <span className="text-[10px] text-[#9BA89F] font-semibold uppercase tracking-wider">System Admin</span>
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={() => setIsCollapsed(!isCollapsed)}
              className="text-[#9BA89F] hover:text-white transition-colors cursor-pointer border-0 bg-transparent p-1"
              title={isCollapsed ? "Expand Sidebar" : "Collapse Sidebar"}
            >
              <svg className="w-5 h-5 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={isCollapsed ? "M9 5l7 7-7 7" : "M15 19l-7-7 7-7"} />
              </svg>
            </button>
          </div>

          {/* Navigation Links Grouped */}
          <nav className="space-y-4">
            {/* Group 1: Operations */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('operations')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Operations</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.operations ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.operations) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarBtn('dashboard', 'Dashboard', '📊')}
                  {renderSidebarBtn('providers', 'Provider Verification', '🏢')}
                  {renderSidebarBtn('scholarships', 'Scholarships', '🎓')}
                  {renderSidebarBtn('students', 'Student Management', '👨‍🎓')}
                </div>
              )}
            </div>

            {/* Group 2: Oversight */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('oversight')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Oversight</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.oversight ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.oversight) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarBtn('applications', 'Application Monitor', '📝')}
                  {renderSidebarBtn('documents', 'Docs Oversight', '📄')}
                  {renderSidebarBtn('reports', 'Reports & Complaints', '🚩')}
                  {renderSidebarBtn('funds', 'Fund Transactions', '💰')}
                </div>
              )}
            </div>

            {/* Group 3: Control */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('control')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Control</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.control ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.control) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarBtn('notifications', 'Broadcast Portal', '📢')}
                  {renderSidebarBtn('users', 'Admins & Roles', '👥')}
                  {renderSidebarBtn('logs', 'System Audit Logs', '📝')}
                  {renderSidebarBtn('settings', 'System Settings', '⚙️')}
                </div>
              )}
            </div>
          </nav>
        </div>

        {/* Footer Profile / Logout */}
        <div className={`p-4 border-t border-[#2D5941]/30 ${isCollapsed ? 'flex flex-col items-center gap-4' : 'space-y-4'}`}>
          {!isCollapsed ? (
            <>
              <div className="flex items-center gap-3 p-3 rounded-2xl bg-white/5 border border-white/10">
                <div className="w-8 h-8 rounded-full bg-[#2D5941] flex items-center justify-center font-bold text-white text-xs">AD</div>
                <div className="min-w-0 flex-1">
                  <h4 className="text-xs font-semibold truncate text-white">admin01</h4>
                  <p className="text-[10px] text-[#9BA89F] truncate">Super Admin</p>
                </div>
              </div>
              <button
                onClick={onLogout}
                className="w-full bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2.5 rounded-xl shadow-md cursor-pointer transition-colors border-0"
              >
                Sign Out
              </button>
            </>
          ) : (
            <>
              <div className="w-8 h-8 rounded-full bg-[#2D5941] flex items-center justify-center font-bold text-white text-xs" title="admin01 - Super Admin">AD</div>
              <button
                onClick={onLogout}
                className="text-[#9BA89F] hover:text-white cursor-pointer border-0 bg-transparent flex items-center justify-center"
                title="Sign Out"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
              </button>
            </>
          )}
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 p-8 overflow-y-auto max-w-7xl mx-auto space-y-6">
        
        {/* Module Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-extrabold text-[#1A3C2E] font-serif capitalize">
              {activeTab === 'logs' ? 'System Audit Logs' : activeTab === 'funds' ? 'Fund Release Monitoring' : activeTab === 'providers' ? 'Provider Verification & Verification Pipeline' : activeTab}
            </h1>
            <p className="text-xs text-[#6C6C70] mt-1">
              System Administration, trust moderation, and oversight metrics.
            </p>
          </div>
          {activeTab === 'dashboard' && (
            <span className="text-xs font-bold px-3 py-1.5 rounded-full bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
              Platform Status: Operational
            </span>
          )}
        </div>

        {/* 1. DASHBOARD MODULE */}
        {activeTab === 'dashboard' && (
          <div className="space-y-6">
            {/* Metric Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
                <span className="text-xs font-bold text-[#6C6C70] uppercase">Total Registered Students</span>
                <span className="text-3xl font-extrabold font-serif text-[#1A3C2E] mt-2">12,540</span>
              </div>
              <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
                <span className="text-xs font-bold text-[#6C6C70] uppercase">Scholarship Providers</span>
                <div className="flex items-baseline justify-between mt-2">
                  <span className="text-3xl font-extrabold font-serif text-[#1A3C2E]">184</span>
                  <span className="text-[10px] text-[#2D5941] bg-[#EBF5EE] font-bold px-2 py-0.5 rounded">151 Verified</span>
                </div>
              </div>
              <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
                <span className="text-xs font-bold text-[#6C6C70] uppercase">Pending Verifications</span>
                <div className="flex items-baseline justify-between mt-2">
                  <span className="text-3xl font-extrabold font-serif text-[#C97B2E]">23</span>
                  <span className="text-[10px] text-[#C97B2E] bg-[#FFF8EE] font-bold px-2 py-0.5 rounded">Requires Review</span>
                </div>
              </div>
              <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm flex flex-col justify-between">
                <span className="text-xs font-bold text-[#6C6C70] uppercase">Active Scholarships</span>
                <span className="text-3xl font-extrabold font-serif text-[#2D5941] mt-2">327</span>
              </div>
            </div>

            {/* Sub-Metrics Section */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
                <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Application Pipeline</h3>
                <div className="space-y-3">
                  <div className="flex justify-between text-xs">
                    <span className="text-[#6C6C70]">Pending Applications:</span>
                    <span className="font-bold text-[#1C1C1E]">1,842</span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-[#6C6C70]">Approved Scholars:</span>
                    <span className="font-bold text-[#2D5941]">1,200</span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-[#6C6C70]">Reported/Scam Flagged:</span>
                    <span className="font-bold text-[#B34040]">2</span>
                  </div>
                </div>
              </div>

              <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
                <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Finances</h3>
                <div className="space-y-3">
                  <div className="flex justify-between text-xs">
                    <span className="text-[#6C6C70]">Total Released:</span>
                    <span className="font-extrabold text-[#2D5941]">₱2,504,500</span>
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-[#6C6C70]">Pending Disbursements:</span>
                    <span className="font-bold text-[#C97B2E]">₱125,000</span>
                  </div>
                </div>
              </div>

              <div className="bg-white p-6 rounded-2xl border border-[#D9D2C5] shadow-sm">
                <h3 className="text-sm font-bold text-[#1A3C2E] uppercase border-b border-[#D9D2C5] pb-3 mb-4">Provider Verifications Panel</h3>
                <div className="flex gap-2">
                  <button
                    onClick={() => setActiveTab('providers')}
                    className="flex-1 text-center bg-[#2D5941] text-white text-xs font-bold py-2 px-3 rounded-xl hover:bg-[#1A3C2E] transition-colors cursor-pointer"
                  >
                    Pending List
                  </button>
                  <button
                    onClick={() => setActiveTab('reports')}
                    className="flex-1 text-center bg-[#C97B2E] text-white text-xs font-bold py-2 px-3 rounded-xl hover:bg-[#B56D24] transition-colors cursor-pointer"
                  >
                    View Reports
                  </button>
                </div>
              </div>
            </div>

            {/* Recent System Activity */}
            <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
              <h3 className="text-base font-bold text-[#1A3C2E] font-serif mb-4">Recent Audit Activity</h3>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs text-[#6C6C70]">
                  <thead>
                    <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                      <th className="py-2.5">Time</th>
                      <th>Admin</th>
                      <th>Action</th>
                      <th>Target Entity</th>
                      <th>IP Address</th>
                    </tr>
                  </thead>
                  <tbody>
                    {auditLogs.slice(0, 5).map(log => (
                      <tr key={log.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                        <td className="py-2">{log.date} {log.time}</td>
                        <td className="font-semibold text-[#1C1C1E]">{log.admin}</td>
                        <td>
                          <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                            log.action.includes('APPROVED') ? 'bg-[#EBF5EE] text-[#2D5941]' :
                            log.action.includes('SUSPENDED') ? 'bg-red-50 text-[#B34040]' :
                            'bg-[#EDE8DE] text-[#6C6C70]'
                          }`}>
                            {log.action}
                          </span>
                        </td>
                        <td>{log.target}</td>
                        <td className="font-mono text-[10px]">{log.ip}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 2. PROVIDER VERIFICATION MODULE */}
        {activeTab === 'providers' && (
          <div className="space-y-6">
            <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
              <div className="flex justify-between items-center mb-6">
                <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Verification Pipeline</h3>
                <div className="flex gap-2">
                  <select
                    value={providerFilter}
                    onChange={(e) => setProviderFilter(e.target.value)}
                    className="px-3 py-1.5 rounded-xl border border-[#D9D2C5] bg-white text-xs font-semibold"
                  >
                    <option value="All">All Statuses</option>
                    <option value="Pending">Pending</option>
                    <option value="Under Review">Under Review</option>
                    <option value="Verified">Verified</option>
                    <option value="Suspended">Suspended</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Providers Table / List */}
                <div className="lg:col-span-2 space-y-3">
                  {providers
                    .filter(p => providerFilter === 'All' || p.status === providerFilter)
                    .map(prov => (
                      <div
                        key={prov.id}
                        onClick={() => setSelectedProvider(prov)}
                        className={`p-4 rounded-xl border transition-all cursor-pointer flex justify-between items-center ${
                          selectedProvider?.id === prov.id
                            ? 'border-[#2D5941] bg-[#EBF5EE]/30'
                            : 'border-[#D9D2C5] bg-white hover:bg-[#F9F5EF]/50'
                        }`}
                      >
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-sm text-[#1C1C1E]">{prov.name}</span>
                            <span className="text-[10px] bg-[#EDE8DE] text-[#6C6C70] font-bold px-2 py-0.5 rounded">
                              {prov.type}
                            </span>
                          </div>
                          <p className="text-xs text-[#6C6C70] mt-1">Rep: {prov.representative} • {prov.email}</p>
                          <p className="text-[10px] text-[#8E8E93] mt-0.5">Registered: {prov.dateRegistered}</p>
                        </div>
                        <span className={`text-[10px] font-bold px-2 py-1 rounded-full ${
                          prov.status === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                          prov.status === 'Under Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                          prov.status === 'Suspended' ? 'bg-red-50 text-[#B34040]' :
                          'bg-[#EDE8DE] text-[#6C6C70]'
                        }`}>
                          {prov.status}
                        </span>
                      </div>
                    ))}
                </div>

                {/* Detail View Pane */}
                <div className="bg-[#F9F5EF]/50 border border-[#D9D2C5] rounded-2xl p-6">
                  {selectedProvider ? (
                    <div className="space-y-6">
                      <div>
                        <h4 className="font-bold text-base text-[#1A3C2E] font-serif">{selectedProvider.name}</h4>
                        <p className="text-xs text-[#6C6C70]">{selectedProvider.type} Scholarship Provider</p>
                      </div>

                      <div className="space-y-3 bg-white p-4 rounded-xl border border-[#D9D2C5] text-xs">
                        <div>
                          <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Representative</span>
                          <span className="text-[#1C1C1E] font-medium">{selectedProvider.representative}</span>
                        </div>
                        <div>
                          <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Email Address</span>
                          <span className="text-[#1C1C1E] font-medium">{selectedProvider.email}</span>
                        </div>
                      </div>

                      <div>
                        <h5 className="text-xs font-bold text-[#1C1C1E] uppercase mb-2">Submitted Verification Documents</h5>
                        <div className="space-y-2">
                          {selectedProvider.documents.map((doc, idx) => (
                            <div key={idx} className="flex justify-between items-center bg-white p-3 rounded-lg border border-[#D9D2C5]/50 text-xs">
                              <span className="font-medium text-[#1C1C1E]">{doc.name}</span>
                              <button
                                type="button"
                                onClick={() => showToast(`Simulating viewing of document: ${doc.name}`)}
                                className="text-[#2D5941] font-bold hover:underline cursor-pointer"
                              >
                                View File
                              </button>
                            </div>
                          ))}
                        </div>
                      </div>

                      <div className="flex flex-col gap-2 pt-4 border-t border-[#D9D2C5]">
                        <div className="flex gap-2">
                          <button
                            type="button"
                            onClick={() => handleVerifyProvider(selectedProvider.id, 'Verified')}
                            className="flex-1 bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                          >
                            Approve
                          </button>
                          <button
                            type="button"
                            onClick={() => handleVerifyProvider(selectedProvider.id, 'Under Review')}
                            className="flex-1 bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1C1C1E] text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                          >
                            Under Review
                          </button>
                        </div>
                        <div className="flex gap-2">
                          <button
                            type="button"
                            onClick={() => handleVerifyProvider(selectedProvider.id, 'Suspended')}
                            className="flex-1 bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                          >
                            Suspend
                          </button>
                          <button
                            type="button"
                            onClick={() => handleVerifyProvider(selectedProvider.id, 'Revoked')}
                            className="flex-1 bg-gray-600 hover:bg-gray-800 text-white text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                          >
                            Revoke
                          </button>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div className="h-full flex flex-col items-center justify-center text-center py-12 text-[#8E8E93]">
                      <svg className="w-10 h-10 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                      <p className="text-xs font-medium">Select a Provider from the pipeline to verify details.</p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 3. SCHOLARSHIP MANAGEMENT */}
        {activeTab === 'scholarships' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
            <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-4">Scholarship Governance</h3>
            <p className="text-xs text-[#6C6C70] mb-6">
              Review and moderate scholarships created by providers. All programs must be approved before publishing.
            </p>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs text-[#6C6C70]">
                <thead>
                  <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                    <th className="py-3">Title</th>
                    <th>Provider</th>
                    <th>Category</th>
                    <th>Grant Value</th>
                    <th>Status</th>
                    <th>Submitted</th>
                    <th className="text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {scholarships.map(s => (
                    <tr key={s.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                      <td className="py-4 font-bold text-[#1C1C1E]">{s.title}</td>
                      <td>{s.providerName}</td>
                      <td>{s.category}</td>
                      <td className="font-semibold text-[#2D5941]">₱{s.amount.toLocaleString()}/sem</td>
                      <td>
                        <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                          s.status === 'Published' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                          s.status === 'Pending Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                          'bg-red-50 text-[#B34040]'
                        }`}>
                          {s.status}
                        </span>
                      </td>
                      <td>{s.dateCreated}</td>
                      <td className="text-right">
                        <div className="flex justify-end gap-1.5">
                          {s.status === 'Pending Review' && (
                            <>
                              <button
                                type="button"
                                onClick={() => handleScholarshipAction(s.id, 'Approved')}
                                className="bg-[#2D5941] text-white hover:bg-[#1A3C2E] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                              >
                                Approve
                              </button>
                              <button
                                type="button"
                                onClick={() => handleScholarshipAction(s.id, 'Rejected')}
                                className="bg-[#B34040] text-white hover:bg-[#8E2F2F] px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer border-0"
                              >
                                Reject
                              </button>
                            </>
                          )}
                          {s.status === 'Published' && (
                            <button
                              type="button"
                              onClick={() => handleScholarshipAction(s.id, 'Suspended')}
                              className="bg-red-50 text-[#B34040] border border-solid border-[#B34040]/30 px-2.5 py-1 rounded text-[10px] font-bold cursor-pointer hover:bg-red-100"
                            >
                              Suspend
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* 4. STUDENT MANAGEMENT */}
        {activeTab === 'students' && (
          <div className="space-y-6">
            <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
              <div className="flex justify-between items-center mb-6">
                <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Registered Students</h3>
                <input
                  type="text"
                  placeholder="Search students..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="px-4 py-2 text-xs rounded-xl border border-[#D9D2C5] focus:outline-none w-64 bg-white"
                />
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Students List */}
                <div className="lg:col-span-2 space-y-3">
                  {students
                    .filter(s => s.name.toLowerCase().includes(searchQuery.toLowerCase()) || s.school.toLowerCase().includes(searchQuery.toLowerCase()))
                    .map(student => (
                      <div
                        key={student.id}
                        onClick={() => setSelectedStudent(student)}
                        className={`p-4 rounded-xl border transition-all cursor-pointer flex justify-between items-center ${
                          selectedStudent?.id === student.id
                            ? 'border-[#2D5941] bg-[#EBF5EE]/30'
                            : 'border-[#D9D2C5] bg-white hover:bg-[#F9F5EF]/50'
                        }`}
                      >
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-sm text-[#1C1C1E]">{student.name}</span>
                            <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded ${
                              student.verificationStatus === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                              student.verificationStatus === 'Pending' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                              'bg-red-50 text-[#B34040]'
                            }`}>
                              {student.verificationStatus}
                            </span>
                          </div>
                          <p className="text-xs text-[#6C6C70] mt-1">{student.school} • GPA: {student.gpa}</p>
                        </div>
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                          student.accountStatus === 'Active' ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-red-50 text-[#B34040]'
                        }`}>
                          {student.accountStatus}
                        </span>
                      </div>
                    ))}
                </div>

                {/* Detail Panel */}
                <div className="bg-[#F9F5EF]/50 border border-[#D9D2C5] rounded-2xl p-6">
                  {selectedStudent ? (
                    <div className="space-y-6">
                      <div>
                        <h4 className="font-bold text-base text-[#1A3C2E] font-serif">{selectedStudent.name}</h4>
                        <p className="text-xs text-[#6C6C70]">Profile and application audit</p>
                      </div>

                      <div className="space-y-3 bg-white p-4 rounded-xl border border-[#D9D2C5] text-xs">
                        <div>
                          <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Email Address</span>
                          <span className="text-[#1C1C1E] font-medium">{selectedStudent.email}</span>
                        </div>
                        <div>
                          <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Enrolled Institution</span>
                          <span className="text-[#1C1C1E] font-medium">{selectedStudent.school}</span>
                        </div>
                        <div>
                          <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Verification Status</span>
                          <span className="text-[#1C1C1E] font-medium">{selectedStudent.verificationStatus}</span>
                        </div>
                      </div>

                      <div className="pt-4 border-t border-[#D9D2C5] flex gap-2">
                        {selectedStudent.accountStatus === 'Active' ? (
                          <button
                            type="button"
                            onClick={() => handleStudentStatus(selectedStudent.id, 'Suspended')}
                            className="w-full bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                          >
                            Suspend Student Account
                          </button>
                        ) : (
                          <button
                            type="button"
                            onClick={() => handleStudentStatus(selectedStudent.id, 'Active')}
                            className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                          >
                            Reactivate Account
                          </button>
                        )}
                      </div>
                    </div>
                  ) : (
                    <div className="h-full flex flex-col items-center justify-center text-center py-12 text-[#8E8E93]">
                      <p className="text-xs font-medium">Select a student from the list to manage accounts.</p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 5. APPLICATION MONITORING */}
        {activeTab === 'applications' && (
          <div className="space-y-6">
            <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
              <h3 className="text-base font-bold text-[#1A3C2E] font-serif mb-4">Application Pipelines Dashboard</h3>
              <div className="grid grid-cols-5 gap-4 mb-6 text-center">
                <div className="p-3 bg-gray-50 rounded-xl border border-[#D9D2C5]/50">
                  <span className="text-lg font-bold text-gray-700">1,842</span>
                  <p className="text-[10px] text-gray-500 font-bold uppercase mt-1">Pending</p>
                </div>
                <div className="p-3 bg-amber-50 rounded-xl border border-[#C97B2E]/20">
                  <span className="text-lg font-bold text-[#C97B2E]">923</span>
                  <p className="text-[10px] text-[#C97B2E] font-bold uppercase mt-1">Under Review</p>
                </div>
                <div className="p-3 bg-[#EBF5EE] rounded-xl border border-[#2D5941]/20">
                  <span className="text-lg font-bold text-[#2D5941]">412</span>
                  <p className="text-[10px] text-[#2D5941] font-bold uppercase mt-1">Approved</p>
                </div>
                <div className="p-3 bg-red-50 rounded-xl border border-[#B34040]/20">
                  <span className="text-lg font-bold text-[#B34040]">301</span>
                  <p className="text-[10px] text-[#B34040] font-bold uppercase mt-1">Rejected</p>
                </div>
                <div className="p-3 bg-blue-50 rounded-xl border border-blue-200">
                  <span className="text-lg font-bold text-blue-700">76</span>
                  <p className="text-[10px] text-blue-500 font-bold uppercase mt-1">Withdrawn</p>
                </div>
              </div>

              <div className="overflow-x-auto text-xs text-[#6C6C70]">
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                      <th className="py-2.5">Student ID</th>
                      <th>Scholarship Program</th>
                      <th>Status</th>
                      <th>Last Provider Activity</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr className="border-b border-[#D9D2C5]/40 py-2">
                      <td className="py-2.5 font-bold text-[#1C1C1E]">STU-2931</td>
                      <td>DOST Merit Scholarship Program</td>
                      <td><span className="px-2 py-0.5 rounded bg-amber-50 text-[#C97B2E] font-bold text-[10px]">Under Review</span></td>
                      <td>3 hours ago by DOST Representative</td>
                    </tr>
                    <tr className="border-b border-[#D9D2C5]/40 py-2">
                      <td className="py-2.5 font-bold text-[#1C1C1E]">STU-1824</td>
                      <td>Tulong Dunong Financial Assistance</td>
                      <td><span className="px-2 py-0.5 rounded bg-[#EBF5EE] text-[#2D5941] font-bold text-[10px]">Approved</span></td>
                      <td>1 day ago by CHED Representative</td>
                    </tr>
                    <tr className="border-b border-[#D9D2C5]/40 py-2">
                      <td className="py-2.5 font-bold text-[#1C1C1E]">STU-0294</td>
                      <td>ABC Tech Innovators Grant</td>
                      <td><span className="px-2 py-0.5 rounded bg-gray-100 text-gray-700 font-bold text-[10px]">Pending</span></td>
                      <td>Stuck - 5 days without activity</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* 6. DOCUMENT MONITORING */}
        {activeTab === 'documents' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
            <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-4">Document Verification Logs</h3>
            <p className="text-xs text-[#6C6C70] mb-6">
              Track student requirement submissions and provider review logs. System admin provides oversight.
            </p>

            <div className="overflow-x-auto text-xs text-[#6C6C70]">
              <table className="w-full text-left">
                <thead>
                  <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                    <th className="py-2.5">Document ID</th>
                    <th>Student</th>
                    <th>Type</th>
                    <th>Provider Verification Status</th>
                    <th className="text-right">Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                    <td className="py-3 font-semibold text-[#1C1C1E]">DOC-77291</td>
                    <td>Maria Santos</td>
                    <td>Official Transcript of Records (GWA 1.25)</td>
                    <td><span className="text-[#2D5941] font-bold">Verified by DOST-SEI</span></td>
                    <td className="text-right">
                      <button type="button" onClick={() => showToast('Document flagged as: Verified')} className="text-gray-400 hover:text-red-500 font-bold border-0 bg-transparent cursor-pointer">Flag File</button>
                    </td>
                  </tr>
                  <tr className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                    <td className="py-3 font-semibold text-[#1C1C1E]">DOC-77292</td>
                    <td>Ethan Gomez</td>
                    <td>Certificate of Indigency</td>
                    <td><span className="text-[#C97B2E] font-bold">Under Review</span></td>
                    <td className="text-right">
                      <button type="button" onClick={() => showToast('Flagged document STU-1023 as suspicious.')} className="text-red-600 hover:underline font-bold border-0 bg-transparent cursor-pointer">Flag Suspicious</button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* 7. REPORTS & COMPLAINTS */}
        {activeTab === 'reports' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
            <div>
              <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">Escalations, Reports & Complaints</h3>
              <p className="text-xs text-[#6C6C70]">Help protect scholars by moderating flagged providers and scholarships.</p>
            </div>

            <div className="space-y-4">
              {reports.map(rep => (
                <div key={rep.id} className="p-5 border border-[#D9D2C5] rounded-2xl bg-[#F9F5EF]/30 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold text-[#1A3C2E] uppercase">REPORT #{rep.id}</span>
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded ${
                        rep.status === 'Resolved' ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-[#FFF8EE] text-[#C97B2E]'
                      }`}>{rep.status}</span>
                    </div>
                    <h4 className="text-sm font-bold text-[#1C1C1E]">
                      Reported {rep.type}: <strong className="text-[#2D5941]">{rep.reportedEntity}</strong>
                    </h4>
                    <p className="text-xs text-[#6C6C70]">
                      Reason: <span className="text-[#B34040] font-medium">"{rep.reason}"</span>
                    </p>
                    <p className="text-[10px] text-[#8E8E93]">Submitted by: {rep.reporter} on {rep.date}</p>
                  </div>
                  {rep.status === 'Under Investigation' && (
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => handleReportAction(rep.id, 'Resolved')}
                        className="bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold px-3 py-2 rounded-xl cursor-pointer border-0"
                      >
                        Dismiss Report
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          showToast(`Suspended associated Provider for Report #${rep.id}`);
                          handleReportAction(rep.id, 'Resolved');
                        }}
                        className="bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold px-3 py-2 rounded-xl cursor-pointer border-0"
                      >
                        Suspend Provider
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* 8. FUND RELEASE MONITORING */}
        {activeTab === 'funds' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
            <div>
              <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">Fund Release Ledgers</h3>
              <p className="text-xs text-[#6C6C70]">System admin monitors the transactions and audit reports without handling money directly.</p>
            </div>

            <div className="overflow-x-auto text-xs text-[#6C6C70]">
              <table className="w-full text-left">
                <thead>
                  <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                    <th className="py-2.5">Transaction ID</th>
                    <th>Provider</th>
                    <th>Scholar</th>
                    <th>Amount</th>
                    <th>Reference</th>
                    <th>Status</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {transactions.map(tx => (
                    <tr key={tx.id} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                      <td className="py-3 font-semibold text-[#1C1C1E]">{tx.id}</td>
                      <td>{tx.provider}</td>
                      <td className="font-semibold">{tx.scholar}</td>
                      <td className="font-bold text-[#2D5941]">₱{tx.amount.toLocaleString()}</td>
                      <td className="font-mono text-[10px]">{tx.reference}</td>
                      <td>
                        <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                          tx.status === 'COMPLETED' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                          tx.status === 'PENDING' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                          'bg-red-50 text-[#B34040]'
                        }`}>
                          {tx.status}
                        </span>
                      </td>
                      <td>{tx.date}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* 9. NOTIFICATIONS & ANNOUNCEMENTS */}
        {activeTab === 'notifications' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
            <div>
              <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">Broadcast System Announcement</h3>
              <p className="text-xs text-[#6C6C70]">Post system-wide notices, maintenance updates, or emergency scholarship notices.</p>
            </div>

            <form onSubmit={handleSendAnnouncement} className="space-y-4 max-w-lg">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Target Audience</label>
                <div className="flex bg-[#EDE8DE]/50 p-1 rounded-xl">
                  {['Students', 'Providers', 'Both'].map(target => (
                    <button
                      key={target}
                      type="button"
                      onClick={() => setAnnouncementTarget(target as any)}
                      className={`flex-1 py-2 text-xs font-bold rounded-lg transition-all cursor-pointer border-0 ${
                        announcementTarget === target ? 'bg-white text-[#2D5941] shadow-sm' : 'text-[#6C6C70]'
                      }`}
                    >
                      {target}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Title / Subject</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Scheduled System Upgrade on Aug 15"
                  value={announcementTitle}
                  onChange={(e) => setAnnouncementTitle(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-xl border border-solid border-[#D9D2C5] text-xs font-semibold focus:outline-none bg-white"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Body Message</label>
                <textarea
                  rows={4}
                  required
                  placeholder="Enter message details..."
                  value={announcementBody}
                  onChange={(e) => setAnnouncementBody(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-xl border border-solid border-[#D9D2C5] text-xs font-semibold focus:outline-none bg-white"
                />
              </div>

              <button
                type="submit"
                className="w-full bg-[#2D5941] text-white hover:bg-[#1A3C2E] py-3 rounded-xl text-xs font-bold shadow-md cursor-pointer transition-colors border-0"
              >
                Broadcast Announcement
              </button>
            </form>
          </div>
        )}

        {/* 10. USER & ROLE MANAGEMENT */}
        {activeTab === 'users' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
            <div>
              <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">User & Role Management</h3>
              <p className="text-xs text-[#6C6C70]">Configure permissions and create new administrative credentials (Super Admin, Moderator, Auditor).</p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Admins List */}
              <div className="lg:col-span-2 space-y-3">
                <h4 className="text-xs font-bold text-[#1A3C2E] uppercase">Administrative Accounts</h4>
                {adminsList.map(a => (
                  <div key={a.id} className="p-4 rounded-xl border border-[#D9D2C5] bg-white flex justify-between items-center">
                    <div>
                      <span className="font-bold text-sm text-[#1C1C1E]">{a.username}</span>
                      <p className="text-xs text-[#6C6C70] mt-0.5">Role: {a.role}</p>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        a.status === 'Active' ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-red-50 text-[#B34040]'
                      }`}>{a.status}</span>
                      <button
                        type="button"
                        onClick={() => handleToggleAdminStatus(a.id)}
                        className="text-xs text-[#2D5941] font-bold hover:underline cursor-pointer border-0 bg-transparent"
                      >
                        {a.status === 'Active' ? 'Disable' : 'Enable'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>

              {/* Add Admin form */}
              <div className="p-6 bg-[#F9F5EF]/50 rounded-2xl border border-[#D9D2C5] h-fit">
                <h4 className="text-xs font-bold text-[#1A3C2E] uppercase mb-4">Create Admin Account</h4>
                <form onSubmit={handleCreateAdmin} className="space-y-4">
                  <div>
                    <label className="block text-[10px] font-bold text-[#1C1C1E] uppercase mb-1">Username</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. admin_pascual"
                      value={newAdminUser}
                      onChange={(e) => setNewAdminUser(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white"
                    />
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-[#1C1C1E] uppercase mb-1">Role Type</label>
                    <select
                      value={newAdminRole}
                      onChange={(e) => setNewAdminRole(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white cursor-pointer"
                    >
                      <option value="Super Admin">Super Admin (All permissions)</option>
                      <option value="Moderator">Moderator (Verification & moderation)</option>
                      <option value="Auditor">Auditor (Read logs and ledger only)</option>
                    </select>
                  </div>
                  <button
                    type="submit"
                    className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0"
                  >
                    Add Admin
                  </button>
                </form>
              </div>
            </div>
          </div>
        )}

        {/* 11. AUDIT LOGS MODULE */}
        {activeTab === 'logs' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-4">
            <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Platform Audit Trail</h3>
            <p className="text-xs text-[#6C6C70]">
              Every administrative action is recorded. This log is immutable and complies with security requirements.
            </p>

            <div className="overflow-x-auto text-xs text-[#6C6C70]">
              <table className="w-full text-left">
                <thead>
                  <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                    <th className="py-2.5">Timestamp</th>
                    <th>Administrator</th>
                    <th>Action Executed</th>
                    <th>Target Object</th>
                    <th>IP Address</th>
                  </tr>
                </thead>
                <tbody>
                  {auditLogs.map(log => (
                    <tr key={log.id} className="border-b border-[#D9D2C5]/40 py-2.5 hover:bg-[#F9F5EF]/50">
                      <td className="py-2.5">{log.date} {log.time}</td>
                      <td className="font-semibold text-[#1C1C1E]">{log.admin}</td>
                      <td>
                        <span className="font-bold text-[#C97B2E]">{log.action}</span>
                      </td>
                      <td>{log.target}</td>
                      <td className="font-mono text-[10px] text-[#8E8E93]">{log.ip}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* 12. SYSTEM SETTINGS */}
        {activeTab === 'settings' && (
          <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
            <div>
              <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">System Config Settings</h3>
              <p className="text-xs text-[#6C6C70]">Set scholarship options and application processing variables.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              {/* Categories */}
              <div className="space-y-3">
                <h4 className="text-xs font-bold text-[#1C1C1E] uppercase">Scholarship Categories</h4>
                <div className="flex flex-wrap gap-2">
                  {categories.map(cat => (
                    <span key={cat} className="px-3 py-1 rounded-full bg-[#EDE8DE] text-xs font-semibold text-[#1C1C1E]">
                      {cat}
                    </span>
                  ))}
                </div>
                <input
                  type="text"
                  placeholder="Press Enter to add new category..."
                  onKeyDown={handleAddCategory}
                  className="w-full max-w-xs px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white mt-2"
                />
              </div>

              {/* Maintenance toggle */}
              <div className="space-y-4">
                <h4 className="text-xs font-bold text-[#1C1C1E] uppercase">System State</h4>
                <div className="flex items-center justify-between p-4 rounded-xl border border-[#D9D2C5] bg-[#F9F5EF]/20">
                  <div>
                    <span className="text-xs font-bold text-[#1C1C1E] block">Maintenance Mode</span>
                    <span className="text-[10px] text-[#6C6C70]">Suspends applications for students temporarily.</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      const next = !maintenanceMode;
                      setMaintenanceMode(next);
                      addAuditLog(`TOGGLED MAINTENANCE MODE`, next ? 'ON' : 'OFF');
                      showToast(`Maintenance mode turned ${next ? 'ON' : 'OFF'}.`);
                    }}
                    className={`px-4 py-2 rounded-xl text-xs font-bold cursor-pointer transition-colors border-0 ${
                      maintenanceMode ? 'bg-[#B34040] text-white' : 'bg-[#EDE8DE] text-[#1C1C1E]'
                    }`}
                  >
                    {maintenanceMode ? 'ACTIVE' : 'INACTIVE'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
};

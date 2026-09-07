import React, { useState, useEffect } from 'react';
import type { ProviderOrg, StudentAdminView } from '../types';

export type AnnouncementTargetType = 'Students' | 'Providers' | 'Both' | 'Specific Provider' | 'Specific Scholar';

interface AdminBroadcastItem {
  id: string | number;
  broadcastId?: string;
  title: string;
  body: string;
  target: AnnouncementTargetType | string;
  targetName?: string;
  author: string;
  date: string;
  recipientsCount?: number;
}

interface AdminNotificationsTabProps {
  handleSendAnnouncement: (e: React.FormEvent) => void;
  announcementTarget: AnnouncementTargetType;
  setAnnouncementTarget: (target: AnnouncementTargetType) => void;
  announcementTitle: string;
  setAnnouncementTitle: (title: string) => void;
  announcementBody: string;
  setAnnouncementBody: (body: string) => void;
  adminBroadcasts?: AdminBroadcastItem[];
  isSendingAnnouncement?: boolean;
  onDeleteBroadcast?: (id: string | number) => void;
  providers?: ProviderOrg[];
  students?: StudentAdminView[];
  selectedTargetProviderId?: string;
  setSelectedTargetProviderId?: (id: string) => void;
  selectedTargetUserId?: string;
  setSelectedTargetUserId?: (id: string) => void;
}

export const AdminNotificationsTab: React.FC<AdminNotificationsTabProps> = ({
  handleSendAnnouncement,
  announcementTarget,
  setAnnouncementTarget,
  announcementTitle,
  setAnnouncementTitle,
  announcementBody,
  setAnnouncementBody,
  adminBroadcasts = [],
  isSendingAnnouncement = false,
  onDeleteBroadcast,
  providers = [],
  students = [],
  selectedTargetProviderId = '',
  setSelectedTargetProviderId,
  selectedTargetUserId = '',
  setSelectedTargetUserId,
}) => {
  const [activeFilter, setActiveFilter] = useState<'All' | 'Both' | 'Students' | 'Providers' | 'Specific Provider' | 'Specific Scholar'>('All');
  const [currentPage, setCurrentPage] = useState<number>(1);
  const ITEMS_PER_PAGE = 5;

  const [providerSearch, setProviderSearch] = useState('');
  const [scholarSearch, setScholarSearch] = useState('');
  const [isProviderDropdownOpen, setIsProviderDropdownOpen] = useState(false);
  const [isScholarDropdownOpen, setIsScholarDropdownOpen] = useState(false);

  useEffect(() => {
    setCurrentPage(1);
  }, [activeFilter]);

  const applyTemplate = (type: 'maintenance' | 'deadline' | 'policy' | 'welcome') => {
    if (type === 'maintenance') {
      setAnnouncementTarget('Both');
      setAnnouncementTitle('Scheduled System Maintenance Notice');
      setAnnouncementBody('The IskoAko platform will undergo scheduled server maintenance this Saturday from 12:00 AM to 04:00 AM. Access may be momentarily unavailable during this window.');
    } else if (type === 'deadline') {
      setAnnouncementTarget('Students');
      setAnnouncementTitle('National Scholarship Application Cycle Approaching Deadline');
      setAnnouncementBody('Reminder: Several government and private scholarship application cycles are closing soon. Please ensure all required documents (TOR, COR, Income Certificate) are verified in your profile.');
    } else if (type === 'policy') {
      setAnnouncementTarget('Providers');
      setAnnouncementTitle('Updated Provider Evaluation & Disbursement Guidelines');
      setAnnouncementBody('Dear Scholarship Providers, please be advised that new guidelines on batch disbursement verification and AI compliance tracking have been issued in the admin handbook.');
    } else if (type === 'welcome') {
      setAnnouncementTarget('Both');
      setAnnouncementTitle('Welcome to Academic Year 2026-2027 on IskoAko!');
      setAnnouncementBody('We are excited to kick off the new academic year with expanded scholarship slots and streamlined direct payout integrations. Wishing all scholars and partners a fruitful year ahead!');
    }
  };

  const filteredBroadcasts = adminBroadcasts.filter(b => {
    if (activeFilter === 'All') return true;
    return b.target === activeFilter;
  });

  const filteredProviders = providers.filter(p => {
    if (!providerSearch.trim()) return true;
    const q = providerSearch.toLowerCase();
    return (
      (p.name && p.name.toLowerCase().includes(q)) ||
      (p.type && p.type.toLowerCase().includes(q)) ||
      (p.representative && p.representative.toLowerCase().includes(q)) ||
      (p.email && p.email.toLowerCase().includes(q))
    );
  });

  const filteredStudents = students.filter(s => {
    if (!scholarSearch.trim()) return true;
    const q = scholarSearch.toLowerCase();
    return (
      (s.name && s.name.toLowerCase().includes(q)) ||
      (s.email && s.email.toLowerCase().includes(q)) ||
      (s.school && s.school.toLowerCase().includes(q)) ||
      (s.course && s.course.toLowerCase().includes(q))
    );
  });

  const selectedProviderObj = providers.find(p => String(p.id) === String(selectedTargetProviderId));
  const selectedStudentObj = students.find(s => String(s.id) === String(selectedTargetUserId));

  const totalPages = Math.ceil(filteredBroadcasts.length / ITEMS_PER_PAGE) || 1;
  const safePage = Math.min(currentPage, totalPages);
  const startIndex = (safePage - 1) * ITEMS_PER_PAGE;
  const paginatedBroadcasts = filteredBroadcasts.slice(startIndex, startIndex + ITEMS_PER_PAGE);

  const isSubmitDisabled = isSendingAnnouncement || !announcementTitle.trim() || !announcementBody.trim() ||
    (announcementTarget === 'Specific Provider' && !selectedTargetProviderId) ||
    (announcementTarget === 'Specific Scholar' && !selectedTargetUserId);

  return (
    <div className="space-y-8 animate-fade-in">
      {/* ─── Hero Header & Stats ─── */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-gradient-to-r from-[#1A3C2E] via-[#244E3B] to-[#2D5941] text-white p-7 rounded-3xl shadow-lg border border-[#2D5941]/50 relative overflow-hidden">
        <div className="space-y-1 relative z-10">
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider bg-[#E8A838] text-[#1A3C2E]">
              System Administration
            </span>
            <span className="text-[11px] text-[#9BA89F] font-semibold">● Dedicated Broadcast Channels</span>
          </div>
          <h2 className="text-2xl lg:text-3xl font-extrabold font-serif tracking-tight text-white mt-1">
            System Announcements & Broadcast Portal
          </h2>
          <p className="text-xs text-[#E8A838]/90 max-w-xl leading-relaxed">
            Dispatch platform-wide announcements or send targeted broadcast notices directly to a specific provider organization or scholar account.
          </p>
        </div>

        <div className="flex items-center gap-3 shrink-0 relative z-10">
          <div className="bg-white/10 backdrop-blur-md px-4 py-3 rounded-2xl border border-white/15 text-center min-w-[90px]">
            <span className="text-xl font-black font-serif text-[#E8A838] block leading-none">{adminBroadcasts.length}</span>
            <span className="text-[10px] text-white/80 font-bold uppercase tracking-wider mt-1 block">Broadcasts</span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* ─── Broadcast Form (5 cols) ─── */}
        <div className="lg:col-span-5 bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-sm space-y-5">
          <div className="border-b border-[#D9D2C5]/40 pb-4">
            <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Broadcast Announcement</h3>
            <p className="text-xs text-[#6C6C70] mt-0.5">Dispatches in-app notifications and real-time push alerts.</p>
          </div>

          {/* Quick templates */}
          <div className="space-y-1.5">
            <span className="text-[10px] font-bold text-[#6C6C70] uppercase tracking-wider">Quick Templates:</span>
            <div className="flex flex-wrap gap-1.5">
              <button
                type="button"
                onClick={() => applyTemplate('maintenance')}
                className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-[#FFFFFF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                ⚙️ Maintenance
              </button>
              <button
                type="button"
                onClick={() => applyTemplate('deadline')}
                className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-[#FFFFFF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                ⏰ Deadline Notice
              </button>
              <button
                type="button"
                onClick={() => applyTemplate('policy')}
                className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-[#FFFFFF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                📜 Provider Policy
              </button>
              <button
                type="button"
                onClick={() => applyTemplate('welcome')}
                className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-[#FFFFFF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                🎉 Welcome A.Y.
              </button>
            </div>
          </div>

          <form onSubmit={handleSendAnnouncement} className="space-y-4">
            {/* Target Audience Selector */}
            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                Target Broadcast Audience
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-1.5 bg-[#FFFFFF] p-1.5 rounded-2xl border border-[#D9D2C5]/60">
                {[
                  { target: 'Both', label: '🌟 All Users' },
                  { target: 'Students', label: '👨‍🎓 All Scholars' },
                  { target: 'Providers', label: '🏢 All Providers' },
                ].map(item => (
                  <button
                    key={item.target}
                    type="button"
                    onClick={() => {
                      setAnnouncementTarget(item.target as AnnouncementTargetType);
                      setIsProviderDropdownOpen(false);
                      setIsScholarDropdownOpen(false);
                    }}
                    className={`py-2 px-1 text-xs font-bold rounded-xl transition-all cursor-pointer border-0 text-center ${
                      announcementTarget === item.target
                        ? 'bg-[#1A3C2E] text-white shadow-sm'
                        : 'text-[#6C6C70] hover:text-[#1A3C2E]'
                    }`}
                  >
                    {item.label}
                  </button>
                ))}
              </div>

              {/* Specific Target Channel Options */}
              <div className="grid grid-cols-2 gap-1.5 mt-2">
                <button
                  type="button"
                  onClick={() => {
                    setAnnouncementTarget('Specific Provider');
                    setIsProviderDropdownOpen(true);
                  }}
                  className={`py-2 px-2 text-xs font-bold rounded-xl border transition-all cursor-pointer text-center flex items-center justify-center gap-1.5 ${
                    announcementTarget === 'Specific Provider'
                      ? 'bg-[#1A3C2E] text-white border-[#1A3C2E] shadow-sm'
                      : 'bg-[#F9F5EF] text-[#2D5941] border-[#D9D2C5]/60 hover:bg-[#EDE8DE]'
                  }`}
                >
                  <span>🏢</span>
                  <span>Specific Provider</span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setAnnouncementTarget('Specific Scholar');
                    setIsScholarDropdownOpen(true);
                  }}
                  className={`py-2 px-2 text-xs font-bold rounded-xl border transition-all cursor-pointer text-center flex items-center justify-center gap-1.5 ${
                    announcementTarget === 'Specific Scholar'
                      ? 'bg-[#1A3C2E] text-white border-[#1A3C2E] shadow-sm'
                      : 'bg-[#F9F5EF] text-[#2D5941] border-[#D9D2C5]/60 hover:bg-[#EDE8DE]'
                  }`}
                >
                  <span>👤</span>
                  <span>Specific Scholar</span>
                </button>
              </div>
            </div>

            {/* Searchable Combobox: Specific Provider Selector */}
            {announcementTarget === 'Specific Provider' && (
              <div className="bg-[#EBF5EE] p-4 rounded-2xl border border-[#2D5941]/30 space-y-3 animate-fade-in">
                <div className="flex items-center justify-between">
                  <label className="block text-xs font-extrabold text-[#1A3C2E] uppercase tracking-wide">
                    Target Provider Organization
                  </label>
                  <span className="text-[10px] text-[#2D5941] font-semibold bg-[#2D5941]/10 px-2 py-0.5 rounded-full">
                    {providers.length} registered
                  </span>
                </div>

                {selectedProviderObj ? (
                  <div className="bg-white p-3 rounded-xl border border-[#2D5941]/30 shadow-xs flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-extrabold text-xs text-[#1A3C2E] truncate">{selectedProviderObj.name}</span>
                        <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-[#EDE8DE] text-[#1A3C2E] shrink-0">
                          {selectedProviderObj.type}
                        </span>
                      </div>
                      <p className="text-[11px] text-[#6C6C70] truncate mt-0.5">
                        {selectedProviderObj.representative} • {selectedProviderObj.email}
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        if (setSelectedTargetProviderId) setSelectedTargetProviderId('');
                        setIsProviderDropdownOpen(true);
                      }}
                      className="text-xs font-bold text-[#B34040] hover:text-[#8E2F2F] bg-red-50 hover:bg-red-100 px-2.5 py-1 rounded-lg border-0 cursor-pointer shrink-0 transition-colors"
                    >
                      Change ✕
                    </button>
                  </div>
                ) : (
                  <div className="relative space-y-1.5">
                    <div className="relative">
                      <input
                        type="text"
                        placeholder="🔍 Search provider by name, type, rep, or email..."
                        value={providerSearch}
                        onChange={(e) => {
                          setProviderSearch(e.target.value);
                          setIsProviderDropdownOpen(true);
                        }}
                        onFocus={() => setIsProviderDropdownOpen(true)}
                        className="w-full pl-3.5 pr-8 py-2.5 rounded-xl border border-[#2D5941]/40 text-xs font-semibold focus:outline-none focus:border-[#1A3C2E] bg-white text-[#1A3C2E]"
                      />
                      {providerSearch && (
                        <button
                          type="button"
                          onClick={() => setProviderSearch('')}
                          className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-gray-600 border-0 bg-transparent cursor-pointer"
                        >
                          ✕
                        </button>
                      )}
                    </div>

                    {isProviderDropdownOpen && (
                      <div className="bg-white border border-[#2D5941]/30 rounded-xl shadow-lg max-h-48 overflow-y-auto z-20 space-y-0.5 p-1 animate-fade-in">
                        {filteredProviders.length === 0 ? (
                          <div className="p-3 text-center text-xs text-[#6C6C70] font-medium">
                            No matching providers found for "{providerSearch}"
                          </div>
                        ) : (
                          filteredProviders.map(p => (
                            <button
                              key={p.id}
                              type="button"
                              onClick={() => {
                                if (setSelectedTargetProviderId) setSelectedTargetProviderId(String(p.id));
                                setIsProviderDropdownOpen(false);
                              }}
                              className="w-full text-left p-2.5 rounded-lg hover:bg-[#EBF5EE] transition-colors cursor-pointer border-0 flex items-center justify-between gap-2"
                            >
                              <div className="min-w-0">
                                <div className="font-bold text-xs text-[#1A3C2E] truncate">{p.name}</div>
                                <div className="text-[10px] text-[#6C6C70] truncate">
                                  {p.representative || p.email}
                                </div>
                              </div>
                              <span className="text-[10px] px-2 py-0.5 rounded-md bg-[#EDE8DE] text-[#1A3C2E] font-bold shrink-0">
                                {p.type}
                              </span>
                            </button>
                          ))
                        )}
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* Searchable Combobox: Specific Scholar Selector */}
            {announcementTarget === 'Specific Scholar' && (
              <div className="bg-[#EBF5EE] p-4 rounded-2xl border border-[#2D5941]/30 space-y-3 animate-fade-in">
                <div className="flex items-center justify-between">
                  <label className="block text-xs font-extrabold text-[#1A3C2E] uppercase tracking-wide">
                    Target Scholar / Student
                  </label>
                  <span className="text-[10px] text-[#2D5941] font-semibold bg-[#2D5941]/10 px-2 py-0.5 rounded-full">
                    {students.length} scholars
                  </span>
                </div>

                {selectedStudentObj ? (
                  <div className="bg-white p-3 rounded-xl border border-[#2D5941]/30 shadow-xs flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-extrabold text-xs text-[#1A3C2E] truncate">{selectedStudentObj.name}</span>
                        <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-blue-50 text-blue-800 shrink-0">
                          {selectedStudentObj.verificationStatus}
                        </span>
                      </div>
                      <p className="text-[11px] text-[#6C6C70] truncate mt-0.5">
                        {selectedStudentObj.email} • {selectedStudentObj.school} ({selectedStudentObj.course})
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        if (setSelectedTargetUserId) setSelectedTargetUserId('');
                        setIsScholarDropdownOpen(true);
                      }}
                      className="text-xs font-bold text-[#B34040] hover:text-[#8E2F2F] bg-red-50 hover:bg-red-100 px-2.5 py-1 rounded-lg border-0 cursor-pointer shrink-0 transition-colors"
                    >
                      Change ✕
                    </button>
                  </div>
                ) : (
                  <div className="relative space-y-1.5">
                    <div className="relative">
                      <input
                        type="text"
                        placeholder="🔍 Search scholar by name, email, or school..."
                        value={scholarSearch}
                        onChange={(e) => {
                          setScholarSearch(e.target.value);
                          setIsScholarDropdownOpen(true);
                        }}
                        onFocus={() => setIsScholarDropdownOpen(true)}
                        className="w-full pl-3.5 pr-8 py-2.5 rounded-xl border border-[#2D5941]/40 text-xs font-semibold focus:outline-none focus:border-[#1A3C2E] bg-white text-[#1A3C2E]"
                      />
                      {scholarSearch && (
                        <button
                          type="button"
                          onClick={() => setScholarSearch('')}
                          className="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-gray-600 border-0 bg-transparent cursor-pointer"
                        >
                          ✕
                        </button>
                      )}
                    </div>

                    {isScholarDropdownOpen && (
                      <div className="bg-white border border-[#2D5941]/30 rounded-xl shadow-lg max-h-48 overflow-y-auto z-20 space-y-0.5 p-1 animate-fade-in">
                        {filteredStudents.length === 0 ? (
                          <div className="p-3 text-center text-xs text-[#6C6C70] font-medium">
                            No matching scholars found for "{scholarSearch}"
                          </div>
                        ) : (
                          filteredStudents.map(s => (
                            <button
                              key={s.id}
                              type="button"
                              onClick={() => {
                                if (setSelectedTargetUserId) setSelectedTargetUserId(String(s.id));
                                setIsScholarDropdownOpen(false);
                              }}
                              className="w-full text-left p-2.5 rounded-lg hover:bg-[#EBF5EE] transition-colors cursor-pointer border-0 flex items-center justify-between gap-2"
                            >
                              <div className="min-w-0">
                                <div className="font-bold text-xs text-[#1A3C2E] truncate">{s.name}</div>
                                <div className="text-[10px] text-[#6C6C70] truncate">
                                  {s.email} • {s.school}
                                </div>
                              </div>
                              <span className="text-[10px] px-2 py-0.5 rounded-md bg-blue-50 text-blue-800 font-bold shrink-0">
                                {s.verificationStatus}
                              </span>
                            </button>
                          ))
                        )}
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* Title */}
            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                Title / Subject
              </label>
              <input
                type="text"
                required
                maxLength={100}
                placeholder="e.g. Scheduled System Upgrade or Direct Notice"
                value={announcementTitle}
                onChange={(e) => setAnnouncementTitle(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-semibold focus:outline-none focus:border-[#2D5941] bg-white"
              />
            </div>

            {/* Body */}
            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                Body Message
              </label>
              <textarea
                rows={5}
                required
                maxLength={1000}
                placeholder="Enter detailed broadcast notice, instructions, or direct channel message..."
                value={announcementBody}
                onChange={(e) => setAnnouncementBody(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-semibold focus:outline-none focus:border-[#2D5941] bg-white leading-relaxed"
              />
            </div>

            <button
              type="submit"
              disabled={isSubmitDisabled}
              className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] disabled:bg-[#D9D2C5] disabled:cursor-not-allowed text-white py-3.5 rounded-xl text-xs font-bold shadow-md cursor-pointer transition-colors border-0 flex items-center justify-center gap-2"
            >
              {isSendingAnnouncement ? (
                <>
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  <span>Dispatching Announcement...</span>
                </>
              ) : (
                <>
                  <span>📢</span>
                  <span>
                    {announcementTarget === 'Specific Provider'
                      ? 'Send Direct Announcement to Provider'
                      : announcementTarget === 'Specific Scholar'
                      ? 'Send Direct Announcement to Scholar'
                      : 'Broadcast System Announcement'}
                  </span>
                </>
              )}
            </button>
          </form>
        </div>

        {/* ─── Broadcast History (7 cols) ─── */}
        <div className="lg:col-span-7 space-y-6">
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-sm space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Sent Broadcast History</h3>
                <p className="text-xs text-[#6C6C70]">System notices logged to user inboxes</p>
              </div>

              {/* Filter Tabs */}
              <div className="flex flex-wrap items-center gap-1 bg-[#FFFFFF] p-1 rounded-xl border border-[#D9D2C5]/60">
                {['All', 'Both', 'Students', 'Providers', 'Specific Provider', 'Specific Scholar'].map(filter => (
                  <button
                    key={filter}
                    type="button"
                    onClick={() => setActiveFilter(filter as any)}
                    className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all border-0 cursor-pointer ${
                      activeFilter === filter
                        ? 'bg-[#2D5941] text-white shadow-xs'
                        : 'text-[#6C6C70] hover:text-[#1A3C2E]'
                    }`}
                  >
                    {filter === 'Specific Provider' ? '🏢 Direct Provider' : filter === 'Specific Scholar' ? '👤 Direct Scholar' : filter}
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="space-y-4">
            {filteredBroadcasts.length === 0 ? (
              <div className="bg-white rounded-3xl border border-dashed border-[#D9D2C5] p-12 text-center space-y-3">
                <div className="w-14 h-14 bg-[#EDE8DE] rounded-2xl flex items-center justify-center mx-auto text-2xl text-[#2D5941]">
                  📢
                </div>
                <h4 className="font-bold text-[#1A3C2E] font-serif text-base">No Broadcasts Found</h4>
                <p className="text-xs text-[#6C6C70] max-w-sm mx-auto">
                  System announcements you broadcast will appear here and be delivered directly to the inboxes of all targeted accounts.
                </p>
              </div>
            ) : (
              paginatedBroadcasts.map(bc => (
                <div
                  key={bc.id}
                  className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-sm space-y-3 hover:shadow-md transition-all animate-fade-in group"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="px-2.5 py-0.5 rounded-lg text-[10px] font-extrabold uppercase tracking-wide bg-purple-100 text-purple-800 border border-purple-200">
                          🏛️ System Announcement
                        </span>
                        <span className={`px-2.5 py-0.5 rounded-lg text-[10px] font-bold ${
                          bc.target === 'Specific Provider'
                            ? 'bg-amber-100 text-amber-900 border border-amber-300'
                            : bc.target === 'Specific Scholar'
                            ? 'bg-blue-100 text-blue-900 border border-blue-300'
                            : 'bg-[#EDE8DE] text-[#1A3C2E]'
                        }`}>
                          Target: {bc.targetName ? `${bc.target} (${bc.targetName})` : bc.target}
                        </span>
                        <span className="text-[10px] text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full font-bold">
                          ✓ Delivered
                        </span>
                      </div>
                      <h4 className="text-base font-bold text-[#1A3C2E] font-serif mt-2">
                        {bc.title}
                      </h4>
                      <span className="text-[11px] text-[#6C6C70] font-medium block mt-0.5">
                        Sent on {bc.date} by <strong>{bc.author}</strong>
                      </span>
                    </div>

                    {onDeleteBroadcast && (
                      <button
                        type="button"
                        onClick={() => {
                          if (window.confirm(`Delete broadcast "${bc.title}"?`)) {
                            onDeleteBroadcast(bc.broadcastId || bc.id);
                          }
                        }}
                        className="opacity-0 group-hover:opacity-100 transition-opacity text-xs text-red-600 hover:text-red-800 font-bold px-2.5 py-1 rounded-lg bg-red-50 hover:bg-red-100 border-0 cursor-pointer shrink-0"
                      >
                        Delete 🗑️
                      </button>
                    )}
                  </div>

                  <p className="text-xs text-[#48484A] leading-relaxed whitespace-pre-wrap">
                    {bc.body}
                  </p>
                </div>
              ))
            )}

            {/* Pagination Controls */}
            {filteredBroadcasts.length > ITEMS_PER_PAGE && (
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/70 p-4 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3 animate-fade-in">
                <span className="text-xs font-semibold text-[#6C6C70]">
                  Showing <strong className="text-[#1A3C2E]">{startIndex + 1}</strong> - <strong className="text-[#1A3C2E]">{Math.min(startIndex + ITEMS_PER_PAGE, filteredBroadcasts.length)}</strong> of <strong className="text-[#1A3C2E]">{filteredBroadcasts.length}</strong> broadcasts
                </span>

                <div className="flex items-center gap-1.5">
                  <button
                    type="button"
                    onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                    disabled={safePage <= 1}
                    className="px-3 py-1.5 rounded-xl text-xs font-bold bg-[#F9F5EF] hover:bg-[#EDE8DE] disabled:opacity-40 disabled:cursor-not-allowed text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer flex items-center gap-1"
                  >
                    <span>← Previous</span>
                  </button>

                  <div className="flex items-center gap-1 px-1">
                    {Array.from({ length: totalPages }, (_, i) => i + 1).map((pageNum) => (
                      <button
                        key={pageNum}
                        type="button"
                        onClick={() => setCurrentPage(pageNum)}
                        className={`w-8 h-8 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer flex items-center justify-center ${
                          safePage === pageNum
                            ? 'bg-[#1A3C2E] text-white shadow-sm font-extrabold'
                            : 'bg-[#F9F5EF] text-[#6C6C70] hover:bg-[#EDE8DE] hover:text-[#1A3C2E]'
                        }`}
                      >
                        {pageNum}
                      </button>
                    ))}
                  </div>

                  <button
                    type="button"
                    onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                    disabled={safePage >= totalPages}
                    className="px-3 py-1.5 rounded-xl text-xs font-bold bg-[#F9F5EF] hover:bg-[#EDE8DE] disabled:opacity-40 disabled:cursor-not-allowed text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer flex items-center gap-1"
                  >
                    <span>Next →</span>
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};


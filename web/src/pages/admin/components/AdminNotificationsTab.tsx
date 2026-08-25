import React, { useState } from 'react';

interface AdminBroadcastItem {
  id: string | number;
  broadcastId?: string;
  title: string;
  body: string;
  target: 'Students' | 'Providers' | 'Both' | string;
  author: string;
  date: string;
  recipientsCount?: number;
}

interface AdminNotificationsTabProps {
  handleSendAnnouncement: (e: React.FormEvent) => void;
  announcementTarget: 'Students' | 'Providers' | 'Both';
  setAnnouncementTarget: (target: 'Students' | 'Providers' | 'Both') => void;
  announcementTitle: string;
  setAnnouncementTitle: (title: string) => void;
  announcementBody: string;
  setAnnouncementBody: (body: string) => void;
  adminBroadcasts?: AdminBroadcastItem[];
  isSendingAnnouncement?: boolean;
  onDeleteBroadcast?: (id: string | number) => void;
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
}) => {
  const [activeFilter, setActiveFilter] = useState<'All' | 'Students' | 'Providers' | 'Both'>('All');

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

  return (
    <div className="space-y-8 animate-fade-in">
      {/* ─── Hero Header & Stats ─── */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-gradient-to-r from-[#1A3C2E] via-[#244E3B] to-[#2D5941] text-white p-7 rounded-3xl shadow-lg border border-[#2D5941]/50 relative overflow-hidden">
        <div className="space-y-1 relative z-10">
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider bg-[#E8A838] text-[#1A3C2E]">
              System Administration
            </span>
            <span className="text-[11px] text-[#9BA89F] font-semibold">● Platform-wide Notification System</span>
          </div>
          <h2 className="text-2xl lg:text-3xl font-extrabold font-serif tracking-tight text-white mt-1">
            System Announcements & Broadcasts
          </h2>
          <p className="text-xs text-[#E8A838]/90 max-w-xl leading-relaxed">
            Dispatch announcements directly to registered scholars, scholarship providers, or all accounts. Broadcasts are saved in real-time to users' database notification inboxes.
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
            <p className="text-xs text-[#6C6C70] mt-0.5">Dispatches in-app notifications and inbox alerts.</p>
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
            {/* Target Audience */}
            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                Target Audience
              </label>
              <div className="flex bg-[#FFFFFF] p-1 rounded-2xl border border-[#D9D2C5]/60">
                {[
                  { target: 'Both', label: '🌟 All Users' },
                  { target: 'Students', label: '👨‍🎓 Scholars Only' },
                  { target: 'Providers', label: '🏢 Providers Only' },
                ].map(item => (
                  <button
                    key={item.target}
                    type="button"
                    onClick={() => setAnnouncementTarget(item.target as any)}
                    className={`flex-1 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer border-0 ${
                      announcementTarget === item.target
                        ? 'bg-[#1A3C2E] text-white shadow-sm'
                        : 'text-[#6C6C70] hover:text-[#1A3C2E]'
                    }`}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Title */}
            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                Title / Subject
              </label>
              <input
                type="text"
                required
                maxLength={100}
                placeholder="e.g. Scheduled System Upgrade on Aug 15"
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
                placeholder="Enter detailed broadcast notice, instructions, or emergency updates..."
                value={announcementBody}
                onChange={(e) => setAnnouncementBody(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-[#D9D2C5] text-xs font-semibold focus:outline-none focus:border-[#2D5941] bg-white leading-relaxed"
              />
            </div>

            <button
              type="submit"
              disabled={isSendingAnnouncement || !announcementTitle.trim() || !announcementBody.trim()}
              className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] disabled:bg-[#D9D2C5] disabled:cursor-not-allowed text-white py-3.5 rounded-xl text-xs font-bold shadow-md cursor-pointer transition-colors border-0 flex items-center justify-center gap-2"
            >
              {isSendingAnnouncement ? (
                <>
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  <span>Sending System Broadcast...</span>
                </>
              ) : (
                <>
                  <span>📢</span>
                  <span>Broadcast System Announcement</span>
                </>
              )}
            </button>
          </form>
        </div>

        {/* ─── Broadcast History (7 cols) ─── */}
        <div className="lg:col-span-7 space-y-6">
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-sm space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Sent Broadcast History</h3>
                <p className="text-xs text-[#6C6C70]">System notices logged to user inboxes</p>
              </div>

              {/* Filter Tabs */}
              <div className="flex items-center gap-1 bg-[#FFFFFF] p-1 rounded-xl border border-[#D9D2C5]/60">
                {['All', 'Both', 'Students', 'Providers'].map(filter => (
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
                    {filter}
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
                <h4 className="font-bold text-[#1A3C2E] font-serif text-base">No Broadcasts Yet</h4>
                <p className="text-xs text-[#6C6C70] max-w-sm mx-auto">
                  System announcements you broadcast will appear here and be delivered directly to the inboxes of all targeted accounts.
                </p>
              </div>
            ) : (
              filteredBroadcasts.map(bc => (
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
                        <span className="px-2.5 py-0.5 rounded-lg text-[10px] font-bold bg-[#EDE8DE] text-[#1A3C2E]">
                          Target: {bc.target}
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
                            onDeleteBroadcast(bc.id);
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
          </div>
        </div>
      </div>
    </div>
  );
};

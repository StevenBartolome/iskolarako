import React from 'react';

interface AdminNotificationsTabProps {
  handleSendAnnouncement: (e: React.FormEvent) => void;
  announcementTarget: 'Students' | 'Providers' | 'Both';
  setAnnouncementTarget: (target: 'Students' | 'Providers' | 'Both') => void;
  announcementTitle: string;
  setAnnouncementTitle: (title: string) => void;
  announcementBody: string;
  setAnnouncementBody: (body: string) => void;
}

export const AdminNotificationsTab: React.FC<AdminNotificationsTabProps> = ({
  handleSendAnnouncement,
  announcementTarget,
  setAnnouncementTarget,
  announcementTitle,
  setAnnouncementTitle,
  announcementBody,
  setAnnouncementBody,
}) => {
  return (
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
  );
};

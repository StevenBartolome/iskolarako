import React from 'react';
import type { Program } from '../ProviderPortal';

interface RenewCycleModalProps {
  isOpen: boolean;
  program: Program | null;
  onClose: () => void;
  onSubmit: (e: React.FormEvent) => void;
  renewCycleName: string;
  setRenewCycleName: (val: string) => void;
  renewStartDate: string;
  setRenewStartDate: (val: string) => void;
  renewEndDate: string;
  setRenewEndDate: (val: string) => void;
  renewSlots: string;
  setRenewSlots: (val: string) => void;
  renewCycleType: 'new_applicant' | 'renewal';
  setRenewCycleType: (val: 'new_applicant' | 'renewal') => void;
  renewSemester: string;
  setRenewSemester: (val: string) => void;
}

export const RenewCycleModal: React.FC<RenewCycleModalProps> = ({
  isOpen,
  program,
  onClose,
  onSubmit,
  renewCycleName,
  setRenewCycleName,
  renewStartDate,
  setRenewStartDate,
  renewEndDate,
  setRenewEndDate,
  renewSlots,
  setRenewSlots,
  renewCycleType,
  setRenewCycleType,
  renewSemester,
  setRenewSemester,
}) => {
  if (!isOpen || !program) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden border border-[#D9D2C5]/30">
        <div className="bg-[#1A3C2E] p-6 text-white flex justify-between items-center">
          <div>
            <h3 className="text-lg font-bold font-serif">
              {renewCycleType === 'renewal' ? '🔄 Open Semestral Renewal Period' : '✨ New Application Cycle'}
            </h3>
            <p className="text-xs text-white/70 mt-1">For: {program.title}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-white/80 hover:text-white bg-transparent border-0 cursor-pointer text-xl"
          >&times;</button>
        </div>

        <form onSubmit={onSubmit} className="p-7 space-y-5">
          <div className="space-y-4">

            {/* Cycle Type Selector */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Cycle Purpose *</label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setRenewCycleType('renewal');
                    const year = new Date().getFullYear();
                    setRenewCycleName(`AY ${year}-${year + 1} • 2nd Sem Renewal`);
                  }}
                  className={`p-3 rounded-xl border text-left cursor-pointer transition-all ${
                    renewCycleType === 'renewal'
                      ? 'border-[#1A3C2E] bg-[#EBF5EE] text-[#1A3C2E] font-bold shadow-sm'
                      : 'border-[#D9D2C5] bg-white text-[#6C6C70] hover:bg-gray-50'
                  }`}
                >
                  <div className="text-xs font-bold flex items-center gap-1.5">
                    <span>🔄 Semestral Renewal</span>
                  </div>
                  <p className="text-[10.5px] text-[#6C6C70] mt-1">
                    For approved/continuing scholars submitting grades & COR
                  </p>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setRenewCycleType('new_applicant');
                    const year = new Date().getFullYear();
                    setRenewCycleName(`AY ${year + 1}-${year + 2}`);
                  }}
                  className={`p-3 rounded-xl border text-left cursor-pointer transition-all ${
                    renewCycleType === 'new_applicant'
                      ? 'border-[#1A3C2E] bg-[#EBF5EE] text-[#1A3C2E] font-bold shadow-sm'
                      : 'border-[#D9D2C5] bg-white text-[#6C6C70] hover:bg-gray-50'
                  }`}
                >
                  <div className="text-xs font-bold flex items-center gap-1.5">
                    <span>✨ New Applicant Batch</span>
                  </div>
                  <p className="text-[10.5px] text-[#6C6C70] mt-1">
                    For fresh applicants & incoming new scholars
                  </p>
                </button>
              </div>
            </div>

            {/* Semester Selection */}
            {renewCycleType === 'renewal' && (
              <div className="space-y-1">
                <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Academic Term / Semester *</label>
                <select
                  value={renewSemester}
                  onChange={(e) => {
                    const newSem = e.target.value;
                    setRenewSemester(newSem);
                    const year = new Date().getFullYear();
                    setRenewCycleName(`AY ${year}-${year + 1} • ${newSem} Renewal`);
                  }}
                  className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-xs font-bold font-sans"
                >
                  <option value="2nd Semester">2nd Semester (Mid-Year Renewal)</option>
                  <option value="1st Semester">1st Semester (Annual Continuing Renewal)</option>
                  <option value="Summer Term">Summer / Midyear Term</option>
                </select>
              </div>
            )}

            {/* Cycle Name */}
            <div className="space-y-1">
              <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Cycle Name *</label>
              <input
                type="text"
                required
                value={renewCycleName}
                onChange={(e) => setRenewCycleName(e.target.value)}
                placeholder="e.g. AY 2026-2027 • 2nd Sem Renewal"
                className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-sm font-sans"
              />
            </div>

            {/* Date Inputs */}
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Submission Start *</label>
                <input
                  type="date"
                  required
                  value={renewStartDate}
                  onChange={(e) => setRenewStartDate(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-sm font-sans"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Submission Deadline *</label>
                <input
                  type="date"
                  required
                  value={renewEndDate}
                  onChange={(e) => setRenewEndDate(e.target.value)}
                  min={renewStartDate}
                  className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-sm font-sans"
                />
              </div>
            </div>

            {/* Slots Available */}
            {renewCycleType === 'new_applicant' ? (
              <div className="space-y-1">
                <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Slots Available (Optional)</label>
                <input
                  type="number"
                  min="1"
                  value={renewSlots}
                  onChange={(e) => setRenewSlots(e.target.value)}
                  placeholder="Leave empty for unlimited slots"
                  className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-sm font-sans"
                />
              </div>
            ) : (
              <div className="p-3.5 rounded-xl bg-[#EBF5EE] border border-[#2D5941]/30 text-xs text-[#1A3C2E] flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-sm">👥</span>
                  <span className="font-bold">Renewal Slots:</span>
                </div>
                <span className="font-extrabold bg-[#1A3C2E] text-white px-3 py-1 rounded-full text-[11px] shadow-sm">
                  Unlimited (All Active Continuing Scholars)
                </span>
              </div>
            )}

            {renewCycleType === 'renewal' && (
              <div className="p-3.5 rounded-xl bg-amber-50 border border-amber-200 text-xs text-[#C97B2E] space-y-1">
                <div className="font-bold flex items-center gap-1">
                  <span>📢 Automatic Continuing Scholar Notification</span>
                </div>
                <p className="text-[11px] text-[#8C5216] leading-relaxed">
                  Publishing this cycle will automatically notify all currently approved scholars of <strong>{program.title}</strong> to submit their latest semester grade slip and enrollment proof (COR).
                </p>
              </div>
            )}

          </div>

          <div className="flex gap-3 pt-4 border-t border-[#D9D2C5]/30 justify-end">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-sm font-bold border-0 cursor-pointer transition-all"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-5 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-sm font-bold border-0 cursor-pointer transition-all shadow-md"
            >
              {renewCycleType === 'renewal' ? 'Open Renewal Period' : 'Confirm Cycle'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

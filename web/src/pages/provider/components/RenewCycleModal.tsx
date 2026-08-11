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
}) => {
  if (!isOpen || !program) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden border border-[#D9D2C5]/30">
        <div className="bg-[#1A3C2E] p-6 text-white flex justify-between items-center">
          <div>
            <h3 className="text-lg font-bold font-serif">Renew / Add Application Cycle</h3>
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
            {/* Cycle Name */}
            <div className="space-y-1">
              <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Cycle Name *</label>
              <input
                type="text"
                required
                value={renewCycleName}
                onChange={(e) => setRenewCycleName(e.target.value)}
                placeholder="e.g. AY 2027-2028"
                className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-sm font-sans"
              />
              <p className="text-[10px] text-[#6C6C70]">Suggested automatically based on the latest cycle.</p>
            </div>

            {/* Date Inputs */}
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Start Date *</label>
                <input
                  type="date"
                  required
                  value={renewStartDate}
                  onChange={(e) => setRenewStartDate(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-sm font-sans"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">End Date *</label>
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
            <div className="space-y-1">
              <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Slots Available (Optional)</label>
              <input
                type="number"
                min="1"
                value={renewSlots}
                onChange={(e) => setRenewSlots(e.target.value)}
                placeholder="Leave empty for unlimited/configured slots"
                className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-sm font-sans"
              />
            </div>
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
              className="px-5 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-sm font-bold border-0 cursor-pointer transition-all"
            >
              Confirm Renewal
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

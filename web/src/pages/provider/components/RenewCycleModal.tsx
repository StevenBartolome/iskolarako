import React, { useState } from 'react';
import type { Program } from '../ProviderPortal';

export interface RenewalRequirementItem {
  name: string;
  description: string;
}

interface RenewCycleModalProps {
  isOpen: boolean;
  program: Program | null;
  cycleToEdit?: any | null;
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
  renewRequirements: RenewalRequirementItem[];
  setRenewRequirements: (val: RenewalRequirementItem[]) => void;
}

const PRESET_REQUIREMENTS: RenewalRequirementItem[] = [
  {
    name: '1st Semester Official Grade Slip / Report of Grades',
    description: 'Signed copy or student portal screenshot of your 1st semester grades/GWA',
  },
  {
    name: 'Certificate of Registration (COR) / Enrollment Form (2nd Semester)',
    description: 'Official proof of enrollment for the upcoming semester with enrolled units',
  },
  {
    name: 'Certificate of Good Moral Character',
    description: 'Issued by your school dean, registrar, or office of student affairs',
  },
  {
    name: 'Barangay Certificate of Indigency',
    description: 'Recent certificate of economic indigency from your local barangay',
  },
  {
    name: 'Statement of Account / Tuition Assessment',
    description: 'Assessment of school fees and breakdown of tuition charges for the semester',
  },
];

export const RenewCycleModal: React.FC<RenewCycleModalProps> = ({
  isOpen,
  program,
  cycleToEdit,
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
  renewRequirements,
  setRenewRequirements,
}) => {
  const [customReqName, setCustomReqName] = useState('');
  const [customReqDesc, setCustomReqDesc] = useState('');

  if (!isOpen || !program) return null;

  const isEditing = Boolean(cycleToEdit);

  // Helper to calculate the current academic year from existing cycles
  const getCurrentAcademicYear = () => {
    if (renewCycleName) {
      const match = renewCycleName.match(/AY\s*(\d{4})[-–](\d{4})/i);
      if (match) return `AY ${match[1]}-${match[2]}`;
    }
    if (program.cycles && program.cycles.length > 0) {
      for (let i = program.cycles.length - 1; i >= 0; i--) {
        const c = program.cycles[i];
        const match = (c.name || '').match(/AY\s*(\d{4})[-–](\d{4})/i);
        if (match) return `AY ${match[1]}-${match[2]}`;
        const yrs = (c.name || '').match(/\d{4}/g);
        if (yrs && yrs.length >= 2) return `AY ${yrs[0]}-${yrs[1]}`;
      }
    }
    const curYear = new Date().getFullYear();
    return `AY ${curYear}-${curYear + 1}`;
  };

  // Helper to calculate the next academic year progression from existing cycles
  const getNextAcademicYear = () => {
    let nextStartYear = new Date().getFullYear();
    if (program.cycles && program.cycles.length > 0) {
      for (const c of program.cycles) {
        const match = (c.name || '').match(/20\d{2}/g);
        if (match && match.length > 0) {
          const parsedYears = match.map((y: string) => parseInt(y, 10));
          const maxYear = Math.max(...parsedYears);
          if (maxYear >= nextStartYear) {
            nextStartYear = maxYear;
          }
        }
      }
    }
    return `${nextStartYear}-${nextStartYear + 1}`;
  };

  const isPresetChecked = (presetName: string) => {
    return renewRequirements.some((r) => r.name === presetName);
  };

  const togglePreset = (preset: RenewalRequirementItem) => {
    if (isPresetChecked(preset.name)) {
      setRenewRequirements(renewRequirements.filter((r) => r.name !== preset.name));
    } else {
      setRenewRequirements([...renewRequirements, { name: preset.name, description: preset.description }]);
    }
  };

  const handleAddCustomReq = () => {
    const trimmedName = customReqName.trim();
    if (trimmedName && !renewRequirements.some((r) => r.name.toLowerCase() === trimmedName.toLowerCase())) {
      setRenewRequirements([
        ...renewRequirements,
        {
          name: trimmedName,
          description: customReqDesc.trim(),
        },
      ]);
      setCustomReqName('');
      setCustomReqDesc('');
    }
  };

  const handleRemoveReq = (nameToRemove: string) => {
    setRenewRequirements(renewRequirements.filter((r) => r.name !== nameToRemove));
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden border border-[#D9D2C5]/30">
        <div className="bg-[#1A3C2E] p-6 text-white flex justify-between items-center shrink-0">
          <div>
            <h3 className="text-lg font-bold font-serif">
              {isEditing
                ? `✏️ Edit Cycle: ${renewCycleName || 'Cycle'}`
                : renewCycleType === 'renewal'
                ? '🔄 Open Semestral Renewal Period'
                : '✨ New Application Cycle'}
            </h3>
            <p className="text-xs text-white/70 mt-1">For: {program.title}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-white/80 hover:text-white bg-transparent border-0 cursor-pointer text-xl"
          >&times;</button>
        </div>

        <form onSubmit={onSubmit} className="p-7 space-y-5 overflow-y-auto flex-1">
          <div className="space-y-4">

            {/* Cycle Type Selector */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Cycle Purpose *</label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setRenewCycleType('renewal');
                    if (!isEditing) {
                      const curAY = getCurrentAcademicYear();
                      const semTag = renewSemester === '2nd Semester' ? '2nd Sem' : (renewSemester || '2nd Sem');
                      setRenewCycleName(`${curAY} • ${semTag} Renewal`);
                    }
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
                    For approved/continuing scholars submitting renewal requirements
                  </p>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setRenewCycleType('new_applicant');
                    setRenewSemester('1st Semester');
                    if (!isEditing) {
                      const nextAy = getNextAcademicYear();
                      setRenewCycleName(`AY ${nextAy}`);
                    }
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
            <div className="space-y-1">
              <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Academic Term / Semester *</label>
              <select
                value={renewSemester}
                onChange={(e) => {
                  const newSem = e.target.value;
                  setRenewSemester(newSem);
                  if (renewCycleType === 'renewal') {
                    const curAY = getCurrentAcademicYear();
                    const semTag = newSem === '2nd Semester' ? '2nd Sem' : newSem;
                    setRenewCycleName(`${curAY} • ${semTag} Renewal`);
                  }
                }}
                className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-[#F9F5EF]/30 text-xs font-bold font-sans"
              >
                <option value="1st Semester">1st Semester (Annual Continuing Renewal / Initial Batch)</option>
                <option value="2nd Semester">2nd Semester (Mid-Year Renewal)</option>
                <option value="Summer Term">Summer / Midyear Term</option>
              </select>
            </div>

            {/* Cycle Name */}
            <div className="space-y-1">
              <label className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Cycle Name *</label>
              <input
                type="text"
                required
                value={renewCycleName}
                onChange={(e) => setRenewCycleName(e.target.value)}
                placeholder="e.g. AY 2027-2028 • 2nd Sem Renewal"
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

            {/* Requirements Section for Semestral Renewal */}
            {renewCycleType === 'renewal' && (
              <div className="space-y-3 p-4 rounded-2xl bg-[#F9F5EF] border border-[#D9D2C5]/60">
                <div>
                  <label className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wider block">
                    📋 Required Documents for this Renewal *
                  </label>
                  <p className="text-[11px] text-[#6C6C70] mt-0.5">
                    Scholars will be required to upload these documents before their renewal can be submitted.
                  </p>
                </div>

                {/* Preset Checkboxes */}
                <div className="space-y-2">
                  {PRESET_REQUIREMENTS.map((preset) => {
                    const isChecked = isPresetChecked(preset.name);
                    return (
                      <label
                        key={preset.name}
                        className={`flex items-start gap-2.5 p-2.5 rounded-xl border cursor-pointer transition-all ${
                          isChecked
                            ? 'bg-[#EBF5EE] border-[#1A3C2E]/40 text-[#1A3C2E]'
                            : 'bg-white border-[#D9D2C5]/70 text-[#1C1C1E] hover:bg-white/80'
                        }`}
                      >
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => togglePreset(preset)}
                          className="w-4 h-4 mt-0.5 rounded text-[#1A3C2E] focus:ring-[#1A3C2E] accent-[#1A3C2E]"
                        />
                        <div className="flex-1">
                          <span className="text-xs font-bold block">{preset.name}</span>
                          <span className="text-[10.5px] text-[#6C6C70] block leading-snug mt-0.5">
                            {preset.description}
                          </span>
                        </div>
                      </label>
                    );
                  })}
                </div>

                {/* Custom Requirements Adder */}
                <div className="pt-3 border-t border-[#D9D2C5]/40 space-y-2.5">
                  <span className="text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wider block">
                    + Add Custom Renewal Requirement
                  </span>
                  <div className="space-y-2">
                    <input
                      type="text"
                      value={customReqName}
                      onChange={(e) => setCustomReqName(e.target.value)}
                      placeholder="Requirement Name (e.g. Community Service Hours Log)"
                      className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-white text-xs font-sans font-medium"
                    />
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={customReqDesc}
                        onChange={(e) => setCustomReqDesc(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') {
                            e.preventDefault();
                            handleAddCustomReq();
                          }
                        }}
                        placeholder="Description / Instructions (Optional - e.g. Signed by coordinator)"
                        className="flex-1 px-3 py-2 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] bg-white text-xs font-sans"
                      />
                      <button
                        type="button"
                        onClick={handleAddCustomReq}
                        disabled={!customReqName.trim()}
                        className="px-4 py-2 rounded-xl bg-[#1A3C2E] text-white text-xs font-bold hover:bg-[#2D5941] disabled:opacity-50 border-0 cursor-pointer transition-all shrink-0"
                      >
                        + Add
                      </button>
                    </div>
                  </div>

                  {/* Active Custom Requirements List */}
                  {renewRequirements.filter((r) => !PRESET_REQUIREMENTS.some((p) => p.name === r.name)).length > 0 && (
                    <div className="space-y-1.5 pt-1">
                      {renewRequirements
                        .filter((r) => !PRESET_REQUIREMENTS.some((p) => p.name === r.name))
                        .map((customReq) => (
                          <div
                            key={customReq.name}
                            className="flex items-start justify-between gap-2 p-2.5 rounded-xl bg-[#1A3C2E] text-white text-xs"
                          >
                            <div className="flex-1 min-w-0">
                              <span className="font-bold block">{customReq.name}</span>
                              {customReq.description && customReq.description.trim().length > 0 && (
                                <span className="text-[10px] text-white/80 block mt-0.5 leading-snug">
                                  {customReq.description.trim()}
                                </span>
                              )}
                            </div>
                            <button
                              type="button"
                              onClick={() => handleRemoveReq(customReq.name)}
                              className="text-white/80 hover:text-white bg-transparent border-0 cursor-pointer text-sm leading-none p-1 shrink-0"
                              title="Remove"
                            >
                              &times;
                            </button>
                          </div>
                        ))}
                    </div>
                  )}
                </div>

                {renewRequirements.length === 0 && (
                  <p className="text-[11px] text-rose-600 font-medium">
                    ⚠️ Please select or add at least one required renewal document.
                  </p>
                )}
              </div>
            )}

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
                  Opening this renewal will notify all approved scholars of <strong>{program.title}</strong> with the requirement checklist ({renewRequirements.length} documents) and deadline.
                </p>
              </div>
            )}

          </div>

          <div className="flex gap-3 pt-4 border-t border-[#D9D2C5]/30 justify-end shrink-0">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-sm font-bold border-0 cursor-pointer transition-all"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={renewCycleType === 'renewal' && renewRequirements.length === 0}
              className={`px-5 py-2.5 rounded-xl text-white text-sm font-bold border-0 cursor-pointer transition-all shadow-md ${
                renewCycleType === 'renewal' && renewRequirements.length === 0
                  ? 'bg-gray-400 cursor-not-allowed'
                  : 'bg-[#1A3C2E] hover:bg-[#2D5941]'
              }`}
            >
              {isEditing
                ? 'Save Cycle Changes'
                : renewCycleType === 'renewal'
                ? 'Open Renewal Period'
                : 'Confirm Cycle'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};


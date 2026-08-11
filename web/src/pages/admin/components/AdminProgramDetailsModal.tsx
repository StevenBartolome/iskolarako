import React from 'react';

interface AdminProgramDetails {
  id: string;
  title: string;
  description: string;
  status: string;
  total_slots: number | null;
  funding_frequency: string;
  renewal_policy: string;
  course_eligibility: string[];
  scholarship_categories?: { name: string } | null;
  provider?: { name: string } | null;
}

interface AdminProgramDetailsModalProps {
  program: AdminProgramDetails | null;
  onClose: () => void;
}

export const AdminProgramDetailsModal: React.FC<AdminProgramDetailsModalProps> = ({
  program,
  onClose,
}) => {
  if (!program) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
      <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-8 max-w-lg w-full space-y-6 relative animate-fade-in max-h-[85vh] overflow-y-auto text-left">
        <button
          onClick={onClose}
          className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer bg-transparent border-0"
        >✕</button>

        <div>
          <span className="text-[9px] uppercase font-bold text-[#8E8E93] tracking-wider block mb-1">
            {program.scholarship_categories?.name || 'Category'}
          </span>
          <h3 className="text-2xl font-bold font-serif text-[#1A3C2E] leading-tight">
            {program.title}
          </h3>
          <p className="text-xs text-[#6C6C70] mt-1 font-medium">
            Provided by: <strong className="text-[#1A3C2E]">{program.provider?.name || 'Unknown Provider'}</strong>
          </p>
        </div>

        <div className="space-y-4 text-xs">
          <div className="bg-[#F9F5EF] rounded-2xl p-4 grid grid-cols-2 gap-4">
            <div>
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Status</span>
              <span className="font-bold text-[#1C1C1E] capitalize">{program.status}</span>
            </div>
            <div>
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Total Slots</span>
              <span className="font-bold text-[#1C1C1E]">{program.total_slots || 'Unlimited'}</span>
            </div>
            <div>
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Funding Freq</span>
              <span className="font-bold text-[#1C1C1E]">{program.funding_frequency || 'N/A'}</span>
            </div>
            <div>
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Renewal Policy</span>
              <span className="font-bold text-[#1C1C1E]">{program.renewal_policy || 'N/A'}</span>
            </div>
          </div>

          <div className="space-y-1.5">
            <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Description</span>
            <p className="text-[#6C6C70] leading-relaxed">{program.description}</p>
          </div>

          {program.course_eligibility && (
            <div className="space-y-1.5">
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Course Eligibility</span>
              <span className="font-semibold text-[#1C1C1E]">{program.course_eligibility.join(', ')}</span>
            </div>
          )}
        </div>

        <div className="flex justify-end pt-2">
          <button
            type="button"
            onClick={onClose}
            className="bg-[#2D5941] hover:bg-[#1A3C2E] text-white px-6 py-2.5 rounded-xl text-xs font-bold border-0 cursor-pointer shadow-sm"
          >
            Close View
          </button>
        </div>
      </div>
    </div>
  );
};

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
  budget_total: number | null;
  covers_tuition: boolean;
  covers_stipend: boolean;
  stipend_amount: number | null;
  covers_allowance: boolean;
  allowance_amount: number | null;
  covers_other: boolean;
  other_benefits: string[] | null;
  application_deadline: string | null;
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

  const formatCurrency = (amount: number | null) => {
    if (amount === null || amount === undefined) return 'N/A';
    return `₱${amount.toLocaleString()}`;
  };

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'Not set';
    return new Date(dateStr).toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
      <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-8 max-w-2xl w-full space-y-6 relative animate-fade-in max-h-[85vh] overflow-y-auto text-left">
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
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Funding Frequency</span>
              <span className="font-bold text-[#1C1C1E]">{program.funding_frequency || 'N/A'}</span>
            </div>
            <div>
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Renewal Policy</span>
              <span className="font-bold text-[#1C1C1E]">{program.renewal_policy || 'N/A'}</span>
            </div>
            <div className="col-span-2">
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Total Grant Value (Budget Total)</span>
              <span className="font-bold text-[#2D5941] text-lg">{formatCurrency(program.budget_total)}</span>
            </div>
          </div>

          <div className="bg-[#F9F5EF] rounded-2xl p-4 space-y-3">
            <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Coverage & Benefits</span>
            <div className="grid grid-cols-2 gap-3 text-[11px]">
              <div className={`p-2 rounded ${program.covers_tuition ? 'bg-green-50 text-green-800' : 'bg-gray-50 text-gray-500'}`}>
                <span className="font-bold">{program.covers_tuition ? '✓' : '✗'} Tuition</span>
                {program.covers_tuition && <span className="ml-2">Full coverage</span>}
              </div>
              <div className={`p-2 rounded ${program.covers_stipend ? 'bg-green-50 text-green-800' : 'bg-gray-50 text-gray-500'}`}>
                <span className="font-bold">{program.covers_stipend ? '✓' : '✗'} Stipend</span>
                {program.covers_stipend && program.stipend_amount && <span className="ml-2">{formatCurrency(program.stipend_amount)}/mo</span>}
              </div>
              <div className={`p-2 rounded ${program.covers_allowance ? 'bg-green-50 text-green-800' : 'bg-gray-50 text-gray-500'}`}>
                <span className="font-bold">{program.covers_allowance ? '✓' : '✗'} Allowance</span>
                {program.covers_allowance && program.allowance_amount && <span className="ml-2">{formatCurrency(program.allowance_amount)}</span>}
              </div>
              <div className={`p-2 rounded ${program.covers_other ? 'bg-green-50 text-green-800' : 'bg-gray-50 text-gray-500'}`}>
                <span className="font-bold">{program.covers_other ? '✓' : '—'} Other Benefits</span>
              </div>
            </div>
            {program.other_benefits && program.other_benefits.length > 0 && (
              <div className="text-[#6C6C70] leading-relaxed">
                <span className="font-bold">Details: </span>{program.other_benefits.join(', ')}
              </div>
            )}
          </div>

          <div className="space-y-1.5">
            <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Description</span>
            <p className="text-[#6C6C70] leading-relaxed">{program.description || 'No description provided.'}</p>
          </div>

          {program.course_eligibility && program.course_eligibility.length > 0 && (
            <div className="space-y-1.5">
              <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Course Eligibility</span>
              <span className="font-semibold text-[#1C1C1E]">{program.course_eligibility.join(', ')}</span>
            </div>
          )}

          <div className="space-y-1.5">
            <span className="text-[#8E8E93] font-bold uppercase tracking-wider text-[9px] block">Application Deadline</span>
            <span className="font-semibold text-[#1C1C1E]">{formatDate(program.application_deadline)}</span>
          </div>
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

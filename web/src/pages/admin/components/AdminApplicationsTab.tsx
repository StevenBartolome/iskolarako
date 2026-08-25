import React, { useState, useEffect } from 'react';
import { supabase } from '@/services/supabaseClient';

export const AdminApplicationsTab: React.FC = () => {
  const [applications, setApplications] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchApplications();
  }, []);

  const fetchApplications = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('scholarship_applications')
        .select(`
          id,
          status,
          created_at,
          updated_at,
          scholar:scholar_id (
            first_name,
            last_name
          ),
          cycle:cycle_id (
            cycle_name,
            program:program_id (
              title,
              provider:provider_id (
                name
              )
            )
          )
        `)
        .order('created_at', { ascending: false });

      if (!error && data) {
        setApplications(data);
      }
    } catch (err) {
      console.error('Error fetching admin applications:', err);
    } finally {
      setLoading(false);
    }
  };

  const counts = {
    pending: applications.filter(a => (a.status || '').toLowerCase() === 'pending').length,
    underReview: applications.filter(a => (a.status || '').toLowerCase() === 'under_review' || (a.status || '').toLowerCase() === 'for_exam').length,
    approved: applications.filter(a => (a.status || '').toLowerCase() === 'approved').length,
    rejected: applications.filter(a => (a.status || '').toLowerCase() === 'rejected').length,
    withdrawn: applications.filter(a => (a.status || '').toLowerCase() === 'withdrawn').length,
  };

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <h3 className="text-base font-bold text-[#1A3C2E] font-serif mb-4">Application Pipelines Dashboard</h3>
        
        {/* Real Dynamic Pipeline Counter Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-4 mb-6 text-center">
          <div className="p-3 bg-gray-50 rounded-xl border border-[#D9D2C5]/50">
            <span className="text-lg font-bold text-gray-700">{counts.pending}</span>
            <p className="text-[10px] text-gray-500 font-bold uppercase mt-1">Pending</p>
          </div>
          <div className="p-3 bg-amber-50 rounded-xl border border-[#C97B2E]/20">
            <span className="text-lg font-bold text-[#C97B2E]">{counts.underReview}</span>
            <p className="text-[10px] text-[#C97B2E] font-bold uppercase mt-1">Under Review</p>
          </div>
          <div className="p-3 bg-[#EBF5EE] rounded-xl border border-[#2D5941]/20">
            <span className="text-lg font-bold text-[#2D5941]">{counts.approved}</span>
            <p className="text-[10px] text-[#2D5941] font-bold uppercase mt-1">Approved</p>
          </div>
          <div className="p-3 bg-red-50 rounded-xl border border-[#B34040]/20">
            <span className="text-lg font-bold text-[#B34040]">{counts.rejected}</span>
            <p className="text-[10px] text-[#B34040] font-bold uppercase mt-1">Rejected</p>
          </div>
          <div className="p-3 bg-blue-50 rounded-xl border border-blue-200">
            <span className="text-lg font-bold text-blue-700">{counts.withdrawn}</span>
            <p className="text-[10px] text-blue-500 font-bold uppercase mt-1">Withdrawn</p>
          </div>
        </div>

        <div className="overflow-x-auto text-xs text-[#6C6C70]">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
                <th className="py-2.5">Application ID / Student</th>
                <th>Scholarship Program</th>
                <th>Status</th>
                <th>Last Update</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={4} className="py-8 text-center text-xs text-[#6C6C70] italic">
                    Loading pipeline applications from database...
                  </td>
                </tr>
              ) : applications.length === 0 ? (
                <tr>
                  <td colSpan={4} className="py-8 text-center text-xs text-[#6C6C70] italic">
                    No applications found in system.
                  </td>
                </tr>
              ) : (
                applications.map(app => {
                  const studentName = app.scholar
                    ? `${app.scholar.first_name || ''} ${app.scholar.last_name || ''}`.trim()
                    : `APP-${app.id.toString().substring(0, 6)}`;
                  const programTitle = app.cycle?.program?.title || 'Scholarship Program';
                  const providerName = app.cycle?.program?.provider?.name || 'Provider';
                  const status = (app.status || 'pending').toLowerCase();

                  let statusBadge = <span className="px-2 py-0.5 rounded bg-gray-100 text-gray-700 font-bold text-[10px]">Pending</span>;
                  if (status === 'approved') {
                    statusBadge = <span className="px-2 py-0.5 rounded bg-[#EBF5EE] text-[#2D5941] font-bold text-[10px]">Approved</span>;
                  } else if (status === 'under_review' || status === 'for_exam') {
                    statusBadge = <span className="px-2 py-0.5 rounded bg-amber-50 text-[#C97B2E] font-bold text-[10px]">Under Review</span>;
                  } else if (status === 'rejected') {
                    statusBadge = <span className="px-2 py-0.5 rounded bg-red-50 text-[#B34040] font-bold text-[10px]">Rejected</span>;
                  } else if (status === 'withdrawn') {
                    statusBadge = <span className="px-2 py-0.5 rounded bg-blue-50 text-blue-700 font-bold text-[10px]">Withdrawn</span>;
                  }

                  const dateStr = app.updated_at
                    ? new Date(app.updated_at).toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' })
                    : 'Recently';

                  return (
                    <tr key={app.id} className="border-b border-[#D9D2C5]/40 py-2 hover:bg-[#F9F5EF]/30">
                      <td className="py-2.5 font-bold text-[#1C1C1E]">{studentName}</td>
                      <td>{programTitle} <span className="text-[10px] text-[#8E8E93]">({providerName})</span></td>
                      <td>{statusBadge}</td>
                      <td>{dateStr}</td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

import React from 'react';
import type { ProviderOrg, AdminTab } from '../types';
import { supabase } from '@/services/supabaseClient';

interface AdminProvidersTabProps {
  providerFilter: string;
  setProviderFilter: (filter: string) => void;
  providers: ProviderOrg[];
  selectedProvider: ProviderOrg | null;
  setSelectedProvider: (prov: ProviderOrg | null) => void;
  providerRequirementsMap: Record<string, { name: string; description: string; required: boolean }[]>;
  isChecklistCollapsed: boolean;
  setIsChecklistCollapsed: (collapsed: boolean) => void;
  isOversightCollapsed: boolean;
  setIsOversightCollapsed: (collapsed: boolean) => void;
  loadingPrograms: boolean;
  providerPrograms: any[];
  setSelectedScholarshipDetails: (prog: any) => void;
  setActiveTab: (tab: AdminTab) => void;
  handleVerifyProvider: (id: any, status: ProviderOrg['status']) => void;
}

export const AdminProvidersTab: React.FC<AdminProvidersTabProps> = ({
  providerFilter,
  setProviderFilter,
  providers,
  selectedProvider,
  setSelectedProvider,
  providerRequirementsMap,
  isChecklistCollapsed,
  setIsChecklistCollapsed,
  isOversightCollapsed,
  setIsOversightCollapsed,
  loadingPrograms,
  providerPrograms,
  setSelectedScholarshipDetails,
  setActiveTab,
  handleVerifyProvider,
}) => {
  return (
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

                {(() => {
                  const typeKey = selectedProvider.type === 'Government' ? 'public' : selectedProvider.type === 'Private' ? 'private' : 'ngo';
                  const reqs = providerRequirementsMap[typeKey] || [];
                  return (
                    <div className="space-y-4">
                      <div className="border-t border-[#D9D2C5] pt-4">
                        <button
                          type="button"
                          onClick={() => setIsChecklistCollapsed(!isChecklistCollapsed)}
                          className="w-full flex justify-between items-center text-xs font-bold text-[#1C1C1E] uppercase cursor-pointer border-0 bg-transparent mb-2"
                        >
                          <span>Requirements Checklist</span>
                          <svg className={`w-3.5 h-3.5 transition-transform duration-200 ${isChecklistCollapsed ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                          </svg>
                        </button>
                        
                        {!isChecklistCollapsed && (
                          <div className="space-y-2 mt-2">
                            {reqs.map((req, idx) => {
                              const submittedDoc = selectedProvider.documents.find(d => d.name === req.name);
                              const isPassed = !!submittedDoc;

                              return (
                                <div key={idx} className="p-3.5 bg-white rounded-xl border border-[#D9D2C5]/50 text-xs flex flex-col gap-1.5 shadow-sm">
                                  <div className="flex justify-between items-start">
                                    <div>
                                      <span className="font-bold text-[#1A3C2E]">{req.name}</span>
                                      {req.required && (
                                        <span className="ml-1.5 text-[8px] bg-red-50 text-red-600 font-bold px-1.5 py-0.5 rounded border border-red-200">REQ</span>
                                      )}
                                    </div>
                                    <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded font-sans ${
                                      isPassed ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-amber-50 text-[#C97B2E]'
                                    }`}>
                                      {isPassed ? 'Passed' : 'Not Yet'}
                                    </span>
                                  </div>
                                  <p className="text-[10px] text-[#6C6C70] font-sans leading-normal">{req.description}</p>
                                  
                                  {isPassed && submittedDoc && (
                                    <div className="flex justify-end pt-1.5 border-t border-dashed border-[#D9D2C5]/40 mt-1">
                                      {submittedDoc.url && submittedDoc.url !== '#' ? (
                                        <a
                                          href={submittedDoc.url}
                                          target="_blank"
                                          rel="noreferrer"
                                          className="text-[10px] font-bold text-[#2D5941] hover:underline flex items-center gap-0.5"
                                        >
                                          Preview Submitted Document &rarr;
                                        </a>
                                      ) : (
                                        <span className="text-[10px] text-gray-400 italic font-sans">Mock Document Attached</span>
                                      )}
                                    </div>
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })()}

                {selectedProvider.remarks && (
                  <div className="bg-red-50/50 border border-red-200/40 text-red-900 rounded-xl p-4 text-xs font-sans space-y-1">
                    <strong>{selectedProvider.status === 'Suspended' ? 'Active Suspension Remarks:' : 'Active Rejection Remarks:'}</strong>
                    <p className="leading-relaxed">{selectedProvider.remarks}</p>
                  </div>
                )}

                {/* Provider's Scholarship Programs Oversight Section */}
                <div className="space-y-3 pt-4 border-t border-[#D9D2C5]">
                  <button
                    type="button"
                    onClick={() => setIsOversightCollapsed(!isOversightCollapsed)}
                    className="w-full flex justify-between items-center text-xs font-bold text-[#1C1C1E] uppercase cursor-pointer border-0 bg-transparent mb-2"
                  >
                    <span>Scholarship Programs Oversight</span>
                    <svg className={`w-3.5 h-3.5 transition-transform duration-200 ${isOversightCollapsed ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  
                  {!isOversightCollapsed && (
                    <>
                      {loadingPrograms ? (
                        <div className="text-xs text-[#6C6C70] italic">Loading programs...</div>
                      ) : providerPrograms.length === 0 ? (
                        <div className="text-xs text-[#6C6C70] italic bg-white p-3 rounded-xl border border-[#D9D2C5]/50">No scholarship programs configured yet.</div>
                      ) : (
                        <div className="space-y-2 max-h-48 overflow-y-auto pr-1 mt-2">
                          {providerPrograms.map((prog) => (
                            <div key={prog.id} className="p-3 bg-white rounded-xl border border-[#D9D2C5]/50 text-xs flex justify-between items-center shadow-sm">
                              <div className="space-y-0.5">
                                <div className="font-bold text-[#1A3C2E] truncate max-w-[130px]" title={prog.title}>{prog.title}</div>
                                <div className="text-[10px] text-[#6C6C70]">Slots: {prog.total_slots || 'Unlimited'} • {prog.funding_frequency}</div>
                              </div>
                              <div className="flex items-center gap-1.5">
                                <span className={`text-[9px] font-bold px-2 py-0.5 rounded ${
                                  prog.status === 'Active' || prog.status === 'active' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                                  prog.status === 'Closed' || prog.status === 'closed' ? 'bg-red-50 text-[#B34040]' :
                                  'bg-[#EDE8DE] text-[#6C6C70]'
                                }`}>
                                  {prog.status}
                                </span>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    try {
                                      const { data: fullProg } = await supabase
                                        .from('scholarship_programs')
                                        .select(`
                                          *,
                                          provider ( name ),
                                          scholarship_categories ( name )
                                        `)
                                        .eq('id', prog.id)
                                        .single();

                                      if (fullProg) {
                                        setSelectedScholarshipDetails(fullProg);
                                        setActiveTab('scholarships');
                                      }
                                    } catch (e) {
                                      console.error(e);
                                    }
                                  }}
                                  className="bg-[#2D5941] text-white hover:bg-[#1A3C2E] px-2 py-1 rounded text-[9px] font-bold cursor-pointer border-0"
                                >
                                  View
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </>
                  )}
                </div>

                <div className="flex flex-col gap-2 pt-4 border-t border-[#D9D2C5]">
                  {selectedProvider.status === 'Verified' ? (
                    <>
                      <button
                        type="button"
                        onClick={() => handleVerifyProvider(selectedProvider.id, 'Suspended')}
                        className="w-full bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0 shadow-sm transition-all"
                      >
                        ⛔ Suspend with Remarks
                      </button>
                      <p className="text-[10px] text-[#6C6C70] font-sans text-center leading-relaxed">
                        Suspending requires the provider to re-upload and re-submit their verification documents.
                      </p>
                    </>
                  ) : selectedProvider.status === 'Suspended' ? (
                    <div className="bg-amber-50 border border-amber-200/60 text-amber-900 rounded-xl p-3 text-xs font-sans leading-relaxed">
                      This provider is <strong>suspended</strong>. Approval is locked until they re-upload and re-submit
                      their verification documents.
                    </div>
                  ) : (
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => handleVerifyProvider(selectedProvider.id, 'Verified')}
                        className="flex-1 bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0 shadow-sm transition-all"
                      >
                        Approve
                      </button>
                      <button
                        type="button"
                        onClick={() => handleVerifyProvider(selectedProvider.id, 'Suspended')}
                        className="flex-1 bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0 shadow-sm transition-all"
                      >
                        Reject
                      </button>
                    </div>
                  )}
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
  );
};

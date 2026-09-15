import React, { useState, useEffect } from 'react';
import { GoogleMap, Autocomplete } from '@react-google-maps/api';
import {
  Eye,
  EyeOff,
  FileText,
  Coins,
  ClipboardList,
  GraduationCap,
  Megaphone,
  Target,
  Users,
  User,
  MapPin,
  Map as MapIcon,
  AlertTriangle,
  Send,
  Search,
  Trash2,
  ExternalLink,
} from 'lucide-react';
import type { AnnType, Program } from '../types';

interface Announcement {
  id: string | number;
  broadcastId?: string;
  type: AnnType;
  title: string;
  body: string;
  date: string;
  audience: string;
  author: string;
  location?: string;
  coordinates?: { lat: number; lng: number };
  recipientsCount?: number;
}

interface ProviderAnnouncementsTabProps {
  handleAddAnnouncement: (e: React.FormEvent) => void;
  newAnnType: AnnType;
  setNewAnnType: (type: AnnType) => void;
  newAnnAudience: string;
  setNewAnnAudience: (aud: string) => void;
  selectedProgramId?: string;
  setSelectedProgramId?: (id: string) => void;
  programsList?: Program[];
  setIsBigMapModalOpen: (open: boolean) => void;
  isLoaded: boolean;
  onAutocompleteLoad: (autocomplete: google.maps.places.Autocomplete) => void;
  onPlaceChanged: () => void;
  mapSearchText: string;
  setMapSearchText: (text: string) => void;
  examCoords: { lat: number; lng: number; address: string };
  mapZoom: number;
  setMapZoom: React.Dispatch<React.SetStateAction<number>>;
  handleMapClick: (e: google.maps.MapMouseEvent) => void;
  newAnnTitle: string;
  setNewAnnTitle: (title: string) => void;
  newAnnBody: string;
  setNewAnnBody: (body: string) => void;
  announcements: Announcement[];
  onDeleteAnnouncement?: (id: string | number) => void;
  isBroadcasting?: boolean;
  applicantsList?: any[];
  scholarsList?: any[];
  selectedTargetUserId?: string;
  setSelectedTargetUserId?: (id: string) => void;
}

export const ProviderAnnouncementsTab: React.FC<ProviderAnnouncementsTabProps> = ({
  handleAddAnnouncement,
  newAnnType,
  setNewAnnType,
  newAnnAudience,
  setNewAnnAudience,
  selectedProgramId = 'all',
  setSelectedProgramId,
  programsList = [],
  setIsBigMapModalOpen,
  isLoaded,
  onAutocompleteLoad,
  onPlaceChanged,
  mapSearchText,
  setMapSearchText,
  examCoords,
  mapZoom,
  setMapZoom,
  handleMapClick,
  newAnnTitle,
  setNewAnnTitle,
  newAnnBody,
  setNewAnnBody,
  announcements,
  onDeleteAnnouncement,
  isBroadcasting = false,
  applicantsList = [],
  scholarsList = [],
  selectedTargetUserId = '',
  setSelectedTargetUserId,
}) => {
  const [filterType, setFilterType] = useState<string>('All');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [showPreview, setShowPreview] = useState<boolean>(false);
  const [currentPage, setCurrentPage] = useState<number>(1);
  const ITEMS_PER_PAGE = 2;

  // Build unique person options (scholars + applicants) for direct individual announcements
  const personOptions = React.useMemo(() => {
    const map = new Map<string, { userId: string; name: string; email: string; program: string; role: string; school: string }>();

    (applicantsList || []).forEach((app: any) => {
      const uId = app.rawApplication?.scholar?.user_id || app.rawApplication?.scholar?.user?.id || app.scholarId;
      if (!uId) return;
      const key = String(uId);
      if (!map.has(key)) {
        map.set(key, {
          userId: String(uId),
          name: app.name || 'Applicant',
          email: app.email || 'N/A',
          program: app.program || 'Scholarship Program',
          role: app.status === 'Approved' ? 'Scholar' : 'Applicant',
          school: app.school || 'N/A',
        });
      }
    });

    (scholarsList || []).forEach((sch: any) => {
      const uId = sch.appDetail?.rawApplication?.scholar?.user_id || sch.appDetail?.scholarId;
      if (!uId) return;
      const key = String(uId);
      if (!map.has(key)) {
        map.set(key, {
          userId: String(uId),
          name: sch.scholarName || 'Scholar',
          email: sch.appDetail?.email || 'N/A',
          program: sch.programTitle || 'Scholarship Program',
          role: 'Scholar',
          school: sch.appDetail?.school || 'N/A',
        });
      }
    });

    return Array.from(map.values()).sort((a, b) => a.name.localeCompare(b.name));
  }, [applicantsList, scholarsList]);

  // Quick Template helper
  const applyTemplate = (templateType: string) => {
    if (templateType === 'exam') {
      setNewAnnType('Examination Schedule');
      setNewAnnTitle('Schedule of Qualifying Examinations & Screening');
      setNewAnnBody('All shortlisted candidates are requested to appear at the designated examination center. Please bring your valid School ID, 2x2 photo, pencil (2B), and examination permit. Latecomers will not be entertained.');
    } else if (templateType === 'fund') {
      setNewAnnType('Release of Funds');
      setNewAnnTitle('Stipend & Allowance Disbursement Notice');
      setNewAnnBody('We are pleased to inform you that your semester stipend and book allowance have been processed for bank crediting. Please verify your verified payment account details in the portal.');
    } else if (templateType === 'reqs') {
      setNewAnnType('Requirements Update');
      setNewAnnTitle('Submission Deadline for 2nd Semester Grades & COR');
      setNewAnnBody('All continuing scholars must upload their certified true copy of grades and official Certificate of Registration (COR) through the IskoAko portal on or before the indicated cutoff date.');
    } else if (templateType === 'orientation') {
      setNewAnnType('General Notice');
      setNewAnnTitle('General Assembly & Scholar Orientation');
      setNewAnnBody('Join us for the annual Scholar Orientation and Awarding Assembly. Important reminders regarding academic retention requirements and special projects will be discussed.');
    }
  };

  // Filtered announcements
  const filteredAnnouncements = announcements.filter((ann) => {
    const q = searchQuery.toLowerCase().trim();
    const matchesSearch =
      !q ||
      ann.title?.toLowerCase().includes(q) ||
      ann.body?.toLowerCase().includes(q) ||
      ann.audience?.toLowerCase().includes(q) ||
      ann.location?.toLowerCase().includes(q);

    if (!matchesSearch) return false;
    if (filterType === 'All') return true;
    if (filterType === 'Exam') return ann.type === 'Examination Schedule' || ann.type?.toLowerCase().includes('exam');
    if (filterType === 'Funds') return ann.type === 'Release of Funds' || ann.type?.toLowerCase().includes('fund');
    if (filterType === 'Reqs') return ann.type === 'Requirements Update' || ann.type?.toLowerCase().includes('req');
    if (filterType === 'General') return ann.type === 'General Notice' || ann.type?.toLowerCase().includes('general');
    return false;
  });

  const totalExams = announcements.filter(a => a.type === 'Examination Schedule' || a.type?.toLowerCase().includes('exam')).length;
  const totalFunds = announcements.filter(a => a.type === 'Release of Funds' || a.type?.toLowerCase().includes('fund')).length;
  const totalReqs = announcements.filter(a => a.type === 'Requirements Update' || a.type?.toLowerCase().includes('req')).length;
  const totalGeneral = announcements.filter(a => a.type === 'General Notice' || a.type?.toLowerCase().includes('general')).length;

  useEffect(() => {
    setCurrentPage(1);
  }, [filterType, searchQuery]);

  const totalPages = Math.ceil(filteredAnnouncements.length / ITEMS_PER_PAGE) || 1;
  const safePage = Math.min(currentPage, totalPages);
  const startIndex = (safePage - 1) * ITEMS_PER_PAGE;
  const paginatedAnnouncements = filteredAnnouncements.slice(startIndex, startIndex + ITEMS_PER_PAGE);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* ─── Hero Header & Stats ─── */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-gradient-to-r from-[#1A3C2E] via-[#244E3B] to-[#2D5941] text-white p-5 rounded-3xl shadow-lg border border-[#2D5941]/50 relative overflow-hidden">
        {/* Background glow circle */}
        <div className="absolute top-0 right-0 -mr-16 -mt-16 w-64 h-64 bg-[#E8A838]/10 rounded-full blur-3xl pointer-events-none" />

        <div className="relative z-10 space-y-0.5">
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider bg-[#E8A838] text-[#1A3C2E]">
              Scholar Broadcast Center
            </span>
            <span className="text-[11px] text-[#9BA89F] font-semibold">● Direct Scholar Inbox Sync</span>
          </div>
          <h2 className="text-xl lg:text-2xl font-extrabold font-serif tracking-tight text-white mt-0.5">
            Announcements & Notices
          </h2>
          <p className="text-[11.5px] text-[#E8A838]/90 max-w-xl leading-relaxed">
            Dispatch announcements directly into registered scholars' and applicants' inboxes. Schedule examinations with venue pins, release payout alerts, or issue requirements updates.
          </p>
        </div>

        {/* Mini stats cards */}
        <div className="relative z-10 flex items-center gap-2.5 shrink-0">
          <div className="bg-white/10 backdrop-blur-md px-3.5 py-2.5 rounded-2xl border border-white/15 text-center min-w-[76px]">
            <span className="text-lg font-black font-serif text-[#E8A838] block leading-none">{announcements.length}</span>
            <span className="text-[9.5px] text-white/80 font-bold uppercase tracking-wider mt-0.5 block">Total Sent</span>
          </div>
          <div className="bg-white/10 backdrop-blur-md px-3.5 py-2.5 rounded-2xl border border-white/15 text-center min-w-[76px]">
            <span className="text-lg font-black font-serif text-white block leading-none">{totalExams}</span>
            <span className="text-[9.5px] text-white/80 font-bold uppercase tracking-wider mt-0.5 block">Exams</span>
          </div>
          <div className="bg-white/10 backdrop-blur-md px-3.5 py-2.5 rounded-2xl border border-white/15 text-center min-w-[76px]">
            <span className="text-lg font-black font-serif text-white block leading-none">{totalFunds}</span>
            <span className="text-[9.5px] text-white/80 font-bold uppercase tracking-wider mt-0.5 block">Fund Releases</span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* ─── Left Column: Broadcast Composer (5 cols) ─── */}
        <div className="lg:col-span-5 bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-sm space-y-4">
          <div className="flex items-center justify-between border-b border-[#D9D2C5]/40 pb-3">
            <div>
              <h3 className="font-bold text-[#1A3C2E] font-serif text-base leading-tight">Create Broadcast</h3>
              <p className="text-[10.5px] text-[#6C6C70] mt-0.5">Saves to scholars' database notification inbox</p>
            </div>
            <button
              type="button"
              onClick={() => setShowPreview(!showPreview)}
              className="text-[10.5px] font-bold text-[#2D5941] hover:text-[#1A3C2E] bg-[#EBF5EE] hover:bg-[#EDE8DE] px-2.5 py-1 rounded-xl transition-colors border-0 cursor-pointer flex items-center gap-1.5"
            >
              {showPreview ? (
                <>
                  <EyeOff className="w-3.5 h-3.5" />
                  <span>Hide Preview</span>
                </>
              ) : (
                <>
                  <Eye className="w-3.5 h-3.5" />
                  <span>Preview</span>
                </>
              )}
            </button>
          </div>

          {/* Quick Template Pills */}
          <div className="space-y-1">
            <span className="text-[9.5px] font-bold text-[#6C6C70] uppercase tracking-wider">Quick Templates:</span>
            <div className="flex flex-wrap gap-1">
              <button
                type="button"
                onClick={() => applyTemplate('exam')}
                className="inline-flex items-center gap-1 px-2 py-0.5 text-[10.5px] font-semibold rounded-lg bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                <FileText className="w-3 h-3 text-[#2D5941]" /> Exam Screening
              </button>
              <button
                type="button"
                onClick={() => applyTemplate('fund')}
                className="inline-flex items-center gap-1 px-2 py-0.5 text-[10.5px] font-semibold rounded-lg bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                <Coins className="w-3 h-3 text-amber-600" /> Payout Alert
              </button>
              <button
                type="button"
                onClick={() => applyTemplate('reqs')}
                className="inline-flex items-center gap-1 px-2 py-0.5 text-[10.5px] font-semibold rounded-lg bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                <ClipboardList className="w-3 h-3 text-purple-600" /> Grades & COR
              </button>
              <button
                type="button"
                onClick={() => applyTemplate('orientation')}
                className="inline-flex items-center gap-1 px-2 py-0.5 text-[10.5px] font-semibold rounded-lg bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer"
              >
                <GraduationCap className="w-3 h-3 text-emerald-600" /> Orientation
              </button>
            </div>
          </div>

          <form onSubmit={handleAddAnnouncement} className="space-y-3">
            {/* Category Selector */}
            <div>
              <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                Announcement Category
              </label>
              <div className="grid grid-cols-2 gap-1.5">
                {[
                  { value: 'General Notice', label: 'General Notice', icon: Megaphone },
                  { value: 'Examination Schedule', label: 'Exam Schedule', icon: FileText },
                  { value: 'Release of Funds', label: 'Release Funds', icon: Coins },
                  { value: 'Requirements Update', label: 'Requirements', icon: ClipboardList },
                ].map(cat => {
                  const IconComp = cat.icon;
                  return (
                    <button
                      key={cat.value}
                      type="button"
                      onClick={() => setNewAnnType(cat.value as AnnType)}
                      className={`py-2 px-2.5 rounded-xl text-[11px] font-bold text-left transition-all border cursor-pointer inline-flex items-center gap-1.5 ${
                        newAnnType === cat.value
                          ? 'bg-[#1A3C2E] text-white border-[#1A3C2E] shadow-xs'
                          : 'bg-[#F9F5EF] text-[#1C1C1E] border-[#D9D2C5]/80 hover:bg-[#EDE8DE]'
                      }`}
                    >
                      <IconComp className="w-3.5 h-3.5 shrink-0" />
                      <span>{cat.label}</span>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Audience / Program Selector */}
            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide">
                  Target Audience / Program
                </label>
                {newAnnType === 'Examination Schedule' ? (
                  <span className="inline-flex items-center gap-1 text-[9.5px] font-extrabold text-amber-700 bg-amber-100/80 px-1.5 py-0.5 rounded-md">
                    <Target className="w-3 h-3 text-amber-600" /> for_exam status only
                  </span>
                ) : selectedProgramId === 'single_person' ? (
                  <span className="inline-flex items-center gap-1 text-[9.5px] font-extrabold text-purple-700 bg-purple-100/80 px-1.5 py-0.5 rounded-md">
                    <User className="w-3 h-3 text-purple-600" /> Specific Person Notice
                  </span>
                ) : selectedProgramId === 'all_scholars_and_applicants' ? (
                  <span className="inline-flex items-center gap-1 text-[9.5px] font-extrabold text-blue-700 bg-blue-100/80 px-1.5 py-0.5 rounded-md">
                    <Users className="w-3 h-3 text-blue-600" /> Scholars & Applicants
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 text-[9.5px] font-extrabold text-emerald-700 bg-emerald-100/80 px-1.5 py-0.5 rounded-md">
                    <Target className="w-3 h-3 text-emerald-600" /> Approved Scholars Only
                  </span>
                )}
              </div>

              <select
                value={selectedProgramId || newAnnAudience}
                onChange={(e) => {
                  const val = e.target.value;
                  if (setSelectedProgramId) setSelectedProgramId(val);
                  if (val === 'all_scholars_and_applicants') {
                    setNewAnnAudience('All (Scholars and Applicants)');
                  } else if (val === 'all') {
                    setNewAnnAudience('All Approved Scholars');
                  } else {
                    const match = programsList.find(p => String(p.id) === val);
                    setNewAnnAudience(match ? match.title : val);
                  }
                }}
                className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] text-xs font-semibold cursor-pointer bg-white"
              >
                {newAnnType === 'Examination Schedule' ? (
                  <>
                    <option value="all">All Programs (Candidates in "for_exam" status)</option>
                    <option value="all_scholars_and_applicants">All (Scholars & Applicants - General)</option>
                    <option value="single_person">Specific Person (Direct Individual Announcement)</option>
                    {programsList.map(prog => (
                      <option key={prog.id} value={String(prog.id)}>
                        Program: {prog.title} (for_exam status only)
                      </option>
                    ))}
                  </>
                ) : (
                  <>
                    <option value="all_scholars_and_applicants">All (Scholars and Applicants)</option>
                    <option value="all">All Approved Scholars (Across All Programs)</option>
                    <option value="single_person">Specific Person (Direct Individual Announcement)</option>
                    {programsList.map(prog => (
                      <option key={prog.id} value={String(prog.id)}>
                        Program: {prog.title} (Approved Scholars Only)
                      </option>
                    ))}
                  </>
                )}
              </select>

              {/* Specific Person Picker */}
              {selectedProgramId === 'single_person' && (
                <div className="space-y-2 p-3.5 rounded-2xl border border-purple-300 bg-purple-50/60 animate-fade-in mt-2">
                  <div className="flex justify-between items-center">
                    <span className="text-[10.5px] font-extrabold text-purple-900 uppercase tracking-wide flex items-center gap-1.5">
                      <User className="w-3.5 h-3.5 text-purple-700" />
                      <span>Target Specific Person</span>
                      <span className="text-red-500 font-black">*</span>
                    </span>
                    <span className="text-[9.5px] font-bold text-purple-800 bg-purple-100 px-2 py-0.5 rounded-full">
                      {personOptions.length} Persons Available
                    </span>
                  </div>

                  {personOptions.length === 0 ? (
                    <p className="text-xs text-amber-800 italic bg-amber-50 p-2.5 rounded-xl border border-amber-200">
                      No applicants or scholars with linked user accounts found.
                    </p>
                  ) : (
                    <select
                      value={selectedTargetUserId || ''}
                      onChange={(e) => {
                        const uid = e.target.value;
                        if (setSelectedTargetUserId) setSelectedTargetUserId(uid);
                        const matched = personOptions.find(p => p.userId === uid);
                        if (matched) {
                          setNewAnnAudience(`Specific Person: ${matched.name} (${matched.role})`);
                        } else {
                          setNewAnnAudience('Specific Person');
                        }
                      }}
                      className="w-full px-3 py-2 rounded-xl border border-purple-300 text-xs font-semibold bg-white focus:outline-none focus:border-[#2D5941] shadow-xs cursor-pointer"
                    >
                      <option value="">-- Choose Specific Person --</option>
                      {personOptions.map(p => (
                        <option key={p.userId} value={p.userId}>
                          [{p.role}] {p.name} — {p.program}
                        </option>
                      ))}
                    </select>
                  )}

                  {selectedTargetUserId && (() => {
                    const selectedPerson = personOptions.find(p => p.userId === selectedTargetUserId);
                    if (!selectedPerson) return null;
                    return (
                      <div className="bg-white p-3 rounded-xl border border-purple-200 text-xs flex items-center gap-3 mt-1 shadow-xs">
                        <div className="w-8 h-8 rounded-full bg-[#1A3C2E] text-white flex items-center justify-center font-bold text-xs shrink-0">
                          {selectedPerson.name.split(' ').map((n: string) => n[0]).join('')}
                        </div>
                        <div className="flex-1 min-w-0">
                          <span className="font-bold text-[#1C1C1E] block truncate">{selectedPerson.name}</span>
                          <span className="text-[10.5px] text-[#6C6C70] block truncate">
                            {selectedPerson.email} • {selectedPerson.school} • <span className="font-bold text-purple-800">{selectedPerson.role}</span>
                          </span>
                        </div>
                      </div>
                    );
                  })()}
                </div>
              )}
            </div>

            {/* Google Maps Venue Search (Shown when Examination Schedule is selected) */}
            {newAnnType === 'Examination Schedule' && (
              <div className="space-y-2 p-3 rounded-2xl border border-amber-300 bg-amber-50/50 animate-fade-in">
                <div className="flex justify-between items-center">
                  <span className="text-[10.5px] font-extrabold text-[#94580E] uppercase tracking-wide flex items-center gap-1.5">
                    <MapPin className="w-3.5 h-3.5 text-amber-700" />
                    <span>Examination Venue</span>
                    <span className="text-red-500 font-black">*</span>
                  </span>
                  <div className="flex items-center gap-2">
                    {(!examCoords.address?.trim() && !mapSearchText?.trim()) && (
                      <span className="text-[9.5px] font-extrabold text-red-600 bg-red-100 px-1.5 py-0.2 rounded-md">
                        Required
                      </span>
                    )}
                    <button
                      type="button"
                      onClick={() => setIsBigMapModalOpen(true)}
                      className="inline-flex items-center gap-1 text-[10px] font-bold text-[#2D5941] hover:underline cursor-pointer bg-transparent border-0"
                    >
                      <MapIcon className="w-3 h-3" />
                      <span>Enlarge Map</span>
                    </button>
                  </div>
                </div>

                {isLoaded ? (
                  <Autocomplete onLoad={onAutocompleteLoad} onPlaceChanged={onPlaceChanged}>
                    <input
                      type="text"
                      required
                      placeholder="Search exam venue e.g. UP Bahay ng Alumni..."
                      value={mapSearchText}
                      onChange={(e) => setMapSearchText(e.target.value)}
                      className="w-full px-3 py-1.5 rounded-xl border border-[#D9D2C5] text-xs font-semibold bg-white focus:outline-none focus:border-[#2D5941] shadow-xs"
                    />
                  </Autocomplete>
                ) : (
                  <div className="text-xs font-medium text-[#6C6C70]">Loading Google Maps Autocomplete...</div>
                )}

                {(!examCoords.address?.trim() && !mapSearchText?.trim()) && (
                  <p className="inline-flex items-center gap-1.5 text-[10.5px] font-semibold text-red-600 bg-red-50 p-1.5 rounded-xl border border-red-200 leading-tight">
                    <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
                    <span>Please search or pin a specific venue on the map.</span>
                  </p>
                )}

                {/* Google Maps Viewport */}
                <div className="w-full h-28 rounded-xl border border-[#D9D2C5] overflow-hidden relative shadow-inner bg-slate-100">
                  {isLoaded ? (
                    <GoogleMap
                      mapContainerStyle={{ width: '100%', height: '100%' }}
                      center={{ lat: examCoords.lat, lng: examCoords.lng }}
                      zoom={mapZoom}
                      onClick={handleMapClick}
                      options={{
                        disableDefaultUI: true,
                        zoomControl: false,
                      }}
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-xs font-semibold text-[#6C6C70]">
                      Loading Live Google Map...
                    </div>
                  )}

                  {/* Coordinates indicator */}
                  <div className="absolute top-1.5 left-1.5 z-10 bg-white/95 backdrop-blur-xs px-1.5 py-0.5 rounded-md text-[8.5px] text-[#1A3C2E] font-bold border border-[#D9D2C5]/50 shadow-xs">
                    {examCoords.lat.toFixed(4)}° N, {examCoords.lng.toFixed(4)}° E
                  </div>

                  {/* Zoom controls */}
                  <div className="absolute bottom-1.5 right-1.5 z-10 flex gap-1">
                    <button
                      type="button"
                      onClick={() => setMapZoom(prev => Math.min(prev + 1, 18))}
                      className="w-5 h-5 bg-white hover:bg-slate-50 border border-[#D9D2C5] text-[10px] font-black rounded flex items-center justify-center cursor-pointer shadow-xs"
                    >
                      +
                    </button>
                    <button
                      type="button"
                      onClick={() => setMapZoom(prev => Math.max(prev - 1, 6))}
                      className="w-5 h-5 bg-white hover:bg-slate-50 border border-[#D9D2C5] text-[10px] font-black rounded flex items-center justify-center cursor-pointer shadow-xs"
                    >
                      -
                    </button>
                  </div>
                </div>

                {/* Selected Address Display */}
                {examCoords.address && (
                  <div className="text-[10.5px] font-semibold text-[#1A3C2E] bg-white p-1.5 rounded-xl border border-[#D9D2C5] flex items-start gap-1.5">
                    <MapPin className="w-3.5 h-3.5 shrink-0 text-amber-600 mt-0.5" />
                    <span className="leading-snug break-words">{examCoords.address}</span>
                  </div>
                )}
              </div>
            )}

            {/* Title */}
            <div>
              <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1">
                Announcement Title
              </label>
              <input
                type="text"
                required
                maxLength={100}
                placeholder="e.g. Mandatory Qualifying Exam on Saturday"
                value={newAnnTitle}
                onChange={(e) => setNewAnnTitle(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] text-xs font-semibold bg-white"
              />
            </div>

            {/* Message Details */}
            <div>
              <div className="flex justify-between items-center mb-1">
                <label className="text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide">
                  Message Details
                </label>
                <span className="text-[9.5px] text-[#8E8E93]">{newAnnBody.length}/1000</span>
              </div>
              <textarea
                required
                rows={3}
                maxLength={1000}
                placeholder="Write full instructions, exam schedules, deadlines, or announcements..."
                value={newAnnBody}
                onChange={(e) => setNewAnnBody(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] focus:outline-none focus:border-[#2D5941] text-xs font-semibold bg-white leading-relaxed"
              />
            </div>

            {/* Live Preview Card */}
            {showPreview && (
              <div className="p-3.5 rounded-2xl bg-[#F9F5EF] border border-[#2D5941]/30 space-y-1.5 animate-fade-in">
                <div className="flex items-center justify-between">
                  <span className="text-[9.5px] font-extrabold uppercase text-[#2D5941]">Scholar Mobile Preview</span>
                  <span className="text-[9.5px] font-bold text-[#8E8E93]">Target: {newAnnAudience}</span>
                </div>
                <h4 className="text-xs font-bold text-[#1A3C2E]">{newAnnTitle || 'Untitled Announcement'}</h4>
                <p className="text-[11px] text-[#6C6C70] whitespace-pre-wrap">{newAnnBody || 'Message body will appear here...'}</p>
                {newAnnType === 'Examination Schedule' && examCoords.address && (
                  <div className="inline-flex items-center gap-1 text-[9.5px] font-bold text-[#C97B2E] pt-0.5">
                    <MapPin className="w-3 h-3 text-[#C97B2E]" /> {examCoords.address}
                  </div>
                )}
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={
                isBroadcasting ||
                !newAnnTitle.trim() ||
                !newAnnBody.trim() ||
                (newAnnType === 'Examination Schedule' && !examCoords.address?.trim() && !mapSearchText?.trim())
              }
              className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] disabled:bg-[#D9D2C5] disabled:cursor-not-allowed text-white py-3 rounded-xl text-xs font-bold shadow-sm transition-all cursor-pointer border-0 flex items-center justify-center gap-2"
            >
              {isBroadcasting ? (
                <>
                  <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  <span>Broadcasting to Scholars...</span>
                </>
              ) : (
                <>
                  <Send className="w-3.5 h-3.5" />
                  <span>Broadcast & Save to Scholar Inboxes</span>
                </>
              )}
            </button>
          </form>
        </div>

        {/* ─── Right Column: Active Broadcast Board & History (7 cols) ─── */}
        <div className="lg:col-span-7 space-y-6">
          {/* Feed Controls */}
          <div className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-5 shadow-sm space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Broadcast History</h3>
                <p className="text-xs text-[#6C6C70]">Active alerts sent to scholars' mobile & web apps</p>
              </div>

              {/* Search input */}
              <div className="relative min-w-[220px]">
                <input
                  type="text"
                  placeholder="Search announcements..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-8 pr-3 py-2 rounded-xl border border-[#D9D2C5] text-xs font-semibold bg-[#F9F5EF]/60 focus:bg-white focus:outline-none focus:border-[#2D5941]"
                />
                <Search className="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-[#6C6C70]" />
              </div>
            </div>

            {/* Category Filter Pills */}
            <div className="flex flex-wrap gap-1.5 pt-2 border-t border-[#D9D2C5]/30">
              {[
                { key: 'All', label: 'All Broadcasts', count: announcements.length, icon: null },
                { key: 'Exam', label: 'Exam Schedules', count: totalExams, icon: FileText },
                { key: 'Funds', label: 'Fund Releases', count: totalFunds, icon: Coins },
                { key: 'Reqs', label: 'Requirements', count: totalReqs, icon: ClipboardList },
                { key: 'General', label: 'General Notices', count: totalGeneral, icon: Megaphone },
              ].map(tab => {
                const IconComp = tab.icon;
                return (
                  <button
                    key={tab.key}
                    type="button"
                    onClick={() => setFilterType(tab.key)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer flex items-center gap-1.5 ${
                      filterType === tab.key
                        ? 'bg-[#1A3C2E] text-white shadow-sm'
                        : 'bg-[#F9F5EF] text-[#6C6C70] hover:bg-[#EDE8DE]'
                    }`}
                  >
                    {IconComp && <IconComp className="w-3.5 h-3.5" />}
                    <span>{tab.label}</span>
                    <span className={`text-[9px] px-1.5 py-0.2 rounded-full font-extrabold ${
                      filterType === tab.key ? 'bg-white/20 text-white' : 'bg-[#EDE8DE] text-[#1A3C2E]'
                    }`}>
                      {tab.count}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Broadcast Cards Feed */}
          <div className="space-y-4">
            {filteredAnnouncements.length === 0 ? (
              <div className="bg-white rounded-3xl border border-dashed border-[#D9D2C5] p-12 text-center space-y-3">
                <div className="w-14 h-14 bg-[#EDE8DE] rounded-2xl flex items-center justify-center mx-auto text-[#2D5941]">
                  <Megaphone className="w-7 h-7 text-[#2D5941]" />
                </div>
                <h4 className="font-bold text-[#1A3C2E] font-serif text-base">No Broadcasts Found</h4>
                <p className="text-xs text-[#6C6C70] max-w-sm mx-auto leading-relaxed">
                  {searchQuery
                    ? 'No announcements match your search term. Try adjusting your query or filter.'
                    : 'Use the composer on the left to broadcast examination venues, disbursement schedules, or general notices to scholars.'}
                </p>
              </div>
            ) : (
              paginatedAnnouncements.map((ann) => {
                const isExam = ann.type === 'Examination Schedule' || ann.type?.toLowerCase().includes('exam');
                const isFund = ann.type === 'Release of Funds' || ann.type?.toLowerCase().includes('fund');
                const isReqs = ann.type === 'Requirements Update' || ann.type?.toLowerCase().includes('req');

                return (
                  <div
                    key={ann.id}
                    className="bg-white rounded-3xl border border-[#D9D2C5]/70 p-6 shadow-sm space-y-4 hover:shadow-md transition-all animate-fade-in group"
                  >
                    {/* Header */}
                    <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-3">
                      <div>
                        <div className="flex items-center gap-2 flex-wrap">
                          <span
                            className={`px-2.5 py-1 rounded-lg text-[10px] font-extrabold uppercase tracking-wider border ${
                              isExam
                                ? 'bg-amber-50 text-amber-800 border-amber-200'
                                : isFund
                                ? 'bg-blue-50 text-blue-800 border-blue-200'
                                : isReqs
                                ? 'bg-purple-50 text-purple-800 border-purple-200'
                                : 'bg-[#EBF5EE] text-[#2D5941] border-[#2D5941]/20'
                            }`}
                          >
                            {ann.type}
                          </span>
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[10px] font-bold bg-[#EDE8DE] text-[#1A3C2E]">
                            <Target className="w-3 h-3 text-[#2D5941]" /> {ann.audience}
                          </span>
                          <span className="text-[10px] text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full font-bold">
                            ✓ Saved in Inboxes
                          </span>
                        </div>
                        <h4 className="text-base font-bold text-[#1A3C2E] font-serif mt-2.5 leading-snug">
                          {ann.title}
                        </h4>
                        <span className="text-[11px] text-[#6C6C70] font-medium block mt-1">
                          Published by <strong className="text-[#1A3C2E]">{ann.author}</strong> • {ann.date}
                        </span>
                      </div>

                      {/* Delete action */}
                      {onDeleteAnnouncement && (
                        <button
                          type="button"
                          onClick={() => {
                            if (window.confirm(`Are you sure you want to delete "${ann.title}"?`)) {
                              onDeleteAnnouncement(ann.id);
                            }
                          }}
                          className="opacity-0 group-hover:opacity-100 transition-opacity text-xs text-red-600 hover:text-red-800 font-bold px-2.5 py-1 rounded-lg bg-red-50 hover:bg-red-100 border-0 cursor-pointer shrink-0 self-start inline-flex items-center gap-1"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                          <span>Delete</span>
                        </button>
                      )}
                    </div>

                    {/* Body */}
                    <p className="text-xs text-[#48484A] leading-relaxed whitespace-pre-wrap">
                      {ann.body}
                    </p>

                    {/* Venue Location Preview */}
                    {ann.location && (
                      <div className="pt-2">
                        <div className="p-3 rounded-2xl bg-amber-50/70 border border-amber-200/70 flex items-start justify-between gap-3">
                          <div className="flex items-start gap-2 min-w-0">
                            <MapPin className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
                            <div>
                              <span className="text-[10px] font-extrabold uppercase tracking-wide text-amber-900 block">
                                Examination Venue
                              </span>
                              <p className="text-xs font-semibold text-[#1A3C2E] mt-0.5 break-words">
                                {ann.location}
                              </p>
                            </div>
                          </div>
                          {ann.location && (
                            <a
                              href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(ann.location)}`}
                              target="_blank"
                              rel="noreferrer"
                              className="inline-flex items-center gap-1 text-[11px] font-bold text-[#2D5941] hover:underline bg-white px-2.5 py-1.5 rounded-xl border border-[#D9D2C5] shrink-0 self-center no-underline"
                            >
                              Open in Maps <ExternalLink className="w-3 h-3" />
                            </a>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                );
              })
            )}

            {/* Pagination Controls */}
            {filteredAnnouncements.length > ITEMS_PER_PAGE && (
              <div className="bg-white rounded-2xl border border-[#D9D2C5]/70 p-4 shadow-xs flex flex-col sm:flex-row items-center justify-between gap-3 animate-fade-in">
                <span className="text-xs font-semibold text-[#6C6C70]">
                  Showing <strong className="text-[#1A3C2E]">{startIndex + 1}</strong> - <strong className="text-[#1A3C2E]">{Math.min(startIndex + ITEMS_PER_PAGE, filteredAnnouncements.length)}</strong> of <strong className="text-[#1A3C2E]">{filteredAnnouncements.length}</strong> announcements
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

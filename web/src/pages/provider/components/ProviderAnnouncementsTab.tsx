import React from 'react';
import { GoogleMap, Autocomplete } from '@react-google-maps/api';
import type { AnnType } from '../types';

interface Announcement {
  id: number;
  type: AnnType;
  title: string;
  body: string;
  date: string;
  audience: string;
  author: string;
  location?: string;
  coordinates?: { lat: number; lng: number };
}

interface ProviderAnnouncementsTabProps {
  handleAddAnnouncement: (e: React.FormEvent) => void;
  newAnnType: AnnType;
  setNewAnnType: (type: AnnType) => void;
  newAnnAudience: string;
  setNewAnnAudience: (aud: string) => void;
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
}

export const ProviderAnnouncementsTab: React.FC<ProviderAnnouncementsTabProps> = ({
  handleAddAnnouncement,
  newAnnType,
  setNewAnnType,
  newAnnAudience,
  setNewAnnAudience,
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
}) => {
  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h2 className="text-3xl font-extrabold text-[#1A3C2E] font-serif">Announcements</h2>
        <p className="text-sm text-[#6C6C70] mt-1 font-medium">Broadcast notices and search exam venues with live Google Maps Autocomplete</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
        {/* Broadcast Announcement Form */}
        <div className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-4">
          <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Broadcast Announcement</h3>
          <form onSubmit={handleAddAnnouncement} className="space-y-3">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Type</label>
                <select
                  value={newAnnType}
                  onChange={(e) => setNewAnnType(e.target.value as AnnType)}
                  className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                >
                  <option value="General Notice">General Notice</option>
                  <option value="Examination Schedule">Exam Schedule</option>
                  <option value="Release of Funds">Release of Funds</option>
                  <option value="Requirements Update">Requirements</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Audience</label>
                <select
                  value={newAnnAudience} onChange={(e) => setNewAnnAudience(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                >
                  <option value="All Scholars">All Scholars</option>
                  <option value="DOST-SEI Only">DOST-SEI Only</option>
                  <option value="CHED Only">CHED Only</option>
                </select>
              </div>
            </div>

            {/* Google Maps Autocomplete Search Input */}
            {newAnnType === 'Examination Schedule' && (
              <div className="space-y-2 p-2.5 rounded-2xl border border-[#D9D2C5] bg-[#F9F5EF]/50 animate-fade-in">
                <div className="flex justify-between items-center">
                  <label className="block text-[10px] font-bold text-[#1A3C2E] uppercase tracking-wide">🔍 Search Location</label>
                  <button
                    type="button"
                    onClick={() => setIsBigMapModalOpen(true)}
                    className="text-[10px] font-bold text-[#2D5941] hover:underline cursor-pointer bg-transparent border-0"
                  >
                    Choose on Larger Map 🗺️
                  </button>
                </div>

                {isLoaded ? (
                  <Autocomplete
                    onLoad={onAutocompleteLoad}
                    onPlaceChanged={onPlaceChanged}
                  >
                    <input
                      type="text"
                      placeholder="Type venue e.g. UP Diliman..."
                      value={mapSearchText}
                      onChange={(e) => setMapSearchText(e.target.value)}
                      className="w-full px-3 py-1.5 rounded-lg border border-[#D9D2C5] text-xs font-semibold bg-white focus:outline-none focus:border-[#2D5941]"
                    />
                  </Autocomplete>
                ) : (
                  <div className="text-xs font-medium text-[#6C6C70]">Loading search script...</div>
                )}

                {/* Google Maps live viewport */}
                <div className="w-full h-28 rounded-xl border border-[#D9D2C5] overflow-hidden relative flex flex-col justify-between shadow-inner bg-slate-100">
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
                      Loading Live Google Maps...
                    </div>
                  )}

                  <div className="absolute top-1.5 left-1.5 z-10 bg-white/90 backdrop-blur px-1.5 py-0.5 rounded text-[7px] text-[#6C6C70] font-semibold border border-[#D9D2C5]/50 shadow-sm">
                    <span>
                      {examCoords.lat.toFixed(4)}° N, {examCoords.lng.toFixed(4)}° E
                    </span>
                  </div>

                  <div className="absolute bottom-1.5 left-1.5 right-1.5 z-10 flex justify-between items-center">
                    <span className="text-[6px] text-[#2D5941] bg-white/90 px-1.5 py-0.5 rounded font-bold uppercase tracking-wider shadow">
                      Google Maps
                    </span>
                    <div className="flex gap-1">
                      <button type="button" onClick={() => setMapZoom(prev => Math.min(prev + 1, 18))} className="w-4 h-4 bg-white border border-[#D9D2C5] hover:bg-slate-50 text-[9px] font-bold rounded flex items-center justify-center cursor-pointer shadow-sm">+</button>
                      <button type="button" onClick={() => setMapZoom(prev => Math.max(prev - 1, 10))} className="w-4 h-4 bg-white border border-[#D9D2C5] hover:bg-slate-50 text-[9px] font-bold rounded flex items-center justify-center cursor-pointer shadow-sm">-</button>
                    </div>
                  </div>
                </div>

                <p className="text-[9px] text-[#6C6C70] leading-relaxed italic truncate">
                  <strong>Address:</strong> {examCoords.address}
                </p>
              </div>
            )}

            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Announcement Title</label>
              <input
                type="text" required placeholder="e.g. Schedule of Qualifying Examinations"
                value={newAnnTitle} onChange={(e) => setNewAnnTitle(e.target.value)}
                className="w-full px-4 py-2 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-xs font-semibold"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Message / Details</label>
              <textarea
                required rows={3} placeholder="Specify date, times, venues or step-by-step info here..."
                value={newAnnBody} onChange={(e) => setNewAnnBody(e.target.value)}
                className="w-full px-4 py-2 rounded-xl border border-[#D9D2C5]/60 focus:outline-none text-xs font-semibold"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white py-2.5 rounded-xl text-xs font-bold shadow-md transition-all cursor-pointer border-0"
            >
              Publish Announcement
            </button>
          </form>
        </div>

        <div className="lg:col-span-2 space-y-6">
          <h3 className="font-bold text-[#1A3C2E] font-serif text-lg">Active Broadcast Board</h3>
          <div className="space-y-4">
            {announcements.length === 0 ? (
              <div className="bg-[#F9F5EF]/60 rounded-3xl border border-dashed border-[#D9D2C5] p-12 text-center space-y-3">
                <div className="w-12 h-12 bg-[#EDE8DE] rounded-full flex items-center justify-center mx-auto text-[#2D5941] text-xl">
                  📢
                </div>
                <h4 className="font-bold text-[#1A3C2E] font-serif text-base">No Broadcasts Yet</h4>
                <p className="text-xs text-[#6C6C70] max-w-xs mx-auto">
                  Use the form on the left to broadcast exam schedules, stipend releases, or notices to scholars.
                </p>
              </div>
            ) : (
              announcements.map((ann) => (
              <div key={ann.id} className="bg-white rounded-3xl border border-[#D9D2C5]/60 p-6 shadow-sm space-y-4 animate-fade-in">
                <div className="flex justify-between items-start gap-4">
                  <div>
                    <span
                      className={`inline-block px-3 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider ${ann.type === 'Examination Schedule'
                        ? 'bg-amber-100 text-[#C97B2E] border border-amber-200'
                        : ann.type === 'Release of Funds'
                          ? 'bg-blue-100 text-blue-700 border border-blue-200'
                          : ann.type === 'Requirements Update'
                            ? 'bg-purple-100 text-purple-700 border border-purple-200'
                            : 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20'
                        }`}
                    >
                      {ann.type}
                    </span>
                    <h4 className="text-lg font-bold text-[#1A3C2E] font-serif mt-2">{ann.title}</h4>
                    <span className="text-[10px] text-[#6C6C70] font-medium block mt-1">
                      Published by {ann.author} on {ann.date}
                    </span>
                  </div>
                  <span className="px-3 py-1 rounded-full text-[10px] font-bold bg-[#EDE8DE] text-[#6C6C70]">
                    {ann.audience}
                  </span>
                </div>

                <p className="text-sm text-[#6C6C70] leading-relaxed">{ann.body}</p>

                {ann.location && (
                  <div className="pt-2 flex items-center gap-1.5 text-xs font-bold text-[#C97B2E]">
                    <span>📍 Venue:</span>
                    <span className="underline">{ann.location}</span>
                  </div>
                )}
              </div>
            )))}
          </div>
        </div>
      </div>
    </div>
  );
};

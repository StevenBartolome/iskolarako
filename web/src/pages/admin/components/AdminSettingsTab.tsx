import React from 'react';
import { Pencil, Check, X } from 'lucide-react';
import type { RequirementItem, CategoryItem } from '../types';

interface AdminSettingsTabProps {
  categories: CategoryItem[];
  showAddCategoryForm: boolean;
  setShowAddCategoryForm: (val: boolean) => void;
  editingCategoryId: any;
  setEditingCategoryId: (val: any) => void;
  editingCategoryName: string;
  setEditingCategoryName: (val: string) => void;
  categoryInputs: string[];
  setCategoryInputs: (val: string[]) => void;
  handleSaveEditCategory: (id: any) => void;
  handleStartEditCategory: (cat: CategoryItem) => void;
  handleDeleteCategory: (id: any, name: string) => void;
  handleSaveMultipleCategories: (e: React.FormEvent) => void;
  maintenanceMode: boolean;
  setMaintenanceMode: (val: boolean) => void;
  addAuditLog: (action: string, target: string) => void;
  showToast: (msg: string) => void;
  selectedProviderType: string;
  setSelectedProviderType: (val: any) => void;
  reqItems: RequirementItem[];
  editingReqIndex: number | null;
  setEditingReqIndex: (val: number | null) => void;
  editReqName: string;
  setEditReqName: (val: string) => void;
  editReqDesc: string;
  setEditReqDesc: (val: string) => void;
  editReqRequired: boolean;
  setEditReqRequired: (val: boolean) => void;
  handleSaveEditRequirement: (index: number) => void;
  handleStartEditRequirement: (index: number, item: RequirementItem) => void;
  handleRemoveRequirement: (index: number) => void;
  handleAddRequirement: (e: React.FormEvent) => void;
  newReqProviderTypes: string[];
  setNewReqProviderTypes: React.Dispatch<React.SetStateAction<any>>;
  newReqName: string;
  setNewReqName: (val: string) => void;
  newReqDesc: string;
  setNewReqDesc: (val: string) => void;
  newReqRequired: boolean;
  setNewReqRequired: (val: boolean) => void;
  isSavingReq: boolean;
  handleSaveRequirements: () => void;
}

export const AdminSettingsTab: React.FC<AdminSettingsTabProps> = ({
  categories,
  showAddCategoryForm,
  setShowAddCategoryForm,
  editingCategoryId,
  setEditingCategoryId,
  editingCategoryName,
  setEditingCategoryName,
  categoryInputs,
  setCategoryInputs,
  handleSaveEditCategory,
  handleStartEditCategory,
  handleDeleteCategory,
  handleSaveMultipleCategories,
  maintenanceMode,
  setMaintenanceMode,
  addAuditLog,
  showToast,
  selectedProviderType,
  setSelectedProviderType,
  reqItems,
  editingReqIndex,
  setEditingReqIndex,
  editReqName,
  setEditReqName,
  editReqDesc,
  setEditReqDesc,
  editReqRequired,
  setEditReqRequired,
  handleSaveEditRequirement,
  handleStartEditRequirement,
  handleRemoveRequirement,
  handleAddRequirement,
  newReqProviderTypes,
  setNewReqProviderTypes,
  newReqName,
  setNewReqName,
  newReqDesc,
  setNewReqDesc,
  newReqRequired,
  setNewReqRequired,
  isSavingReq,
  handleSaveRequirements,
}) => {
  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
      <div>
        <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">System Config Settings</h3>
        <p className="text-xs text-[#6C6C70]">Set scholarship options and application processing variables.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Categories */}
        <div className="space-y-3 text-left">
          <div className="flex items-center justify-between">
            <h4 className="text-xs font-bold text-[#1C1C1E] uppercase">Scholarship Categories</h4>
            <button
              type="button"
              onClick={() => setShowAddCategoryForm(!showAddCategoryForm)}
              className="px-3 py-1 bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold rounded-lg transition-all cursor-pointer border-0 flex items-center gap-1 shadow-sm"
            >
              {showAddCategoryForm ? '✕ Close Form' : '+ Add Categories'}
            </button>
          </div>

          {/* Categories Chips with Inline Editing */}
          <div className="flex flex-wrap gap-2">
            {categories.length === 0 ? (
              <span className="text-xs text-[#8E8E93] italic">No categories loaded. Add one below!</span>
            ) : (
              categories.map(cat => (
                <div key={cat.id} className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#EDE8DE] text-xs font-semibold text-[#1C1C1E] border border-solid border-[#D9D2C5]">
                  {editingCategoryId === cat.id ? (
                    <div className="flex items-center gap-1">
                      <input
                        type="text"
                        value={editingCategoryName}
                        onChange={(e) => setEditingCategoryName(e.target.value)}
                        className="px-2 py-0.5 rounded border border-[#2D5941] text-xs bg-white focus:outline-none w-28"
                        autoFocus
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') handleSaveEditCategory(cat.id);
                          if (e.key === 'Escape') setEditingCategoryId(null);
                        }}
                      />
                      <button
                        type="button"
                        onClick={() => handleSaveEditCategory(cat.id)}
                        className="text-[#2D5941] hover:text-[#1A3C2E] cursor-pointer border-0 bg-transparent p-0"
                        title="Save"
                      >
                        <Check className="w-3.5 h-3.5" />
                      </button>
                      <button
                        type="button"
                        onClick={() => setEditingCategoryId(null)}
                        className="text-[#8E8E93] hover:text-[#1C1C1E] cursor-pointer border-0 bg-transparent p-0"
                        title="Cancel"
                      >
                        <X className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ) : (
                    <>
                      <span>{cat.name}</span>
                      <button
                        type="button"
                        onClick={() => handleStartEditCategory(cat)}
                        className="w-4 h-4 rounded-full hover:bg-[#2D5941]/20 text-[#2D5941] inline-flex items-center justify-center cursor-pointer transition-all border-0 p-0"
                        title={`Edit ${cat.name}`}
                      >
                        <Pencil className="w-2.5 h-2.5" />
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeleteCategory(cat.id, cat.name)}
                        className="w-4 h-4 rounded-full bg-[#B34040]/10 hover:bg-[#B34040] text-[#B34040] hover:text-white inline-flex items-center justify-center cursor-pointer transition-all border-0 p-0"
                        title={`Delete ${cat.name}`}
                      >
                        <X className="w-2.5 h-2.5" />
                      </button>
                    </>
                  )}
                </div>
              ))
            )}
          </div>

          {/* Multiple Category Addition Form */}
          {showAddCategoryForm && (
            <form onSubmit={handleSaveMultipleCategories} className="p-4 bg-[#FFFFFF] border border-[#D9D2C5] rounded-xl space-y-3 mt-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-[#1A3C2E] uppercase">Add New Categories</span>
                <span className="text-[10px] text-[#6C6C70]">Separate multiple with commas or add fields</span>
              </div>

              <div className="space-y-2">
                {categoryInputs.map((val, idx) => (
                  <div key={idx} className="flex items-center gap-2">
                    <input
                      type="text"
                      placeholder={`Category ${idx + 1} (e.g. STEM or Arts, Sports)`}
                      value={val}
                      onChange={(e) => {
                        const updated = [...categoryInputs];
                        updated[idx] = e.target.value;
                        setCategoryInputs(updated);
                      }}
                      className="flex-1 px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white"
                    />
                    {categoryInputs.length > 1 && (
                      <button
                        type="button"
                        onClick={() => {
                          setCategoryInputs(categoryInputs.filter((_, i) => i !== idx));
                        }}
                        className="text-[#B34040] hover:text-[#8E2F2F] text-xs font-bold p-1 border-0 bg-transparent cursor-pointer"
                      >
                        ✕
                      </button>
                    )}
                  </div>
                ))}
              </div>

              <div className="flex items-center justify-between pt-1">
                <button
                  type="button"
                  onClick={() => setCategoryInputs([...categoryInputs, ''])}
                  className="text-xs font-semibold text-[#2D5941] hover:underline cursor-pointer border-0 bg-transparent"
                >
                  + Add Another Field
                </button>

                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setShowAddCategoryForm(false);
                      setCategoryInputs(['']);
                    }}
                    className="px-3 py-1.5 text-xs text-[#6C6C70] hover:text-[#1C1C1E] cursor-pointer border-0 bg-transparent font-medium"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-4 py-1.5 bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold rounded-xl cursor-pointer border-0 shadow-sm"
                  >
                    Save Categories
                  </button>
                </div>
              </div>
            </form>
          )}
        </div>

        {/* Maintenance toggle */}
        <div className="space-y-4 text-left">
          <h4 className="text-xs font-bold text-[#1C1C1E] uppercase">System State</h4>
          <div className="flex items-center justify-between p-4 rounded-xl border border-[#D9D2C5] bg-[#FFFFFF]/20">
            <div>
              <span className="text-xs font-bold text-[#1C1C1E] block">Maintenance Mode</span>
              <span className="text-[10px] text-[#6C6C70]">Suspends applications for students temporarily.</span>
            </div>
            <button
              type="button"
              onClick={() => {
                const next = !maintenanceMode;
                setMaintenanceMode(next);
                addAuditLog(`TOGGLED MAINTENANCE MODE`, next ? 'ON' : 'OFF');
                showToast(`Maintenance mode turned ${next ? 'ON' : 'OFF'}.`);
              }}
              className={`px-4 py-2 rounded-xl text-xs font-bold cursor-pointer transition-colors border-0 ${
                maintenanceMode ? 'bg-[#B34040] text-white' : 'bg-[#EDE8DE] text-[#1C1C1E]'
              }`}
            >
              {maintenanceMode ? 'ACTIVE' : 'INACTIVE'}
            </button>
          </div>
        </div>
      </div>

      {/* Provider Requirements Config Section */}
      <div className="border-t border-[#D9D2C5] pt-6 mt-6 space-y-4 text-left">
        <div>
          <h4 className="text-sm font-bold text-[#1A3C2E] font-serif mb-1">Provider Verification Documents Customization</h4>
          <p className="text-xs text-[#6C6C70]">Configure what registration documents and credentials scholarship organizations must submit depending on their category.</p>
        </div>

        {/* Provider Type Selector */}
        <div className="flex bg-[#FFFFFF] p-1 rounded-xl border border-solid border-[#D9D2C5] max-w-md">
          <button
            type="button"
            onClick={() => setSelectedProviderType('public')}
            className={`flex-1 py-2 text-xs font-semibold rounded-lg transition-all cursor-pointer border-0 ${
              selectedProviderType === 'public'
                ? 'bg-[#2D5941] text-white shadow-sm'
                : 'text-[#6c757d] hover:text-[#2D5941] bg-transparent'
            }`}
          >
            Government
          </button>
          <button
            type="button"
            onClick={() => setSelectedProviderType('private')}
            className={`flex-1 py-2 text-xs font-semibold rounded-lg transition-all cursor-pointer border-0 ${
              selectedProviderType === 'private'
                ? 'bg-[#2D5941] text-white shadow-sm'
                : 'text-[#6c757d] hover:text-[#2D5941] bg-transparent'
            }`}
          >
            Private Partner
          </button>
          <button
            type="button"
            onClick={() => setSelectedProviderType('ngo')}
            className={`flex-1 py-2 text-xs font-semibold rounded-lg transition-all cursor-pointer border-0 ${
              selectedProviderType === 'ngo'
                ? 'bg-[#2D5941] text-white shadow-sm'
                : 'text-[#6c757d] hover:text-[#2D5941] bg-transparent'
            }`}
          >
            NGO / Foundation
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 pt-2">
          {/* Requirements List (Col Span 2) */}
          <div className="lg:col-span-2 space-y-3">
            <span className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Current Configured Documents</span>
            {reqItems.length === 0 ? (
              <div className="text-center py-8 rounded-xl border border-dashed border-[#D9D2C5] text-xs text-[#8E8E93]">
                No requirements configured yet. Add some below!
              </div>
            ) : (
              <div className="space-y-2 max-h-96 overflow-y-auto pr-2">
                {reqItems.map((item, idx) => (
                  <div key={idx} className="p-3.5 bg-[#FFFFFF]/30 border border-[#D9D2C5] rounded-xl hover:border-[#2D5941] transition-all">
                    {editingReqIndex === idx ? (
                      /* Inline Editing Mode for Requirement */
                      <div className="space-y-3">
                        <div>
                          <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">Document Title</label>
                          <input
                            type="text"
                            value={editReqName}
                            onChange={(e) => setEditReqName(e.target.value)}
                            className="w-full px-3 py-1.5 rounded-lg border border-[#2D5941] text-xs focus:outline-none bg-white font-bold"
                          />
                        </div>
                        <div>
                          <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">Description</label>
                          <input
                            type="text"
                            value={editReqDesc}
                            onChange={(e) => setEditReqDesc(e.target.value)}
                            className="w-full px-3 py-1.5 rounded-lg border border-[#D9D2C5] text-xs focus:outline-none bg-white"
                          />
                        </div>
                        <div className="flex items-center justify-between">
                          <label className="flex items-center gap-2 text-xs text-[#1C1C1E] font-semibold cursor-pointer">
                            <input
                              type="checkbox"
                              checked={editReqRequired}
                              onChange={(e) => setEditReqRequired(e.target.checked)}
                              className="w-3.5 h-3.5 text-[#2D5941] rounded"
                            />
                            Required Document
                          </label>
                          <div className="flex gap-2">
                            <button
                              type="button"
                              onClick={() => setEditingReqIndex(null)}
                              className="px-3 py-1 text-xs text-[#6C6C70] hover:text-[#1C1C1E] border-0 bg-transparent cursor-pointer"
                            >
                              Cancel
                            </button>
                            <button
                              type="button"
                              onClick={() => handleSaveEditRequirement(idx)}
                              className="px-3 py-1 bg-[#2D5941] text-white text-xs font-bold rounded-lg border-0 cursor-pointer"
                            >
                              Save Edit
                            </button>
                          </div>
                        </div>
                      </div>
                    ) : (
                      /* Normal View Mode for Requirement */
                      <div className="flex items-center justify-between">
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-2">
                            <span className="text-xs font-bold text-[#1C1C1E]">{item.name}</span>
                            <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold ${
                              item.required ? 'bg-[#B34040]/10 text-[#B34040]' : 'bg-[#EDE8DE] text-[#6C6C70]'
                            }`}>
                              {item.required ? 'REQUIRED' : 'OPTIONAL'}
                            </span>
                          </div>
                          {item.description && (
                            <p className="text-[10px] text-[#6C6C70] truncate mt-0.5">{item.description}</p>
                          )}
                        </div>
                        <div className="flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => handleStartEditRequirement(idx, item)}
                            className="text-[#2D5941] hover:bg-[#2D5941]/10 p-1.5 rounded-lg cursor-pointer transition-all border-0 bg-transparent inline-flex items-center justify-center"
                            title="Edit document requirement"
                          >
                            <Pencil className="w-3.5 h-3.5" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleRemoveRequirement(idx)}
                            className="text-[#B34040] hover:text-[#8E2F2F] hover:bg-[#B34040]/10 p-1.5 rounded-lg cursor-pointer transition-all border-0 bg-transparent"
                            title="Remove document"
                          >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Add New Requirement form */}
          <div className="bg-[#FFFFFF]/10 p-4 border border-[#D9D2C5] rounded-xl space-y-3 h-fit">
            <span className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider block">Add Document Requirement</span>
            <form onSubmit={handleAddRequirement} className="space-y-3">
              {/* Provider Type Multi-Select Checkboxes */}
              <div>
                <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-2">Apply to Provider Types</label>
                <div className="space-y-1.5">
                  {[
                    { value: 'public', label: 'Government' },
                    { value: 'private', label: 'Private Partner' },
                    { value: 'ngo', label: 'NGO / Foundation' },
                  ].map(({ value, label }) => (
                    <label key={value} className="flex items-center gap-2.5 cursor-pointer group">
                      <div className="relative">
                        <input
                          type="checkbox"
                          checked={newReqProviderTypes.includes(value)}
                          onChange={(e) => {
                            if (e.target.checked) {
                              setNewReqProviderTypes((prev: string[]) => [...prev, value]);
                            } else {
                              setNewReqProviderTypes((prev: string[]) => prev.filter((t: string) => t !== value));
                            }
                          }}
                          className="w-4 h-4 accent-[#2D5941] cursor-pointer rounded"
                        />
                      </div>
                      <span className={`text-xs font-semibold transition-colors ${
                        newReqProviderTypes.includes(value) ? 'text-[#2D5941]' : 'text-[#6C6C70] group-hover:text-[#1C1C1E]'
                      }`}>{label}</span>
                      {newReqProviderTypes.includes(value) && (
                        <span className="ml-auto text-[9px] bg-[#2D5941]/10 text-[#2D5941] px-1.5 py-0.5 rounded-full font-bold">✓ Selected</span>
                      )}
                    </label>
                  ))}
                </div>
                {newReqProviderTypes.length === 0 && (
                  <p className="text-[9px] text-[#B34040] mt-1">Select at least one provider type.</p>
                )}
                {newReqProviderTypes.length > 0 && (
                  <p className="text-[9px] text-[#8E8E93] mt-1">
                    Adding to: <span className="font-bold text-[#2D5941]">
                      {newReqProviderTypes.map((t: string) =>
                        t === 'public' ? 'Gov\'t' : t === 'private' ? 'Private' : 'NGO'
                      ).join(', ')}
                    </span>
                  </p>
                )}
              </div>

              <div>
                <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">Document Title</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. SEC Registration"
                  value={newReqName}
                  onChange={(e) => setNewReqName(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white"
                />
              </div>
              <div>
                <label className="block text-[10px] font-bold text-[#6C6C70] uppercase mb-1">Description / Instruction</label>
                <textarea
                  rows={2}
                  placeholder="e.g. Must be verified and updated copy"
                  value={newReqDesc}
                  onChange={(e) => setNewReqDesc(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white resize-none"
                />
              </div>
              <div className="flex items-center justify-between p-2 rounded-lg bg-[#EDE8DE]/40">
                <span className="text-[10px] font-bold text-[#1C1C1E] uppercase">Submission Required</span>
                <input
                  type="checkbox"
                  checked={newReqRequired}
                  onChange={(e) => setNewReqRequired(e.target.checked)}
                  className="w-4 h-4 text-[#2D5941] focus:ring-[#2D5941] border-[#D9D2C5] rounded cursor-pointer"
                />
              </div>
              <button
                type="submit"
                disabled={newReqProviderTypes.length === 0}
                className="w-full py-2 bg-[#2D5941]/10 hover:bg-[#2D5941]/20 text-[#2D5941] hover:text-[#1A3C2E] border border-solid border-[#2D5941]/30 rounded-xl text-xs font-bold transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
              >
                + Add to {newReqProviderTypes.length === 3 ? 'All Types' : newReqProviderTypes.length === 0 ? '(Select a Type)' : newReqProviderTypes.map((t: string) => t === 'public' ? 'Gov\'t' : t === 'private' ? 'Private' : 'NGO').join(' & ')}
              </button>
            </form>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex justify-end pt-2">
          <button
            type="button"
            disabled={isSavingReq}
            onClick={handleSaveRequirements}
            className="px-6 py-2.5 bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold rounded-xl shadow-md cursor-pointer transition-all disabled:opacity-50 border-0 flex items-center gap-2"
          >
            {isSavingReq ? (
              <>
                <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                </svg>
                Saving...
              </>
            ) : (
              'Save Requirements Config'
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

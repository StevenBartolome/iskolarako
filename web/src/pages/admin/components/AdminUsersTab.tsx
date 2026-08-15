import React from 'react';
import type { AdminAccount } from '../types';

interface AdminUsersTabProps {
  adminsList: AdminAccount[];
  handleToggleAdminStatus: (id: number) => void;
  handleCreateAdmin: (e: React.FormEvent) => void;
  newAdminUser: string;
  setNewAdminUser: (val: string) => void;
  newAdminRole: string;
  setNewAdminRole: (val: string) => void;
}

export const AdminUsersTab: React.FC<AdminUsersTabProps> = ({
  adminsList,
  handleToggleAdminStatus,
  handleCreateAdmin,
  newAdminUser,
  setNewAdminUser,
  newAdminRole,
  setNewAdminRole,
}) => {
  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
      <div>
        <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">User & Role Management</h3>
        <p className="text-xs text-[#6C6C70]">Configure permissions and create new administrative credentials (Super Admin, Moderator, Auditor).</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Admins List */}
        <div className="lg:col-span-2 space-y-3">
          <h4 className="text-xs font-bold text-[#1A3C2E] uppercase">Administrative Accounts</h4>
          {adminsList.map(a => (
            <div key={a.id} className="p-4 rounded-xl border border-[#D9D2C5] bg-[#F9F5EF]/30 flex justify-between items-center">
              <div>
                <span className="font-bold text-sm text-[#1C1C1E]">{a.username}</span>
                <p className="text-xs text-[#6C6C70] mt-0.5">Role: {a.role}</p>
              </div>
              <div className="flex items-center gap-3">
                <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                  a.status === 'Active' ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-red-50 text-[#B34040]'
                }`}>{a.status}</span>
                <button
                  type="button"
                  onClick={() => handleToggleAdminStatus(a.id)}
                  className="text-xs text-[#2D5941] font-bold hover:underline cursor-pointer border-0 bg-transparent"
                >
                  {a.status === 'Active' ? 'Disable' : 'Enable'}
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Add Admin form */}
        <div className="p-6 bg-[#F9F5EF]/50 rounded-2xl border border-[#D9D2C5] h-fit">
          <h4 className="text-xs font-bold text-[#1A3C2E] uppercase mb-4">Create Admin Account</h4>
          <form onSubmit={handleCreateAdmin} className="space-y-4">
            <div>
              <label className="block text-[10px] font-bold text-[#1C1C1E] uppercase mb-1">Username</label>
              <input
                type="text"
                required
                placeholder="e.g. admin_pascual"
                value={newAdminUser}
                onChange={(e) => setNewAdminUser(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white"
              />
            </div>
            <div>
              <label className="block text-[10px] font-bold text-[#1C1C1E] uppercase mb-1">Role Type</label>
              <select
                value={newAdminRole}
                onChange={(e) => setNewAdminRole(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs focus:outline-none bg-white cursor-pointer"
              >
                <option value="Super Admin">Super Admin (All permissions)</option>
                <option value="Moderator">Moderator (Verification & moderation)</option>
                <option value="Auditor">Auditor (Read logs and ledger only)</option>
              </select>
            </div>
            <button
              type="submit"
              className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold py-2.5 rounded-xl cursor-pointer border-0"
            >
              Add Admin
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

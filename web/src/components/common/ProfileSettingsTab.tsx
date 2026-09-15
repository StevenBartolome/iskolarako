import React, { useEffect, useState } from 'react';
import { Save } from 'lucide-react';
import { supabase } from '@/services/supabaseClient';
import { createAuditLog } from '@/services/auditLogService';

interface ProfileSettingsTabProps {
  showToast: (msg: string) => void;
  onProfileUpdated?: (updated: { firstName: string; lastName: string; providerName?: string }) => void;
  providerDetails?: { id: string; name: string } | null;
  onProviderUpdated?: (name: string) => void;
}

const inputClass =
  'w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm bg-white focus:border-[#2D5941]';

const labelClass =
  'block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5';

export const ProfileSettingsTab: React.FC<ProfileSettingsTabProps> = ({
  showToast,
  onProfileUpdated,
  providerDetails,
  onProviderUpdated,
}) => {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [suffix, setSuffix] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('');
  const [providerName, setProviderName] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadProfile = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;

        setEmail(user.email || '');

        const { data: userData, error: userErr } = await supabase
          .from('users')
          .select('first_name, last_name, suffix, role')
          .eq('id', user.id)
          .single();

        if (userErr || !userData) return;

        setFirstName(userData.first_name || '');
        setLastName(userData.last_name || '');
        setSuffix(userData.suffix || '');
        setRole(userData.role || '');
        if (providerDetails) {
          setProviderName(providerDetails.name || '');
        }
      } catch (err) {
        console.error('Error loading profile settings:', err);
      } finally {
        setLoading(false);
      }
    };

    loadProfile();
  }, [providerDetails]);

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!firstName.trim() || !lastName.trim()) {
      showToast('Please enter both first and last name.');
      return;
    }
    if (password && password.length < 6) {
      showToast('Password must be at least 6 characters.');
      return;
    }
    if (password !== confirmPassword) {
      showToast('Passwords do not match.');
      return;
    }

    setSaving(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        showToast('You are not signed in.');
        return;
      }

      const { error: updateErr } = await supabase
        .from('users')
        .update({
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          suffix: suffix.trim() || null
        })
        .eq('id', user.id);

      if (updateErr) {
        console.error('Error updating profile:', updateErr);
        showToast(`Failed to update profile: ${updateErr.message}`);
        return;
      }

      createAuditLog('UPDATED PROFILE SETTINGS', `User: ${firstName.trim()} ${lastName.trim()}`, user.email || 'User');

      if (password) {
        const { error: pwErr } = await supabase.auth.updateUser({ password });
        if (pwErr) {
          console.error('Error updating password:', pwErr);
          showToast(`Profile saved, but password update failed: ${pwErr.message}`);
        } else {
          setPassword('');
          setConfirmPassword('');
          createAuditLog('CHANGED PASSWORD', `User: ${firstName.trim()} ${lastName.trim()}`, user.email || 'User');
        }
      }

      if (providerDetails) {
        const { error: provErr } = await supabase
          .from('provider')
          .update({ name: providerName.trim(), updated_at: new Date().toISOString() })
          .eq('id', providerDetails.id);

        if (provErr) {
          console.error('Error updating provider name:', provErr);
          showToast(`Profile saved, but organization name update failed: ${provErr.message}`);
        } else {
          onProviderUpdated?.(providerName.trim());
          createAuditLog('UPDATED PROVIDER ORGANIZATION NAME', `Provider: ${providerName.trim()}`, user.email || 'User');
        }
      }

      onProfileUpdated?.({ firstName: firstName.trim(), lastName: lastName.trim(), providerName: providerName.trim() });
      showToast('Profile updated successfully!');
    } catch (err: any) {
      console.error('Error saving profile:', err);
      showToast(`Error: ${err.message || 'Failed to save profile.'}`);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-10 flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <svg className="animate-spin h-8 w-8 text-[#2D5941]" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
          <span className="text-sm font-semibold text-[#1A3C2E]">Loading profile...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-6">
        <div>
          <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-2">Profile Settings</h3>
          <p className="text-xs text-[#6C6C70]">Update your personal information. Changes are saved to your account.</p>
        </div>

        <form onSubmit={handleSaveProfile} className="space-y-5">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className={labelClass}>First Name *</label>
              <input
                type="text"
                required
                placeholder="e.g. Juan"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className={inputClass}
              />
            </div>
            <div>
              <label className={labelClass}>Last Name *</label>
              <input
                type="text"
                required
                placeholder="e.g. Dela Cruz"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className={inputClass}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className={labelClass}>Suffix</label>
              <input
                type="text"
                placeholder="e.g. Jr., III (optional)"
                value={suffix}
                onChange={(e) => setSuffix(e.target.value)}
                className={inputClass}
              />
            </div>
            <div>
              <label className={labelClass}>Email</label>
              <input
                type="email"
                disabled
                value={email}
                className={`${inputClass} bg-[#F9F5EF] cursor-not-allowed opacity-70`}
              />
              <p className="text-[10px] text-[#6C6C70] mt-1">Email is tied to your account sign-in and cannot be changed here.</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className={labelClass}>Role</label>
              <input
                type="text"
                disabled
                value={role === 'admin' ? 'System Admin' : role === 'provider' ? 'Scholarship Provider' : role === 'provider-member' ? 'Provider Member' : role}
                className={`${inputClass} bg-[#F9F5EF] cursor-not-allowed opacity-70`}
              />
            </div>
            <div>
              <label className={labelClass}>Account ID</label>
              <span className="block text-xs text-[#6C6C70]">Manage account access below by updating your password.</span>
            </div>
          </div>

          {providerDetails && (
            <div className="border-t border-[#D9D2C5]/50 pt-5">
              <h4 className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wide mb-1.5">Organization Information</h4>
              <p className="text-[10px] text-[#6C6C70] mb-3">This is the organization name shown to students and the system admin.</p>
              <div>
                <label className={labelClass}>Organization Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Department of Science and Technology"
                  value={providerName}
                  onChange={(e) => setProviderName(e.target.value)}
                  className={inputClass}
                />
              </div>
            </div>
          )}

          <div className="border-t border-[#D9D2C5]/50 pt-5">
            <h4 className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wide mb-1.5">Change Password</h4>
            <p className="text-[10px] text-[#6C6C70] mb-3">Leave blank to keep your current password.</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className={labelClass}>New Password</label>
                <input
                  type="password"
                  placeholder="At least 6 characters"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className={inputClass}
                />
              </div>
              <div>
                <label className={labelClass}>Confirm New Password</label>
                <input
                  type="password"
                  placeholder="Repeat new password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className={inputClass}
                />
              </div>
            </div>
          </div>

          <div className="flex justify-end pt-2">
            <button
              type="submit"
              disabled={saving}
              className="inline-flex items-center justify-center gap-1.5 px-8 py-2.5 bg-[#1A3C2E] hover:bg-[#2D5941] text-white rounded-xl text-xs font-bold border-0 cursor-pointer transition-all shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving ? 'Saving...' : (
                <>
                  <Save className="w-4 h-4" />
                  <span>Save Changes</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
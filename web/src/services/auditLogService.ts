import { supabase } from './supabaseClient';

export interface AuditLogEntry {
  id: string | number;
  admin: string;
  action: string;
  target: string;
  date: string;
  time: string;
  ip: string;
}

const LOCAL_STORAGE_KEY = 'iskoako_audit_logs';

const getMockLogs = (): AuditLogEntry[] => [];

export const fetchAuditLogs = async (): Promise<AuditLogEntry[]> => {
  try {
    const { data, error } = await supabase
      .from('audit_logs')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.warn('Supabase audit_logs read failed, falling back to localStorage:', error.message);
      const local = localStorage.getItem(LOCAL_STORAGE_KEY);
      if (local) {
        return JSON.parse(local);
      }
      return [];
    }

    if (data && data.length > 0) {
      return data.map(item => {
        const dateObj = new Date(item.created_at || item.date);
        return {
          id: item.id,
          admin: item.actor || item.admin || 'System',
          action: item.action,
          target: item.target,
          date: dateObj.toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' }),
          time: dateObj.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          ip: item.ip_address || item.ip || 'Unknown'
        };
      });
    }
  } catch (err) {
    console.error('Exception in fetchAuditLogs:', err);
  }

  const local = localStorage.getItem(LOCAL_STORAGE_KEY);
  if (local) {
    return JSON.parse(local);
  }
  return [];
};

export const createAuditLog = async (
  action: string,
  target: string,
  adminUsername: string = 'admin01'
): Promise<AuditLogEntry> => {
  const now = new Date();
  const dateStr = now.toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' });
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  
  const mockIps = ['192.168.1.45', '192.168.1.99', '192.168.1.102', '192.168.1.15'];
  const ip = mockIps[Math.floor(Math.random() * mockIps.length)];

  const newLog: AuditLogEntry = {
    id: Date.now(),
    admin: adminUsername,
    action,
    target,
    date: dateStr,
    time: timeStr,
    ip
  };

  try {
    const { error } = await supabase
      .from('audit_logs')
      .insert({
        actor: adminUsername,
        action,
        target,
        ip_address: ip,
        created_at: now.toISOString()
      });

    if (error) {
      console.warn('Supabase audit_logs write failed, logging to localStorage:', error.message);
    }
  } catch (err) {
    console.error('Exception in createAuditLog database write:', err);
  }

  try {
    const local = localStorage.getItem(LOCAL_STORAGE_KEY);
    const existing: AuditLogEntry[] = local ? JSON.parse(local) : getMockLogs();
    const updated = [newLog, ...existing];
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(updated));
  } catch (err) {
    console.error('Error writing audit logs to localStorage:', err);
  }

  return newLog;
};

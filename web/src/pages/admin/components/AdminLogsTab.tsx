import React from 'react';
import type { AuditLogEntry } from '../types';

interface AdminLogsTabProps {
  auditLogs: AuditLogEntry[];
}

export const AdminLogsTab: React.FC<AdminLogsTabProps> = ({ auditLogs }) => {
  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6 space-y-4">
      <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Platform Audit Trail</h3>
      <p className="text-xs text-[#6C6C70]">
        Every administrative action is recorded. This log is immutable and complies with security requirements.
      </p>

      <div className="overflow-x-auto text-xs text-[#6C6C70]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
              <th className="py-2.5">Timestamp</th>
              <th>Administrator</th>
              <th>Action Executed</th>
              <th>Target Object</th>
            </tr>
          </thead>
          <tbody>
            {auditLogs.map(log => (
              <tr key={log.id} className="border-b border-[#D9D2C5]/40 py-2.5 hover:bg-[#F9F5EF]/50">
                <td className="py-2.5">{log.date} {log.time}</td>
                <td className="font-semibold text-[#1C1C1E]">{log.admin}</td>
                <td>
                  <span className="font-bold text-[#C97B2E]">{log.action}</span>
                </td>
                <td>{log.target}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

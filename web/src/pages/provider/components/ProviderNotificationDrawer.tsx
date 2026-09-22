import React, { useState, useEffect } from 'react';
import { Bell, X, Inbox, Building2, FileText, Coins, Megaphone, MapPin, RefreshCw } from 'lucide-react';
import { supabase } from '@/services/supabaseClient';
import {
  fetchUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
} from '@/services/notificationService';

interface ProviderNotificationDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  userId?: string;
  onUnreadCountChange?: (count: number) => void;
}

export const ProviderNotificationDrawer: React.FC<ProviderNotificationDrawerProps> = ({
  isOpen,
  onClose,
  userId,
  onUnreadCountChange,
}) => {
  const [notifications, setNotifications] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [activeFilter, setActiveFilter] = useState<'all' | 'unread' | 'admin' | 'system'>('all');

  const loadNotifications = async () => {
    if (!userId) return;
    setLoading(true);
    try {
      const data = await fetchUserNotifications(userId);
      // For provider accounts, ONLY get notifications sent by the Admin targeted for Providers or Both
      const adminNotifications = data.filter((n: any) => {
        const meta = n.metadata || {};
        if (meta.is_admin_broadcast) return false;
        if (meta.target_audience === 'Students') return false;
        return meta.sender_type === 'admin' || meta.target_audience === 'Providers' || meta.target_audience === 'Both';
      });
      setNotifications(adminNotifications);
      const unread = adminNotifications.filter((n: any) => !n.is_read).length;
      onUnreadCountChange?.(unread);
    } catch (err) {
      console.error('Error loading provider notifications:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (userId) {
      loadNotifications();

      // Realtime subscription for instant notifications
      const channel = supabase
        .channel(`provider-notifs-${userId}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'notifications',
            filter: `user_id=eq.${userId}`,
          },
          () => {
            loadNotifications();
          }
        )
        .subscribe();

      return () => {
        supabase.removeChannel(channel);
      };
    }
  }, [userId]);

  const handleMarkAsRead = async (id: string) => {
    setNotifications(prev =>
      prev.map(n => (n.id === id ? { ...n, is_read: true } : n))
    );
    await markNotificationAsRead(id);
    const updatedUnread = notifications.filter(n => n.id !== id && !n.is_read).length;
    onUnreadCountChange?.(updatedUnread);
  };

  const handleMarkAllRead = async () => {
    if (!userId) return;
    setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
    await markAllNotificationsAsRead(userId);
    onUnreadCountChange?.(0);
  };

  const handleDelete = async (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    setNotifications(prev => prev.filter(n => n.id !== id));
    await deleteNotification(id);
    const updatedUnread = notifications.filter(n => n.id !== id && !n.is_read).length;
    onUnreadCountChange?.(updatedUnread);
  };

  const filteredNotifications = notifications.filter(n => {
    if (activeFilter === 'unread') return !n.is_read;
    if (activeFilter === 'admin') {
      const meta = n.metadata || {};
      return meta.sender_type === 'admin';
    }
    if (activeFilter === 'system') {
      return n.type === 'info' || n.type === 'warning';
    }
    return true;
  });

  const unreadCount = notifications.filter(n => !n.is_read).length;

  const formatTimestamp = (dateStr: string) => {
    if (!dateStr) return 'Recently';
    const d = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - d.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 2) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/40 backdrop-blur-xs animate-fade-in">
      {/* Click outside to close */}
      <div className="flex-1" onClick={onClose} />

      {/* Slide-over Panel */}
      <div className="w-full max-w-md bg-white h-full shadow-2xl flex flex-col border-l border-[#D9D2C5]/50 animate-slide-left overflow-hidden">
        {/* Drawer Header */}
        <div className="p-5 border-b border-[#D9D2C5]/50 bg-gradient-to-r from-[#1A3C2E] to-[#2D5941] text-white flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-white/10 flex items-center justify-center border border-white/20">
              <Bell className="w-5 h-5 text-white" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base font-bold font-serif leading-none text-white">Notifications</h3>
                {unreadCount > 0 && (
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-[#E8A838] text-[#1A3C2E]">
                    {unreadCount} new
                  </span>
                )}
              </div>
              <p className="text-[11px] text-[#9BA89F] mt-1">Provider inbox & system broadcasts</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {unreadCount > 0 && (
              <button
                type="button"
                onClick={handleMarkAllRead}
                className="text-[11px] font-bold text-[#E8A838] hover:text-white px-2 py-1 rounded-lg bg-white/10 hover:bg-white/20 transition-all border-0 cursor-pointer"
                title="Mark all as read"
              >
                Mark all read
              </button>
            )}
            <button
              type="button"
              onClick={onClose}
              className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 text-white flex items-center justify-center font-bold text-sm border-0 cursor-pointer transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Filter Tabs */}
        <div className="flex items-center gap-1.5 p-3 bg-[#F9F5EF] border-b border-[#D9D2C5]/40 overflow-x-auto">
          {[
            { key: 'all', label: 'All', count: notifications.length },
            { key: 'unread', label: 'Unread', count: unreadCount },
            { key: 'admin', label: 'Admin Notices', count: notifications.filter(n => n.metadata?.sender_type === 'admin').length },
            { key: 'system', label: 'System', count: notifications.filter(n => n.type === 'info' || n.type === 'warning').length },
          ].map(tab => (
            <button
              key={tab.key}
              type="button"
              onClick={() => setActiveFilter(tab.key as any)}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer whitespace-nowrap flex items-center gap-1.5 ${
                activeFilter === tab.key
                  ? 'bg-[#2D5941] text-white shadow-sm'
                  : 'bg-white text-[#6C6C70] hover:bg-[#EDE8DE]'
              }`}
            >
              <span>{tab.label}</span>
              {tab.count > 0 && (
                <span
                  className={`text-[9px] px-1.5 py-0.2 rounded-full font-extrabold ${
                    activeFilter === tab.key ? 'bg-white/20 text-white' : 'bg-[#EDE8DE] text-[#1A3C2E]'
                  }`}
                >
                  {tab.count}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Notifications List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-3 [scrollbar-width:thin]">
          {loading && notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-48 text-[#6C6C70] gap-2">
              <div className="w-7 h-7 border-2 border-[#2D5941] border-t-transparent rounded-full animate-spin" />
              <p className="text-xs font-semibold">Loading notifications...</p>
            </div>
          ) : filteredNotifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 text-center p-6 space-y-3">
              <div className="w-14 h-14 rounded-2xl bg-[#EDE8DE] flex items-center justify-center text-[#2D5941]">
                <Inbox className="w-7 h-7 text-[#2D5941]" />
              </div>
              <h4 className="text-sm font-bold text-[#1A3C2E] font-serif">Inbox is completely clear</h4>
              <p className="text-xs text-[#6C6C70] max-w-xs">
                {activeFilter === 'unread'
                  ? 'No unread notifications! You are up to date with all scholarship alerts.'
                  : 'No notifications in this category right now.'}
              </p>
            </div>
          ) : (
            filteredNotifications.map(item => {
              const meta = item.metadata || {};
              const isAdmin = meta.sender_type === 'admin';
              const isExam = item.type === 'exam' || item.title?.toLowerCase().includes('exam');
              const isFund = item.type === 'fund' || item.title?.toLowerCase().includes('disbursement') || item.title?.toLowerCase().includes('fund');
              const isUnread = !item.is_read;

              return (
                <div
                  key={item.id}
                  onClick={() => handleMarkAsRead(item.id)}
                  className={`group relative p-4 rounded-2xl transition-all cursor-pointer border ${
                    isUnread
                      ? 'bg-[#F9F5EF] border-[#2D5941]/30 shadow-sm ring-1 ring-[#2D5941]/10'
                      : 'bg-white border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/60'
                  }`}
                >
                  {/* Unread Indicator Bar */}
                  {isUnread && (
                    <div className="absolute top-4 left-0 bottom-4 w-1 bg-[#E8A838] rounded-r-full" />
                  )}

                  <div className="flex items-start gap-3">
                    {/* Icon */}
                    <div
                      className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 border ${
                        isAdmin
                          ? 'bg-purple-50 text-purple-700 border-purple-200'
                          : isExam
                          ? 'bg-amber-50 text-amber-700 border-amber-200'
                          : isFund
                          ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                          : 'bg-[#EBF5EE] text-[#2D5941] border-[#2D5941]/20'
                      }`}
                    >
                      {isAdmin ? (
                        <Building2 className="w-4 h-4" />
                      ) : isExam ? (
                        <FileText className="w-4 h-4" />
                      ) : isFund ? (
                        <Coins className="w-4 h-4" />
                      ) : (
                        <Megaphone className="w-4 h-4" />
                      )}
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          {isAdmin ? (
                            <span className="px-2 py-0.5 rounded-md text-[9px] font-extrabold uppercase tracking-wide bg-purple-100 text-purple-800">
                              Admin Broadcast
                            </span>
                          ) : (
                            <span className="px-2 py-0.5 rounded-md text-[9px] font-extrabold uppercase tracking-wide bg-[#EDE8DE] text-[#1A3C2E]">
                              {meta.announcement_type || item.type || 'Notice'}
                            </span>
                          )}
                          {isUnread && (
                            <span className="w-2 h-2 rounded-full bg-[#E8A838] inline-block" />
                          )}
                        </div>
                        <span className="text-[10px] text-[#6C6C70] font-medium shrink-0">
                          {formatTimestamp(item.created_at)}
                        </span>
                      </div>

                      <h4 className={`text-xs mt-1.5 text-[#1A3C2E] ${isUnread ? 'font-bold' : 'font-semibold'}`}>
                        {item.title}
                      </h4>

                      <p className="text-xs text-[#6C6C70] mt-1 leading-relaxed break-words">
                        {item.message}
                      </p>

                      {meta.location && (
                        <div className="mt-2 text-[10px] font-bold text-[#C97B2E] bg-amber-50/80 px-2 py-1 rounded-lg flex items-center gap-1.5 border border-amber-200/50">
                          <MapPin className="w-3 h-3 text-[#C97B2E] shrink-0" />
                          <span className="shrink-0">Venue:</span>
                          <span className="break-words">{meta.location}</span>
                        </div>
                      )}

                      {/* Footer Actions */}
                      <div className="flex items-center justify-between mt-3 pt-2 border-t border-[#D9D2C5]/30">
                        <span className="text-[10px] text-[#9BA89F] font-medium">
                          From: {meta.sender_name || 'IskoAko System'}
                        </span>
                        <button
                          type="button"
                          onClick={(e) => handleDelete(e, item.id)}
                          className="opacity-0 group-hover:opacity-100 text-[10px] text-red-600 hover:text-red-800 font-bold transition-opacity bg-transparent border-0 cursor-pointer"
                        >
                          Dismiss
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Drawer Footer */}
        <div className="p-3 bg-[#F9F5EF] border-t border-[#D9D2C5]/50 flex items-center justify-between text-xs text-[#6C6C70]">
          <span className="text-[11px] font-semibold">IskoAko Realtime Notifications</span>
          <button
            type="button"
            onClick={loadNotifications}
            className="text-[11px] font-bold text-[#2D5941] hover:underline cursor-pointer bg-transparent border-0 flex items-center gap-1"
          >
            <RefreshCw className="w-3 h-3" />
            <span>Refresh</span>
          </button>
        </div>
      </div>
    </div>
  );
};

import emailjs from '@emailjs/browser';
import { supabase } from '@/services/supabaseClient';

export interface DecisionNotificationParams {
  toEmail?: string;
  toName: string;
  programTitle: string;
  providerName?: string;
  status: 'For Exam' | 'Approved' | 'Rejected' | 'Under Review' | 'Flagged' | string;
  remarks?: string;
  scholarId?: string;
  userId?: string;
}

export const sendDecisionNotification = async (params: DecisionNotificationParams) => {
  const {
    toEmail,
    toName,
    programTitle,
    providerName = 'Scholarship Provider',
    status,
    remarks = '',
    scholarId,
    userId
  } = params;

  let emailSubject = '';
  let emailHeadline = '';
  let emailBody = '';
  let notifType = 'info';

  const normalizedStatus = status.toLowerCase();

  if (normalizedStatus.includes('exam') || normalizedStatus === 'for_exam') {
    emailSubject = `Congratulations! You have passed the evaluation for ${programTitle}`;
    emailHeadline = 'Shortlisted for Qualifying Examination 🎉';
    emailBody = `Congratulations ${toName}!\n\nWe are pleased to inform you that you have passed the initial document and profile evaluation for the scholarship program "${programTitle}" offered by ${providerName}.\n\nYou have been shortlisted for the Examination / Screening stage. Please wait for further announcements and guidelines regarding your exam schedule, testing platform/venue, and required materials.\n\n${remarks ? `Provider Note: ${remarks}\n\n` : ''}Keep your notifications active in the IskoAko app for upcoming examination details.`;
    notifType = 'success';
  } else if (normalizedStatus.includes('approved')) {
    emailSubject = `Congratulations! Your application for ${programTitle} is Approved!`;
    emailHeadline = 'Scholarship Award Approved! 🎓';
    emailBody = `Congratulations ${toName}!\n\nWe are thrilled to inform you that your application for "${programTitle}" has been officially APPROVED! You have been awarded the scholarship.\n\n${remarks ? `Remarks from Provider: ${remarks}\n\n` : ''}Please log in to your IskoAko portal to review your award details, disbursement schedules, and continuing scholar obligations. Welcome to the program!`;
    notifType = 'success';
  } else if (normalizedStatus.includes('flagged') || normalizedStatus.includes('rejected_file')) {
    emailSubject = `Action Required: Document Issue Flagged for ${programTitle}`;
    emailHeadline = 'Document Resubmission Required ⚠️';
    emailBody = `Hello ${toName},\n\nThe provider reviewing your application for "${programTitle}" has flagged an issue with one or more of your submitted documents.\n\nReason / Feedback: "${remarks || 'Please review and resubmit the requested file.'}"\n\nYou can resubmit the replacement file directly through the IskoAko mobile app while the scholarship application cycle remains open.`;
    notifType = 'warning';
  } else if (normalizedStatus.includes('rejected')) {
    emailSubject = `Application Status Update for ${programTitle}`;
    emailHeadline = 'Application Evaluation Result';
    emailBody = `Dear ${toName},\n\nThank you for applying for "${programTitle}".\n\nAfter thorough review and evaluation, we regret to inform you that we are unable to offer you a scholarship slot for this cycle due to limited availability.\n\n${remarks ? `Remarks: ${remarks}\n\n` : ''}We encourage you to explore and apply for other scholarship opportunities on IskoAko. We wish you the best in your academic journey.`;
    notifType = 'error';
  } else {
    emailSubject = `Application Status Update: ${programTitle}`;
    emailHeadline = 'Application Status Updated';
    emailBody = `Hello ${toName},\n\nYour application status for "${programTitle}" has been updated to: ${status}.\n\n${remarks ? `Remarks: ${remarks}\n\n` : ''}Log in to your IskoAko account to track your latest progress.`;
    notifType = 'info';
  }

  // 1. Send Email Notification via EmailJS
  const serviceId = import.meta.env.VITE_EMAILJS_SERVICE_ID;
  const templateId = import.meta.env.VITE_EMAILJS_NOTIF_TEMPLATE_ID || import.meta.env.VITE_EMAILJS_TEMPLATE_ID;
  const publicKey = import.meta.env.VITE_EMAILJS_PUBLIC_KEY;

  if (toEmail && toEmail !== 'N/A' && toEmail.includes('@')) {
    if (serviceId && templateId && publicKey) {
      try {
        console.log(`[EmailJS Sending]: To ${toEmail} | Subject: ${emailSubject}`);
        await emailjs.send(
          serviceId,
          templateId,
          {
            to_name: toName,
            to_email: toEmail,
            subject: emailSubject,
            headline: emailHeadline,
            message: emailBody,
            body: emailBody,
            content: emailBody,
            verification_code: emailHeadline,
            program_name: programTitle,
            provider_name: providerName,
            status_text: status,
            status: status,
            remarks: remarks || 'No additional remarks.',
          },
          publicKey
        );
        console.log(`[EmailJS Success]: Notification email sent to ${toEmail}`);
      } catch (emailErr) {
        console.error('[EmailJS Error]: Failed to send decision email:', emailErr);
      }
    } else {
      console.warn('[EmailJS Notice]: EmailJS credentials not fully set. Email send simulated for:', toEmail);
    }
  }

  // 2. Insert System In-App Notification (Database Sync)
  try {
    let targetUserId = userId;

    if (!targetUserId && scholarId) {
      const { data: scholarRow } = await supabase
        .from('scholar')
        .select('user_id')
        .eq('id', scholarId)
        .maybeSingle();

      if (scholarRow?.user_id) {
        targetUserId = scholarRow.user_id;
      }
    }

    if (targetUserId) {
      const { error: notifErr } = await supabase
        .from('notifications')
        .insert({
          user_id: targetUserId,
          title: emailHeadline,
          message: emailBody.split('\n\n')[1] || emailBody,
          type: notifType,
          is_read: false,
          created_at: new Date().toISOString(),
          metadata: {
            program_title: programTitle,
            provider_name: providerName,
            status,
            remarks
          }
        });

      if (notifErr) {
        console.warn('[System Notification Insert Note]:', notifErr.message);
      } else {
        console.log(`[System Notification Success]: Notification logged for user ${targetUserId}`);

        // Trigger Real-Time FCM Push Notification via Edge Function
        try {
          supabase.functions.invoke('send-push-notification', {
            body: {
              userId: targetUserId,
              title: emailHeadline,
              body: emailBody.split('\n\n')[1] || emailBody,
              type: notifType,
              data: {
                programTitle,
                providerName,
                status,
              },
            },
          }).then((res) => {
            console.log(`[FCM Push Result for ${targetUserId}]:`, res.data || res.error || res);
            if (res.data?.errors) {
              console.error('[FCM Error Details]:', JSON.stringify(res.data.errors, null, 2));
            }
          });
        } catch (pushErr) {
          console.warn('[FCM Push Trigger Note]:', pushErr);
        }
      }
    }
  } catch (sysNotifErr) {
    console.warn('[System Notification Exception]:', sysNotifErr);
  }
};

export interface ScholarAgreementNotificationParams {
  toEmail?: string;
  toName: string;
  programTitle: string;
  providerName: string;
  agreementContent: string;
  maintainingGwa?: string | number;
  scholarId?: string;
  userId?: string;
  applicationId?: string | number;
}

export const sendScholarAgreementNotification = async (params: ScholarAgreementNotificationParams) => {
  const {
    toEmail,
    toName,
    programTitle,
    providerName,
    agreementContent,
    scholarId,
    userId,
    applicationId,
  } = params;

  const emailSubject = `Official Scholar Agreement & Guidelines: ${programTitle}`;
  const emailHeadline = 'Scholar Agreement & Maintaining Rules 📜';
  const emailBody = `Dear ${toName},\n\nYour scholarship guidelines, maintaining academic standards, and renewal terms for "${programTitle}" have been issued by ${providerName}.\n\nPlease review your complete award agreement in your IskoAko portal to stay informed about maintaining GWA requirements and submission deadlines.\n\nSummary Preview:\n${agreementContent.slice(0, 400)}...`;

  // 1. EmailJS send
  const serviceId = import.meta.env.VITE_EMAILJS_SERVICE_ID;
  const templateId = import.meta.env.VITE_EMAILJS_NOTIF_TEMPLATE_ID || import.meta.env.VITE_EMAILJS_TEMPLATE_ID;
  const publicKey = import.meta.env.VITE_EMAILJS_PUBLIC_KEY;

  if (toEmail && toEmail !== 'N/A' && toEmail.includes('@')) {
    if (serviceId && templateId && publicKey) {
      try {
        await emailjs.send(
          serviceId,
          templateId,
          {
            to_name: toName,
            to_email: toEmail,
            subject: emailSubject,
            headline: emailHeadline,
            message: emailBody,
            body: emailBody,
            content: emailBody,
            verification_code: 'SCHOLAR AGREEMENT',
            program_name: programTitle,
            provider_name: providerName,
            status_text: 'Agreement Issued',
            status: 'Agreement Issued',
            remarks: 'Please see attached guidelines and maintaining terms.',
          },
          publicKey
        );
      } catch (err) {
        console.warn('[EmailJS Error]: Failed to send agreement email:', err);
      }
    }
  }

  // 2. In-App Notification & DB Persistence
  try {
    let targetUserId = userId;
    if (!targetUserId && scholarId) {
      const { data: scholarRow } = await supabase
        .from('scholar')
        .select('user_id')
        .eq('id', scholarId)
        .maybeSingle();
      if (scholarRow?.user_id) targetUserId = scholarRow.user_id;
    }

    if (targetUserId) {
      await supabase.from('notifications').insert({
        user_id: targetUserId,
        title: emailHeadline,
        message: `Your maintaining rules and guidelines for ${programTitle} have been published. Review your agreement in IskoAko.`,
        type: 'info',
        is_read: false,
        created_at: new Date().toISOString(),
        metadata: {
          program_title: programTitle,
          provider_name: providerName,
          application_id: applicationId,
          agreement_content: agreementContent,
        },
      });
    }

    // Also persist agreement in application / remarks
    if (applicationId) {
      await supabase
        .from('scholarship_applications')
        .update({
          remarks: `[AGREEMENT ISSUED]: Maintaining guidelines sent on ${new Date().toLocaleDateString()}`,
        })
        .eq('id', applicationId);
    }
  } catch (err) {
    console.warn('[Agreement Notification DB Exception]:', err);
  }
};

// ─── ADMIN ANNOUNCEMENTS ──────────────────────────────────────────────────

export interface AdminAnnouncementParams {
  title: string;
  message: string;
  target: 'Students' | 'Providers' | 'Both';
  adminId?: string;
  adminName?: string;
}

export const sendAdminAnnouncement = async (params: AdminAnnouncementParams): Promise<{ success: boolean; count: number; error?: string }> => {
  const { title, message, target, adminId, adminName = 'System Admin' } = params;

  try {
    const broadcastId = `admin-bc-${Date.now()}`;
    let targetUserIds: string[] = [];

    // Query target users based on selection
    if (target === 'Students') {
      const { data, error } = await supabase
        .from('users')
        .select('id')
        .eq('role', 'scholar');
      if (!error && data) targetUserIds = data.map(u => u.id);
    } else if (target === 'Providers') {
      const { data, error } = await supabase
        .from('users')
        .select('id')
        .in('role', ['provider', 'provider-member']);
      if (!error && data) targetUserIds = data.map(u => u.id);
    } else {
      // Both
      const { data, error } = await supabase
        .from('users')
        .select('id')
        .in('role', ['scholar', 'provider', 'provider-member', 'admin']);
      if (!error && data) targetUserIds = data.map(u => u.id);
    }

    // Filter out duplicates and invalid IDs
    const uniqueUserIds = Array.from(new Set(targetUserIds.filter(Boolean)));

    // Prepare notification rows for all target users
    const nowIso = new Date().toISOString();
    const rowsToInsert: any[] = uniqueUserIds.map(uid => ({
      user_id: uid,
      title: title,
      message: message,
      type: 'announcement',
      is_read: false,
      created_at: nowIso,
      metadata: {
        sender_type: 'admin',
        sender_name: adminName,
        target_audience: target,
        broadcast_id: broadcastId,
        announcement_type: 'System Announcement'
      }
    }));

    // If current admin is sending, also add a broadcast tracking row for admin's broadcast history
    if (adminId && !uniqueUserIds.includes(adminId)) {
      rowsToInsert.push({
        user_id: adminId,
        title: title,
        message: message,
        type: 'announcement',
        is_read: true,
        created_at: nowIso,
        metadata: {
          is_admin_broadcast: true,
          sender_type: 'admin',
          sender_name: adminName,
          target_audience: target,
          broadcast_id: broadcastId,
          recipients_count: uniqueUserIds.length,
          announcement_type: 'System Announcement'
        }
      });
    }

    if (rowsToInsert.length > 0) {
      // Supabase insert in chunks if large
      const chunkSize = 100;
      for (let i = 0; i < rowsToInsert.length; i += chunkSize) {
        const chunk = rowsToInsert.slice(i, i + chunkSize);
        const { error: insErr } = await supabase.from('notifications').insert(chunk);
        if (insErr) {
          console.error('[Admin Announcement Insert Chunk Error]:', insErr);
          return { success: false, count: 0, error: insErr.message || 'Permission denied on notifications table' };
        }
      }
    }

    return { success: true, count: uniqueUserIds.length };
  } catch (err: any) {
    console.error('[Admin Announcement Exception]:', err);
    return { success: false, count: 0, error: err.message || 'Unknown error' };
  }
};

// ─── PROVIDER ANNOUNCEMENTS ───────────────────────────────────────────────

export interface ProviderAnnouncementParams {
  providerId: string;
  providerName: string;
  authorUserId?: string;
  authorName?: string;
  title: string;
  message: string;
  type: 'General Notice' | 'Examination Schedule' | 'Release of Funds' | 'Requirements Update' | string;
  audience: string; // 'All Scholars' | programId or program title
  programId?: string;
  programTitle?: string;
  location?: string;
  coordinates?: { lat: number; lng: number; address?: string };
}

export const sendProviderAnnouncement = async (params: ProviderAnnouncementParams): Promise<{ success: boolean; count: number; error?: string }> => {
  const {
    providerId,
    providerName,
    authorUserId,
    authorName = providerName,
    title,
    message,
    type,
    audience,
    programId,
    programTitle,
    location,
    coordinates
  } = params;

  try {
    // 0. Validate required venue location for Examination Schedule
    if (type === 'Examination Schedule' && (!location || !location.trim())) {
      return {
        success: false,
        count: 0,
        error: 'Examination Venue is required. Please specify a valid venue address or map pin for the examination notice.'
      };
    }

    const broadcastId = `provider-bc-${Date.now()}`;
    const targetUserIds: Set<string> = new Set();

    // 1. If announcement is an Examination Schedule, ONLY send to applicants with status = 'for_exam'
    if (type === 'Examination Schedule') {
      if (programId && programId !== 'all' && programId !== 'all_scholars_and_applicants' && programId !== 'all_for_exam') {
        const { data: cycles } = await supabase
          .from('application_cycles')
          .select('id')
          .eq('program_id', programId);

        const cycleIds = cycles?.map(c => c.id) || [];
        if (cycleIds.length > 0) {
          const { data: apps } = await supabase
            .from('scholarship_applications')
            .select('scholar_id, status, scholar:scholar(user_id)')
            .in('cycle_id', cycleIds)
            .eq('status', 'for_exam');

          apps?.forEach((a: any) => {
            if (a.scholar?.user_id) targetUserIds.add(a.scholar.user_id);
          });
        }
      } else {
        // If 'all' or 'all_scholars_and_applicants' selected for exam schedule, find all applications with status = 'for_exam' for this provider's programs
        const { data: programs } = await supabase
          .from('scholarship_programs')
          .select('id')
          .eq('provider_id', providerId);

        const progIds = programs?.map(p => p.id) || [];
        if (progIds.length > 0) {
          const { data: cycles } = await supabase
            .from('application_cycles')
            .select('id')
            .in('program_id', progIds);

          const cycleIds = cycles?.map(c => c.id) || [];
          if (cycleIds.length > 0) {
            const { data: apps } = await supabase
              .from('scholarship_applications')
              .select('scholar_id, status, scholar:scholar(user_id)')
              .in('cycle_id', cycleIds)
              .eq('status', 'for_exam');

            apps?.forEach((a: any) => {
              if (a.scholar?.user_id) targetUserIds.add(a.scholar.user_id);
            });
          }
        }
      }
    } else {
      // 2. For non-exam announcement types (General Notice, Release of Funds, Requirements Update)
      if (programId === 'all_scholars_and_applicants') {
        // Broadcast to ALL (Enrolled Scholars, Applicants & registered scholars)
        const { data: programs } = await supabase
          .from('scholarship_programs')
          .select('id')
          .eq('provider_id', providerId);

        const progIds = programs?.map(p => p.id) || [];
        if (progIds.length > 0) {
          const { data: cycles } = await supabase
            .from('application_cycles')
            .select('id')
            .in('program_id', progIds);

          const cycleIds = cycles?.map(c => c.id) || [];
          if (cycleIds.length > 0) {
            const { data: apps } = await supabase
              .from('scholarship_applications')
              .select('scholar_id, status, scholar:scholar(user_id)')
              .in('cycle_id', cycleIds);

            apps?.forEach((a: any) => {
              if (a.scholar?.user_id) targetUserIds.add(a.scholar.user_id);
            });
          }
        }

        // Also add all registered scholars platform-wide
        const { data: allScholars } = await supabase
          .from('users')
          .select('id')
          .eq('role', 'scholar');
        allScholars?.forEach(s => targetUserIds.add(s.id));
      } else if (programId && programId !== 'all' && programId !== 'all_approved') {
        const { data: cycles } = await supabase
          .from('application_cycles')
          .select('id')
          .eq('program_id', programId);

        const cycleIds = cycles?.map(c => c.id) || [];
        if (cycleIds.length > 0) {
          // ONLY send to scholars who have been APPROVED for this specific program
          const { data: apps } = await supabase
            .from('scholarship_applications')
            .select('scholar_id, status, scholar:scholar(user_id)')
            .in('cycle_id', cycleIds)
            .eq('status', 'approved');

          apps?.forEach((a: any) => {
            if (a.scholar?.user_id) targetUserIds.add(a.scholar.user_id);
          });
        }
      } else {
        // Targeted to all approved scholars of this provider's programs
        const { data: programs } = await supabase
          .from('scholarship_programs')
          .select('id')
          .eq('provider_id', providerId);

        const progIds = programs?.map(p => p.id) || [];
        if (progIds.length > 0) {
          const { data: cycles } = await supabase
            .from('application_cycles')
            .select('id')
            .in('program_id', progIds);

          const cycleIds = cycles?.map(c => c.id) || [];
          if (cycleIds.length > 0) {
            const { data: apps } = await supabase
              .from('scholarship_applications')
              .select('scholar_id, status, scholar:scholar(user_id)')
              .in('cycle_id', cycleIds)
              .eq('status', 'approved');

            apps?.forEach((a: any) => {
              if (a.scholar?.user_id) targetUserIds.add(a.scholar.user_id);
            });
          }
        }

        // If no approved scholars yet across provider programs, also notify registered scholars
        if (targetUserIds.size === 0) {
          const { data: allScholars } = await supabase
            .from('users')
            .select('id')
            .eq('role', 'scholar');
          allScholars?.forEach(s => targetUserIds.add(s.id));
        }
      }
    }

    const recipientList = Array.from(targetUserIds).filter(Boolean);
    const nowIso = new Date().toISOString();

    const notifType = type === 'Examination Schedule' ? 'exam' : (type === 'Release of Funds' ? 'fund' : 'announcement');

    // Build notifications for scholars
    const rowsToInsert: any[] = recipientList.map(uid => ({
      user_id: uid,
      title: title,
      message: message,
      type: notifType,
      is_read: false,
      created_at: nowIso,
      metadata: {
        sender_type: 'provider',
        provider_id: providerId,
        provider_name: providerName,
        author_name: authorName,
        announcement_type: type,
        audience: audience,
        program_id: programId || null,
        program_title: programTitle || null,
        location: location || null,
        coordinates: coordinates || null,
        broadcast_id: broadcastId,
        date: nowIso,
      }
    }));

    // Also insert a tracking notification row for the provider author user so it shows in provider's broadcast history & inbox
    if (authorUserId) {
      rowsToInsert.push({
        user_id: authorUserId,
        title: title,
        message: message,
        type: notifType,
        is_read: true,
        created_at: nowIso,
        metadata: {
          is_provider_broadcast: true,
          sender_type: 'provider',
          provider_id: providerId,
          provider_name: providerName,
          author_name: authorName,
          announcement_type: type,
          audience: audience,
          program_id: programId || null,
          program_title: programTitle || null,
          location: location || null,
          coordinates: coordinates || null,
          broadcast_id: broadcastId,
          recipients_count: recipientList.length,
          date: nowIso,
        }
      });
    }

    if (rowsToInsert.length > 0) {
      const chunkSize = 100;
      for (let i = 0; i < rowsToInsert.length; i += chunkSize) {
        const chunk = rowsToInsert.slice(i, i + chunkSize);
        const { error: insErr } = await supabase.from('notifications').insert(chunk);
        if (insErr) {
          console.error('[Provider Announcement Insert Chunk Error]:', insErr);
          return { success: false, count: 0, error: insErr.message || 'Permission denied on notifications table' };
        }
      }
    }

    return { success: true, count: recipientList.length };
  } catch (err: any) {
    console.error('[Provider Announcement Exception]:', err);
    return { success: false, count: 0, error: err.message || 'Unknown error' };
  }
};

// ─── FETCH BROADCAST HISTORY ──────────────────────────────────────────────

export const fetchProviderBroadcasts = async (providerId: string, authorUserId?: string): Promise<any[]> => {
  try {
    let query = supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false });

    if (authorUserId) {
      query = query.eq('user_id', authorUserId);
    }

    const { data, error } = await query;
    if (error || !data) return [];

    // Filter to provider broadcasts
    const providerBroadcasts = data.filter((n: any) => {
      const meta = n.metadata || {};
      return meta.sender_type === 'provider' && (meta.provider_id === providerId || meta.is_provider_broadcast);
    });

    // Deduplicate by broadcast_id or (title + created_at)
    const map = new Map<string, any>();
    providerBroadcasts.forEach((n: any) => {
      const meta = n.metadata || {};
      const key = meta.broadcast_id || `${n.title}-${n.created_at}`;
      if (!map.has(key)) {
        map.set(key, {
          id: n.id,
          broadcastId: meta.broadcast_id || n.id,
          title: n.title,
          body: n.message,
          type: meta.announcement_type || n.type || 'General Notice',
          audience: meta.audience || 'All Scholars',
          author: meta.author_name || meta.provider_name || 'Provider Admin',
          location: meta.location || undefined,
          coordinates: meta.coordinates || undefined,
          date: new Date(n.created_at).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          }),
          rawCreatedAt: n.created_at,
          recipientsCount: meta.recipients_count || 0
        });
      }
    });

    return Array.from(map.values());
  } catch (err) {
    console.error('[Fetch Provider Broadcasts Error]:', err);
    return [];
  }
};

export const fetchAdminBroadcasts = async (): Promise<any[]> => {
  try {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false });

    if (error || !data) return [];

    const adminBroadcasts = data.filter((n: any) => {
      const meta = n.metadata || {};
      return meta.sender_type === 'admin';
    });

    const map = new Map<string, any>();
    adminBroadcasts.forEach((n: any) => {
      const meta = n.metadata || {};
      const key = meta.broadcast_id || `${n.title}-${n.created_at}`;
      if (!map.has(key)) {
        map.set(key, {
          id: n.id,
          broadcastId: meta.broadcast_id || n.id,
          title: n.title,
          body: n.message,
          target: meta.target_audience || 'Both',
          author: meta.sender_name || 'System Admin',
          date: new Date(n.created_at).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          }),
          rawCreatedAt: n.created_at,
          recipientsCount: meta.recipients_count || 0
        });
      }
    });

    return Array.from(map.values());
  } catch (err) {
    console.error('[Fetch Admin Broadcasts Error]:', err);
    return [];
  }
};

// ─── USER NOTIFICATIONS / INBOX ──────────────────────────────────────────

export const fetchUserNotifications = async (userId: string) => {
  try {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  } catch (err) {
    console.error('[Fetch User Notifications Error]:', err);
    return [];
  }
};

export const markNotificationAsRead = async (notificationId: string) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', notificationId);
    if (error) throw error;
    return true;
  } catch (err) {
    console.error('[Mark Notification Read Error]:', err);
    return false;
  }
};

export const markAllNotificationsAsRead = async (userId: string) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', userId);
    if (error) throw error;
    return true;
  } catch (err) {
    console.error('[Mark All Read Error]:', err);
    return false;
  }
};

export const deleteNotification = async (notificationId: string) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .delete()
      .eq('id', notificationId);
    if (error) throw error;
    return true;
  } catch (err) {
    console.error('[Delete Notification Error]:', err);
    return false;
  }
};

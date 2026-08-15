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
      }
    }
  } catch (sysNotifErr) {
    console.warn('[System Notification Exception]:', sysNotifErr);
  }
};

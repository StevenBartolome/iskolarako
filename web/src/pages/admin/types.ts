export interface SystemAdminPortalProps {
  onLogout: () => void;
  showWelcome?: boolean;
}

export type AdminTab =
  | 'dashboard'
  | 'providers'
  | 'scholarships'
  | 'students'
  | 'applications'
  | 'documents'
  | 'reports'
  | 'funds'
  | 'notifications'
  | 'users'
  | 'logs'
  | 'settings'
  | 'profile';

import type { DocVerificationResult } from '@/services/aiExtractionService';

export interface ProviderDocumentItem {
  name: string;
  url: string;
  verified: boolean;
  status?: 'Pending' | 'Verified' | 'Flagged';
  remarks?: string;
  isAiScanning?: boolean;
  aiVerification?: DocVerificationResult;
}

export interface ProviderOrg {
  id: any;
  name: string;
  representative: string;
  email: string;
  type: 'Government' | 'Private' | 'NGO' | string;
  status: 'Pending' | 'Under Review' | 'Verified' | 'Active' | 'Suspended' | 'Revoked' | string;
  documents: ProviderDocumentItem[];
  dateRegistered: string;
  remarks?: string;
  aiAuditSummary?: {
    total: number;
    verified: number;
    flagged: number;
    actionTaken?: string;
  };
}

export interface ScholarshipAdminView {
  id: any;
  title: string;
  providerName: string;
  category: string;
  amount: number;
  status: 'Pending Review' | 'Approved' | 'Rejected' | 'Published' | 'Suspended' | string;
  dateCreated: string;
}

export interface StudentAdminView {
  id: number | string;
  name: string;
  email: string;
  school: string;
  course: string;
  yearLevel: string;
  gpa: string;
  citizenship: string;
  verificationStatus: 'Verified' | 'Pending' | 'Flagged' | string;
  accountStatus: 'Active' | 'Suspended' | string;
}

export interface AdminReport {
  id: number;
  reportedEntity: string;
  type: 'Provider' | 'Scholarship' | string;
  reason: string;
  reporter: string;
  status: 'Under Investigation' | 'Resolved' | 'Dismissed' | string;
  date: string;
}

export interface TransactionRecord {
  id: string;
  provider: string;
  scholar: string;
  amount: number;
  status: 'COMPLETED' | 'PENDING' | 'FAILED' | string;
  reference: string;
  date: string;
}

export interface AuditLogEntry {
  id: string | number;
  admin: string;
  action: string;
  target: string;
  date: string;
  time: string;
  ip: string;
}

export interface RequirementItem {
  name: string;
  description: string;
  required: boolean;
}

export interface AdminAccount {
  id: number;
  username: string;
  role: string;
  status: 'Active' | 'Disabled' | string;
}

export interface CategoryItem {
  id: any;
  name: string;
}

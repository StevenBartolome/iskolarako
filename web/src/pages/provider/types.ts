export interface ProviderPortalProps {
  onLogout: () => void;
  showWelcome?: boolean;
}

export type FundingFreq = any;
export type RenewalPolicy = any;
export type ScholarshipType = any;

export type EducationLevel =
  | 'college'
  | 'graduate'
  | 'senior_high'
  | 'high_school'
  | 'elementary'
  | 'vocational'
  | 'incoming_college';

export type GradingSystem = 'scale_5' | 'scale_4' | 'percentage';

export interface Program {
  id?: any;
  title?: any;
  category?: any;
  category_id?: any;
  amount?: any;
  funding_frequency?: any;
  fundingFrequency?: any;
  gpa_requirement?: any;
  income_ceiling?: any;
  target_education_level?: EducationLevel;
  grading_system?: GradingSystem;
  targetEducationLevel?: EducationLevel;
  gradingSystem?: GradingSystem;
  status?: any;
  applicants_count?: any;
  scholars_count?: any;
  disbursed_total?: any;
  total_slots?: any;
  totalSlots?: any;
  cycles_count?: any;
  description?: any;
  eligible_courses?: any;
  eligible_year_levels?: any;
  eligible_regions?: any;
  selection_criteria?: any;
  renewalPolicy?: any;
  coverstuition?: any;
  coversStipend?: any;
  stipendAmount?: any;
  coversAllowance?: any;
  allowanceAmount?: any;
  otherBenefits?: any;
  courseEligibility?: any;
  yearLevelEligibility?: any;
  minimumGwa?: any;
  availabilityScope?: any;
  budgetTotal?: any;
  applicationRequirements?: any;
  cycles?: any;
  [key: string]: any;
}

export interface ApplicationCycle {
  id?: any;
  program_id?: any;
  cycle_name?: any;
  academic_year?: any;
  semester?: any;
  start_date?: any;
  end_date?: any;
  target_slots?: any;
  status?: any;
  [key: string]: any;
}

export interface ProgramRequirement {
  id?: any;
  program_id?: any;
  document_name?: any;
  name?: any;
  description?: any;
  is_required?: any;
  required?: any;
  [key: string]: any;
}

export interface DisbursementTx {
  id?: any;
  cycle_id?: any;
  scholar_name?: any;
  scholarName?: any;
  scholar_id?: any;
  program_title?: any;
  programTitle?: any;
  program?: any;
  amount?: any;
  numericAmount?: any;
  disbursement_date?: any;
  disbursement_channel?: any;
  reference_number?: any;
  status?: any;
  [key: string]: any;
}

export interface ScholarAward {
  id?: any;
  scholar_name?: any;
  scholarName?: any;
  email?: any;
  school?: any;
  course?: any;
  year_level?: any;
  gpa?: any;
  award_amount?: any;
  programTitle?: any;
  status?: any;
  payoutHistory?: any[];
  payoutStatus?: string;
  [key: string]: any;
}

export type TabType = any;
export type AnnType = any;

export interface Announcement {
  id?: any;
  title?: any;
  body?: any;
  type?: any;
  audience?: any;
  date?: any;
  author?: any;
  location?: any;
  [key: string]: any;
}

export type ApplicantStatus = any;

export interface ProviderDetails {
  id?: any;
  name?: any;
  providerType?: any;
  verificationStatus?: any;
  requirementsSubmitted?: any;
  user_id?: any;
  organization_name?: any;
  organization_type?: any;
  contact_person?: any;
  email?: any;
  phone?: any;
  address?: any;
  documents?: any;
  remarks?: any;
  [key: string]: any;
}

export interface ProviderProfile {
  id?: any;
  name?: any;
  type?: any;
  status?: any;
  [key: string]: any;
}

export type AvailabilityScope = any;

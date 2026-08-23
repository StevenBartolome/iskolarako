import React, { useState, useEffect } from 'react';
import { GoogleMap, useJsApiLoader, Marker, Autocomplete } from '@react-google-maps/api';
import LogoGoldSvg from '@/assets/logo/iskolarakologo-notext-gold.svg';
import { supabase } from '@/services/supabaseClient';
import { CloseProgramConfirmModal } from './components/CloseProgramConfirmModal';
import { DeleteCycleConfirmModal } from './components/DeleteCycleConfirmModal';
import { RenewCycleModal } from './components/RenewCycleModal';
import { ReviewApplicationModal } from './components/ReviewApplicationModal';
import type { ApplicationDetail, SubmittedDocItem } from './components/ReviewApplicationModal';
import { ProviderDashboardTab } from './components/ProviderDashboardTab';
import { ProviderApplicantsTab } from './components/ProviderApplicantsTab';
import { ProviderProgramsTab } from './components/ProviderProgramsTab';
import { ProviderDisbursementsTab } from './components/ProviderDisbursementsTab';
import { ProviderAnnouncementsTab } from './components/ProviderAnnouncementsTab';
import { ProviderReportsTab } from './components/ProviderReportsTab';
import { ProviderVerificationTab } from './components/ProviderVerificationTab';
import { ProviderViewApplicationTab } from './components/ProviderViewApplicationTab';
import { ProviderProgramFormTab } from './components/ProviderProgramFormTab';
import { ProfileSettingsTab } from '@/components/common/ProfileSettingsTab';
import { ProviderNotificationDrawer } from './components/ProviderNotificationDrawer';
import { sendProviderAnnouncement, fetchProviderBroadcasts, deleteNotification, sendDecisionNotification } from '@/services/notificationService';
import type {
  ProviderPortalProps,
  TabType,
  AnnType,
  ApplicantStatus,
  ApplicationCycle,
  ProgramRequirement,
  Program,
  DisbursementTx,
  ScholarAward,
} from './types';
export type { ApplicationCycle, ProgramRequirement, Program };

const parseLocalMidnight = (dateStr: string) => {
  if (!dateStr) return new Date();
  const [year, month, day] = dateStr.split('-').map(Number);
  return new Date(year, month - 1, day);
};

const getTodayMidnight = () => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return today;
};


export const ProviderPortal: React.FC<ProviderPortalProps> = ({ onLogout, showWelcome }) => {
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  
  // Current authenticated user ID
  const [currentUserId, setCurrentUserId] = useState<string | undefined>(undefined);

  // Notification Drawer State
  const [isNotificationDrawerOpen, setIsNotificationDrawerOpen] = useState(false);
  const [unreadNotifCount, setUnreadNotifCount] = useState(0);

  // Profile state loaded dynamically from Supabase
  const [profile, setProfile] = useState<{
    firstName: string;
    lastName: string;
    role: string;
    providerName: string;
  } | null>(null);

  // Provider verification states loaded dynamically from Supabase
  const [providerDetails, setProviderDetails] = useState<{
    id: string;
    name: string;
    providerType: string;
    verificationStatus: 'pending' | 'under_review' | 'verified' | 'rejected';
    requirementsSubmitted: Record<string, string>;
  } | null>(null);

  // Requirements checklist configuration for this provider type
  const [requiredDocs, setRequiredDocs] = useState<{ name: string; description: string; required: boolean }[]>([]);
  const [isLoadingProvider, setIsLoadingProvider] = useState(true);

  // Uploading and submission indicators
  const [uploadingDoc, setUploadingDoc] = useState<string | null>(null);
  const [submittingVerification, setSubmittingVerification] = useState(false);

  // Tracks whether the provider has edited/re-uploaded a document in the current status window
  const [hasModifiedDocs, setHasModifiedDocs] = useState(false);

  // Reset the modification flag whenever the verification status changes,
  // so a resubmission always requires a fresh document edit/re-upload
  useEffect(() => {
    setHasModifiedDocs(false);
  }, [providerDetails?.verificationStatus]);

  const fetchRequirementsConfig = async (providerType: string) => {
    try {
      const { data: configData } = await supabase
        .from('provider_requirements_config')
        .select('required_fields')
        .eq('provider_type', providerType)
        .maybeSingle();

      if (configData && configData.required_fields && Array.isArray(configData.required_fields)) {
        setRequiredDocs(configData.required_fields);
      } else {
        // Fallback templates based on type if configuration doesn't exist yet
        if (providerType === 'public') {
          setRequiredDocs([
            { name: 'Government Charter or Mandate', description: 'Copy of the official establishing act/mandate', required: true },
            { name: 'Representative ID', description: 'Valid government ID of the focal person', required: true }
          ]);
        } else if (providerType === 'private') {
          setRequiredDocs([
            { name: 'SEC Registration Certificate', description: 'SEC Certificate of Registration', required: true },
            { name: 'BIR Form 2303', description: 'Certificate of Registration with BIR', required: true },
            { name: 'Business Permit', description: 'Current year Mayor\'s Business Permit', required: true }
          ]);
        } else {
          setRequiredDocs([
            { name: 'SEC or DTI Registration Certificate', description: 'Official corporate registration copy', required: true },
            { name: 'BIR Certificate / Tax Exemption', description: 'Tax exemption certificate if applicable', required: false }
          ]);
        }
      }
    } catch (err) {
      console.error('Error fetching requirements config:', err);
    }
  };

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;
        setCurrentUserId(user.id);

        // Fetch user record
        const { data: userData, error: userErr } = await supabase
          .from('users')
          .select('first_name, last_name, role, provider_id')
          .eq('id', user.id)
          .single();

        if (userErr || !userData) return;

        // Fetch provider name and verification details if exists
        let provName = 'Public Provider';
        if (userData.provider_id) {
          const { data: provData, error: provErr } = await supabase
            .from('provider')
            .select('id, name, provider_type, verification_status, requirements_submitted')
            .eq('id', userData.provider_id)
            .single();

          if (!provErr && provData) {
            provName = provData.name;
            setProviderDetails({
              id: provData.id,
              name: provData.name,
              providerType: provData.provider_type,
              verificationStatus: provData.verification_status as any,
              requirementsSubmitted: provData.requirements_submitted || {}
            });

            // Fetch required documents configuration
            await fetchRequirementsConfig(provData.provider_type);
          }
        }

        setProfile({
          firstName: userData.first_name,
          lastName: userData.last_name,
          role: userData.role,
          providerName: provName
        });

        // Show welcome toast dynamically only on successful login flow, not on page reload session restores
        if (showWelcome) {
          setToastMessage(`Welcome back, ${userData.first_name}!`);
          setTimeout(() => setToastMessage(null), 3000);
        }
      } catch (err) {
        console.error('Error fetching provider profile:', err);
      } finally {
        setIsLoadingProvider(false);
      }
    };

    fetchProfile();
  }, [showWelcome]);

  // Subscribe to real-time updates for the current provider
  useEffect(() => {
    if (!providerDetails?.id) return;

    const channel = supabase
      .channel('provider-realtime-channel')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'provider'
        },
        (payload: any) => {
          const updated = payload.new;
          if (updated && updated.id === providerDetails.id) {
            setProviderDetails(prev => {
              if (!prev) return null;
              // Only update if things actually changed
              if (
                prev.verificationStatus === updated.verification_status &&
                JSON.stringify(prev.requirementsSubmitted) === JSON.stringify(updated.requirements_submitted || {})
              ) {
                return prev;
              }
              return {
                ...prev,
                verificationStatus: updated.verification_status,
                requirementsSubmitted: updated.requirements_submitted || {}
              };
            });
            showToast('Verification status updated in real-time!');
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [providerDetails?.id]);

  // Subscribe to real-time updates for requirements configurations
  useEffect(() => {
    if (!providerDetails?.providerType) return;

    const channel = supabase
      .channel('provider-requirements-config-channel')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'provider_requirements_config'
        },
        (payload: any) => {
          const updated = payload.new;
          if (updated && updated.provider_type === providerDetails.providerType) {
            if (updated.required_fields && Array.isArray(updated.required_fields)) {
              setRequiredDocs(updated.required_fields);
              showToast('Required documents updated in real-time!');
            }
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [providerDetails?.providerType]);

  // Categories Lookup & Real Database Fetching for Programs
  const [categories, setCategories] = useState<{ id: string; name: string }[]>([]);

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const { data, error } = await supabase
          .from('scholarship_categories')
          .select('id, name');
        if (!error && data) {
          setCategories(data);
        }
      } catch (err) {
        console.error('Error fetching categories:', err);
      }
    };
    fetchCategories();
  }, []);

  const mapDbToProgram = (dbProg: any): Program => {
    return {
      id: dbProg.id,
      provider: providerDetails?.name || 'My Provider',
      status: dbProg.status === 'approved' || dbProg.status === 'Approved' || dbProg.status === 'active' || dbProg.status === 'Active' ? 'Approved' : dbProg.status === 'pending' || dbProg.status === 'Pending' ? 'Pending Review' : dbProg.status === 'paused' ? 'Rejected' : dbProg.status === 'draft' || dbProg.status === 'Draft' ? 'Draft' : 'Closed',
      statusType: dbProg.status === 'approved' || dbProg.status === 'Approved' || dbProg.status === 'active' || dbProg.status === 'Active' ? 'success' : dbProg.status === 'pending' || dbProg.status === 'Pending' ? 'draft' : dbProg.status === 'paused' ? 'closing' : dbProg.status === 'draft' || dbProg.status === 'Draft' ? 'draft' : 'closing',
      title: dbProg.title,
      description: dbProg.description,
      category: dbProg.category?.name || 'Merit-Based',
      scholarshipType: dbProg.scholarship_type,
      coverstuition: dbProg.covers_tuition,
      coversStipend: dbProg.covers_stipend,
      stipendAmount: dbProg.stipend_amount ? String(dbProg.stipend_amount) : '',
      coversAllowance: dbProg.covers_allowance,
      allowanceAmount: dbProg.allowance_amount ? String(dbProg.allowance_amount) : '',
      otherBenefits: dbProg.other_benefits || [],
      courseEligibility: dbProg.course_eligibility || [],
      yearLevelEligibility: dbProg.year_level_eligibility || [],
      minimumGwa: dbProg.minimum_gwa ? String(dbProg.minimum_gwa) : '',
      availabilityScope: dbProg.availability_scope,
      availableRegions: dbProg.available_regions || [],
      availableSchools: dbProg.available_schools ? dbProg.available_schools.join(', ') : '',
      totalSlots: dbProg.total_slots ? String(dbProg.total_slots) : '',
      applicationRequirements: dbProg.application_requirements || [],
      renewalPolicy: dbProg.renewal_policy,
      fundingFrequency: dbProg.funding_frequency,
      disbursement_mode: dbProg.disbursement_mode,
      banking_policy: dbProg.banking_policy,
      required_bank_name: dbProg.required_bank_name,
      renewalGwa: dbProg.renewal_gwa_requirement ? String(dbProg.renewal_gwa_requirement) : '',
      cycles: (dbProg.cycles || []).map((cyc: any) => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const end = cyc.application_end_date ? new Date(cyc.application_end_date + 'T00:00:00') : null;
        const start = cyc.application_start_date ? new Date(cyc.application_start_date + 'T00:00:00') : null;

        let dynamicStatus = 'Closed';
        const rawStatus = (cyc.status || '').toLowerCase().trim();

        if (rawStatus === 'closed' || rawStatus === 'archived') {
          dynamicStatus = 'Closed';
        } else if (end && end < today) {
          // Deadline has passed! Automatically mark as Closed
          dynamicStatus = 'Closed';
        } else if (start && start > today) {
          dynamicStatus = 'Upcoming';
        } else if (rawStatus === 'evaluating') {
          dynamicStatus = 'Evaluating';
        } else {
          dynamicStatus = 'Open';
        }

        return {
          id: cyc.id,
          name: cyc.cycle_name,
          startDate: cyc.application_start_date,
          endDate: cyc.application_end_date,
          status: dynamicStatus,
          cycleType: cyc.cycle_type,
          semester: cyc.semester,
          slotsAvailable: cyc.slots_available,
          renewalRequirements: cyc.renewal_requirements,
        };
      }),
      budgetUsed: '₱0',
      budgetTotal: dbProg.budget_total ? `₱${Number(dbProg.budget_total).toLocaleString()}` : '₱0',
      rejectionRemarks: dbProg.rejection_remarks || undefined,
      targetEducationLevel: dbProg.target_education_level || 'college',
      gradingSystem: dbProg.grading_system || 'scale_5',
    };
  };

  const fetchPrograms = async () => {
    if (!providerDetails?.id) return;
    try {
      const { data, error } = await supabase
        .from('scholarship_programs')
        .select(`
          *,
          category:scholarship_categories (
            name
          ),
          cycles:application_cycles (
            *
          )
        `)
        .eq('provider_id', providerDetails.id);

      if (error) {
        console.error('Error fetching programs:', error);
        return;
      }

      if (data) {
        // Auto-sync expired cycles in the database to status: 'closed'
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const expiredCycleIds = data.flatMap((p: any) =>
          (p.cycles || [])
            .filter((c: any) => (c.status === 'open' || c.status === 'active') && c.application_end_date && new Date(c.application_end_date + 'T00:00:00') < today)
            .map((c: any) => c.id)
        );

        if (expiredCycleIds.length > 0) {
          supabase
            .from('application_cycles')
            .update({ status: 'closed' })
            .in('id', expiredCycleIds)
            .then(() => console.log(`[Auto-Close Cycles]: Synced ${expiredCycleIds.length} expired cycles to closed in DB.`));
        }

        const mapped = data.map(mapDbToProgram);
        setProgramsList(mapped);
      }
    } catch (err) {
      console.error('Error fetching programs:', err);
    }
  };

  useEffect(() => {
    fetchPrograms();

    const progChannel = supabase
      .channel('provider-programs-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_programs' },
        () => {
          fetchPrograms();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'application_cycles' },
        () => {
          fetchPrograms();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(progChannel);
    };
  }, [providerDetails?.id, categories]);

  // Search & filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  // Sub-tab toggles under Applicants view: 'applicants' vs 'scholars'
  const [subTab, setSubTab] = useState<'applicants' | 'scholars'>('applicants');

  // Toast indicator
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [collapsedGroups, setCollapsedGroups] = useState<Record<string, boolean>>({
    management: false,
    operations: false
  });

  const toggleGroup = (group: string) => {
    if (isCollapsed) return;
    setCollapsedGroups(prev => ({ ...prev, [group]: !prev[group] }));
  };

  // Modal states
  const [isPayoutModalOpen, setIsPayoutModalOpen] = useState(false);
  const [isBigMapModalOpen, setIsBigMapModalOpen] = useState(false);

  // Renew/Reopen Cycle Modal States
  const [isRenewModalOpen, setIsRenewModalOpen] = useState(false);
  const [selectedProgramForRenewal, setSelectedProgramForRenewal] = useState<Program | null>(null);
  const [cycleToEdit, setCycleToEdit] = useState<any | null>(null);
  const [renewCycleName, setRenewCycleName] = useState('');
  const [renewStartDate, setRenewStartDate] = useState('');
  const [renewEndDate, setRenewEndDate] = useState('');
  const [renewSlots, setRenewSlots] = useState('');
  const [renewCycleType, setRenewCycleType] = useState<'new_applicant' | 'renewal'>('renewal');
  const [renewSemester, setRenewSemester] = useState<string>('2nd Semester');
  const [renewRequirements, setRenewRequirements] = useState<Array<{ name: string; description: string }>>([
    {
      name: '1st Semester Official Grade Slip / Report of Grades',
      description: 'Signed copy or student portal screenshot of your 1st semester grades/GWA',
    },
    {
      name: 'Certificate of Registration (COR) / Enrollment Form (2nd Semester)',
      description: 'Official proof of enrollment for the upcoming semester with enrolled units',
    },
  ]);

  // Delete Cycle Confirm Modal States
  const [isDeleteCycleConfirmOpen, setIsDeleteCycleConfirmOpen] = useState(false);
  const [cycleToDelete, setCycleToDelete] = useState<{ id: string; name: string } | null>(null);

  // New payout form inputs
  const [selectedPayoutProgram, setSelectedPayoutProgram] = useState('DOST-SEI Undergraduate Scholarship');

  // Google Maps simulation states
  const [selectedExamLocation, setSelectedExamLocation] = useState('');
  const [mapSearchText, setMapSearchText] = useState('');
  const [examCoords, setExamCoords] = useState({
    lat: 14.6538,
    lng: 121.0685,
    address: 'University of the Philippines, Diliman, Quezon City'
  });
  const [mapZoom, setMapZoom] = useState(14);
  const [autocomplete, setAutocomplete] = useState<google.maps.places.Autocomplete | null>(null);

  const [libraries] = useState<"places"[]>(['places']);

  // Load live Google Maps
  const { isLoaded } = useJsApiLoader({
    googleMapsApiKey: import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '',
    id: 'google-map-script',
    libraries
  });

  const onAutocompleteLoad = (autocompleteInstance: google.maps.places.Autocomplete) => {
    setAutocomplete(autocompleteInstance);
  };

  const onPlaceChanged = () => {
    if (autocomplete !== null) {
      const place = autocomplete.getPlace();
      const name = place.name || '';
      const address = place.formatted_address || '';
      const lat = place.geometry?.location?.lat() || 14.6538;
      const lng = place.geometry?.location?.lng() || 121.0685;

      setSelectedExamLocation(name || address);
      setMapSearchText(name || address);
      setExamCoords({ lat, lng, address });
      showToast(`Selected: ${name || address}`);
    }
  };

  const handleMapClick = (e: google.maps.MapMouseEvent) => {
    if (e.latLng) {
      const lat = e.latLng.lat();
      const lng = e.latLng.lng();
      if (window.google && window.google.maps) {
        const geocoder = new window.google.maps.Geocoder();
        geocoder.geocode({ location: { lat, lng } }, (results, status) => {
          if (status === 'OK' && results && results[0]) {
            const address = results[0].formatted_address;
            setSelectedExamLocation(address);
            setMapSearchText(address);
            setExamCoords({ lat, lng, address });
            showToast(`Location set to: ${address}`);
          } else {
            const coordsString = `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
            setSelectedExamLocation(coordsString);
            setMapSearchText(coordsString);
            setExamCoords({ lat, lng, address: `Coordinates: ${coordsString}` });
            showToast(`Location set to: ${coordsString}`);
          }
        });
      } else {
        const coordsString = `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
        setSelectedExamLocation(coordsString);
        setMapSearchText(coordsString);
        setExamCoords({ lat, lng, address: `Coordinates: ${coordsString}` });
        showToast(`Location set to: ${coordsString}`);
      }
    }
  };

  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  // Announcements state
  const [announcements, setAnnouncements] = useState<any[]>([]);
  const [newAnnTitle, setNewAnnTitle] = useState('');
  const [newAnnBody, setNewAnnBody] = useState('');
  const [newAnnType, setNewAnnType] = useState<AnnType>('General Notice');
  const [newAnnAudience, setNewAnnAudience] = useState('All Scholars');
  const [selectedProgramId, setSelectedProgramId] = useState<string>('all');
  const [isBroadcasting, setIsBroadcasting] = useState(false);

  const fetchBroadcasts = async () => {
    if (!providerDetails?.id) return;
    try {
      const data = await fetchProviderBroadcasts(providerDetails.id, currentUserId);
      if (data && data.length > 0) {
        setAnnouncements(data);
      }
    } catch (err) {
      console.error('Error fetching provider broadcasts:', err);
    }
  };

  useEffect(() => {
    if (providerDetails?.id) {
      fetchBroadcasts();
    }
  }, [providerDetails?.id, currentUserId]);

  const handleAddAnnouncement = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAnnTitle.trim() || !newAnnBody.trim() || !providerDetails?.id) return;

    // Validate Examination Venue for exam schedules
    const examLocation = (examCoords.address || selectedExamLocation || '').trim();
    if (newAnnType === 'Examination Schedule' && !examLocation) {
      showToast('Examination Venue is required! Please specify a venue location.');
      return;
    }

    setIsBroadcasting(true);
    try {
      const matchedProg = programsList.find(p => String(p.id) === selectedProgramId);
      const res = await sendProviderAnnouncement({
        providerId: providerDetails.id,
        providerName: providerDetails.name,
        authorUserId: currentUserId,
        authorName: profile ? `${profile.firstName} ${profile.lastName}` : providerDetails.name,
        title: newAnnTitle.trim(),
        message: newAnnBody.trim(),
        type: newAnnType,
        audience: newAnnAudience,
        programId: selectedProgramId !== 'all' ? selectedProgramId : undefined,
        programTitle: matchedProg ? matchedProg.title : undefined,
        location: newAnnType === 'Examination Schedule' ? examLocation : undefined,
        coordinates: newAnnType === 'Examination Schedule' ? { lat: examCoords.lat, lng: examCoords.lng, address: examCoords.address } : undefined,
      });

      if (res.success) {
        if (newAnnType === 'Examination Schedule') {
          if (res.count > 0) {
            showToast(`Exam schedule published & sent to ${res.count} shortlisted "for_exam" candidates!`);
          } else {
            showToast(`Exam schedule published (0 candidates currently in "for_exam" status).`);
          }
        } else if (selectedProgramId !== 'all' && matchedProg) {
          if (res.count > 0) {
            showToast(`Announcement published & sent to ${res.count} approved scholars of "${matchedProg.title}"!`);
          } else {
            showToast(`Announcement published (0 approved scholars found for "${matchedProg.title}").`);
          }
        } else {
          showToast(`Announcement published & saved to ${res.count} scholars' inboxes!`);
        }
        setNewAnnTitle('');
        setNewAnnBody('');
        await fetchBroadcasts();
      } else {
        showToast(`Broadcast failed: ${res.error || 'Unknown error'}`);
      }
    } catch (err: any) {
      console.error('Error broadcasting announcement:', err);
      showToast(`Broadcast failed: ${err.message || 'Error occurred'}`);
    } finally {
      setIsBroadcasting(false);
    }
  };

  const handleDeleteAnnouncement = async (id: string | number) => {
    try {
      await deleteNotification(String(id));
      showToast('Announcement removed.');
      await fetchBroadcasts();
    } catch (err) {
      console.error('Error deleting announcement:', err);
    }
  };

  // Programs State (Loaded dynamically from database)
  const [programsList, setProgramsList] = useState<Program[]>([]);

  // Interactive Applicants State (Students in an active application cycle)
  const [applicantsList, setApplicantsList] = useState<ApplicationDetail[]>([]);

  // Active Scholars (Awarded students under requirements monitoring)
  const [scholarsList, setScholarsList] = useState<ScholarAward[]>([]);

  // Review Application Modal states
  const [selectedAppForReview, setSelectedAppForReview] = useState<ApplicationDetail | null>(null);
  const [isReviewModalOpen, setIsReviewModalOpen] = useState(false);

  const fetchApplicantsAndScholars = async () => {
    if (!providerDetails?.id) {
      console.log('[Provider Portal Debug]: No provider details yet, skipping fetch');
      return;
    }

    console.log('[Provider Portal Debug]: Fetching scholarship_applications for provider:', providerDetails.id);
    try {
      // First, get the program IDs for this provider
      const { data: programsData, error: programsError } = await supabase
        .from('scholarship_programs')
        .select('id')
        .eq('provider_id', providerDetails.id);

      if (programsError) {
        console.error('[Provider Portal Programs Error]:', programsError);
        return;
      }

      const programIds = programsData?.map(p => p.id) || [];
      if (programIds.length === 0) {
        console.log('[Provider Portal Debug]: No programs found for this provider');
        setApplicantsList([]);
        setScholarsList([]);
        return;
      }

      // Get cycle IDs for these programs
      const { data: cyclesData, error: cyclesError } = await supabase
        .from('application_cycles')
        .select('id')
        .in('program_id', programIds);

      if (cyclesError) {
        console.error('[Provider Portal Cycles Error]:', cyclesError);
        return;
      }

      const cycleIds = cyclesData?.map(c => c.id) || [];
      if (cycleIds.length === 0) {
        console.log('[Provider Portal Debug]: No cycles found for this provider programs');
        setApplicantsList([]);
        setScholarsList([]);
        return;
      }

      // Now fetch applications for these cycles only
      const { data, error } = await supabase
        .from('scholarship_applications')
        .select(`
          *,
          scholar:scholar (
            *,
            user:users (
              id,
              email,
              first_name,
              last_name
            )
          ),
          cycle:application_cycles (
            *,
            program:scholarship_programs (*)
          )
        `)
        .in('cycle_id', cycleIds)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('[Provider Portal Query Error - scholarship_applications]:', error);
        if (error.code === '42501' || error.message?.includes('permission') || error.message?.includes('policy')) {
          console.error('[Provider RLS Permission Warning]: RLS Policy blocking access to "scholarship_applications" table.');
        }
        setApplicantsList([]);
        setScholarsList([]);
        return;
      }

      console.log(`[Provider Portal Debug]: Found ${data?.length || 0} applications for provider ${providerDetails.name}`);

        if (data && data.length > 0) {
          // Fetch scholar_documents for the scholars in these applications
          const scholarIds = data.map((a: any) => a.scholar_id).filter(Boolean);
          let scholarDocsMap: Record<string, SubmittedDocItem[]> = {};
          if (scholarIds.length > 0) {
            try {
              const { data: docsData, error: docsErr } = await supabase
                .from('scholar_documents')
                .select('*')
                .in('scholar_id', scholarIds);

              if (docsErr) {
                console.error('[Provider Scholar Documents Error]:', docsErr);
                if (docsErr.code === '42501' || docsErr.message?.includes('permission') || docsErr.message?.includes('policy')) {
                  console.error('[Provider RLS Permission Warning]: RLS Policy blocking access to "scholar_documents" table.');
                }
              } else if (docsData) {
                console.log(`[Provider Scholar Documents Debug]: Loaded ${docsData.length} records from scholar_documents table.`);
                docsData.forEach((d: any) => {
                  if (!scholarDocsMap[d.scholar_id]) {
                    scholarDocsMap[d.scholar_id] = [];
                  }

                  let aiVerificationObj = undefined;
                  if (d.ai_verification_status && d.ai_verification_status !== 'pending') {
                    aiVerificationObj = {
                      isAuthenticLayout: d.ai_verification_status === 'verified',
                      tamperingDetected: d.ai_flags && Array.isArray(d.ai_flags) && d.ai_flags.some((f: string) => f.toLowerCase().includes('tamper') || f.toLowerCase().includes('alter')),
                      hasOfficialSealOrSignature: d.ai_verification_status === 'verified',
                      isDocumentLegitimate: d.ai_verification_status !== 'rejected',
                      extractedName: d.ai_extracted_data?.extractedName,
                      extractedSchool: d.ai_extracted_data?.extractedSchool,
                      extractedGwa: d.ai_extracted_data?.extractedGwa,
                      extractedIncome: d.ai_extracted_data?.extractedIncome,
                      extractedDocType: d.ai_extracted_data?.extractedDocType || d.document_name,
                      verificationStatus: d.ai_verification_status,
                      confidenceScore: typeof d.ai_confidence_score === 'number' ? d.ai_confidence_score : 0.9,
                      flags: Array.isArray(d.ai_flags) ? d.ai_flags : [],
                      summary: d.remarks || 'Forensic verification recorded.',
                      aiModelUsed: d.ai_model_used || 'AI Forensic Engine',
                      provider: 'IskoAko AI',
                      sha256Hash: d.file_sha256_hash,
                      crossCheckResults: d.ai_extracted_data?.crossCheckResults || {
                        nameMatch: true,
                        schoolMatch: true,
                        gwaMatch: null,
                        sealPresent: true,
                        tamperingFound: false,
                      },
                    };
                  }

                  scholarDocsMap[d.scholar_id].push({
                    id: d.id,
                    name: d.document_name,
                    filename: d.document_name,
                    document_url: d.document_url,
                    url: d.document_url,
                    status: d.verification_status === 'verified' ? 'Verified' : d.verification_status === 'rejected' ? 'Flagged' : 'Pending',
                    remarks: d.remarks || '',
                    submitted_at: d.created_at ? new Date(d.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'Recently',
                    aiVerification: aiVerificationObj,
                  });
                });
              }
            } catch (dErr) {
              console.warn('[Provider Scholar Documents Exception]:', dErr);
            }
          }

          let scholarPaymentMap: Record<string, any> = {};
          let scholarPayoutsMap: Record<string, any[]> = {};
          if (scholarIds.length > 0) {
            try {
              const { data: pAccData } = await supabase
                .from('scholar_payment_accounts')
                .select('*')
                .in('scholar_id', scholarIds);
              if (pAccData) {
                pAccData.forEach((p: any) => {
                  scholarPaymentMap[p.scholar_id] = p;
                });
              }
            } catch (pErr) {
              console.warn('[Provider Scholar Payment Accounts Exception]:', pErr);
            }

            try {
              const { data: frData } = await supabase
                .from('fund_releases')
                .select(`
                  id,
                  application_id,
                  scholar_id,
                  cycle_id,
                  program_id,
                  amount,
                  status,
                  blockchain_verified,
                  fund_type,
                  created_at,
                  cycle:cycle_id(cycle_name, semester, cycle_type)
                `)
                .in('scholar_id', scholarIds)
                .order('created_at', { ascending: true });

              if (frData) {
                frData.forEach((fr: any) => {
                  if (!scholarPayoutsMap[fr.scholar_id]) {
                    scholarPayoutsMap[fr.scholar_id] = [];
                  }
                  scholarPayoutsMap[fr.scholar_id].push(fr);
                });
              }
            } catch (frErr) {
              console.warn('[Provider Fund Releases Exception]:', frErr);
            }
          }

          const formatYearLevel = (yl: any) => {
            if (yl === null || yl === undefined || yl === '') return '1st Year';
            const num = Number(yl);
            if (!isNaN(num)) {
              if (num === 1) return '1st Year';
              if (num === 2) return '2nd Year';
              if (num === 3) return '3rd Year';
              if (num === 4) return '4th Year';
              if (num === 5) return '5th Year';
              return `${num}th Year`;
            }
            return String(yl);
          };

          const formatGwa = (raw: any, remarksStr?: string) => {
            if (raw !== null && raw !== undefined && String(raw).trim() !== '') {
              return String(raw).trim();
            }
            if (remarksStr) {
              const match = remarksStr.match(/GWA:\s*([0-9\.]+)/i);
              if (match && match[1]) return match[1];
            }
            return '1.50';
          };

          const mappedApplicants: ApplicationDetail[] = data.map((app: any) => {
            const scholar = app.scholar || {};
            const user = scholar.user || {};
            const cycle = app.cycle || {};
            const prog = cycle.program || {};

            console.log('[Provider Join Debug]: app.scholar =', JSON.stringify(app.scholar));
            console.log('[Provider Join Debug]: scholar.user =', JSON.stringify((app.scholar || {}).user));
            console.log('[Provider Join Debug]: app.cycle =', JSON.stringify(app.cycle));

            const scholarName = [
              scholar.first_name || user.first_name,
              scholar.middle_name,
              scholar.last_name || user.last_name,
              scholar.suffix
            ].filter(Boolean).join(' ').trim() || app.applicant_name || user.email || 'Applicant Student';

            const email = user.email || scholar.email || app.email || 'N/A';
            const phone = scholar.phone || app.phone || 'N/A';
            const school = scholar.school || scholar.institution || 'Unspecified University';
            const course = scholar.course || scholar.degree || 'Undergraduate Degree';
            const yearLevel = formatYearLevel(scholar.year_level);
            const gpa = formatGwa(scholar.gpa || scholar.gwa, app.remarks);
            const citizenship = scholar.citizenship || 'Filipino';
            const addressParts = [scholar.barangay, scholar.municipality, scholar.province, scholar.region].filter(Boolean);
            const address = addressParts.length > 0 ? addressParts.join(', ') : 'N/A';

            const dbStatus = (app.status || 'pending').toLowerCase();
            let status: ApplicantStatus = 'Pending';
            if (dbStatus === 'under_review') status = 'Under Review';
            else if (dbStatus === 'for_exam') status = 'For Exam';
            else if (dbStatus === 'approved') status = 'Approved';
            else if (dbStatus === 'rejected') status = 'Rejected';

            const createdDate = app.created_at ? new Date(app.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'Recently';

            let docs: SubmittedDocItem[] = [];
            if (app.submitted_documents) {
              let rawDocs: any[] = [];
              if (Array.isArray(app.submitted_documents)) {
                rawDocs = app.submitted_documents;
              } else if (app.submitted_documents.documents && Array.isArray(app.submitted_documents.documents)) {
                rawDocs = app.submitted_documents.documents;
              }
              docs = rawDocs.map((d: any) => ({
                id: d.id,
                name: d.name || d.document_name || d.filename || 'Submitted Document',
                filename: d.filename || d.name || d.document_name,
                filesize: d.filesize,
                document_url: d.document_url || d.url,
                url: d.document_url || d.url,
                submitted_at: d.submitted_at || (app.created_at ? new Date(app.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'Recently'),
                status: d.status || (d.verification_status === 'verified' ? 'Verified' : d.verification_status === 'rejected' ? 'Flagged' : 'Pending'),
                remarks: d.remarks || '',
                aiVerification: d.aiVerification,
              }));
            }

            if (scholarDocsMap[scholar.id]) {
              scholarDocsMap[scholar.id].forEach(sd => {
                const sdName = (sd.name || '').toLowerCase().trim();
                const sdUrl = (sd.document_url || sd.url || '').toLowerCase().trim();

                const existingIdx = docs.findIndex(d => {
                  const dUrl = (d.document_url || d.url || '').toLowerCase().trim();
                  if (dUrl && sdUrl && (dUrl === sdUrl || dUrl.includes(sdUrl) || sdUrl.includes(dUrl))) return true;
                  const dName = (d.name || '').toLowerCase().trim();
                  return sdName && dName && (sdName === dName || sdName.includes(dName) || dName.includes(sdName));
                });

                if (existingIdx !== -1) {
                  const currentDoc = docs[existingIdx];
                  const cachedAiVerif = currentDoc.aiVerification || sd.aiVerification;
                  const cachedStatus = (currentDoc.status === 'Verified' || currentDoc.status === 'Flagged')
                    ? currentDoc.status
                    : (cachedAiVerif?.verificationStatus === 'verified' ? 'Verified' : (sd.status || currentDoc.status || 'Pending'));

                  docs[existingIdx] = {
                    ...currentDoc,
                    id: sd.id || currentDoc.id,
                    status: cachedStatus,
                    remarks: currentDoc.remarks || sd.remarks || '',
                    aiVerification: cachedAiVerif,
                    document_url: currentDoc.document_url || sd.document_url,
                    url: currentDoc.url || sd.url,
                  };
                }
              });
            }

            // Final strict deduplication of docs list
            const uniqueDocsList: SubmittedDocItem[] = [];
            const seenNamesSet = new Set<string>();
            const seenUrlsSet = new Set<string>();

            for (const docItem of docs) {
              const nKey = (docItem.name || '').toLowerCase().trim();
              const uKey = (docItem.document_url || docItem.url || docItem.filename || '').toLowerCase().trim();
              const isDupN = nKey && seenNamesSet.has(nKey);
              const isDupU = uKey && seenUrlsSet.has(uKey);

              if (!isDupN && !isDupU) {
                if (nKey) seenNamesSet.add(nKey);
                if (uKey) seenUrlsSet.add(uKey);
                uniqueDocsList.push(docItem);
              }
            }
            docs = uniqueDocsList;

            return {
              id: app.id,
              scholarId: scholar.id,
              name: scholarName,
              email: email,
              phone: phone,
              program: prog.title || 'Scholarship Program',
              program_id: prog.id,
              disbursement_mode: prog.disbursement_mode || 'online',
              banking_policy: prog.banking_policy || 'any_bank',
              paymentAccount: scholarPaymentMap[scholar.id] || null,
              cycle: cycle.cycle_name || 'Active Cycle',
              cycle_type: cycle.cycle_type,
              semester: cycle.semester,
              school: school,
              course: course,
              yearLevel: yearLevel,
              grade: gpa,
              citizenship: citizenship,
              address: address,
              status: status,
              date: createdDate,
              submittedDocuments: docs,
              remarks: app.remarks || '',
              rawApplication: app
            };
          });

          setApplicantsList(mappedApplicants);

          const approvedApps = data.filter((app: any) => (app.status || '').toLowerCase() === 'approved');
          const mappedScholars: ScholarAward[] = approvedApps.map((app: any) => {
            const scholar = app.scholar || {};
            const user = scholar.user || {};
            const cycle = app.cycle || {};
            const prog = cycle.program || {};

            const scholarName = [
              scholar.first_name || user.first_name,
              scholar.middle_name,
              scholar.last_name || user.last_name,
              scholar.suffix
            ].filter(Boolean).join(' ').trim() || 'Awarded Scholar';

            const awardedDate = app.updated_at ? new Date(app.updated_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'Recently';

            const email = user.email || scholar.email || 'N/A';
            const phone = scholar.phone || 'N/A';
            const school = scholar.school || scholar.institution || 'Unspecified University';
            const course = scholar.course || scholar.degree || 'Undergraduate Degree';
            const yearLevel = formatYearLevel(scholar.year_level);
            const gpa = formatGwa(scholar.gpa || scholar.gwa, app.remarks);
            const citizenship = scholar.citizenship || 'Filipino';
            const addressParts = [scholar.barangay, scholar.municipality, scholar.province, scholar.region].filter(Boolean);
            const address = addressParts.length > 0 ? addressParts.join(', ') : 'N/A';

            let docs: SubmittedDocItem[] = [];
            if (app.submitted_documents) {
              let rawDocs: any[] = [];
              if (Array.isArray(app.submitted_documents)) {
                rawDocs = app.submitted_documents;
              } else if (app.submitted_documents.documents && Array.isArray(app.submitted_documents.documents)) {
                rawDocs = app.submitted_documents.documents;
              }
              docs = rawDocs.map((d: any) => ({
                id: d.id,
                name: d.name || d.document_name || d.filename || 'Submitted Document',
                filename: d.filename || d.name || d.document_name,
                filesize: d.filesize,
                document_url: d.document_url || d.url,
                url: d.document_url || d.url,
                submitted_at: d.submitted_at || 'Recently',
                status: d.status || 'Pending',
                remarks: d.remarks || '',
                aiVerification: d.aiVerification,
              }));
            }

            if (scholarDocsMap[scholar.id]) {
              scholarDocsMap[scholar.id].forEach(sd => {
                const sdName = (sd.name || '').toLowerCase().trim();
                const sdUrl = (sd.document_url || sd.url || '').toLowerCase().trim();

                const existingIdx = docs.findIndex(d => {
                  const dUrl = (d.document_url || d.url || '').toLowerCase().trim();
                  if (dUrl && sdUrl && (dUrl === sdUrl || dUrl.includes(sdUrl) || sdUrl.includes(dUrl))) return true;
                  const dName = (d.name || '').toLowerCase().trim();
                  return sdName && dName && (sdName === dName || sdName.includes(dName) || dName.includes(sdName));
                });

                if (existingIdx !== -1) {
                  const currentDoc = docs[existingIdx];
                  const cachedAiVerif = currentDoc.aiVerification || sd.aiVerification;
                  const cachedStatus = (currentDoc.status === 'Verified' || currentDoc.status === 'Flagged')
                    ? currentDoc.status
                    : (cachedAiVerif?.verificationStatus === 'verified' ? 'Verified' : (sd.status || currentDoc.status || 'Pending'));

                  docs[existingIdx] = {
                    ...currentDoc,
                    id: sd.id || currentDoc.id,
                    status: cachedStatus,
                    remarks: currentDoc.remarks || sd.remarks || '',
                    aiVerification: cachedAiVerif,
                    document_url: currentDoc.document_url || sd.document_url,
                    url: currentDoc.url || sd.url,
                  };
                }
              });
            }

            // Final strict deduplication of docs list
            const uniqueDocsList: SubmittedDocItem[] = [];
            const seenNamesSet = new Set<string>();
            const seenUrlsSet = new Set<string>();

            for (const docItem of docs) {
              const nKey = (docItem.name || '').toLowerCase().trim();
              const uKey = (docItem.document_url || docItem.url || docItem.filename || '').toLowerCase().trim();
              const isDupN = nKey && seenNamesSet.has(nKey);
              const isDupU = uKey && seenUrlsSet.has(uKey);

              if (!isDupN && !isDupU) {
                if (nKey) seenNamesSet.add(nKey);
                if (uKey) seenUrlsSet.add(uKey);
                uniqueDocsList.push(docItem);
              }
            }
            docs = uniqueDocsList;

            const appDetail: ApplicationDetail = {
              id: app.id,
              scholarId: scholar.id,
              name: scholarName,
              email: email,
              phone: phone,
              program: prog.title || 'Scholarship Program',
              program_id: prog.id,
              disbursement_mode: prog.disbursement_mode || 'online',
              banking_policy: prog.banking_policy || 'any_bank',
              paymentAccount: scholarPaymentMap[scholar.id] || null,
              cycle: cycle.cycle_name || 'Active Cycle',
              school: school,
              course: course,
              yearLevel: yearLevel,
              grade: gpa,
              citizenship: citizenship,
              address: address,
              status: 'Approved',
              date: awardedDate,
              submittedDocuments: docs,
              remarks: app.remarks || '',
              rawApplication: app
            };

            const payouts = scholarPayoutsMap[scholar.id] || [];
            const releaseHistory = payouts.map(p => ({
              id: p.id,
              applicationId: p.application_id,
              cycleId: p.cycle_id,
              cycleName: p.cycle?.cycle_name || 'Intake Cycle',
              semester: p.cycle?.semester || '1st Semester',
              amount: Number(p.amount) || 0,
              status: p.status || (p.blockchain_verified ? 'released' : 'pending'),
              date: p.created_at ? new Date(p.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'Recently',
              isRenewal: p.cycle?.cycle_type === 'renewal' ||
                (p.cycle?.cycle_name || '').toLowerCase().includes('renewal') ||
                (p.cycle?.cycle_name || '').toLowerCase().includes('2nd sem') ||
                (p.cycle?.semester || '').toLowerCase().includes('2nd')
            }));

            return {
              id: app.id,
              scholarName: scholarName,
              programTitle: prog.title || 'Scholarship Program',
              cycleJoined: cycle.cycle_name || 'Active Cycle',
              status: 'Maintaining',
              gwa: gpa,
              dateAwarded: awardedDate,
              disbursement_mode: prog.disbursement_mode || 'online',
              banking_policy: prog.banking_policy || 'any_bank',
              paymentAccount: scholarPaymentMap[scholar.id] || null,
              payoutHistory: releaseHistory,
              appDetail: appDetail
            };
          });

          // Strictly deduplicate scholars by scholar ID (or name) + program title
          const scholarMap = new Map<string, ScholarAward>();
          for (const sch of mappedScholars) {
            const scholarKey = `${sch.appDetail.scholarId || sch.scholarName}_${sch.programTitle}`;
            if (!scholarMap.has(scholarKey)) {
              scholarMap.set(scholarKey, sch);
            } else {
              const existing = scholarMap.get(scholarKey)!;
              // If existing lacks payment account but this row has it, merge it
              if (!existing.paymentAccount && sch.paymentAccount) {
                existing.paymentAccount = sch.paymentAccount;
                existing.appDetail.paymentAccount = sch.paymentAccount;
              }
              // Merge payout history
              if (sch.payoutHistory && sch.payoutHistory.length > 0) {
                const existingIds = new Set((existing.payoutHistory || []).map((p: any) => p.id));
                const newPayouts = sch.payoutHistory.filter((p: any) => !existingIds.has(p.id));
                existing.payoutHistory = [...(existing.payoutHistory || []), ...newPayouts];
              }
              // If this row is more recent or is a renewal cycle, update cycleJoined and docs
              if (sch.cycleJoined && (sch.cycleJoined.toLowerCase().includes('renewal') || sch.cycleJoined.toLowerCase().includes('sem'))) {
                existing.cycleJoined = sch.cycleJoined;
                existing.appDetail.cycle = sch.cycleJoined;
              }
            }
          }

          setScholarsList(Array.from(scholarMap.values()));
        } else {
          setApplicantsList([]);
          setScholarsList([]);
        }
    } catch (err) {
      console.error('Error fetching applicants:', err);
      setApplicantsList([]);
      setScholarsList([]);
    }
  };

  useEffect(() => {
    fetchApplicantsAndScholars();

    const appChannel = supabase
      .channel('provider-applications-realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'scholarship_applications'
        },
        () => {
          fetchApplicantsAndScholars();
          showToast('Applications refreshed with latest student updates!');
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'scholar_documents'
        },
        () => {
          fetchApplicantsAndScholars();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(appChannel);
    };
  }, [providerDetails?.id]);



  // Handle applicant status and document decision updates
  const handleUpdateStatus = async (
    id: string | number,
    nextStatus: ApplicantStatus,
    remarks?: string,
    updatedDocs?: SubmittedDocItem[]
  ) => {
    let dbStatus = 'pending';
    if (nextStatus === 'Under Review') dbStatus = 'under_review';
    else if (nextStatus === 'For Exam') dbStatus = 'for_exam';
    else if (nextStatus === 'Approved') dbStatus = 'approved';
    else if (nextStatus === 'Rejected') dbStatus = 'rejected';

    const applicant = applicantsList.find(a => a.id === id);
    const existingRefNum = applicant?.rawApplication?.submitted_documents?.reference_number || `ISK-${new Date().getFullYear()}-${id.toString().substring(0, 5).toUpperCase()}`;

    try {
      const { data: userData } = await supabase.auth.getUser();
      const currentUserId = userData?.user?.id;

      const updatePayload: any = {
        status: dbStatus,
        updated_at: new Date().toISOString(),
        reviewed_at: new Date().toISOString(),
      };
      if (currentUserId) {
        updatePayload.reviewed_by = currentUserId;
      }
      if (remarks !== undefined) {
        updatePayload.remarks = remarks;
      }
      if (updatedDocs !== undefined) {
        updatePayload.submitted_documents = {
          reference_number: existingRefNum,
          documents: updatedDocs
        };
      }

      await supabase
        .from('scholarship_applications')
        .update(updatePayload)
        .eq('id', id);

      // Synchronize document verification statuses to scholar_documents table
      let scholarId = applicant?.scholarId || applicant?.rawApplication?.scholar_id;

      if (!scholarId && typeof id === 'string' && id.includes('-') && id.length > 20) {
        try {
          const { data: appData } = await supabase
            .from('scholarship_applications')
            .select('scholar_id')
            .eq('id', id)
            .maybeSingle();
          if (appData?.scholar_id) {
            scholarId = appData.scholar_id;
          }
        } catch (fetchScholarErr) {
          console.warn('[Fetch scholar_id fallback note]:', fetchScholarErr);
        }
      }

      if (scholarId && updatedDocs && updatedDocs.length > 0) {
        for (const doc of updatedDocs) {
          try {
            const docName = doc.name || doc.filename || '';
            const docUrl = doc.document_url || doc.url || '';
            let docStatusDb = 'pending';
            if (doc.status === 'Verified') docStatusDb = 'verified';
            else if (doc.status === 'Flagged') docStatusDb = 'rejected';

            const docRemarks = doc.remarks || (docStatusDb === 'verified' ? 'Verified by provider' : docStatusDb === 'rejected' ? 'Flagged during provider review' : '');

            let recordIdToUpdate = doc.id;
            if (!recordIdToUpdate || typeof recordIdToUpdate === 'number' || (typeof recordIdToUpdate === 'string' && !recordIdToUpdate.includes('-'))) {
              const { data: existingRecords } = await supabase
                .from('scholar_documents')
                .select('id, document_name, document_url')
                .eq('scholar_id', scholarId);

              if (existingRecords && existingRecords.length > 0) {
                const match = existingRecords.find(r =>
                  (r.document_name && r.document_name.toLowerCase().trim() === docName.toLowerCase().trim()) ||
                  (r.document_url && docUrl && r.document_url.trim() === docUrl.trim())
                );
                if (match) recordIdToUpdate = match.id;
              }
            }

            const aiPayload: any = {};
            if (doc.aiVerification) {
              aiPayload.ai_verification_status = doc.aiVerification.verificationStatus;
              aiPayload.ai_confidence_score = doc.aiVerification.confidenceScore;
              aiPayload.ai_flags = doc.aiVerification.flags;
              aiPayload.ai_extracted_data = {
                extractedName: doc.aiVerification.extractedName,
                extractedSchool: doc.aiVerification.extractedSchool,
                extractedGwa: doc.aiVerification.extractedGwa,
                extractedIncome: doc.aiVerification.extractedIncome,
                extractedDocType: doc.aiVerification.extractedDocType,
                crossCheckResults: doc.aiVerification.crossCheckResults,
              };
              aiPayload.ai_model_used = doc.aiVerification.aiModelUsed;
              aiPayload.file_sha256_hash = doc.aiVerification.sha256Hash;
            }

            if (recordIdToUpdate) {
              const { error: updErr } = await supabase
                .from('scholar_documents')
                .update({
                  verification_status: docStatusDb,
                  remarks: docRemarks,
                  document_url: docUrl || undefined,
                  updated_at: new Date().toISOString(),
                  ...aiPayload,
                })
                .eq('id', recordIdToUpdate);

              if (updErr) {
                if (updErr.message?.includes('column') || updErr.code === '42703') {
                  await supabase
                    .from('scholar_documents')
                    .update({
                      verification_status: docStatusDb,
                      remarks: docRemarks,
                      document_url: docUrl || undefined,
                      updated_at: new Date().toISOString(),
                    })
                    .eq('id', recordIdToUpdate);
                } else {
                  console.error(`[Error updating scholar_documents record ${recordIdToUpdate}]:`, updErr);
                }
              } else {
                console.log(`[Success updating scholar_documents record ${recordIdToUpdate}]: status -> ${docStatusDb}`);
              }
            } else if (docUrl || docName) {
              const { error: insErr } = await supabase
                .from('scholar_documents')
                .insert({
                  scholar_id: scholarId,
                  document_name: docName,
                  document_url: docUrl || '',
                  verification_status: docStatusDb,
                  remarks: docRemarks,
                  created_at: new Date().toISOString(),
                  updated_at: new Date().toISOString(),
                  ...aiPayload,
                });

              if (insErr) {
                if (insErr.message?.includes('column') || insErr.code === '42703') {
                  await supabase
                    .from('scholar_documents')
                    .insert({
                      scholar_id: scholarId,
                      document_name: docName,
                      document_url: docUrl || '',
                      verification_status: docStatusDb,
                      remarks: docRemarks,
                      created_at: new Date().toISOString(),
                      updated_at: new Date().toISOString(),
                    });
                } else {
                  console.error('[Error inserting scholar_documents record]:', insErr);
                }
              } else {
                console.log(`[Success inserting scholar_documents record]: ${docName} -> ${docStatusDb}`);
              }
            }
          } catch (docSyncErr) {
            console.error('[Doc Sync Exception]:', docSyncErr);
          }
        }
      }

      await fetchApplicantsAndScholars();

      // Trigger decision notification (EmailJS + Database In-App + FCM Push Notification)
      if (applicant) {
        sendDecisionNotification({
          toEmail: applicant.email,
          toName: applicant.name,
          programTitle: applicant.program,
          providerName: providerDetails?.name || 'Scholarship Provider',
          status: nextStatus,
          remarks: remarks || '',
          scholarId: applicant.scholarId,
        }).catch((notifErr) => console.warn('[Decision Notification Error]:', notifErr));
      }

    } catch (e) {
      console.error('Error updating application status in Supabase:', e);
    }

    if (nextStatus === 'Approved' && applicant) {
      const newScholar: ScholarAward = {
        id: applicant.id,
        scholarName: applicant.name,
        programTitle: applicant.program,
        cycleJoined: applicant.cycle,
        status: 'Maintaining',
        gwa: applicant.grade,
        dateAwarded: 'Today',
        appDetail: { ...applicant, status: 'Approved', remarks: remarks || applicant.remarks, submittedDocuments: updatedDocs || applicant.submittedDocuments }
      };
      setScholarsList(prev => [newScholar, ...prev]);
      setApplicantsList(prev =>
        prev.map(a => (a.id === id ? { ...a, status: 'Approved', remarks: remarks || a.remarks, submittedDocuments: updatedDocs || a.submittedDocuments } : a))
      );
      showToast(`Approved application for ${applicant.name}! Scholar record created.`);
    } else {
      setApplicantsList(prev =>
        prev.map(a => (a.id === id ? { ...a, status: nextStatus, remarks: remarks || a.remarks, submittedDocuments: updatedDocs || a.submittedDocuments } : a))
      );
      showToast(`Application updated to ${nextStatus}.`);
    }
  };

  // Interactive Disbursements State (loaded from Supabase)
  const [disbursementsList, setDisbursementsList] = useState<DisbursementTx[]>([]);
  const [_loadingDisbursements, setLoadingDisbursements] = useState(false);

  const fetchDisbursements = async () => {
    if (!providerDetails?.id) return;
    setLoadingDisbursements(true);
    try {
      const { data, error } = await supabase
        .from('fund_releases')
        .select(`
          *,
          scholar:scholar (
            first_name,
            last_name
          ),
          program:scholarship_programs!inner (
            title,
            provider_id
          )
        `)
        .eq('program.provider_id', providerDetails.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      if (data) {
        const mapped: DisbursementTx[] = data.map((d: any) => ({
          id: d.id,
          scholar: d.scholar ? `${d.scholar.first_name} ${d.scholar.last_name}` : 'Unknown Scholar',
          program: d.program?.title || 'Unknown Program',
          method: d.fund_type ? `${d.fund_type.charAt(0).toUpperCase() + d.fund_type.slice(1)} Release` : 'Bank Transfer',
          amount: `₱${Number(d.amount).toLocaleString()}`,
          numericAmount: Number(d.amount) || 0,
          status: d.status === 'released' ? 'Completed' : (d.status === 'pending' || d.status === 'processing' ? 'Pending' : d.status),
          date: d.created_at ? new Date(d.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'N/A',
        }));
        setDisbursementsList(mapped);
      }
    } catch (err) {
      console.error('Error fetching disbursements:', err);
    } finally {
      setLoadingDisbursements(false);
    }
  };

  const totalCredited = disbursementsList
    .filter(tx => tx.status === 'COMPLETED' || tx.status === 'Completed' || tx.status === 'released')
    .reduce((sum, tx) => sum + tx.numericAmount, 0);

  const totalPending = disbursementsList
    .filter(tx => tx.status === 'PENDING' || tx.status === 'Pending' || tx.status === 'PROCESSING' || tx.status === 'Processing' || tx.status === 'pending' || tx.status === 'processing')
    .reduce((sum, tx) => sum + tx.numericAmount, 0);

  // Fetch disbursements when provider details are loaded
  useEffect(() => {
    fetchDisbursements();
  }, [providerDetails?.id]);

  // Subscribe to realtime disbursement updates
  useEffect(() => {
    if (!providerDetails?.id) return;

    const channel = supabase
      .channel('provider-disbursements-realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'fund_releases'
        },
        () => {
          fetchDisbursements();
          showToast('Disbursements updated in real-time!');
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [providerDetails?.id]);

  // Handle program payout release first
  const handleReleaseProgramFunds = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!providerDetails?.id) return;

    try {
      // Get the program ID for the selected program
      const program = programsList.find(p => p.title === selectedPayoutProgram);
      if (!program) {
        showToast(`Program "${selectedPayoutProgram}" not found.`);
        return;
      }

      // Update fund releases for this program that are pending/processing
      const { error } = await supabase
        .from('fund_releases')
        .update({ status: 'released', updated_at: new Date().toISOString() })
        .eq('program_id', program.id)
        .in('status', ['pending', 'processing', 'PENDING', 'Pending']);

      if (error) throw error;

      setIsPayoutModalOpen(false);
      showToast(`Released funds! Completed pending transactions for "${selectedPayoutProgram}".`);
      // Real-time subscription will refresh the list
    } catch (err: any) {
      console.error('Error releasing funds:', err);
      showToast(`Error: ${err.message || 'Failed to release funds'}`);
    }
  };

  // ── Program Action State ──────────────────────────────────────────────
  const [selectedProgram, setSelectedProgram] = useState<Program | null>(null);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [isCloseConfirmOpen, setIsCloseConfirmOpen] = useState(false);
  const [programToClose, setProgramToClose] = useState<Program | null>(null);

  const handleViewDetails = (prog: Program) => {
    setSelectedProgram(prog);
    setIsViewModalOpen(true);
  };

  const handleOpenCreateProgram = () => {
    setSelectedProgram(null);
    setActiveTab('create-program');
  };

  const handleEditProgram = (prog: Program) => {
    setSelectedProgram(prog);
    setActiveTab('create-program');
  };

  const handleCloseProgram = async () => {
    if (!programToClose) return;
    try {
      const { error } = await supabase
        .from('scholarship_programs')
        .update({ status: 'closed' })
        .eq('id', programToClose.id);

      if (error) {
        console.error('Error closing program:', error);
        showToast('Error closing program.');
      } else {
        showToast(`"${programToClose.title}" has been closed.`);
        await fetchPrograms();
      }
    } catch (err) {
      console.error('Unexpected error closing program:', err);
      showToast('An unexpected error occurred.');
    } finally {
      setIsCloseConfirmOpen(false);
      setProgramToClose(null);
    }
  };

  const handleOpenRenewModal = (prog: Program) => {
    setSelectedProgramForRenewal(prog);
    setCycleToEdit(null);
    
    // Auto-calculate next academic year
    let nextStartYear = new Date().getFullYear();
    if (prog.cycles && prog.cycles.length > 0) {
      for (const c of prog.cycles) {
        const match = (c.name || '').match(/20\d{2}/g);
        if (match && match.length > 0) {
          const parsedYears = match.map((y: string) => parseInt(y, 10));
          const maxYear = Math.max(...parsedYears);
          if (maxYear >= nextStartYear) {
            nextStartYear = maxYear;
          }
        }
      }
    }
      
    const currentYear = new Date().getFullYear();
    setRenewCycleType('renewal');
    setRenewSemester('2nd Semester');
    setRenewCycleName(`AY ${currentYear}-${currentYear + 1} • 2nd Sem Renewal`);
    setRenewStartDate(new Date().toISOString().split('T')[0]);
    setRenewEndDate(new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString().split('T')[0]);
    setRenewSlots(prog.totalSlots || '');
    setRenewRequirements([
      {
        name: '1st Semester Official Grade Slip / Report of Grades',
        description: 'Signed copy or student portal screenshot of your 1st semester grades/GWA',
      },
      {
        name: 'Certificate of Registration (COR) / Enrollment Form (2nd Semester)',
        description: 'Official proof of enrollment for the upcoming semester with enrolled units',
      },
    ]);
    setIsRenewModalOpen(true);
  };

  const handleOpenEditCycle = (prog: Program, cyc: any) => {
    setSelectedProgramForRenewal(prog);
    setCycleToEdit(cyc);
    setRenewCycleName(cyc.name || '');
    setRenewStartDate(cyc.startDate || new Date().toISOString().split('T')[0]);
    setRenewEndDate(cyc.endDate || new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString().split('T')[0]);
    setRenewSlots(cyc.slotsAvailable ? String(cyc.slotsAvailable) : '');
    
    const isRenewal = cyc.cycleType === 'renewal' || (cyc.name && cyc.name.toLowerCase().includes('renewal'));
    setRenewCycleType(isRenewal ? 'renewal' : 'new_applicant');
    setRenewSemester(cyc.semester || '2nd Semester');

    const rawReqs = (cyc.renewalRequirements && Array.isArray(cyc.renewalRequirements) && cyc.renewalRequirements.length > 0)
      ? cyc.renewalRequirements
      : (prog.applicationRequirements && Array.isArray(prog.applicationRequirements) && prog.applicationRequirements.length > 0)
      ? prog.applicationRequirements
      : null;

    if (rawReqs && rawReqs.length > 0) {
      setRenewRequirements(
        rawReqs.map((r: any) =>
          typeof r === 'string'
            ? { name: r, description: '' }
            : { name: r.name || 'Document', description: r.description || '' }
        )
      );
    } else {
      setRenewRequirements([
        {
          name: 'Official Grade Slip / Report of Grades',
          description: 'Signed copy or portal screenshot of your latest term grades/GWA',
        },
        {
          name: 'Certificate of Registration (COR) / Enrollment Form',
          description: 'Official proof of enrollment for the upcoming semester with enrolled units',
        },
      ]);
    }
    setIsRenewModalOpen(true);
  };

  const handleRenewProgramCycle = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedProgramForRenewal || !renewCycleName || !renewStartDate || !renewEndDate) {
      showToast('Please fill in all required fields.');
      return;
    }

    if (renewCycleType === 'renewal' && renewRequirements.length === 0) {
      showToast('Please select or add at least one required renewal document.');
      return;
    }

    try {
      const cycleStatus = parseLocalMidnight(renewStartDate) > getTodayMidnight() ? 'upcoming' : 'open';
      
      if (cycleToEdit && cycleToEdit.id) {
        // ─── Edit Existing Cycle ───
        const updatePayload: any = {
          cycle_name: renewCycleName,
          cycle_type: renewCycleType,
          semester: renewSemester,
          application_start_date: renewStartDate,
          application_end_date: renewEndDate,
          slots_available: renewCycleType === 'renewal' ? null : (renewSlots ? parseInt(renewSlots, 10) : null),
          status: cycleStatus,
        };

        if (renewCycleType === 'renewal') {
          updatePayload.renewal_requirements = renewRequirements;
        }

        const { error: updateErr } = await supabase
          .from('application_cycles')
          .update(updatePayload)
          .eq('id', cycleToEdit.id);

        if (updateErr) {
          console.warn('Update attempt error, retrying without renewal_requirements:', updateErr);
          delete updatePayload.renewal_requirements;
          const { error: fallbackUpdateErr } = await supabase
            .from('application_cycles')
            .update(updatePayload)
            .eq('id', cycleToEdit.id);

          if (fallbackUpdateErr) {
            console.error('Error updating cycle:', fallbackUpdateErr);
            showToast('Error updating application cycle.');
            return;
          }
        }

        showToast(`Cycle "${renewCycleName}" updated successfully!`);
      } else {
        // ─── Insert New Cycle ───
        const insertPayload: any = {
          program_id: selectedProgramForRenewal.id,
          cycle_name: renewCycleName,
          cycle_type: renewCycleType,
          semester: renewSemester,
          application_start_date: renewStartDate,
          application_end_date: renewEndDate,
          slots_available: renewCycleType === 'renewal' ? null : (renewSlots ? parseInt(renewSlots, 10) : null),
          status: cycleStatus,
        };

        if (renewCycleType === 'renewal') {
          insertPayload.renewal_requirements = renewRequirements;
        }

        let newCycleId = '';
        const { data: cycleData, error: cycleErr } = await supabase
          .from('application_cycles')
          .insert(insertPayload)
          .select('id')
          .single();

        if (cycleErr) {
          console.warn('First insert attempt error, retrying standard payload:', cycleErr);
          delete insertPayload.renewal_requirements;
          const { data: fallbackData, error: fallbackErr } = await supabase
            .from('application_cycles')
            .insert(insertPayload)
            .select('id')
            .single();

          if (fallbackErr) {
            console.error('Error inserting renewal cycle:', fallbackErr);
            showToast('Error creating new application cycle.');
            return;
          }
          newCycleId = fallbackData?.id || '';
        } else {
          newCycleId = cycleData?.id || '';
        }

        // If Semestral Renewal, notify continuing scholars of this program with requirements
        if (renewCycleType === 'renewal') {
          try {
            // Fetch all approved applications for this program (using singular 'scholar')
            const { data: approvedApps } = await supabase
              .from('scholarship_applications')
              .select(`
                id,
                scholar_id,
                scholar:scholar(
                  id,
                  user_id,
                  first_name,
                  last_name
                ),
                cycle:application_cycles!inner(program_id)
              `)
              .eq('status', 'approved')
              .eq('cycle.program_id', selectedProgramForRenewal.id);

            let userIdsToSend: string[] = [];

            if (approvedApps && approvedApps.length > 0) {
              for (const app of approvedApps as any[]) {
                const uId = app.scholar?.user_id;
                if (uId && !userIdsToSend.includes(uId)) {
                  userIdsToSend.push(uId);
                }
              }
            }

            // Fallback: If join didn't return user_ids, fetch scholar table directly
            if (userIdsToSend.length === 0) {
              const { data: rawApps } = await supabase
                .from('scholarship_applications')
                .select('scholar_id, cycle:application_cycles!inner(program_id)')
                .eq('status', 'approved')
                .eq('cycle.program_id', selectedProgramForRenewal.id);

              if (rawApps && rawApps.length > 0) {
                const sIds = Array.from(new Set(rawApps.map((a: any) => a.scholar_id).filter(Boolean)));
                if (sIds.length > 0) {
                  const { data: scholarRows } = await supabase
                    .from('scholar')
                    .select('user_id')
                    .in('id', sIds);
                  if (scholarRows) {
                    userIdsToSend = scholarRows.map((s: any) => s.user_id).filter(Boolean);
                  }
                }
              }
            }

            if (userIdsToSend.length > 0) {
              const notifInserts = userIdsToSend.map((uId: string) => ({
                user_id: uId,
                title: `📢 ${renewSemester} Renewal Open — ${selectedProgramForRenewal.title}`,
                message: `Notice for Continuing Scholars: The renewal for ${selectedProgramForRenewal.title} (${renewSemester}) is now open until ${renewEndDate}.\n\nRequired Documents to Submit:\n${renewRequirements.map((r, i) => `${i + 1}. ${r.name}${r.description ? ` — ${r.description}` : ''}`).join('\n')}\n\nPlease upload them in your IskoAko app to maintain your grant.`,
                type: 'info',
                is_read: false,
                metadata: {
                  program_id: selectedProgramForRenewal.id,
                  cycle_id: newCycleId,
                  cycle_name: renewCycleName,
                  semester: renewSemester,
                  deadline: renewEndDate,
                  renewal_requirements: renewRequirements,
                  action: 'renewal_submission',
                },
              }));

              const { error: notifInsertErr } = await supabase.from('notifications').insert(notifInserts);
              if (notifInsertErr) {
                console.error('Error inserting renewal notifications:', notifInsertErr);
              } else {
                console.log(`[Renewal Broadcast]: Successfully sent in-app notifications to ${userIdsToSend.length} approved scholars!`);
              }
            }
          } catch (notifErr) {
            console.warn('[Renewal Scholar Notification Exception]:', notifErr);
          }
        }

        // Update program status and application_requirements
        if (renewCycleType === 'renewal') {
          const formattedReqs = renewRequirements.map((r) => ({
            name: r.name,
            description: r.description || '',
            required: true,
          }));
          await supabase
            .from('scholarship_programs')
            .update({
              application_requirements: formattedReqs,
              status: 'active',
            })
            .eq('id', selectedProgramForRenewal.id);
        } else {
          await supabase
            .from('scholarship_programs')
            .update({ status: 'active' })
            .eq('id', selectedProgramForRenewal.id);
        }

        showToast(`Successfully opened "${renewCycleName}" with ${renewRequirements.length} required documents!`);
      }

      // If editing renewal cycle, also sync requirements to program
      if (cycleToEdit && renewCycleType === 'renewal') {
        const formattedReqs = renewRequirements.map((r) => ({
          name: r.name,
          description: r.description || '',
          required: true,
        }));
        await supabase
          .from('scholarship_programs')
          .update({
            application_requirements: formattedReqs,
          })
          .eq('id', selectedProgramForRenewal.id);
      }

      // Reload programs
      await fetchPrograms();
      
      // Close modal & reset state
      setIsRenewModalOpen(false);
      setSelectedProgramForRenewal(null);
      setCycleToEdit(null);
      setRenewCycleName('');
      setRenewStartDate('');
      setRenewEndDate('');
      setRenewSlots('');
      setRenewCycleType('renewal');
      setRenewSemester('2nd Semester');
      setRenewRequirements([
        {
          name: '1st Semester Official Grade Slip / Report of Grades',
          description: 'Signed copy or student portal screenshot of your 1st semester grades/GWA',
        },
        {
          name: 'Certificate of Registration (COR) / Enrollment Form (2nd Semester)',
          description: 'Official proof of enrollment for the upcoming semester with enrolled units',
        },
      ]);
    } catch (err) {
      console.error('Unexpected error during renewal:', err);
      showToast('An unexpected error occurred.');
    }
  };

  const handleDeleteCycle = (cycleId: string, cycleName: string) => {
    setCycleToDelete({ id: cycleId, name: cycleName });
    setIsDeleteCycleConfirmOpen(true);
  };

  const handleConfirmDeleteCycle = async () => {
    if (!cycleToDelete) return;
    const { id: cycleId, name: cycleName } = cycleToDelete;

    try {
      const { error } = await supabase
        .from('application_cycles')
        .delete()
        .eq('id', cycleId);

      if (error) {
        console.error('Error deleting cycle:', error);
        if (error.code === '23503') {
          showToast('Cannot delete cycle because it already has applications or related records.');
        } else {
          showToast('Error deleting application cycle.');
        }
        return;
      }

      showToast(`Successfully deleted cycle "${cycleName}".`);
      
      if (selectedProgram) {
        const updatedCycles = selectedProgram.cycles.filter((c: any) => c.id !== cycleId);
        setSelectedProgram({
          ...selectedProgram,
          cycles: updatedCycles
        });
      }
      
      await fetchPrograms();
    } catch (err) {
      console.error('Unexpected error deleting cycle:', err);
      showToast('An unexpected error occurred.');
    } finally {
      setIsDeleteCycleConfirmOpen(false);
      setCycleToDelete(null);
    }
  };



  const filteredApplicants = applicantsList.filter(app => {
    const matchesSearch = app.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      app.school.toLowerCase().includes(searchQuery.toLowerCase()) ||
      app.program.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (app.cycle && app.cycle.toLowerCase().includes(searchQuery.toLowerCase()));

    const isRenewal = Boolean(app.cycle_type === 'renewal' || (app.cycle && app.cycle.toLowerCase().includes('renewal')));

    let matchesStatus = true;
    if (statusFilter === 'Renewals') {
      matchesStatus = isRenewal;
    } else if (statusFilter === 'New Applicants') {
      matchesStatus = !isRenewal;
    } else if (statusFilter !== 'All') {
      matchesStatus = app.status === statusFilter;
    }

    return matchesSearch && matchesStatus;
  });

  const filteredScholars = scholarsList.filter(sch => {
    const matchesSearch = sch.scholarName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      sch.programTitle.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesSearch;
  });

  const handleUploadDocument = async (fieldName: string, file: File) => {
    if (!providerDetails) return;
    setUploadingDoc(fieldName);
    try {
      const fileExt = file.name.split('.').pop();
      const filePath = `${providerDetails.id}/${fieldName.replace(/\s+/g, '_')}_${Date.now()}.${fileExt}`;
      
      const { error } = await supabase.storage
        .from('provider-documents')
        .upload(filePath, file, { upsert: true });

      let publicUrl = '';
      if (error) {
        console.warn('Storage upload error, using local mock URL:', error);
        publicUrl = `https://mock.storage.iskolarako.org/provider-documents/${filePath}`;
      } else {
        const { data: urlData } = supabase.storage
          .from('provider-documents')
          .getPublicUrl(filePath);
        publicUrl = urlData?.publicUrl || `https://mock.storage.iskolarako.org/provider-documents/${filePath}`;
      }

      // Update local state with the uploaded document URL
      const updatedReqs = {
        ...providerDetails.requirementsSubmitted,
        [fieldName]: publicUrl
      };

      setProviderDetails(prev => prev ? {
        ...prev,
        requirementsSubmitted: updatedReqs
      } : null);

      setHasModifiedDocs(true);
      showToast(`Successfully uploaded ${fieldName}!`);
    } catch (err: any) {
      console.error('Error uploading document:', err);
      showToast(`Upload failed: ${err.message}`);
    } finally {
      setUploadingDoc(null);
    }
  };

  const handleSubmitVerification = async () => {
    if (!providerDetails) return;

    // Check if all required fields are filled
    const missingFields = requiredDocs
      .filter(d => d.required)
      .filter(d => !providerDetails.requirementsSubmitted[d.name]);

    if (missingFields.length > 0) {
      showToast(`Missing required documents: ${missingFields.map(f => f.name).join(', ')}`);
      return;
    }

    setSubmittingVerification(true);
    try {
      const updatedReqs = { ...providerDetails.requirementsSubmitted };
      delete updatedReqs._remarks;

      const { error } = await supabase
        .from('provider')
        .update({
          requirements_submitted: updatedReqs,
          verification_status: 'under_review',
          updated_at: new Date().toISOString()
        })
        .eq('id', providerDetails.id);

      if (error) throw error;

      setProviderDetails(prev => prev ? {
        ...prev,
        requirementsSubmitted: updatedReqs,
        verificationStatus: 'under_review'
      } : null);

      showToast('Verification request submitted successfully!');
    } catch (err: any) {
      console.error('Error submitting verification:', err);
      showToast(`Submission failed: ${err.message}`);
    } finally {
      setSubmittingVerification(false);
    }
  };

  const handleUnsubmitVerification = async () => {
    if (!providerDetails) return;

    if (providerDetails.verificationStatus !== 'under_review' && providerDetails.verificationStatus !== 'rejected') {
      return;
    }

    setSubmittingVerification(true);
    try {
      const { error } = await supabase
        .from('provider')
        .update({
          verification_status: 'pending',
          updated_at: new Date().toISOString()
        })
        .eq('id', providerDetails.id);

      if (error) throw error;

      setProviderDetails(prev => prev ? {
        ...prev,
        verificationStatus: 'pending'
      } : null);

      showToast('Successfully unsubmitted verification request. You can now modify your documents.');
    } catch (err: any) {
      console.error('Error unsubmitting verification:', err);
      showToast(`Failed to unsubmit: ${err.message}`);
    } finally {
      setSubmittingVerification(false);
    }
  };

  const renderSidebarItem = (tab: TabType, label: string, icon: React.ReactNode) => {
    const isActive = activeTab === tab;
    const showWarningDot = tab === 'verification' && providerDetails && providerDetails.verificationStatus !== 'verified';

    return (
      <button
        onClick={() => setActiveTab(tab)}
        title={label}
        className={`w-full flex items-center rounded-xl text-sm font-medium transition-all duration-200 cursor-pointer border-0 relative ${isCollapsed ? 'justify-center p-2.5' : 'gap-3.5 px-4 py-3'
          } ${isActive
            ? 'bg-white/10 text-white font-semibold shadow-sm'
            : 'text-[#9BA89F] hover:bg-white/5 hover:text-white bg-transparent'
          }`}
      >
        {icon}
        {!isCollapsed && <span>{label}</span>}
        {showWarningDot && (
          <span className={`absolute ${isCollapsed ? 'top-1.5 right-1.5' : 'top-3.5 right-4'} w-2 h-2 rounded-full bg-[#E8A838] border border-[#1A3C2E]`} />
        )}
      </button>
    );
  };

  if (isLoadingProvider) {
    return (
      <div className="min-h-screen bg-[#F9F5EF] flex items-center justify-center font-sans">
        <div className="flex flex-col items-center gap-3">
          <svg className="animate-spin h-10 w-10 text-[#2D5941]" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
          <span className="text-sm font-semibold text-[#1A3C2E]">Loading provider portal...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="h-screen bg-[#F9F5EF] flex font-sans overflow-hidden relative">

      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-[#1A3C2E] text-[#F9F5EF] border border-[#2D5941] px-5 py-3 rounded-xl shadow-2xl flex items-center gap-2 animate-bounce">
          <svg className="w-5 h-5 text-[#E8A838]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="text-xs font-semibold">{toastMessage}</span>
        </div>
      )}

      {/* Disbursements Payout Release Modal */}
      {isPayoutModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
          <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-8 max-w-md w-full space-y-6 relative animate-fade-in">
            <button onClick={() => setIsPayoutModalOpen(false)} className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer">✕</button>

            <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">Release Program Payouts</h3>
            <p className="text-xs text-[#6C6C70]">Select the target program whose pending fund releases should be processed first.</p>

            <form onSubmit={handleReleaseProgramFunds} className="space-y-5">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Select Scholarship Program</label>
                <select
                  value={selectedPayoutProgram}
                  onChange={(e) => setSelectedPayoutProgram(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm font-semibold cursor-pointer bg-white"
                >
                  <option value="DOST-SEI Undergraduate Scholarship">DOST-SEI Undergraduate Scholarship</option>
                  <option value="Tulong Dunong Financial Assistance">Tulong Dunong Financial Assistance</option>
                  <option value="DOST-SEI Merit Renewal 2026">DOST-SEI Merit Renewal 2026</option>
                  <option value="DOST-SEI Graduate Fellowship">DOST-SEI Graduate Fellowship</option>
                </select>
              </div>

              <div className="bg-[#F9F5EF] p-4 rounded-2xl border border-[#D9D2C5]/50 space-y-2 text-xs">
                <div className="flex justify-between font-medium">
                  <span className="text-[#6C6C70]">Pending Transactions:</span>
                  <span className="font-bold text-[#1C1C1E]">
                    {disbursementsList.filter(tx => tx.program === selectedPayoutProgram && tx.status === 'Processing').length} items
                  </span>
                </div>
                <div className="flex justify-between font-medium">
                  <span className="text-[#6C6C70]">Total Batch Cost:</span>
                  <span className="font-bold text-[#2D5941]">
                    ₱{disbursementsList
                      .filter(tx => tx.program === selectedPayoutProgram && tx.status === 'Processing')
                      .reduce((sum, tx) => sum + tx.numericAmount, 0)
                      .toLocaleString()}
                  </span>
                </div>
              </div>

              <button
                type="submit"
                className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white py-3.5 rounded-xl text-sm font-bold shadow-md cursor-pointer transition-all"
              >
                Confirm Payout & Release Funds
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Large Map Selector Modal (Compact Height) */}
      {isBigMapModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
          <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-5 max-w-2xl w-full space-y-3 relative animate-fade-in max-h-[90vh] overflow-y-auto">
            <button 
              type="button"
              onClick={() => setIsBigMapModalOpen(false)} 
              className="absolute top-4 right-4 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-base cursor-pointer bg-transparent border-0"
            >
              ✕
            </button>
            <div>
              <h3 className="text-lg font-bold font-serif text-[#1A3C2E]">Select Exam Center Venue</h3>
              <p className="text-[11px] text-[#6C6C70]">Search or click directly on the map to pin the examination venue.</p>
            </div>

            <div className="space-y-2.5">
              {isLoaded ? (
                <Autocomplete
                  onLoad={onAutocompleteLoad}
                  onPlaceChanged={onPlaceChanged}
                >
                  <input
                    type="text"
                    placeholder="Search venue e.g. UP Bahay ng Alumni..."
                    value={mapSearchText}
                    onChange={(e) => setMapSearchText(e.target.value)}
                    className="w-full px-3.5 py-2 rounded-xl border border-[#D9D2C5] text-xs font-semibold bg-white focus:outline-none focus:border-[#2D5941]"
                  />
                </Autocomplete>
              ) : (
                <div className="text-xs font-medium text-[#6C6C70]">Loading search script...</div>
              )}

              <div className="w-full h-60 rounded-xl border border-[#D9D2C5] overflow-hidden relative shadow-inner bg-slate-100">
                {isLoaded ? (
                  <GoogleMap
                    mapContainerStyle={{ width: '100%', height: '100%' }}
                    center={{ lat: examCoords.lat, lng: examCoords.lng }}
                    zoom={mapZoom}
                    onClick={handleMapClick}
                    options={{
                      disableDefaultUI: false,
                      zoomControl: true,
                    }}
                  >
                    <Marker position={{ lat: examCoords.lat, lng: examCoords.lng }} />
                  </GoogleMap>
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-xs font-semibold text-[#6C6C70]">
                    Loading Live Google Maps...
                  </div>
                )}
              </div>

              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center text-[11px] bg-[#F9F5EF] p-2.5 rounded-xl border border-[#D9D2C5]/50 gap-1.5">
                <span className="font-medium text-[#6C6C70]">
                  <strong>Coordinates:</strong> {examCoords.lat.toFixed(4)}° N, {examCoords.lng.toFixed(4)}° E
                </span>
                <span className="font-medium text-[#1A3C2E] max-w-sm truncate">
                  <strong>Venue:</strong> {examCoords.address || 'Click map to pin'}
                </span>
              </div>
            </div>

            <div className="flex justify-end gap-2.5 pt-1">
              <button 
                type="button" 
                onClick={() => setIsBigMapModalOpen(false)}
                className="px-4 py-2 rounded-xl border border-solid border-[#D9D2C5] hover:bg-slate-50 text-xs font-bold cursor-pointer text-[#6C6C70] bg-transparent"
              >
                Cancel
              </button>
              <button 
                type="button" 
                onClick={() => setIsBigMapModalOpen(false)}
                className="px-5 py-2 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold cursor-pointer border-0 shadow-sm"
              >
                Confirm Location
              </button>
            </div>
          </div>
        </div>
      )}

      <aside className={`transition-all duration-300 bg-[#1A3C2E] text-white flex flex-col justify-between shrink-0 shadow-xl border-r border-[#2D5941]/30 overflow-hidden ${isCollapsed ? 'w-20' : 'w-72'}`}>
        <div className="p-4 overflow-y-auto overflow-x-hidden flex-1">
          {/* Sidebar Header */}
          <div className={`flex items-center justify-between mb-8 ${isCollapsed ? 'flex-col gap-4' : ''}`}>
            <div className="flex items-center gap-3">
              <img src={LogoGoldSvg} alt="IskolarAko Logo" className="w-12 h-12 object-contain shrink-0" />
              {!isCollapsed && (
                <div>
                  <h1 className="text-xl font-bold font-serif text-[#E8A838] tracking-wide leading-none">ISKOLARAKO</h1>
                  <p className="text-[10px] text-[#9BA89F] mt-1 font-semibold uppercase tracking-wider">DOST-SEI Portal</p>
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={() => setIsCollapsed(!isCollapsed)}
              className="text-[#9BA89F] hover:text-white transition-colors cursor-pointer border-0 bg-transparent p-1"
              title={isCollapsed ? "Expand Sidebar" : "Collapse Sidebar"}
            >
              <svg className="w-5 h-5 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={isCollapsed ? "M9 5l7 7-7 7" : "M15 19l-7-7 7-7"} />
              </svg>
            </button>
          </div>

          {/* Grouped Navigation Links */}
          <nav className="space-y-4">
            {/* Group 1: Management */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('management')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Management</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.management ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.management) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarItem('dashboard', 'Dashboard', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>)}
                  {renderSidebarItem('applicants', 'Applicants & Scholars', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" /></svg>)}
                  {renderSidebarItem('programs', 'Programs', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" /></svg>)}
                  {renderSidebarItem('verification', 'Verification Org', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>)}
                  {renderSidebarItem('profile', 'Profile Settings', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>)}
                </div>
              )}
            </div>

            {/* Group 2: Operations */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('operations')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Operations</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.operations ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.operations) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarItem('disbursements', 'Disbursements', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 8h6m-5 0a3 3 0 110 6H9l3 3m-3-6h6m6 1a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>)}
                  {renderSidebarItem('announcements', 'Announcements', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" /></svg>)}
                  {renderSidebarItem('reports', 'Reports', <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>)}
                </div>
              )}
            </div>
          </nav>
        </div>

        {/* Footer Profile / Logout */}
        <div className={`p-4 border-t border-[#2D5941]/30 ${isCollapsed ? 'flex flex-col items-center gap-4' : 'space-y-4'}`}>
          {!isCollapsed ? (
            <>
              <div className="flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 border border-white/10">
                <div className="w-10 h-10 rounded-xl bg-[#E8A838] flex items-center justify-center font-bold text-[#1A3C2E] shrink-0">
                  {profile ? `${profile.firstName.charAt(0)}${profile.lastName.charAt(0)}`.toUpperCase() : 'U'}
                </div>
                <div className="min-w-0 flex-1">
                  <h4 className="text-sm font-semibold truncate text-white">
                    {profile ? `${profile.firstName} ${profile.lastName}` : 'Loading...'}
                  </h4>
                  <p className="text-xs text-[#9BA89F] truncate">
                    {profile ? profile.providerName : 'Loading...'}
                  </p>
                  {providerDetails && (
                    <span className={`inline-block text-[9px] font-bold px-1.5 py-0.5 rounded mt-1 font-sans ${
                      providerDetails.verificationStatus === 'verified'
                        ? 'bg-[#EBF5EE]/25 text-[#E8A838]'
                        : providerDetails.verificationStatus === 'under_review'
                          ? 'bg-[#FFF8EE]/20 text-[#C97B2E]'
                          : providerDetails.verificationStatus === 'rejected'
                            ? 'bg-red-500/20 text-red-300'
                            : 'bg-white/10 text-white/60'
                    }`}>
                      ● {providerDetails.verificationStatus.replace('_', ' ').toUpperCase()}
                    </span>
                  )}
                </div>
              </div>
              <button
                onClick={onLogout}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl border border-solid border-white/20 text-[#9BA89F] hover:text-white hover:bg-white/5 transition-all text-xs font-semibold cursor-pointer bg-transparent"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
                Sign Out
              </button>
            </>
          ) : (
            <>
              <div 
                className="w-10 h-10 rounded-xl bg-[#E8A838] flex items-center justify-center font-bold text-[#1A3C2E] shrink-0" 
                title={profile ? `${profile.firstName} ${profile.lastName} - ${profile.providerName}` : 'User'}
              >
                {profile ? `${profile.firstName.charAt(0)}${profile.lastName.charAt(0)}`.toUpperCase() : 'U'}
              </div>
              <button
                onClick={onLogout}
                className="text-[#9BA89F] hover:text-white cursor-pointer border-0 bg-transparent text-sm flex items-center justify-center"
                title="Sign Out"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
              </button>
            </>
          )}
        </div>

      </aside>

      {/* Main Content Area with Top Header */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden bg-[#F9F5EF]">
        {/* Top Header Bar */}
        <header className="bg-white border-b border-[#D9D2C5]/60 px-8 py-3.5 flex items-center justify-between shrink-0 shadow-xs z-10">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-full bg-[#2D5941] animate-pulse" />
              <h2 className="text-sm font-bold text-[#1A3C2E] font-serif">
                {providerDetails?.name || 'Scholarship Provider Portal'}
              </h2>
            </div>
            {providerDetails && (
              <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wide ${
                providerDetails.verificationStatus === 'verified'
                  ? 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20'
                  : providerDetails.verificationStatus === 'under_review'
                  ? 'bg-[#FFF8EE] text-[#C97B2E] border border-amber-200'
                  : 'bg-slate-100 text-[#6C6C70]'
              }`}>
                {providerDetails.verificationStatus === 'verified' ? '✓ Verified Partner' : providerDetails.verificationStatus.replace('_', ' ')}
              </span>
            )}
          </div>

          <div className="flex items-center gap-3">
            {/* Notification Bell Button */}
            <button
              type="button"
              onClick={() => setIsNotificationDrawerOpen(true)}
              className="relative p-2.5 rounded-2xl bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5]/60 transition-all cursor-pointer flex items-center justify-center group"
              title="Notifications & Admin Broadcasts"
            >
              <svg className="w-5 h-5 transition-transform group-hover:scale-110 text-[#1A3C2E]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              {unreadNotifCount > 0 && (
                <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 bg-[#E8A838] text-[#1A3C2E] text-[10px] font-black rounded-full flex items-center justify-center shadow-sm ring-2 ring-white animate-bounce">
                  {unreadNotifCount > 9 ? '9+' : unreadNotifCount}
                </span>
              )}
            </button>

            {/* Quick Broadcast button */}
            <button
              type="button"
              onClick={() => setActiveTab('announcements')}
              className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer flex items-center gap-1.5 ${
                activeTab === 'announcements'
                  ? 'bg-[#2D5941] text-white shadow-sm'
                  : 'bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E]'
              }`}
            >
              <span>📢</span>
              <span>Announcements</span>
            </button>
          </div>
        </header>

        {/* Main Content */}
        <main className="flex-1 overflow-y-auto p-10 max-w-7xl w-full mx-auto">
        {activeTab === 'dashboard' && (
          <ProviderDashboardTab
            programsList={programsList}
            scholarsList={scholarsList}
            applicantsList={applicantsList}
            totalCredited={totalCredited}
            totalPending={totalPending}
            setActiveTab={setActiveTab}
            onOpenCreateProgram={handleOpenCreateProgram}
          />
        )}

        {activeTab === 'applicants' && (
          <ProviderApplicantsTab
            subTab={subTab}
            setSubTab={setSubTab}
            statusFilter={statusFilter}
            setStatusFilter={setStatusFilter}
            searchQuery={searchQuery}
            setSearchQuery={setSearchQuery}
            applicantsList={applicantsList}
            scholarsList={scholarsList}
            filteredApplicants={filteredApplicants}
            filteredScholars={filteredScholars}
            setSelectedAppForReview={setSelectedAppForReview}
            setIsReviewModalOpen={setIsReviewModalOpen}
            onOpenViewTab={(app) => {
              setSelectedAppForReview(app);
              setActiveTab('view-application');
            }}
            handleUpdateStatus={handleUpdateStatus}
          />
        )}

        {activeTab === 'view-application' && (
          <ProviderViewApplicationTab
            application={selectedAppForReview}
            onBack={() => setActiveTab('applicants')}
            onUpdateStatus={handleUpdateStatus}
            onUpdateDocs={(appId, updatedDocs) => {
              setApplicantsList(prev => prev.map(a => a.id === appId ? { ...a, submittedDocuments: updatedDocs } : a));
              setSelectedAppForReview(prev => prev && prev.id === appId ? { ...prev, submittedDocuments: updatedDocs } : prev);
            }}
          />
        )}

        {activeTab === 'create-program' && (
          <ProviderProgramFormTab
            programToEdit={selectedProgram}
            onCancel={() => {
              setSelectedProgram(null);
              setActiveTab('programs');
            }}
            onSubmit={async (formData, isEdit) => {
              const matchedCat = categories.find(c => c.name === formData.category);
              const categoryId = matchedCat ? matchedCat.id : null;

              const parseYearLevels = (raw: any): number[] => {
                if (!raw) return [1];
                const list = Array.isArray(raw) ? raw : String(raw).split(',');
                const numbers: number[] = [];
                for (const item of list) {
                  if (typeof item === 'number') {
                    if (!isNaN(item) && !numbers.includes(Math.round(item))) {
                      numbers.push(Math.round(item));
                    }
                  } else if (typeof item === 'string') {
                    const match = item.match(/\d+/);
                    if (match) {
                      const num = parseInt(match[0], 10);
                      if (!isNaN(num) && !numbers.includes(num)) {
                        numbers.push(num);
                      }
                    }
                  }
                }
                return numbers.length > 0 ? numbers : [1];
              };

              const parseStringArray = (raw: any): string[] => {
                if (!raw) return [];
                if (Array.isArray(raw)) return raw.map(String).map((s: string) => s.trim()).filter(Boolean);
                return String(raw).split(',').map((s: string) => s.trim()).filter(Boolean);
              };

              const mapFundingFreq = (freq: string): string => {
                if (!freq) return 'Per Semester';
                const lower = freq.toLowerCase();
                if (lower.includes('sem')) return 'Per Semester';
                if (lower.includes('year') || lower.includes('annual')) return 'Once a Year';
                if (lower.includes('one') || lower.includes('grant')) return 'One-time';
                return 'Per Semester';
              };

              const mapScholarshipType = (cat: string): string => {
                if (!cat) return 'merit';
                const lower = cat.toLowerCase();
                if (lower.includes('need') && lower.includes('merit')) return 'merit_and_need';
                if (lower.includes('need')) return 'need_based';
                if (lower.includes('fellowship') || lower.includes('graduate')) return 'fellowship';
                if (lower.includes('vocational') || lower.includes('grant') || lower.includes('tvet')) return 'grant';
                return 'merit';
              };

              if (isEdit) {
                // Update program
                const updatePayload: any = {
                  title: formData.title,
                  description: formData.description,
                  scholarship_type: mapScholarshipType(formData.category),
                  target_education_level: formData.target_education_level || 'college',
                  grading_system: formData.grading_system || 'scale_5',
                  minimum_gwa: formData.minimumGwa ? parseFloat(formData.minimumGwa) : null,
                  total_slots: formData.total_slots ? parseInt(formData.total_slots, 10) : null,
                  budget_total: formData.amount ? parseFloat(formData.amount) : null,
                  funding_frequency: mapFundingFreq(formData.funding_frequency),
                  covers_tuition: formData.coverstuition ?? false,
                  covers_stipend: formData.coversStipend ?? false,
                  stipend_amount: formData.stipendAmount ? parseFloat(formData.stipendAmount) : null,
                  covers_allowance: formData.coversAllowance ?? false,
                  allowance_amount: formData.allowanceAmount ? parseFloat(formData.allowanceAmount) : null,
                  other_benefits: parseStringArray(formData.otherBenefits),
                  course_eligibility: parseStringArray(formData.eligible_courses).length > 0 ? parseStringArray(formData.eligible_courses) : ['All Degree Programs'],
                  year_level_eligibility: parseYearLevels(formData.eligible_year_levels),
                  application_requirements: formData.applicationRequirements || [],
                };
                if (categoryId) {
                  updatePayload.category_id = categoryId;
                }
                const { error } = await supabase
                  .from('scholarship_programs')
                  .update(updatePayload)
                  .eq('id', selectedProgram?.id);
                if (error) {
                  console.error('Error updating program:', error);
                  showToast(`Error updating program: ${error.message || 'Check fields'}`);
                } else {
                  // Update or insert primary cycle dates
                  if (selectedProgram?.id && formData.application_start_date && formData.application_end_date) {
                    const todayMid = getTodayMidnight();
                    const endMid = parseLocalMidnight(formData.application_end_date);
                    const startMid = parseLocalMidnight(formData.application_start_date);
                    const cycleStatus = endMid < todayMid ? 'closed' : (startMid > todayMid ? 'upcoming' : 'open');

                    const existingCycle = selectedProgram.cycles && selectedProgram.cycles.length > 0 ? selectedProgram.cycles[0] : null;
                    if (existingCycle?.id) {
                      await supabase
                        .from('application_cycles')
                        .update({
                          cycle_name: formData.cycle_name || existingCycle.name || 'AY 2026-2027',
                          application_start_date: formData.application_start_date,
                          application_end_date: formData.application_end_date,
                          status: cycleStatus,
                        })
                        .eq('id', existingCycle.id);
                    } else {
                      await supabase
                        .from('application_cycles')
                        .insert({
                          program_id: selectedProgram.id,
                          cycle_name: formData.cycle_name || 'AY 2026-2027',
                          application_start_date: formData.application_start_date,
                          application_end_date: formData.application_end_date,
                          status: cycleStatus,
                        });
                    }
                  }

                  showToast('Program and intake schedule updated successfully!');
                  await fetchPrograms();
                  setSelectedProgram(null);
                  setActiveTab('programs');
                }
              } else {
                // Create program
                const insertPayload: any = {
                  provider_id: providerDetails?.id,
                  title: formData.title,
                  description: formData.description,
                  category_id: categoryId,
                  scholarship_type: mapScholarshipType(formData.category),
                  target_education_level: formData.target_education_level || 'college',
                  grading_system: formData.grading_system || 'scale_5',
                  minimum_gwa: formData.minimumGwa ? parseFloat(formData.minimumGwa) : null,
                  total_slots: formData.total_slots ? parseInt(formData.total_slots, 10) : null,
                  budget_total: formData.amount ? parseFloat(formData.amount) : null,
                  funding_frequency: mapFundingFreq(formData.funding_frequency),
                  covers_tuition: formData.coverstuition ?? false,
                  covers_stipend: formData.coversStipend ?? false,
                  stipend_amount: formData.stipendAmount ? parseFloat(formData.stipendAmount) : null,
                  covers_allowance: formData.coversAllowance ?? false,
                  allowance_amount: formData.allowanceAmount ? parseFloat(formData.allowanceAmount) : null,
                  other_benefits: parseStringArray(formData.otherBenefits),
                  course_eligibility: parseStringArray(formData.eligible_courses).length > 0 ? parseStringArray(formData.eligible_courses) : ['All Degree Programs'],
                  year_level_eligibility: parseYearLevels(formData.eligible_year_levels),
                  application_requirements: formData.applicationRequirements || [],
                  status: 'pending',
                };
                const { data: progData, error } = await supabase
                  .from('scholarship_programs')
                  .insert([insertPayload])
                  .select()
                  .single();
                if (error || !progData) {
                  console.error('Error creating program:', error);
                  showToast(`Error creating program: ${error?.message || 'Check fields'}`);
                } else {
                  // Create configured intake cycle
                  const startDate = formData.application_start_date || new Date().toISOString().split('T')[0];
                  const endDate = formData.application_end_date || new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString().split('T')[0];
                  const todayMid = getTodayMidnight();
                  const endMid = parseLocalMidnight(endDate);
                  const startMid = parseLocalMidnight(startDate);
                  const cycleStatus = endMid < todayMid ? 'closed' : (startMid > todayMid ? 'upcoming' : 'open');

                  await supabase
                    .from('application_cycles')
                    .insert({
                      program_id: progData.id,
                      cycle_name: formData.cycle_name || 'AY 2026-2027',
                      application_start_date: startDate,
                      application_end_date: endDate,
                      status: cycleStatus,
                    });
                  showToast('Program and application cycle published successfully!');
                  await fetchPrograms();
                  setSelectedProgram(null);
                  setActiveTab('programs');
                }
              }
            }}
            providerDetails={providerDetails}
          />
        )}

        {activeTab === 'programs' && (
          <ProviderProgramsTab
            providerDetails={providerDetails}
            programsList={programsList}
            showToast={showToast}
            onOpenCreateProgram={handleOpenCreateProgram}
            setActiveTab={setActiveTab}
            handleViewDetails={handleViewDetails}
            handleEditProgram={handleEditProgram}
            handleOpenRenewModal={handleOpenRenewModal}
            handleOpenEditCycle={handleOpenEditCycle}
            handleDeleteCycle={handleDeleteCycle}
            setProgramToClose={setProgramToClose}
            setIsCloseConfirmOpen={setIsCloseConfirmOpen}
            fetchPrograms={fetchPrograms}
          />
        )}

        {activeTab === 'disbursements' && (
          <ProviderDisbursementsTab
            totalCredited={totalCredited}
            totalPending={totalPending}
            disbursementsList={disbursementsList}
            setIsPayoutModalOpen={setIsPayoutModalOpen}
            programsList={programsList}
          />
        )}

        {activeTab === 'announcements' && (
          <ProviderAnnouncementsTab
            handleAddAnnouncement={handleAddAnnouncement}
            newAnnType={newAnnType}
            setNewAnnType={setNewAnnType}
            newAnnAudience={newAnnAudience}
            setNewAnnAudience={setNewAnnAudience}
            selectedProgramId={selectedProgramId}
            setSelectedProgramId={setSelectedProgramId}
            programsList={programsList}
            setIsBigMapModalOpen={setIsBigMapModalOpen}
            isLoaded={isLoaded}
            onAutocompleteLoad={onAutocompleteLoad}
            onPlaceChanged={onPlaceChanged}
            mapSearchText={mapSearchText}
            setMapSearchText={setMapSearchText}
            examCoords={examCoords}
            mapZoom={mapZoom}
            setMapZoom={setMapZoom}
            handleMapClick={handleMapClick}
            newAnnTitle={newAnnTitle}
            setNewAnnTitle={setNewAnnTitle}
            newAnnBody={newAnnBody}
            setNewAnnBody={setNewAnnBody}
            announcements={announcements}
            onDeleteAnnouncement={handleDeleteAnnouncement}
            isBroadcasting={isBroadcasting}
          />
        )}

        {activeTab === 'reports' && (
          <ProviderReportsTab
            programs={programsList}
            applicants={applicantsList}
            scholars={scholarsList}
            disbursements={disbursementsList}
            announcements={announcements}
            providerDetails={providerDetails}
            showToast={showToast}
          />
        )}

        {activeTab === 'verification' && (
          <ProviderVerificationTab
            providerDetails={providerDetails}
            profile={profile}
            handleUnsubmitVerification={handleUnsubmitVerification}
            submittingVerification={submittingVerification}
            requiredDocs={requiredDocs}
            setProviderDetails={setProviderDetails}
            showToast={showToast}
            uploadingDoc={uploadingDoc}
            handleUploadDocument={handleUploadDocument}
            handleSubmitVerification={handleSubmitVerification}
            hasModifiedDocs={hasModifiedDocs}
            onDocsModified={() => setHasModifiedDocs(true)}
          />
        )}

        {activeTab === 'profile' && (
          <ProfileSettingsTab
            showToast={showToast}
            providerDetails={providerDetails ? { id: providerDetails.id, name: providerDetails.name } : null}
            onProfileUpdated={(updated) => setProfile(prev => prev ? { ...prev, ...updated } : prev)}
            onProviderUpdated={(name) => {
              setProviderDetails(prev => prev ? { ...prev, name } : prev);
              setProfile(prev => prev ? { ...prev, providerName: name } : prev);
            }}
          />
        )}
        </main>
      </div>

      {/* ─── Provider Notification Drawer ─── */}
      <ProviderNotificationDrawer
        isOpen={isNotificationDrawerOpen}
        onClose={() => setIsNotificationDrawerOpen(false)}
        userId={currentUserId}
        onUnreadCountChange={setUnreadNotifCount}
      />

      {/* ─── View Details Modal ─── */}
      {isViewModalOpen && selectedProgram && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            {/* Header */}
            <div className="flex justify-between items-start p-7 border-b border-[#D9D2C5]/50">
              <div>
                <span className="text-[10px] uppercase font-bold text-[#8E8E93] tracking-widest block mb-1">{selectedProgram.category}</span>
                <h2 className="text-2xl font-bold text-[#1A3C2E] font-serif leading-tight">{selectedProgram.title}</h2>
                <p className="text-xs text-[#6C6C70] mt-1">{selectedProgram.description}</p>
              </div>
              <button
                onClick={() => setIsViewModalOpen(false)}
                className="w-9 h-9 rounded-full bg-[#EDE8DE] hover:bg-[#D9D2C5] flex items-center justify-center text-[#1A3C2E] font-bold text-lg border-0 cursor-pointer shrink-0 ml-4 transition-all"
              >×</button>
            </div>

            <div className="p-7 space-y-6">
              {/* Status & Policy */}
              <div className="grid grid-cols-3 gap-4">
                <div className="bg-[#F9F5EF] rounded-2xl p-4 text-center">
                  <span className="text-[9px] uppercase font-bold text-[#8E8E93] tracking-wider block mb-1">Status</span>
                  <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${
                    selectedProgram.status === 'Active' || selectedProgram.status === 'Approved' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                    selectedProgram.status === 'Pending Review' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                    selectedProgram.status === 'Draft' ? 'bg-blue-50 text-blue-600' :
                    'bg-[#FDF2F2] text-[#B34040]'
                  }`}>{selectedProgram.status}</span>
                </div>
                <div className="bg-[#F9F5EF] rounded-2xl p-4 text-center">
                  <span className="text-[9px] uppercase font-bold text-[#8E8E93] tracking-wider block mb-1">Renewal Policy</span>
                  <span className="text-xs font-bold text-[#1C1C1E]">{selectedProgram.renewalPolicy}</span>
                </div>
                <div className="bg-[#F9F5EF] rounded-2xl p-4 text-center">
                  <span className="text-[9px] uppercase font-bold text-[#8E8E93] tracking-wider block mb-1">Funding</span>
                  <span className="text-xs font-bold text-[#1C1C1E]">{selectedProgram.fundingFrequency}</span>
                </div>
              </div>

              {/* Benefits */}
              <div>
                <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider mb-2">Benefits</h4>
                <div className="flex flex-wrap gap-2">
                  {selectedProgram.coverstuition && <span className="bg-[#EBF5EE] text-[#2D5941] text-xs font-bold px-3 py-1 rounded-full">Full Tuition</span>}
                  {selectedProgram.coversStipend && <span className="bg-[#EBF5EE] text-[#2D5941] text-xs font-bold px-3 py-1 rounded-full">Stipend ₱{Number(selectedProgram.stipendAmount).toLocaleString()}/mo</span>}
                  {selectedProgram.coversAllowance && <span className="bg-[#EBF5EE] text-[#2D5941] text-xs font-bold px-3 py-1 rounded-full">Allowance ₱{Number(selectedProgram.allowanceAmount).toLocaleString()}</span>}
                  {selectedProgram.otherBenefits?.map((b: any, i: number) => <span key={i} className="bg-[#EDE8DE] text-[#6C6C70] text-xs font-semibold px-3 py-1 rounded-full">{b}</span>)}
                </div>
              </div>

              {/* Eligibility */}
              <div>
                <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider mb-2">Eligibility</h4>
                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div><span className="text-[#8E8E93] font-semibold">Courses: </span><span className="font-bold text-[#1C1C1E]">{selectedProgram.courseEligibility?.join(', ') || 'All'}</span></div>
                  <div><span className="text-[#8E8E93] font-semibold">Year Levels: </span><span className="font-bold text-[#1C1C1E]">{selectedProgram.yearLevelEligibility?.length > 0 ? selectedProgram.yearLevelEligibility.map((y: any) => `Year ${y}`).join(', ') : 'All'}</span></div>
                  <div><span className="text-[#8E8E93] font-semibold">Min GWA: </span><span className="font-bold text-[#1C1C1E]">{selectedProgram.minimumGwa || 'None'}</span></div>
                  <div><span className="text-[#8E8E93] font-semibold">Availability: </span><span className="font-bold text-[#1C1C1E] capitalize">{selectedProgram.availabilityScope}</span></div>
                  <div><span className="text-[#8E8E93] font-semibold">Total Slots: </span><span className="font-bold text-[#1C1C1E]">{selectedProgram.totalSlots || 'Unlimited'}</span></div>
                  <div><span className="text-[#8E8E93] font-semibold">Budget: </span><span className="font-bold text-[#1C1C1E]">{selectedProgram.budgetTotal}</span></div>
                </div>
              </div>

              {/* Requirements */}
              {selectedProgram.applicationRequirements?.length > 0 && (
                <div>
                  <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider mb-2">Document Requirements</h4>
                  <div className="space-y-2">
                    {selectedProgram.applicationRequirements?.map((req: any, i: number) => (
                      <div key={i} className="flex items-start gap-3 p-3 rounded-xl border border-[#D9D2C5]/50 bg-[#F9F5EF]/50 text-xs">
                        <div className="flex-1">
                          <span className="font-bold text-[#1C1C1E]">{req.name}</span>
                          {req.description && <span className="text-[#6C6C70] ml-2">— {req.description}</span>}
                        </div>
                        <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded shrink-0 ${req.required ? 'bg-red-50 text-red-600 border border-red-200' : 'bg-slate-100 text-slate-500'}`}>{req.required ? 'REQUIRED' : 'OPTIONAL'}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Cycles */}
              <div>
                <div className="flex justify-between items-center mb-2">
                  <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider">Application Cycles</h4>
                  <button
                    onClick={() => { setIsViewModalOpen(false); handleOpenRenewModal(selectedProgram); }}
                    className="px-2.5 py-1 rounded-lg bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-[10px] font-bold border-0 cursor-pointer transition-all"
                  >
                    🔄 Renew / Add Cycle
                  </button>
                </div>
                <div className="space-y-2">
                  {selectedProgram.cycles?.map((cyc: any) => (
                    <div key={cyc.id} className="flex justify-between items-center bg-[#F9F5EF] px-4 py-3 rounded-xl border border-[#D9D2C5]/30 text-xs">
                      <div>
                        <span className="font-bold text-[#1C1C1E] block">{cyc.name}</span>
                        {cyc.semester && <span className="text-[10px] text-[#6C6C70] font-medium">{cyc.semester}</span>}
                      </div>
                      <div className="flex items-center gap-2.5">
                        <span className="text-[#8E8E93] text-[11px]">{cyc.startDate} → {cyc.endDate}</span>
                        <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                          cyc.status === 'Open' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                          cyc.status === 'Evaluating' ? 'bg-amber-100 text-amber-700' :
                          cyc.status === 'Upcoming' ? 'bg-blue-50 text-blue-600' :
                          'bg-gray-200 text-gray-600'
                        }`}>{cyc.status}</span>
                        <button
                          onClick={() => {
                            setIsViewModalOpen(false);
                            handleOpenEditCycle(selectedProgram, cyc);
                          }}
                          className="px-2 py-1 bg-white hover:bg-[#EDE8DE] text-[#1A3C2E] border border-[#D9D2C5] rounded-lg cursor-pointer transition-all text-[10.5px] font-bold flex items-center gap-1 shadow-2xs"
                          title="Edit this cycle"
                        >
                          <span>✏️</span> Edit
                        </button>
                        <button
                          onClick={() => handleDeleteCycle(cyc.id.toString(), cyc.name)}
                          className="px-2 py-1 bg-white hover:bg-red-50 text-red-600 border border-red-200 rounded-lg cursor-pointer transition-all text-[10.5px] font-bold flex items-center gap-1 shadow-2xs"
                          title="Delete this cycle"
                        >
                          <span>🗑️</span> Delete
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className="p-7 border-t border-[#D9D2C5]/50 flex justify-end gap-3">

              <button
                onClick={() => setIsViewModalOpen(false)}
                className="px-5 py-2.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-sm font-bold border-0 cursor-pointer transition-all"
              >Close</button>
              <button
                onClick={() => { setIsViewModalOpen(false); handleEditProgram(selectedProgram); }}
                className="px-5 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-sm font-bold border-0 cursor-pointer transition-all"
              >Edit Program</button>
            </div>
          </div>
        </div>
      )}

      {/* ─── Close Program Confirm Modal ─── */}
      <CloseProgramConfirmModal
        isOpen={isCloseConfirmOpen}
        program={programToClose}
        onClose={() => { setIsCloseConfirmOpen(false); setProgramToClose(null); }}
        onConfirm={handleCloseProgram}
      />

      {/* ─── Delete Cycle Confirm Modal ─── */}
      <DeleteCycleConfirmModal
        isOpen={isDeleteCycleConfirmOpen}
        cycle={cycleToDelete}
        onClose={() => { setIsDeleteCycleConfirmOpen(false); setCycleToDelete(null); }}
        onConfirm={handleConfirmDeleteCycle}
      />

      {/* ─── Renew / Add Cycle Modal ─── */}
      <RenewCycleModal
        isOpen={isRenewModalOpen}
        program={selectedProgramForRenewal}
        cycleToEdit={cycleToEdit}
        onClose={() => { setIsRenewModalOpen(false); setSelectedProgramForRenewal(null); setCycleToEdit(null); }}
        onSubmit={handleRenewProgramCycle}
        renewCycleName={renewCycleName}
        setRenewCycleName={setRenewCycleName}
        renewStartDate={renewStartDate}
        setRenewStartDate={setRenewStartDate}
        renewEndDate={renewEndDate}
        setRenewEndDate={setRenewEndDate}
        renewSlots={renewSlots}
        setRenewSlots={setRenewSlots}
        renewCycleType={renewCycleType}
        setRenewCycleType={setRenewCycleType}
        renewSemester={renewSemester}
        setRenewSemester={setRenewSemester}
        renewRequirements={renewRequirements}
        setRenewRequirements={setRenewRequirements}
      />

      {/* ─── Review Application Modal ─── */}
      <ReviewApplicationModal
        isOpen={isReviewModalOpen}
        application={selectedAppForReview}
        onClose={() => {
          setIsReviewModalOpen(false);
          setSelectedAppForReview(null);
        }}
        onUpdateStatus={handleUpdateStatus}
      />

    </div>
  );
};

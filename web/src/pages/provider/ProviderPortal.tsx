import React, { useState, useEffect } from 'react';
import { GoogleMap, useJsApiLoader, Marker, Autocomplete } from '@react-google-maps/api';
import LogoGoldSvg from '@/assets/logo/iskolarakologo-notext-gold.svg';
import { supabase } from '@/services/supabaseClient';
import { sendDecisionNotification } from '@/services/notificationService';
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
import { ProfileSettingsTab } from '@/components/common/ProfileSettingsTab';
import type {
  ProviderPortalProps,
  TabType,
  AnnType,
  ApplicantStatus,
  FundingFreq,
  RenewalPolicy,
  ScholarshipType,
  AvailabilityScope,
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
  const [activeTab, setActiveTab] = useState<TabType>('programs');
  
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
      renewalGwa: dbProg.renewal_gwa_requirement ? String(dbProg.renewal_gwa_requirement) : '',
      cycles: (dbProg.cycles || []).map((cyc: any) => ({
        id: cyc.id,
        name: cyc.cycle_name,
        startDate: cyc.application_start_date,
        endDate: cyc.application_end_date,
        status: cyc.status === 'open' ? 'Open' : cyc.status === 'evaluating' ? 'Evaluating' : cyc.status === 'upcoming' ? 'Upcoming' : 'Closed'
      })),
      budgetUsed: '₱0',
      budgetTotal: dbProg.budget_total ? `₱${Number(dbProg.budget_total).toLocaleString()}` : '₱0',
      rejectionRemarks: dbProg.rejection_remarks || undefined
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
          showToast('Programs updated in real-time!');
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
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isPayoutModalOpen, setIsPayoutModalOpen] = useState(false);
  const [isBigMapModalOpen, setIsBigMapModalOpen] = useState(false);

  // Renew/Reopen Cycle Modal States
  const [isRenewModalOpen, setIsRenewModalOpen] = useState(false);
  const [selectedProgramForRenewal, setSelectedProgramForRenewal] = useState<Program | null>(null);
  const [renewCycleName, setRenewCycleName] = useState('');
  const [renewStartDate, setRenewStartDate] = useState('');
  const [renewEndDate, setRenewEndDate] = useState('');
  const [renewSlots, setRenewSlots] = useState('');
  const [renewCycleType, setRenewCycleType] = useState<'new_applicant' | 'renewal'>('renewal');
  const [renewSemester, setRenewSemester] = useState<string>('2nd Semester');

  // Delete Cycle Confirm Modal States
  const [isDeleteCycleConfirmOpen, setIsDeleteCycleConfirmOpen] = useState(false);
  const [cycleToDelete, setCycleToDelete] = useState<{ id: string; name: string } | null>(null);

  // New program form inputs
  const [formTitle, setFormTitle] = useState('');
  const [formDesc, setFormDesc] = useState('');


  const [formFundingFreq, setFormFundingFreq] = useState<FundingFreq>('Per Semester');
  const [formRenewalPolicy, setFormRenewalPolicy] = useState<RenewalPolicy>('Semester Renewal');
  const [formCycleName, setFormCycleName] = useState('AY 2026-2027');
  // Extended program form fields
  const [formCategory, setFormCategory] = useState('Merit-Based');
  const [formScholarshipType, setFormScholarshipType] = useState<ScholarshipType>('merit');
  const [formCoverstuition, setFormCoverstuition] = useState(false);
  const [formCoversStipend, setFormCoversStipend] = useState(false);
  const [formStipendAmount, setFormStipendAmount] = useState('');
  const [formCoversAllowance, setFormCoversAllowance] = useState(false);
  const [formAllowanceAmount, setFormAllowanceAmount] = useState('');
  const [formOtherBenefits, setFormOtherBenefits] = useState('');
  const [formCourseEligibility, setFormCourseEligibility] = useState<string[]>([]);
  const [formCourseInput, setFormCourseInput] = useState('');
  const [formYearLevelEligibility, setFormYearLevelEligibility] = useState<number[]>([]);
  const [formMinGwa, setFormMinGwa] = useState('');
  const [formAvailabilityScope, setFormAvailabilityScope] = useState<AvailabilityScope>('nationwide');
  const [formAvailableRegions, setFormAvailableRegions] = useState('');
  const [formAvailableSchools, setFormAvailableSchools] = useState('');
  const [formTotalSlots, setFormTotalSlots] = useState('');
  const [formBudgetTotal, setFormBudgetTotal] = useState('');
  const [formRenewalGwa, setFormRenewalGwa] = useState('');
  const [formCycleStartDate, setFormCycleStartDate] = useState('');
  const [formCycleEndDate, setFormCycleEndDate] = useState('');
  const [formRequirements, setFormRequirements] = useState<ProgramRequirement[]>([
    { name: 'Transcript of Records', description: 'Official TOR from your registrar', required: true },
    { name: 'Certificate of Good Moral Character', description: 'From your school registrar or dean', required: true },
  ]);
  const [formReqName, setFormReqName] = useState('');
  const [formReqDesc, setFormReqDesc] = useState('');
  const [formReqRequired, setFormReqRequired] = useState(true);
  const [formModalStep, setFormModalStep] = useState(1);

  // PSGC Geographic Data States & Fetch Effects
  const [psgcRegions, setPsgcRegions] = useState<{ code: string; name: string }[]>([]);
  const [psgcProvinces, setPsgcProvinces] = useState<{ code: string; name: string }[]>([]);
  const [psgcMunicipalities, setPsgcMunicipalities] = useState<{ code: string; name: string }[]>([]);
  const [psgcBarangays, setPsgcBarangays] = useState<{ code: string; name: string }[]>([]);
  const [selectedRegionCode, setSelectedRegionCode] = useState('');
  const [selectedProvinceCode, setSelectedProvinceCode] = useState('');
  const [selectedMunicipalityCode, setSelectedMunicipalityCode] = useState('');
  const [selectedBarangayCode, setSelectedBarangayCode] = useState('');

  useEffect(() => {
    const fetchRegions = async () => {
      try {
        const res = await fetch('https://psgc.gitlab.io/api/regions/');
        if (res.ok) {
          const data = await res.json();
          data.sort((a: any, b: any) => a.name.localeCompare(b.name));
          setPsgcRegions(data);
        }
      } catch (err) {
        console.error('Error fetching PSGC regions:', err);
      }
    };
    fetchRegions();
  }, []);

  useEffect(() => {
    const fetchProvinces = async () => {
      if (!selectedRegionCode) {
        setPsgcProvinces([]);
        return;
      }
      try {
        const res = await fetch(`https://psgc.gitlab.io/api/regions/${selectedRegionCode}/provinces/`);
        if (res.ok) {
          const data = await res.json();
          data.sort((a: any, b: any) => a.name.localeCompare(b.name));
          setPsgcProvinces(data);
        }
      } catch (err) {
        console.error('Error fetching PSGC provinces:', err);
      }
    };
    fetchProvinces();
  }, [selectedRegionCode]);

  useEffect(() => {
    const fetchMunicipalities = async () => {
      if (!selectedProvinceCode) {
        setPsgcMunicipalities([]);
        return;
      }
      try {
        const res = await fetch(`https://psgc.gitlab.io/api/provinces/${selectedProvinceCode}/cities-municipalities/`);
        if (res.ok) {
          const data = await res.json();
          data.sort((a: any, b: any) => a.name.localeCompare(b.name));
          setPsgcMunicipalities(data);
        }
      } catch (err) {
        console.error('Error fetching PSGC municipalities:', err);
      }
    };
    fetchMunicipalities();
  }, [selectedProvinceCode]);

  useEffect(() => {
    const fetchBarangays = async () => {
      if (!selectedMunicipalityCode) {
        setPsgcBarangays([]);
        return;
      }
      try {
        const res = await fetch(`https://psgc.gitlab.io/api/cities-municipalities/${selectedMunicipalityCode}/barangays/`);
        if (res.ok) {
          const data = await res.json();
          data.sort((a: any, b: any) => a.name.localeCompare(b.name));
          setPsgcBarangays(data);
        }
      } catch (err) {
        console.error('Error fetching PSGC barangays:', err);
      }
    };
    fetchBarangays();
  }, [selectedMunicipalityCode]);

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

  // Announcements mock state
  const [announcements, setAnnouncements] = useState<any[]>([
    {
      id: 1,
      title: 'Undergraduate Screening Examination Schedule',
      body: 'Qualifying exams for new DOST-SEI applicants will be conducted on September 5, 2026. Testing venues and seat assignments have been dispatched to your portal accounts.',
      type: 'Examination Schedule' as AnnType,
      audience: 'DOST-SEI Only',
      date: 'Aug 8, 2026',
      author: 'Testing Committee',
      location: 'UP Diliman Examination Hall'
    },
    {
      id: 2,
      title: '1st Semester Stipend Release Schedule',
      body: 'Stipends for Tulong Dunong scholars are currently processing. Expect bank transfers to credit by August 18, 2026.',
      type: 'Release of Funds' as AnnType,
      audience: 'CHED Only',
      date: 'Aug 5, 2026',
      author: 'Finance Unit',
      location: null
    }
  ]);

  const [newAnnTitle, setNewAnnTitle] = useState('');
  const [newAnnBody, setNewAnnBody] = useState('');
  const [newAnnType, setNewAnnType] = useState<AnnType>('General Notice');
  const [newAnnAudience, setNewAnnAudience] = useState('All Scholars');

  const handleAddAnnouncement = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAnnTitle || !newAnnBody) return;
    const newAnn = {
      id: Date.now(),
      title: newAnnTitle,
      body: newAnnBody,
      type: newAnnType,
      audience: newAnnAudience,
      date: 'Just Now',
      author: 'DOST-SEI Admin',
      location: newAnnType === 'Examination Schedule' ? selectedExamLocation : null
    };
    setAnnouncements([newAnn, ...announcements]);
    setNewAnnTitle('');
    setNewAnnBody('');
    showToast(`Successfully broadcasted: "${newAnnTitle}"`);
  };

  // Programs State (Loaded dynamically from database)
  const [programsList, setProgramsList] = useState<Program[]>([]);


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
                  scholarDocsMap[d.scholar_id].push({
                    id: d.id,
                    name: d.document_name,
                    filename: d.document_name,
                    document_url: d.document_url,
                    url: d.document_url,
                    status: d.verification_status === 'verified' ? 'Verified' : d.verification_status === 'rejected' ? 'Flagged' : 'Pending',
                    remarks: d.remarks || '',
                    submitted_at: d.created_at ? new Date(d.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'Recently'
                  });
                });
              }
            } catch (dErr) {
              console.warn('[Provider Scholar Documents Exception]:', dErr);
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
            const gpa = scholar.gpa != null ? String(scholar.gpa) : (scholar.gwa != null ? String(scholar.gwa) : '1.50');
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
                remarks: d.remarks || ''
              }));
            }

            if (scholarDocsMap[scholar.id]) {
              const existingNames = new Set(docs.map(d => (d.name || '').toLowerCase().trim()));
              const existingUrls = new Set(docs.map(d => (d.document_url || d.url || '').toLowerCase().trim()).filter(Boolean));
              const existingFiles = new Set(docs.map(d => (d.filename || '').toLowerCase().trim()).filter(Boolean));

              scholarDocsMap[scholar.id].forEach(sd => {
                const sdName = (sd.name || '').toLowerCase().trim();
                const sdUrl = (sd.document_url || sd.url || '').toLowerCase().trim();
                const sdFile = (sd.filename || '').toLowerCase().trim();

                const isDup = (sdName && existingNames.has(sdName)) ||
                              (sdUrl && existingUrls.has(sdUrl)) ||
                              (sdFile && existingFiles.has(sdFile));

                if (!isDup) {
                  docs.push(sd);
                  if (sdName) existingNames.add(sdName);
                  if (sdUrl) existingUrls.add(sdUrl);
                  if (sdFile) existingFiles.add(sdFile);
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
            const gpa = scholar.gpa != null ? String(scholar.gpa) : (scholar.gwa != null ? String(scholar.gwa) : '1.50');
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
                remarks: d.remarks || ''
              }));
            }

            if (scholarDocsMap[scholar.id]) {
              const existingNames = new Set(docs.map(d => (d.name || '').toLowerCase().trim()));
              const existingUrls = new Set(docs.map(d => (d.document_url || d.url || '').toLowerCase().trim()).filter(Boolean));
              const existingFiles = new Set(docs.map(d => (d.filename || '').toLowerCase().trim()).filter(Boolean));

              scholarDocsMap[scholar.id].forEach(sd => {
                const sdName = (sd.name || '').toLowerCase().trim();
                const sdUrl = (sd.document_url || sd.url || '').toLowerCase().trim();
                const sdFile = (sd.filename || '').toLowerCase().trim();

                const isDup = (sdName && existingNames.has(sdName)) ||
                              (sdUrl && existingUrls.has(sdUrl)) ||
                              (sdFile && existingFiles.has(sdFile));

                if (!isDup) {
                  docs.push(sd);
                  if (sdName) existingNames.add(sdName);
                  if (sdUrl) existingUrls.add(sdUrl);
                  if (sdFile) existingFiles.add(sdFile);
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

            return {
              id: app.id,
              scholarName: scholarName,
              programTitle: prog.title || 'Scholarship Program',
              cycleJoined: cycle.cycle_name || 'Active Cycle',
              status: 'Maintaining',
              gwa: gpa,
              dateAwarded: awardedDate,
              appDetail: appDetail
            };
          });

          if (mappedScholars.length > 0) {
            setScholarsList(mappedScholars);
          }
        }
    } catch (err) {
      console.error('Error fetching applicants:', err);
    }
  };

  useEffect(() => {
    fetchApplicantsAndScholars();

    const appChannel = supabase
      .channel('provider-applications-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_applications' },
        () => {
          fetchApplicantsAndScholars();
          showToast('Applications & Scholar status updated live!');
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholar_documents' },
        () => {
          fetchApplicantsAndScholars();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'disbursement_transactions' },
        () => {
          fetchApplicantsAndScholars();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(appChannel);
    };
  }, [providerDetails?.id]);

  // Interactive Applicants State (Students in an active application cycle)
  const [applicantsList, setApplicantsList] = useState<ApplicationDetail[]>([
    {
      id: 'app-01',
      name: 'Juan Dela Cruz',
      email: 'juan.delacruz@up.edu.ph',
      phone: '+63 917 123 4567',
      program: 'DOST-SEI Undergraduate',
      cycle: '2026 Intake',
      school: 'Ateneo de Manila University',
      course: 'BS Computer Science',
      yearLevel: '3rd Year',
      grade: '1.40',
      status: 'Under Review',
      date: 'Aug 08, 2026',
      submittedDocuments: [
        { name: 'Official Transcript of Records (TOR)', filename: 'TOR_GWA_1.40.pdf', filesize: '1.4 MB', status: 'Verified', submitted_at: 'Aug 08, 2026' },
        { name: 'Certificate of Good Moral Character', filename: 'Good_Moral_ADMU.pdf', filesize: '820 KB', status: 'Verified', submitted_at: 'Aug 08, 2026' }
      ]
    },
    {
      id: 'app-02',
      name: 'Ethan Gomez',
      email: 'ethan.gomez@dlsu.edu.ph',
      phone: '+63 918 987 6543',
      program: 'Tulong Dunong Assistance',
      cycle: 'AY 2026-2027',
      school: 'De La Salle University',
      course: 'BS Industrial Engineering',
      yearLevel: '2nd Year',
      grade: '1.75',
      status: 'Pending',
      date: 'Aug 06, 2026',
      submittedDocuments: [
        { name: 'Official Transcript of Records (TOR)', filename: 'DLSU_Grade_Slip.pdf', filesize: '1.1 MB', status: 'Pending', submitted_at: 'Aug 06, 2026' },
        { name: 'Income Tax Return / Proof of Income', filename: 'ITR_Family_2025.pdf', filesize: '950 KB', status: 'Pending', submitted_at: 'Aug 06, 2026' }
      ]
    }
  ]);

  // Active Scholars (Awarded students under requirements monitoring)
  const [scholarsList, setScholarsList] = useState<ScholarAward[]>([
    {
      id: 'sch-01',
      scholarName: 'Maria Santos',
      programTitle: 'DOST-SEI Undergraduate',
      cycleJoined: '2025 Intake',
      status: 'Maintaining',
      gwa: '1.25',
      dateAwarded: 'Aug 07, 2025',
      appDetail: {
        id: 'sch-01',
        name: 'Maria Santos',
        email: 'maria.santos@up.edu.ph',
        phone: '+63 919 555 1234',
        program: 'DOST-SEI Undergraduate',
        cycle: '2025 Intake',
        school: 'University of the Philippines',
        course: 'BS Chemical Engineering',
        yearLevel: '3rd Year',
        grade: '1.25',
        status: 'Approved',
        date: 'Aug 07, 2025',
        submittedDocuments: [
          { name: 'Official Transcript of Records (TOR)', filename: 'UP_TOR_GWA125.pdf', filesize: '1.6 MB', status: 'Verified', submitted_at: 'Aug 07, 2025' }
        ]
      }
    }
  ]);

  // Handle applicant status and document decision updates
  const handleUpdateStatus = async (
    id: number | string,
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
          const docStatusDb = doc.status === 'Verified' ? 'verified' : doc.status === 'Flagged' ? 'rejected' : 'under_review';
          const docRemarks = doc.remarks || (doc.status === 'Verified' ? 'Verified by scholarship provider' : doc.status === 'Flagged' ? 'Flagged: Resubmission required' : null);
          const docUrl = doc.document_url || doc.url || '';
          const docName = doc.name || doc.filename || 'Submitted Document';

          try {
            // 1. Try finding by ID if doc.id is a UUID
            let recordIdToUpdate: string | null = null;
            if (doc.id && typeof doc.id === 'string' && doc.id.includes('-') && doc.id.length > 20) {
              const { data: byId } = await supabase
                .from('scholar_documents')
                .select('id')
                .eq('id', doc.id)
                .maybeSingle();
              if (byId?.id) {
                recordIdToUpdate = byId.id;
              }
            }

            // 2. If not found by ID, search by scholar_id and flexible document_name / url matching
            if (!recordIdToUpdate) {
              const { data: existingRecords } = await supabase
                .from('scholar_documents')
                .select('id, document_name, document_url')
                .eq('scholar_id', scholarId);

              if (existingRecords && existingRecords.length > 0) {
                const match = existingRecords.find(r =>
                  (r.document_name && r.document_name.toLowerCase().trim() === docName.toLowerCase().trim()) ||
                  (r.document_url && docUrl && r.document_url.trim() === docUrl.trim()) ||
                  (r.document_name && docName.toLowerCase().includes(r.document_name.toLowerCase())) ||
                  (r.document_name && r.document_name.toLowerCase().includes(docName.toLowerCase()))
                );
                if (match) {
                  recordIdToUpdate = match.id;
                }
              }
            }

            if (recordIdToUpdate) {
              const { error: updErr } = await supabase
                .from('scholar_documents')
                .update({
                  verification_status: docStatusDb,
                  remarks: docRemarks,
                  document_url: docUrl || undefined,
                  updated_at: new Date().toISOString()
                })
                .eq('id', recordIdToUpdate);

              if (updErr) {
                console.error(`[Error updating scholar_documents record ${recordIdToUpdate}]:`, updErr);
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
                  updated_at: new Date().toISOString()
                });

              if (insErr) {
                console.error('[Error inserting scholar_documents record]:', insErr);
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

      // Trigger EmailJS & In-App System Notification for the student
      const recipientEmail = applicant?.email || applicant?.rawApplication?.scholar?.user?.email || applicant?.rawApplication?.scholar?.email;
      const recipientName = applicant?.name || 'Scholar Applicant';
      const progTitle = applicant?.program || applicant?.rawApplication?.cycle?.program?.title || 'Scholarship Program';
      const pName = providerDetails?.name || 'Scholarship Provider';

      const hasFlaggedDocs = updatedDocs?.some(d => d.status === 'Flagged');
      const flaggedRemarks = updatedDocs?.find(d => d.status === 'Flagged')?.remarks;
      let effectiveStatus = nextStatus;
      if (hasFlaggedDocs && (nextStatus === 'Under Review' || nextStatus === 'Pending')) {
        effectiveStatus = 'Flagged';
      }

      sendDecisionNotification({
        toEmail: recipientEmail,
        toName: recipientName,
        programTitle: progTitle,
        providerName: pName,
        status: effectiveStatus,
        remarks: remarks || flaggedRemarks || '',
        scholarId: scholarId,
        userId: applicant?.rawApplication?.scholar?.user_id,
      }).catch(err => console.warn('[Notification Service Call Note]:', err));
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
      showToast(`Approved ${applicant.name}! Issued Scholar Award & sent email notification.`);
    } else {
      setApplicantsList(prev =>
        prev.map(a => (a.id === id ? { ...a, status: nextStatus, remarks: remarks || a.remarks, submittedDocuments: updatedDocs || a.submittedDocuments } : a))
      );
      showToast(`Application updated to ${nextStatus}. Email notification sent to student.`);
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
        .from('disbursement_transactions')
        .select(`
          *,
          scholar:scholar (
            first_name,
            last_name
          ),
          program:scholarship_programs (
            title
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
          method: d.disbursement_channel || 'Bank Transfer',
          amount: `₱${Number(d.amount).toLocaleString()}`,
          numericAmount: Number(d.amount) || 0,
          status: d.status,
          date: d.disbursement_date ? new Date(d.disbursement_date).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'N/A',
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
    .filter(tx => tx.status === 'COMPLETED' || tx.status === 'Completed')
    .reduce((sum, tx) => sum + tx.numericAmount, 0);

  const totalPending = disbursementsList
    .filter(tx => tx.status === 'PENDING' || tx.status === 'Pending' || tx.status === 'PROCESSING' || tx.status === 'Processing')
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
          table: 'disbursement_transactions'
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

      // Update disbursement transactions for this program that are pending/processing
      const { error } = await supabase
        .from('disbursement_transactions')
        .update({ status: 'COMPLETED', updated_at: new Date().toISOString() })
        .eq('program_id', program.id)
        .in('status', ['PENDING', 'Pending', 'PROCESSING', 'Processing']);

      if (error) throw error;

      setIsPayoutModalOpen(false);
      showToast(`Released funds! Completed pending transactions for "${selectedPayoutProgram}".`);
      // Real-time subscription will refresh the list
    } catch (err: any) {
      console.error('Error releasing funds:', err);
      showToast(`Error: ${err.message || 'Failed to release funds'}`);
    }
  };

  const handleCreateProgram = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formModalStep < 4) {
      setFormModalStep(s => Math.min(4, s + 1));
      return;
    }
    if (!formTitle || !formDesc || !providerDetails?.id) {
      showToast("Cannot create program: Required title or description missing.");
      return;
    }

    const matchedCat = categories.find(c => c.name === formCategory);
    const categoryId = matchedCat ? matchedCat.id : null;

    // Resolve parent names from selection codes
    const selectedProvObj = psgcProvinces.find(p => p.code === selectedProvinceCode);
    const provinceName = selectedProvObj ? selectedProvObj.name : '';
    const selectedMuniObj = psgcMunicipalities.find(m => m.code === selectedMunicipalityCode);
    const municipalityName = selectedMuniObj ? selectedMuniObj.name : '';
    const selectedBrgyObj = psgcBarangays.find(b => b.code === selectedBarangayCode);
    const barangayName = selectedBrgyObj ? selectedBrgyObj.name : '';

    try {
      // 1. Insert into scholarship_programs
      const { data: progData, error: progErr } = await supabase
        .from('scholarship_programs')
        .insert({
          provider_id: providerDetails.id,
          title: formTitle,
          description: formDesc,
          category_id: categoryId,
          scholarship_type: formScholarshipType,
          covers_tuition: formCoverstuition,
          covers_stipend: formCoversStipend,
          stipend_amount: formStipendAmount ? parseFloat(formStipendAmount) : null,
          covers_allowance: formCoversAllowance,
          allowance_amount: formAllowanceAmount ? parseFloat(formAllowanceAmount) : null,
          other_benefits: formOtherBenefits ? formOtherBenefits.split(',').map(s => s.trim()).filter(Boolean) : [],
          course_eligibility: formCourseEligibility.length > 0 ? formCourseEligibility : ['All Courses'],
          year_level_eligibility: formYearLevelEligibility,
          minimum_gwa: formMinGwa ? parseFloat(formMinGwa) : null,
          availability_scope: formAvailabilityScope,
          available_regions: formAvailableRegions ? formAvailableRegions.split(',').map(s => s.trim()) : [],
          available_provinces: (formAvailabilityScope === 'provincial' || formAvailabilityScope === 'municipality' || formAvailabilityScope === 'barangay') && provinceName ? [provinceName] : [],
          available_municipalities: (formAvailabilityScope === 'municipality' || formAvailabilityScope === 'barangay') && municipalityName ? [municipalityName] : [],
          available_barangays: formAvailabilityScope === 'barangay' && barangayName ? [barangayName] : [],
          available_schools: formAvailabilityScope === 'specific_schools' && formAvailableSchools ? formAvailableSchools.split(',').map(s => s.trim()) : [],
          application_requirements: formRequirements,
          total_slots: formTotalSlots ? parseInt(formTotalSlots, 10) : null,
          budget_total: formBudgetTotal ? parseFloat(formBudgetTotal) : null,
          funding_frequency: formFundingFreq,
          renewal_policy: formRenewalPolicy,
          renewal_gwa_requirement: formRenewalGwa ? parseFloat(formRenewalGwa) : null,
          status: 'pending'
        })
        .select()
        .single();

      if (progErr || !progData) {
        console.error('Error inserting program:', progErr);
        showToast('Error creating scholarship program.');
        return;
      }

      // 2. Insert initial application cycle
      const cycleStatus = formCycleStartDate && parseLocalMidnight(formCycleStartDate) > getTodayMidnight() ? 'upcoming' : 'open';
      const { error: cycleErr } = await supabase
        .from('application_cycles')
        .insert({
          program_id: progData.id,
          cycle_name: formCycleName,
          application_start_date: formCycleStartDate || new Date().toISOString().split('T')[0],
          application_end_date: formCycleEndDate || new Date(Date.now() + 90 * 24 * 3600 * 1000).toISOString().split('T')[0],
          status: cycleStatus
        });

      if (cycleErr) {
        console.error('Error inserting application cycle:', cycleErr);
        showToast('Program created, but error creating cycle.');
      } else {
        showToast(`Created program: "${formTitle}" with cycle "${formCycleName}"!`);
      }

      // Reload programs from DB
      await fetchPrograms();

      // Reset Form State
      setIsCreateModalOpen(false);
      setFormTitle('');
      setFormDesc('');
      setFormCategory('Merit-Based');
      setFormScholarshipType('merit');
      setFormCoverstuition(false);
      setFormCoversStipend(false);
      setFormStipendAmount('');
      setFormCoversAllowance(false);
      setFormAllowanceAmount('');
      setFormOtherBenefits('');
      setFormCourseEligibility([]);
      setFormCourseInput('');
      setFormYearLevelEligibility([]);
      setFormMinGwa('');
      setFormAvailabilityScope('nationwide');
      setFormAvailableRegions('');
      setFormAvailableSchools('');
      setFormTotalSlots('');
      setFormBudgetTotal('');
      setFormRenewalGwa('');
      setFormRenewalPolicy('Semester Renewal');
      setFormCycleName('AY 2026-2027');
      setFormCycleStartDate('');
      setFormCycleEndDate('');
      setFormRequirements([
        { name: 'Transcript of Records', description: 'Official TOR from your registrar', required: true },
        { name: 'Certificate of Good Moral Character', description: 'From your school registrar or dean', required: true },
      ]);
      setFormModalStep(1);

    } catch (err) {
      console.error('Failed to create program:', err);
      showToast('An unexpected error occurred.');
    }
  };

  // ── Program Action State ──────────────────────────────────────────────
  const [selectedProgram, setSelectedProgram] = useState<Program | null>(null);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [isCloseConfirmOpen, setIsCloseConfirmOpen] = useState(false);
  const [programToClose, setProgramToClose] = useState<Program | null>(null);
  const [isEditMode, setIsEditMode] = useState(false);

  // Auto pre-select PSGC dropdowns in edit mode when cascading PSGC data finishes loading
  useEffect(() => {
    if (isEditMode && selectedProgram && psgcRegions.length > 0 && !selectedRegionCode) {
      const regionName = selectedProgram.availableRegions[0];
      if (regionName) {
        const matched = psgcRegions.find(
          r => r.name.toLowerCase() === regionName.toLowerCase() ||
               r.name.toLowerCase().includes(regionName.toLowerCase()) ||
               regionName.toLowerCase().includes(r.name.toLowerCase()) ||
               r.code === regionName
        );
        if (matched) {
          setSelectedRegionCode(matched.code);
        }
      }
    }
  }, [isEditMode, selectedProgram, psgcRegions, selectedRegionCode]);

  useEffect(() => {
    if (isEditMode && selectedProgram && psgcProvinces.length > 0 && !selectedProvinceCode) {
      const targetName = selectedProgram.availableSchools;
      if (targetName) {
        const matched = psgcProvinces.find(
          p => p.name.toLowerCase() === targetName.toLowerCase() ||
               p.name.toLowerCase().includes(targetName.toLowerCase()) ||
               targetName.toLowerCase().includes(p.name.toLowerCase())
        );
        if (matched) {
          setSelectedProvinceCode(matched.code);
        }
      }
    }
  }, [isEditMode, selectedProgram, psgcProvinces, selectedProvinceCode]);

  useEffect(() => {
    if (isEditMode && selectedProgram && psgcMunicipalities.length > 0 && !selectedMunicipalityCode) {
      const targetName = selectedProgram.availableSchools;
      if (targetName) {
        const matched = psgcMunicipalities.find(
          m => m.name.toLowerCase() === targetName.toLowerCase() ||
               m.name.toLowerCase().includes(targetName.toLowerCase()) ||
               targetName.toLowerCase().includes(m.name.toLowerCase())
        );
        if (matched) {
          setSelectedMunicipalityCode(matched.code);
        }
      }
    }
  }, [isEditMode, selectedProgram, psgcMunicipalities, selectedMunicipalityCode]);

  useEffect(() => {
    if (isEditMode && selectedProgram && psgcBarangays.length > 0 && !selectedBarangayCode) {
      const targetName = selectedProgram.availableSchools;
      if (targetName) {
        const matched = psgcBarangays.find(
          b => b.name.toLowerCase() === targetName.toLowerCase() ||
               b.name.toLowerCase().includes(targetName.toLowerCase()) ||
               targetName.toLowerCase().includes(b.name.toLowerCase())
        );
        if (matched) {
          setSelectedBarangayCode(matched.code);
        }
      }
    }
  }, [isEditMode, selectedProgram, psgcBarangays, selectedBarangayCode]);

  const handleViewDetails = (prog: Program) => {
    setSelectedProgram(prog);
    setIsViewModalOpen(true);
  };

  const handleOpenCreateProgram = () => {
    setIsEditMode(false);
    setSelectedProgram(null);
    setFormTitle('');
    setFormDesc('');
    setFormCategory('Merit-Based');
    setFormScholarshipType('merit');
    setFormCoverstuition(false);
    setFormCoversStipend(false);
    setFormStipendAmount('');
    setFormCoversAllowance(false);
    setFormAllowanceAmount('');
    setFormOtherBenefits('');
    setFormCourseEligibility([]);
    setFormCourseInput('');
    setFormYearLevelEligibility([]);
    setFormMinGwa('');
    setFormAvailabilityScope('nationwide');
    setFormAvailableRegions('');
    setFormAvailableSchools('');
    setSelectedRegionCode('');
    setSelectedProvinceCode('');
    setSelectedMunicipalityCode('');
    setSelectedBarangayCode('');
    setFormTotalSlots('');
    setFormBudgetTotal('');
    setFormRenewalGwa('');
    setFormRenewalPolicy('Semester Renewal');
    setFormCycleName('AY 2026-2027');
    setFormCycleStartDate('');
    setFormCycleEndDate('');
    setFormRequirements([
      { name: 'Transcript of Records', description: 'Official TOR from your registrar', required: true },
      { name: 'Certificate of Good Moral Character', description: 'From your school registrar or dean', required: true },
    ]);
    setFormModalStep(1);
    setIsCreateModalOpen(true);
  };

  const handleEditProgram = (prog: Program) => {
    // Pre-fill all form fields from the selected program
    setFormTitle(prog.title);
    setFormDesc(prog.description);
    setFormCategory(prog.category);
    setFormScholarshipType(prog.scholarshipType);
    setFormCoverstuition(prog.coverstuition);
    setFormCoversStipend(prog.coversStipend);
    setFormStipendAmount(prog.stipendAmount);
    setFormCoversAllowance(prog.coversAllowance);
    setFormAllowanceAmount(prog.allowanceAmount);
    setFormOtherBenefits(prog.otherBenefits.join(', '));
    setFormCourseEligibility(prog.courseEligibility);
    setFormYearLevelEligibility(prog.yearLevelEligibility);
    setFormMinGwa(prog.minimumGwa);
    setFormAvailabilityScope(prog.availabilityScope);
    setFormAvailableRegions(prog.availableRegions.join(', '));
    setFormAvailableSchools(prog.availableSchools);
    setFormTotalSlots(prog.totalSlots);
    setFormBudgetTotal(prog.budgetTotal.replace(/[₱,]/g, '').replace('M', '000000'));
    setFormRenewalPolicy(prog.renewalPolicy);
    setFormFundingFreq(prog.fundingFrequency);
    setFormRenewalGwa(prog.renewalGwa);
    setFormRequirements(prog.applicationRequirements);
    setFormCycleName(prog.cycles[0]?.name || 'AY 2026-2027');
    setFormCycleStartDate(prog.cycles[0]?.startDate || '');
    setFormCycleEndDate(prog.cycles[0]?.endDate || '');
    setFormModalStep(1);
    setSelectedProgram(prog);
    setIsEditMode(true);

    // Pre-select PSGC region code if available
    const regionName = prog.availableRegions[0];
    if (regionName && psgcRegions.length > 0) {
      const matchedRegion = psgcRegions.find(
        r => r.name.toLowerCase() === regionName.toLowerCase() ||
             r.name.toLowerCase().includes(regionName.toLowerCase()) ||
             regionName.toLowerCase().includes(r.name.toLowerCase()) ||
             r.code === regionName
      );
      if (matchedRegion) {
        setSelectedRegionCode(matchedRegion.code);
      } else {
        setSelectedRegionCode('');
      }
    } else {
      setSelectedRegionCode('');
    }
    setSelectedProvinceCode('');
    setSelectedMunicipalityCode('');
    setSelectedBarangayCode('');

    setIsCreateModalOpen(true);
  };

  const handleUpdateProgram = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formModalStep < 4) {
      setFormModalStep(s => Math.min(4, s + 1));
      return;
    }
    if (!selectedProgram || !formTitle || !formDesc) return;

    const matchedCat = categories.find(c => c.name === formCategory);
    const categoryId = matchedCat ? matchedCat.id : null;

    // Resolve parent names from selection codes
    const selectedProvObj = psgcProvinces.find(p => p.code === selectedProvinceCode);
    const provinceName = selectedProvObj ? selectedProvObj.name : '';
    const selectedMuniObj = psgcMunicipalities.find(m => m.code === selectedMunicipalityCode);
    const municipalityName = selectedMuniObj ? selectedMuniObj.name : '';
    const selectedBrgyObj = psgcBarangays.find(b => b.code === selectedBarangayCode);
    const barangayName = selectedBrgyObj ? selectedBrgyObj.name : '';

    try {
      const { error } = await supabase
        .from('scholarship_programs')
        .update({
          title: formTitle,
          description: formDesc,
          category_id: categoryId,
          scholarship_type: formScholarshipType,
          covers_tuition: formCoverstuition,
          covers_stipend: formCoversStipend,
          stipend_amount: formStipendAmount ? parseFloat(formStipendAmount) : null,
          covers_allowance: formCoversAllowance,
          allowance_amount: formAllowanceAmount ? parseFloat(formAllowanceAmount) : null,
          other_benefits: formOtherBenefits ? formOtherBenefits.split(',').map(s => s.trim()).filter(Boolean) : [],
          course_eligibility: formCourseEligibility.length > 0 ? formCourseEligibility : ['All Courses'],
          year_level_eligibility: formYearLevelEligibility,
          minimum_gwa: formMinGwa ? parseFloat(formMinGwa) : null,
          availability_scope: formAvailabilityScope,
          available_regions: formAvailableRegions ? formAvailableRegions.split(',').map(s => s.trim()) : [],
          available_provinces: (formAvailabilityScope === 'provincial' || formAvailabilityScope === 'municipality' || formAvailabilityScope === 'barangay') && provinceName ? [provinceName] : [],
          available_municipalities: (formAvailabilityScope === 'municipality' || formAvailabilityScope === 'barangay') && municipalityName ? [municipalityName] : [],
          available_barangays: formAvailabilityScope === 'barangay' && barangayName ? [barangayName] : [],
          available_schools: formAvailabilityScope === 'specific_schools' && formAvailableSchools ? formAvailableSchools.split(',').map(s => s.trim()) : [],
          application_requirements: formRequirements,
          total_slots: formTotalSlots ? parseInt(formTotalSlots, 10) : null,
          budget_total: formBudgetTotal ? parseFloat(formBudgetTotal) : null,
          funding_frequency: formFundingFreq,
          renewal_policy: formRenewalPolicy,
          renewal_gwa_requirement: formRenewalGwa ? parseFloat(formRenewalGwa) : null,
        })
        .eq('id', selectedProgram.id);

      if (error) {
        console.error('Error updating program:', error);
        showToast('Error updating scholarship program.');
        return;
      }

      // Update or insert the active application cycle
      if (selectedProgram.cycles && selectedProgram.cycles.length > 0) {
        const activeCycle = selectedProgram.cycles[0];
        const cycleStatus = formCycleStartDate && parseLocalMidnight(formCycleStartDate) > getTodayMidnight() ? 'upcoming' : 'open';
        const { error: cycleErr } = await supabase
          .from('application_cycles')
          .update({
            cycle_name: formCycleName,
            application_start_date: formCycleStartDate,
            application_end_date: formCycleEndDate,
            status: cycleStatus
          })
          .eq('id', activeCycle.id);

        if (cycleErr) {
          console.error('Error updating cycle:', cycleErr);
        }
      } else {
        const cycleStatus = formCycleStartDate && parseLocalMidnight(formCycleStartDate) > getTodayMidnight() ? 'upcoming' : 'open';
        const { error: cycleErr } = await supabase
          .from('application_cycles')
          .insert({
            program_id: selectedProgram.id,
            cycle_name: formCycleName,
            application_start_date: formCycleStartDate || new Date().toISOString().split('T')[0],
            application_end_date: formCycleEndDate || new Date(Date.now() + 90 * 24 * 3600 * 1000).toISOString().split('T')[0],
            status: cycleStatus
          });

        if (cycleErr) {
          console.error('Error inserting cycle on edit:', cycleErr);
        }
      }

      showToast(`"${formTitle}" updated successfully!`);
      await fetchPrograms();

      setIsCreateModalOpen(false);
      setIsEditMode(false);
      setSelectedProgram(null);
      setFormModalStep(1);
    } catch (err) {
      console.error('Failed to update program:', err);
      showToast('An unexpected error occurred.');
    }
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

  const getNextCycleName = (lastCycleName: string): string => {
    const rangeRegex = /(\d{4})\s*-\s*(\d{4})/;
    const singleRegex = /(\d{4})/;
    
    const rangeMatch = lastCycleName.match(rangeRegex);
    if (rangeMatch) {
      const startYear = parseInt(rangeMatch[1], 10);
      const endYear = parseInt(rangeMatch[2], 10);
      return lastCycleName.replace(rangeRegex, `${startYear + 1}-${endYear + 1}`);
    }
    
    const singleMatch = lastCycleName.match(singleRegex);
    if (singleMatch) {
      const year = parseInt(singleMatch[1], 10);
      return lastCycleName.replace(singleRegex, `${year + 1}`);
    }
    
    const currentYear = new Date().getFullYear();
    return `AY ${currentYear}-${currentYear + 1}`;
  };

  const handleOpenRenewModal = (prog: Program) => {
    setSelectedProgramForRenewal(prog);
    
    // Sort cycles to find the latest one
    const latestCycle = prog.cycles && prog.cycles.length > 0
      ? [...prog.cycles].sort((a, b) => new Date(b.startDate).getTime() - new Date(a.startDate).getTime())[0]
      : null;
      
    const currentYear = new Date().getFullYear();
    setRenewCycleType('renewal');
    setRenewSemester('2nd Semester');
    if (latestCycle) {
      setRenewCycleName(`${getNextCycleName(latestCycle.name)} • 2nd Sem Renewal`);
    } else {
      setRenewCycleName(`AY ${currentYear}-${currentYear + 1} • 2nd Sem Renewal`);
    }
    
    setRenewStartDate(new Date().toISOString().split('T')[0]);
    setRenewEndDate(new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString().split('T')[0]);
    setRenewSlots(prog.totalSlots || '');
    setIsRenewModalOpen(true);
  };

  const handleRenewProgramCycle = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedProgramForRenewal || !renewCycleName || !renewStartDate || !renewEndDate) {
      showToast('Please fill in all required fields.');
      return;
    }

    try {
      const cycleStatus = parseLocalMidnight(renewStartDate) > getTodayMidnight() ? 'upcoming' : 'open';
      
      // 1. Insert new cycle with cycle_type & semester
      const { error: cycleErr } = await supabase
        .from('application_cycles')
        .insert({
          program_id: selectedProgramForRenewal.id,
          cycle_name: renewCycleName,
          cycle_type: renewCycleType,
          semester: renewSemester,
          application_start_date: renewStartDate,
          application_end_date: renewEndDate,
          slots_available: renewCycleType === 'renewal' ? null : (renewSlots ? parseInt(renewSlots, 10) : null),
          status: cycleStatus
        });

      if (cycleErr) {
        console.error('Error inserting renewal cycle:', cycleErr);
        showToast('Error creating new application cycle.');
        return;
      }

      // 2. If Semestral Renewal, notify continuing scholars of this program
      if (renewCycleType === 'renewal') {
        try {
          const { data: approvedApps } = await supabase
            .from('scholarship_applications')
            .select(`
              id,
              scholar_id,
              scholar:scholars(
                id,
                user_id,
                first_name,
                last_name,
                user:users(id, email, first_name, last_name)
              ),
              cycle:application_cycles!inner(program_id)
            `)
            .eq('status', 'approved')
            .eq('cycle.program_id', selectedProgramForRenewal.id);

          if (approvedApps && approvedApps.length > 0) {
            const notifInserts = approvedApps.map((app: any) => {
              const uId = app.scholar?.user_id || app.scholar?.user?.id;
              return {
                user_id: uId,
                title: `📢 ${selectedProgramForRenewal.title} — ${renewSemester} Renewal Open!`,
                message: `Notice for Continuing Scholars: The semestral renewal for ${selectedProgramForRenewal.title} (${renewSemester}) is now open until ${renewEndDate}. Please upload your latest Grade Slip and Certificate of Registration (COR) in your IskoAko app to maintain your scholarship grant.`,
                type: 'info',
                is_read: false,
                metadata: {
                  program_id: selectedProgramForRenewal.id,
                  cycle_name: renewCycleName,
                  semester: renewSemester,
                  action: 'renewal_submission'
                }
              };
            }).filter((n: any) => !!n.user_id);

            if (notifInserts.length > 0) {
              await supabase.from('notifications').insert(notifInserts);
              console.log(`[Renewal Broadcast]: Sent in-app notifications to ${notifInserts.length} continuing scholars.`);
            }
          }
        } catch (notifErr) {
          console.warn('[Renewal Scholar Notification Exception]:', notifErr);
        }
      }

      // 3. Update program status to 'active'
      const { error: progErr } = await supabase
        .from('scholarship_programs')
        .update({ status: 'active' })
        .eq('id', selectedProgramForRenewal.id);

      if (progErr) {
        console.error('Error updating program status on renewal:', progErr);
        showToast('Cycle added, but failed to set program status to active.');
      } else {
        showToast(`Successfully opened "${renewCycleName}" for "${selectedProgramForRenewal.title}"!`);
      }

      // Reload programs
      await fetchPrograms();
      
      // Close modal & reset state
      setIsRenewModalOpen(false);
      setSelectedProgramForRenewal(null);
      setRenewCycleName('');
      setRenewStartDate('');
      setRenewEndDate('');
      setRenewSlots('');
      setRenewCycleType('renewal');
      setRenewSemester('2nd Semester');
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

      {/* Program Creation Modal */}
      {isCreateModalOpen && (
        <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/50 backdrop-blur-sm px-4 py-6 overflow-y-auto">
          <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl w-full max-w-3xl relative animate-fade-in my-auto">
            {/* Modal Header */}
            <div className="sticky top-0 bg-white rounded-t-3xl z-10 px-8 pt-7 pb-5 border-b border-[#D9D2C5]/50">
              <button
                type="button"
                onClick={() => { setIsCreateModalOpen(false); setFormModalStep(1); setIsEditMode(false); setSelectedProgram(null); }}
                className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer bg-transparent border-0"
              >✕</button>
              <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">
                {isEditMode ? 'Edit Scholarship Program' : 'Create Scholarship Program'}
              </h3>
              <p className="text-xs text-[#6C6C70] mt-1">
                {isEditMode
                  ? 'Update program details below. Changes are saved immediately to the database.'
                  : 'Fill in all program details. You can manage cycles and update requirements after creation.'}
              </p>
              {/* Step indicator */}
              <div className="flex gap-2 mt-4">
                {['Basic Info', 'Benefits & Eligibility', 'Requirements', 'Application Cycle'].map((step, i) => (
                  <button
                    key={i}
                    type="button"
                    onClick={() => setFormModalStep(i + 1)}
                    className={`flex-1 text-[10px] font-bold py-1.5 rounded-lg transition-all cursor-pointer border-0 ${
                      formModalStep === i + 1
                        ? 'bg-[#1A3C2E] text-white'
                        : 'bg-[#F9F5EF] text-[#6C6C70] hover:bg-[#EDE8DE]'
                    }`}
                  >
                    {i + 1}. {step}
                  </button>
                ))}
              </div>
            </div>

            <form onSubmit={isEditMode ? handleUpdateProgram : handleCreateProgram}>
              <div className="px-8 py-6 space-y-5">

                {/* ─── STEP 1: Basic Info ─── */}
                {formModalStep === 1 && (
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Program Title *</label>
                        <input
                          type="text" required placeholder="e.g. DOST-SEI Undergraduate Scholarship"
                          value={formTitle} onChange={(e) => setFormTitle(e.target.value)}
                          className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Scholarship Category *</label>
                        <select
                          value={formCategory} onChange={(e) => setFormCategory(e.target.value)}
                          className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                        >
                          <option>Merit-Based</option>
                          <option>Need-Based</option>
                          <option>Merit and Need</option>
                          <option>STEM</option>
                          <option>Graduate / Fellowship</option>
                          <option>Vocational / TVET</option>
                          <option>Indigenous Peoples</option>
                          <option>Persons with Disability</option>
                        </select>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Scholarship Type *</label>
                        <select
                          value={formScholarshipType} onChange={(e) => setFormScholarshipType(e.target.value as ScholarshipType)}
                          className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                        >
                          <option value="merit">Merit-Based</option>
                          <option value="need_based">Need-Based</option>
                          <option value="merit_and_need">Merit and Need</option>
                          <option value="grant">Grant</option>
                          <option value="fellowship">Fellowship / Graduate</option>
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Funding Frequency *</label>
                        <select
                          value={formFundingFreq} onChange={(e) => setFormFundingFreq(e.target.value as FundingFreq)}
                          className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                        >
                          <option value="Per Semester">Per Semester</option>
                          <option value="Once a Year">Once a Year</option>
                          <option value="One-time">One-time Grant</option>
                        </select>
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Program Description *</label>
                      <textarea
                        required rows={3} placeholder="Describe the scholarship, its goals, and who it supports..."
                        value={formDesc} onChange={(e) => setFormDesc(e.target.value)}
                        className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm resize-none"
                      />
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Renewal Policy</label>
                        <select
                          value={formRenewalPolicy} onChange={(e) => setFormRenewalPolicy(e.target.value as RenewalPolicy)}
                          className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                        >
                          <option value="Semester Renewal">Semester Renewal</option>
                          <option value="No Renewal">No Renewal</option>
                          <option value="Annual Reapplication">Annual Reapplication</option>
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Renewal Min. GWA</label>
                        <input
                          type="number" step="0.01" min="1" max="5" placeholder="e.g. 1.75"
                          value={formRenewalGwa} onChange={(e) => setFormRenewalGwa(e.target.value)}
                          className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Total Slots</label>
                        <input
                          type="number" min="1" placeholder="Leave blank for unlimited"
                          value={formTotalSlots} onChange={(e) => setFormTotalSlots(e.target.value)}
                          className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Total Budget (₱)</label>
                        <input
                          type="number" min="0" placeholder="e.g. 5000000"
                          value={formBudgetTotal} onChange={(e) => setFormBudgetTotal(e.target.value)}
                          className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                        />
                      </div>
                    </div>
                  </div>
                )}

                {/* ─── STEP 2: Benefits & Eligibility ─── */}
                {formModalStep === 2 && (
                  <div className="space-y-5">
                    {/* Benefits */}
                    <div>
                      <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider mb-3">Coverage / Benefits</h4>
                      <div className="space-y-3">
                        <label className="flex items-center gap-3 p-3 rounded-xl border border-[#D9D2C5] cursor-pointer hover:bg-[#F9F5EF]">
                          <input type="checkbox" checked={formCoverstuition} onChange={(e) => setFormCoverstuition(e.target.checked)} className="w-4 h-4 text-[#2D5941] rounded cursor-pointer" />
                          <span className="text-sm font-semibold text-[#1C1C1E]">Full Tuition Coverage</span>
                        </label>
                        <div className="p-3 rounded-xl border border-[#D9D2C5] space-y-2">
                          <label className="flex items-center gap-3 cursor-pointer">
                            <input type="checkbox" checked={formCoversStipend} onChange={(e) => setFormCoversStipend(e.target.checked)} className="w-4 h-4 text-[#2D5941] rounded cursor-pointer" />
                            <span className="text-sm font-semibold text-[#1C1C1E]">Monthly Stipend</span>
                          </label>
                          {formCoversStipend && (
                            <input
                              type="number" min="0" placeholder="Monthly amount in ₱ e.g. 7000"
                              value={formStipendAmount} onChange={(e) => setFormStipendAmount(e.target.value)}
                              className="w-full px-3 py-2 rounded-lg border border-[#D9D2C5] text-xs font-semibold focus:outline-none"
                            />
                          )}
                        </div>
                        <div className="p-3 rounded-xl border border-[#D9D2C5] space-y-2">
                          <label className="flex items-center gap-3 cursor-pointer">
                            <input type="checkbox" checked={formCoversAllowance} onChange={(e) => setFormCoversAllowance(e.target.checked)} className="w-4 h-4 text-[#2D5941] rounded cursor-pointer" />
                            <span className="text-sm font-semibold text-[#1C1C1E]">Living / Book Allowance</span>
                          </label>
                          {formCoversAllowance && (
                            <input
                              type="number" min="0" placeholder="Allowance amount in ₱ e.g. 3000"
                              value={formAllowanceAmount} onChange={(e) => setFormAllowanceAmount(e.target.value)}
                              className="w-full px-3 py-2 rounded-lg border border-[#D9D2C5] text-xs font-semibold focus:outline-none"
                            />
                          )}
                        </div>
                        <div>
                          <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Other Benefits (comma-separated)</label>
                          <input
                            type="text" placeholder="e.g. Research grant, Laptop allowance, Housing subsidy"
                            value={formOtherBenefits} onChange={(e) => setFormOtherBenefits(e.target.value)}
                            className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                          />
                        </div>
                      </div>
                    </div>

                    <div className="border-t border-[#D9D2C5]/50 pt-5">
                      <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wider mb-3">Eligibility Criteria</h4>
                      <div className="space-y-4">
                        {/* Course Eligibility */}
                        <div>
                          <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Eligible Courses (leave empty for all)</label>
                          <div className="flex gap-2">
                            <input
                              type="text" placeholder="e.g. BSCS, BSECE, BSME"
                              value={formCourseInput} onChange={(e) => setFormCourseInput(e.target.value)}
                              onKeyDown={(e) => {
                                if ((e.key === 'Enter' || e.key === ',') && formCourseInput.trim()) {
                                  e.preventDefault();
                                  setFormCourseEligibility(prev => [...prev, formCourseInput.trim()]);
                                  setFormCourseInput('');
                                }
                              }}
                              className="flex-1 px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                            />
                            <button
                              type="button"
                              onClick={() => {
                                if (formCourseInput.trim()) {
                                  setFormCourseEligibility(prev => [...prev, formCourseInput.trim()]);
                                  setFormCourseInput('');
                                }
                              }}
                              className="px-4 py-2.5 bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] rounded-xl text-xs font-bold border-0 cursor-pointer"
                            >+ Add</button>
                          </div>
                          {formCourseEligibility.length > 0 && (
                            <div className="flex flex-wrap gap-2 mt-2">
                              {formCourseEligibility.map((c, i) => (
                                <span key={i} className="flex items-center gap-1.5 text-xs font-bold bg-[#EBF5EE] text-[#2D5941] px-2.5 py-1 rounded-lg">
                                  {c}
                                  <button type="button" onClick={() => setFormCourseEligibility(prev => prev.filter((_, idx) => idx !== i))} className="text-red-400 hover:text-red-600 font-bold border-0 bg-transparent cursor-pointer leading-none">×</button>
                                </span>
                              ))}
                            </div>
                          )}
                        </div>

                        {/* Year Level */}
                        <div>
                          <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Eligible Year Levels (check all that apply)</label>
                          <div className="flex gap-3">
                            {[1, 2, 3, 4, 5].map(yr => (
                              <label key={yr} className="flex items-center gap-1.5 text-xs font-semibold cursor-pointer">
                                <input
                                  type="checkbox"
                                  checked={formYearLevelEligibility.includes(yr)}
                                  onChange={(e) => {
                                    if (e.target.checked) setFormYearLevelEligibility(prev => [...prev, yr].sort());
                                    else setFormYearLevelEligibility(prev => prev.filter(y => y !== yr));
                                  }}
                                  className="w-4 h-4 text-[#2D5941] rounded cursor-pointer"
                                />
                                Year {yr}
                              </label>
                            ))}
                          </div>
                        </div>

                        {/* GWA */}
                        <div>
                          <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Minimum GWA Required</label>
                          <input
                            type="number" step="0.01" min="1" max="5" placeholder="e.g. 1.75 (blank = no minimum)"
                            value={formMinGwa} onChange={(e) => setFormMinGwa(e.target.value)}
                            className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                          />
                        </div>

                        {/* Availability */}
                        <div>
                          <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Geographic Availability</label>
                          <select
                            value={formAvailabilityScope}
                            onChange={(e) => {
                              setFormAvailabilityScope(e.target.value as AvailabilityScope);
                              setSelectedRegionCode('');
                              setSelectedProvinceCode('');
                              setSelectedMunicipalityCode('');
                              setSelectedBarangayCode('');
                              setFormAvailableRegions('');
                              setFormAvailableSchools('');
                            }}
                            className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                          >
                            <option value="nationwide">Nationwide (All regions)</option>
                            <option value="regional">Regional (Specific region only)</option>
                            <option value="provincial">Provincial (Specific province only)</option>
                            <option value="municipality">Town / Municipality (Specific town only)</option>
                            <option value="barangay">Barangay (Specific barangay only)</option>
                            <option value="specific_schools">Specific Schools Only</option>
                          </select>
                        </div>

                        {/* Region Selector */}
                        {(formAvailabilityScope === 'regional' || formAvailabilityScope === 'provincial' || formAvailabilityScope === 'municipality' || formAvailabilityScope === 'barangay') && (
                          <div>
                            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Select Region *</label>
                            <select
                              value={selectedRegionCode}
                              onChange={(e) => {
                                const code = e.target.value;
                                setSelectedRegionCode(code);
                                const regionObj = psgcRegions.find(r => r.code === code);
                                setFormAvailableRegions(regionObj ? regionObj.name : '');
                                setSelectedProvinceCode('');
                                setSelectedMunicipalityCode('');
                                setSelectedBarangayCode('');
                              }}
                              className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white"
                            >
                              <option value="">-- Choose Region --</option>
                              {psgcRegions.map(r => (
                                <option key={r.code} value={r.code}>{r.name}</option>
                              ))}
                            </select>
                          </div>
                        )}

                        {/* Province Selector */}
                        {(formAvailabilityScope === 'provincial' || formAvailabilityScope === 'municipality' || formAvailabilityScope === 'barangay') && (
                          <div>
                            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Select Province *</label>
                            <select
                              value={selectedProvinceCode}
                              disabled={!selectedRegionCode}
                              onChange={(e) => {
                                const code = e.target.value;
                                setSelectedProvinceCode(code);
                                const provObj = psgcProvinces.find(p => p.code === code);
                                setFormAvailableSchools(provObj ? provObj.name : '');
                                setSelectedMunicipalityCode('');
                                setSelectedBarangayCode('');
                              }}
                              className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white disabled:opacity-50"
                            >
                              <option value="">-- Choose Province --</option>
                              {psgcProvinces.map(p => (
                                <option key={p.code} value={p.code}>{p.name}</option>
                              ))}
                            </select>
                          </div>
                        )}

                        {/* Town/Municipality Selector */}
                        {(formAvailabilityScope === 'municipality' || formAvailabilityScope === 'barangay') && (
                          <div>
                            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Select Town / Municipality *</label>
                            <select
                              value={selectedMunicipalityCode}
                              disabled={!selectedProvinceCode}
                              onChange={(e) => {
                                const code = e.target.value;
                                setSelectedMunicipalityCode(code);
                                const munObj = psgcMunicipalities.find(m => m.code === code);
                                setFormAvailableSchools(munObj ? munObj.name : '');
                                setSelectedBarangayCode('');
                              }}
                              className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white disabled:opacity-50"
                            >
                              <option value="">-- Choose Town/Municipality --</option>
                              {psgcMunicipalities.map(m => (
                                <option key={m.code} value={m.code}>{m.name}</option>
                              ))}
                            </select>
                          </div>
                        )}

                        {/* Barangay Selector */}
                        {formAvailabilityScope === 'barangay' && (
                          <div>
                            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Select Barangay *</label>
                            <select
                              value={selectedBarangayCode}
                              disabled={!selectedMunicipalityCode}
                              onChange={(e) => {
                                const code = e.target.value;
                                setSelectedBarangayCode(code);
                                const brgyObj = psgcBarangays.find(b => b.code === code);
                                setFormAvailableSchools(brgyObj ? brgyObj.name : '');
                              }}
                              className="w-full px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold cursor-pointer bg-white disabled:opacity-50"
                            >
                              <option value="">-- Choose Barangay --</option>
                              {psgcBarangays.map(b => (
                                <option key={b.code} value={b.code}>{b.name}</option>
                              ))}
                            </select>
                          </div>
                        )}

                        {formAvailabilityScope === 'specific_schools' && (
                          <div>
                            <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Eligible Schools (comma-separated) *</label>
                            <input
                              type="text"
                              placeholder="e.g. UP Diliman, DLSU Manila, Ateneo"
                              value={formAvailableSchools} onChange={(e) => setFormAvailableSchools(e.target.value)}
                              className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                            />
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                )}

                {/* ─── STEP 3: Application Requirements ─── */}
                {formModalStep === 3 && (
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h4 className="text-sm font-bold text-[#1C1C1E]">Document Requirements</h4>
                        <p className="text-xs text-[#6C6C70] mt-0.5">Add the documents scholars must submit when applying.</p>
                      </div>
                    </div>

                    {/* Existing requirements */}
                    <div className="space-y-2">
                      {formRequirements.map((req, idx) => (
                        <div key={idx} className="flex items-start gap-3 p-3.5 rounded-xl border border-[#D9D2C5]/70 bg-[#F9F5EF]/50">
                          <div className="flex-1">
                            <div className="flex items-center gap-2">
                              <span className="text-sm font-bold text-[#1C1C1E]">{req.name}</span>
                              {req.required
                                ? <span className="text-[9px] bg-red-50 text-red-600 font-bold px-1.5 py-0.5 rounded border border-red-200">REQUIRED</span>
                                : <span className="text-[9px] bg-slate-100 text-slate-500 font-bold px-1.5 py-0.5 rounded">OPTIONAL</span>
                              }
                            </div>
                            <p className="text-xs text-[#6C6C70] mt-0.5">{req.description}</p>
                          </div>
                          <button
                            type="button"
                            onClick={() => setFormRequirements(prev => prev.filter((_, i) => i !== idx))}
                            className="text-red-400 hover:text-red-600 font-bold text-base border-0 bg-transparent cursor-pointer shrink-0"
                          >×</button>
                        </div>
                      ))}
                    </div>

                    {/* Add new requirement */}
                    <div className="p-4 rounded-2xl border border-dashed border-[#2D5941]/30 bg-[#EBF5EE]/30 space-y-3">
                      <h5 className="text-xs font-bold text-[#2D5941] uppercase tracking-wide">+ Add New Requirement</h5>
                      <div className="grid grid-cols-2 gap-3">
                        <input
                          type="text" placeholder="Requirement name"
                          value={formReqName} onChange={(e) => setFormReqName(e.target.value)}
                          className="px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold"
                        />
                        <input
                          type="text" placeholder="Short description"
                          value={formReqDesc} onChange={(e) => setFormReqDesc(e.target.value)}
                          className="px-3 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-xs font-semibold"
                        />
                      </div>
                      <div className="flex items-center justify-between">
                        <label className="flex items-center gap-2 text-xs font-semibold cursor-pointer">
                          <input
                            type="checkbox" checked={formReqRequired} onChange={(e) => setFormReqRequired(e.target.checked)}
                            className="w-4 h-4 text-[#2D5941] rounded cursor-pointer"
                          />
                          Mark as Required
                        </label>
                        <button
                          type="button"
                          onClick={() => {
                            if (!formReqName.trim()) return;
                            setFormRequirements(prev => [...prev, { name: formReqName.trim(), description: formReqDesc.trim(), required: formReqRequired }]);
                            setFormReqName('');
                            setFormReqDesc('');
                            setFormReqRequired(true);
                          }}
                          className="px-4 py-2 bg-[#2D5941] hover:bg-[#1A3C2E] text-white rounded-xl text-xs font-bold border-0 cursor-pointer transition-all"
                        >Add Requirement</button>
                      </div>
                    </div>
                  </div>
                )}

                {/* ─── STEP 4: Application Cycle ─── */}
                {formModalStep === 4 && (
                  <div className="space-y-4">
                    <div>
                      <h4 className="text-sm font-bold text-[#1C1C1E]">Initial Application Cycle</h4>
                      <p className="text-xs text-[#6C6C70] mt-0.5">Set the first cycle's name and application window. You can add more cycles after creation.</p>
                    </div>

                    <div>
                      <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Cycle Name *</label>
                      <input
                        type="text" required placeholder="e.g. AY 2026-2027"
                        value={formCycleName} onChange={(e) => setFormCycleName(e.target.value)}
                        className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm"
                      />
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Application Start Date *</label>
                        <input
                          type="date" required
                          value={formCycleStartDate} onChange={(e) => setFormCycleStartDate(e.target.value)}
                          className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm cursor-pointer"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">Application End Date *</label>
                        <input
                          type="date" required
                          value={formCycleEndDate} onChange={(e) => setFormCycleEndDate(e.target.value)}
                          min={formCycleStartDate}
                          className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] focus:outline-none text-sm cursor-pointer"
                        />
                      </div>
                    </div>

                    {/* Preview summary */}
                    <div className="bg-[#F9F5EF] rounded-2xl border border-[#D9D2C5]/50 p-5 space-y-3">
                      <h5 className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wider">Program Summary</h5>
                      <div className="grid grid-cols-2 gap-x-6 gap-y-2 text-xs">
                        <div><span className="text-[#6C6C70]">Title: </span><span className="font-semibold text-[#1C1C1E]">{formTitle || '—'}</span></div>
                        <div><span className="text-[#6C6C70]">Category: </span><span className="font-semibold text-[#1C1C1E]">{formCategory}</span></div>
                        <div><span className="text-[#6C6C70]">Type: </span><span className="font-semibold text-[#1C1C1E] capitalize">{formScholarshipType.replace('_', ' ')}</span></div>
                        <div><span className="text-[#6C6C70]">Funding: </span><span className="font-semibold text-[#1C1C1E]">{formFundingFreq}</span></div>
                        <div><span className="text-[#6C6C70]">Renewal: </span><span className="font-semibold text-[#1C1C1E]">{formRenewalPolicy}</span></div>
                        <div><span className="text-[#6C6C70]">Availability: </span><span className="font-semibold text-[#1C1C1E] capitalize">{formAvailabilityScope}</span></div>
                        <div><span className="text-[#6C6C70]">Slots: </span><span className="font-semibold text-[#1C1C1E]">{formTotalSlots || 'Unlimited'}</span></div>
                        <div><span className="text-[#6C6C70]">Budget: </span><span className="font-semibold text-[#1C1C1E]">{formBudgetTotal ? `₱${Number(formBudgetTotal).toLocaleString()}` : '—'}</span></div>
                        <div><span className="text-[#6C6C70]">Min GWA: </span><span className="font-semibold text-[#1C1C1E]">{formMinGwa || 'None'}</span></div>
                        <div><span className="text-[#6C6C70]">Requirements: </span><span className="font-semibold text-[#1C1C1E]">{formRequirements.length} docs</span></div>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* Modal Footer */}
              <div className="px-8 pb-7 flex gap-3 justify-between border-t border-[#D9D2C5]/40 pt-5">
                <button
                  type="button"
                  onClick={() => setFormModalStep(s => Math.max(1, s - 1))}
                  disabled={formModalStep === 1}
                  className="px-6 py-2.5 rounded-xl border border-solid border-[#D9D2C5] text-[#6C6C70] text-xs font-bold cursor-pointer bg-transparent hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  ← Back
                </button>
                {formModalStep < 4 ? (
                  <button
                    type="button"
                    onClick={(e) => { e.preventDefault(); setFormModalStep(s => Math.min(4, s + 1)); }}
                    className="px-8 py-2.5 bg-[#2D5941] hover:bg-[#1A3C2E] text-white rounded-xl text-xs font-bold border-0 cursor-pointer transition-all"
                  >
                    Next →
                  </button>
                ) : (
                  <button type="submit" className="px-8 py-2.5 bg-[#1A3C2E] hover:bg-[#0f2a1d] text-white rounded-xl text-xs font-bold border-0 cursor-pointer transition-all shadow-md">
                    {isEditMode ? '💾 Save & Update Program' : '🎓 Create Scholarship Program'}
                  </button>
                )}
              </div>
            </form>
          </div>
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

      {/* Large Map Selector Modal */}
      {isBigMapModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
          <div className="bg-white rounded-3xl border border-[#D9D2C5] shadow-2xl p-6 max-w-4xl w-full space-y-4 relative animate-fade-in">
            <button 
              type="button"
              onClick={() => setIsBigMapModalOpen(false)} 
              className="absolute top-6 right-6 text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-lg cursor-pointer bg-transparent border-0"
            >
              ✕
            </button>
            <h3 className="text-2xl font-bold font-serif text-[#1A3C2E]">Select Exam Center Location</h3>
            <p className="text-xs text-[#6C6C70]">Search for the venue or click anywhere directly on the map to automatically pin and extract coordinates and address details.</p>

            <div className="space-y-3">
              {isLoaded ? (
                <Autocomplete
                  onLoad={onAutocompleteLoad}
                  onPlaceChanged={onPlaceChanged}
                >
                  <input
                    type="text"
                    placeholder="Search venue e.g. UP Diliman Examination Hall..."
                    value={mapSearchText}
                    onChange={(e) => setMapSearchText(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-sm font-semibold bg-white focus:outline-none focus:border-[#2D5941]"
                  />
                </Autocomplete>
              ) : (
                <div className="text-xs font-medium text-[#6C6C70]">Loading search script...</div>
              )}

              <div className="w-full h-96 rounded-2xl border border-[#D9D2C5] overflow-hidden relative shadow-inner bg-slate-100">
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
                  <div className="w-full h-full flex items-center justify-center text-sm font-semibold text-[#6C6C70]">
                    Loading Live Google Maps...
                  </div>
                )}
              </div>

              <div className="flex justify-between items-center text-xs bg-[#F9F5EF] p-3 rounded-xl border border-[#D9D2C5]/50">
                <span className="font-medium text-[#6C6C70]">
                  <strong>Pinned Coordinates:</strong> {examCoords.lat.toFixed(6)}° N, {examCoords.lng.toFixed(6)}° E
                </span>
                <span className="font-medium text-[#1A3C2E] max-w-md truncate">
                  <strong>Address:</strong> {examCoords.address}
                </span>
              </div>
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <button 
                type="button" 
                onClick={() => setIsBigMapModalOpen(false)}
                className="px-5 py-2.5 rounded-xl border border-solid border-[#D9D2C5] hover:bg-slate-50 text-xs font-bold cursor-pointer text-[#6C6C70] bg-transparent"
              >
                Cancel
              </button>
              <button 
                type="button" 
                onClick={() => setIsBigMapModalOpen(false)}
                className="px-6 py-2.5 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold cursor-pointer border-0"
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

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto p-10 max-w-7xl mx-auto">
        {activeTab === 'dashboard' && (
          <ProviderDashboardTab
            programsList={programsList}
            scholarsList={scholarsList}
            applicantsList={applicantsList}
            totalCredited={totalCredited}
            totalPending={totalPending}
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
            handleUpdateStatus={handleUpdateStatus}
          />
        )}

        {activeTab === 'programs' && (
          <ProviderProgramsTab
            providerDetails={providerDetails}
            programsList={programsList}
            showToast={showToast}
            setIsCreateModalOpen={(open) => open ? handleOpenCreateProgram() : setIsCreateModalOpen(false)}
            setActiveTab={setActiveTab}
            handleViewDetails={handleViewDetails}
            handleEditProgram={handleEditProgram}
            handleOpenRenewModal={handleOpenRenewModal}
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
          />
        )}

        {activeTab === 'announcements' && (
          <ProviderAnnouncementsTab
            handleAddAnnouncement={handleAddAnnouncement}
            newAnnType={newAnnType}
            setNewAnnType={setNewAnnType}
            newAnnAudience={newAnnAudience}
            setNewAnnAudience={setNewAnnAudience}
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
          />
        )}

        {activeTab === 'reports' && <ProviderReportsTab />}

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
                      <span className="font-bold text-[#1C1C1E]">{cyc.name}</span>
                      <div className="flex items-center gap-3">
                        <span className="text-[#8E8E93]">{cyc.startDate} → {cyc.endDate}</span>
                        <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${cyc.status === 'Open' ? 'bg-[#EBF5EE] text-[#2D5941]' : cyc.status === 'Evaluating' ? 'bg-amber-100 text-amber-700' : cyc.status === 'Upcoming' ? 'bg-blue-50 text-blue-600' : 'bg-gray-200 text-gray-600'}`}>{cyc.status}</span>
                        <button
                          onClick={() => handleDeleteCycle(cyc.id.toString(), cyc.name)}
                          className="p-1 text-red-500 hover:text-red-700 hover:bg-red-50 rounded bg-transparent border-0 cursor-pointer transition-all text-xs leading-none"
                          title="Delete Cycle"
                        >
                          🗑️
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
        onClose={() => { setIsRenewModalOpen(false); setSelectedProgramForRenewal(null); }}
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

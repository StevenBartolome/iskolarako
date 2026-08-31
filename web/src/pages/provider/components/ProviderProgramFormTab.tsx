import React, { useState, useEffect, useMemo } from 'react';
import type { Program, EducationLevel, GradingSystem, ProgramRequirement } from '../types';
import {
  YEAR_LEVELS_BY_EDUCATION_LEVEL,
  SHS_STRANDS,
  CHED_COLLEGE_COURSES,
  TESDA_TVET_COURSES,
  parseYearLevelsToNumbers,
  getYearLevelLabel,
} from '../constants/academicCatalog';
import {
  getPSGCRegions,
  getPSGCProvinces,
  getPSGCCitiesMunicipalities,
  getPSGCBarangays,
  type PSGCRegion,
  type PSGCProvince,
  type PSGCCityMunicipality,
  type PSGCBarangay,
} from '@/services/psgcLocationService';

interface ProviderProgramFormTabProps {
  programToEdit?: Program | null;
  selectedCycleId?: string | null;
  onCancel: () => void;
  onSubmit: (formData: any, isEditMode: boolean) => Promise<void>;
  providerDetails?: any;
}

const normalizeCategory = (cat?: string): string => {
  if (!cat) return 'Merit-Based';
  const lower = cat.toLowerCase();
  if ((lower.includes('need') && lower.includes('merit')) || lower.includes('both')) {
    return 'Both Merit and Need';
  }
  if (lower.includes('need')) {
    return 'Need-Based';
  }
  return 'Merit-Based';
};

const isIncomeProofRequirement = (req: ProgramRequirement | string): boolean => {
  const name = (typeof req === 'string' ? req : req.name || '').toLowerCase();
  const desc = (typeof req === 'string' ? '' : req.description || '').toLowerCase();
  const keywords = ['income', 'indigency', 'itr', 'payslip', 'tax return', 'bir 2316', 'low income', 'financial need', 'certificate of indigency', 'proof of income'];
  return keywords.some(kw => name.includes(kw) || desc.includes(kw));
};

const isNeedBasedCategory = (cat: string): boolean => {
  const lower = (cat || '').toLowerCase();
  return lower.includes('need');
};

export const ProviderProgramFormTab: React.FC<ProviderProgramFormTabProps> = ({
  programToEdit,
  selectedCycleId,
  onCancel,
  onSubmit,
}) => {
  const isEditMode = Boolean(programToEdit);

  // Form step state (1 to 5)
  const [currentStep, setCurrentStep] = useState(1);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Step 1: Basic Info
  const [title, setTitle] = useState(programToEdit?.title || '');
  const [category, setCategory] = useState(() =>
    normalizeCategory(programToEdit?.category || programToEdit?.scholarship_type || (programToEdit as any)?.scholarshipType)
  );
  const [targetLevel, setTargetLevel] = useState<EducationLevel>(
    programToEdit?.target_education_level || programToEdit?.targetEducationLevel || 'college'
  );
  const [description, setDescription] = useState(programToEdit?.description || '');

  // Step 1: Application Intake Period (Opening & Closing Dates)
  const defaultStartDate = new Date().toISOString().split('T')[0];
  const defaultEndDate = new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString().split('T')[0];
  const openCycles = (programToEdit?.cycles || []).filter((c: any) => (c.status || '').toLowerCase() === 'open');
  const initialCycle = selectedCycleId
    ? programToEdit?.cycles?.find((c: any) => c.id === selectedCycleId)
    : (openCycles.length > 0 ? openCycles[0] : (programToEdit?.cycles && programToEdit.cycles.length > 0 ? programToEdit.cycles[0] : null));

  const [cycleName, setCycleName] = useState(
    initialCycle?.name || `AY ${new Date().getFullYear()}-${new Date().getFullYear() + 1}`
  );
  const [applicationStartDate, setApplicationStartDate] = useState(
    initialCycle?.startDate || defaultStartDate
  );
  const [applicationEndDate, setApplicationEndDate] = useState(
    initialCycle?.endDate || defaultEndDate
  );

  // Freshmen specifics
  const [allowFreshmanIntendedSchool, setAllowFreshmanIntendedSchool] = useState<boolean>(
    programToEdit?.allow_freshman_intended_school ?? true
  );

  // Step 2: Financial Benefits
  const [amount, setAmount] = useState(
    programToEdit?.budget_total || programToEdit?.amount || programToEdit?.budgetTotal
      ? String(programToEdit.budget_total || programToEdit.amount || programToEdit.budgetTotal).replace(/[^0-9.]/g, '')
      : ''
  );
  const [fundingFreq, setFundingFreq] = useState(() => {
    const raw = programToEdit?.funding_frequency || programToEdit?.fundingFrequency || 'Per Semester';
    if (raw === 'Annual') return 'Once a Year';
    if (raw === 'One-Time Grant') return 'One-time';
    return raw;
  });
  const [totalSlots, setTotalSlots] = useState(
    programToEdit?.total_slots || programToEdit?.totalSlots ? String(programToEdit.total_slots || programToEdit.totalSlots) : ''
  );
  const [coversTuition, setCoversTuition] = useState<boolean>(
    programToEdit?.covers_tuition ?? programToEdit?.coverstuition ?? false
  );
  const [coversStipend, setCoversStipend] = useState<boolean>(
    programToEdit?.covers_stipend ?? programToEdit?.coversStipend ?? false
  );
  const [stipendAmount, setStipendAmount] = useState(
    programToEdit?.stipend_amount || programToEdit?.stipendAmount || ''
  );
  const [coversAllowance, setCoversAllowance] = useState<boolean>(
    programToEdit?.covers_allowance ?? programToEdit?.coversAllowance ?? false
  );
  const [allowanceAmount, setAllowanceAmount] = useState(
    programToEdit?.allowance_amount || programToEdit?.allowanceAmount || ''
  );
  const [otherBenefits, setOtherBenefits] = useState(
    Array.isArray(programToEdit?.other_benefits)
      ? programToEdit.other_benefits.join(', ')
      : (programToEdit?.otherBenefits || '')
  );

  // Tuition & Budget Allocation Modes
  const [disbursementMode, setDisbursementMode] = useState<'online_transfer' | 'in_person_cash'>(() => {
    const mode = String(programToEdit?.disbursement_mode || programToEdit?.disbursementMode || '').toLowerCase();
    return (mode === 'in_person_cash' || mode === 'cash' || mode.includes('cash')) ? 'in_person_cash' : 'online_transfer';
  });
  const [onlineBankType, setOnlineBankType] = useState<'personal_bank' | 'provider_issued_card'>(() => {
    const bankPol = String(programToEdit?.banking_policy || programToEdit?.bankingPolicy || programToEdit?.online_bank_type || programToEdit?.onlineBankType || '').toLowerCase();
    return (bankPol === 'provider_issued' || bankPol === 'provider_issued_card' || bankPol.includes('provider')) ? 'provider_issued_card' : 'personal_bank';
  });

  useEffect(() => {
    if (programToEdit) {
      const mode = String(programToEdit.disbursement_mode || programToEdit.disbursementMode || '').toLowerCase();
      const isCash = mode === 'in_person_cash' || mode === 'cash' || mode.includes('cash');
      setDisbursementMode(isCash ? 'in_person_cash' : 'online_transfer');

      const bankPol = String(programToEdit.banking_policy || programToEdit.bankingPolicy || programToEdit.online_bank_type || programToEdit.onlineBankType || '').toLowerCase();
      const isCard = bankPol === 'provider_issued' || bankPol === 'provider_issued_card' || bankPol.includes('provider');
      setOnlineBankType(isCard ? 'provider_issued_card' : 'personal_bank');
    }
  }, [programToEdit]);
  const [tuitionPayoutMode, setTuitionPayoutMode] = useState<'direct_to_student' | 'direct_to_school_off_system'>(
    programToEdit?.tuition_payout_mode || 'direct_to_student'
  );
  const [tuitionCoverageType, setTuitionCoverageType] = useState<'fixed_cap' | 'actual_matriculation'>(
    programToEdit?.tuition_coverage_type || 'fixed_cap'
  );
  const [tuitionMaxAmount, setTuitionMaxAmount] = useState(
    programToEdit?.tuition_max_amount ? String(programToEdit.tuition_max_amount) : ''
  );
  const [customBenefitsList, setCustomBenefitsList] = useState<{ title: string; amount: string; frequency: string }[]>(() => {
    if (Array.isArray(programToEdit?.custom_benefits)) {
      return programToEdit.custom_benefits.map((b: any) => ({
        title: b.title || b.name || '',
        amount: String(b.amount || ''),
        frequency: b.frequency || 'Per Semester',
      }));
    }
    return [];
  });
  const [newBenefitTitle, setNewBenefitTitle] = useState('');
  const [newBenefitAmount, setNewBenefitAmount] = useState('');
  const [newBenefitFreq, setNewBenefitFreq] = useState('Per Semester');

  const [lowBudgetThreshold, setLowBudgetThreshold] = useState(
    programToEdit?.low_budget_threshold ? String(Number(programToEdit.low_budget_threshold) * 100) : '20'
  );

  // Step 3: Eligibility & Grading
  const [gradingSystem] = useState<GradingSystem>('percentage');
  const [gpaRequirement, setGpaRequirement] = useState(
    programToEdit?.gpa_requirement || programToEdit?.minimum_gwa || programToEdit?.minimumGwa
      ? String(programToEdit.gpa_requirement || programToEdit.minimum_gwa || programToEdit.minimumGwa)
      : ''
  );

  // Dynamic Year Levels State (stored as numbers [1, 2, 3...] for Postgres integer[] column)
  const [selectedYearLevels, setSelectedYearLevels] = useState<number[]>(() => {
    const raw =
      programToEdit?.year_level_eligibility ??
      programToEdit?.yearLevelEligibility ??
      programToEdit?.eligible_year_levels;
    const parsed = parseYearLevelsToNumbers(raw);
    if (parsed.length > 0) return parsed;
    // Don't preselect all years by default when creating a brand new program
    return [];
  });

  // Dynamic Eligible Courses / Strands State
  const [isOpenToAllCourses, setIsOpenToAllCourses] = useState<boolean>(() => {
    const raw =
      programToEdit?.course_eligibility ??
      programToEdit?.courseEligibility ??
      programToEdit?.eligible_courses;
    if (!raw || (Array.isArray(raw) && raw.length === 0)) return true;
    if (Array.isArray(raw) && raw.some(c => typeof c === 'string' && (c.toLowerCase().includes('all course') || c.toLowerCase().includes('all strand') || c.toLowerCase().includes('all degree') || c === 'All'))) {
      return true;
    }
    if (typeof raw === 'string' && (raw.toLowerCase().includes('all course') || raw.toLowerCase().includes('all strand') || raw.toLowerCase().includes('all degree') || raw.trim() === 'All')) {
      return true;
    }
    return false;
  });

  const [selectedCourses, setSelectedCourses] = useState<string[]>(() => {
    const raw =
      programToEdit?.course_eligibility ??
      programToEdit?.courseEligibility ??
      programToEdit?.eligible_courses;
    if (Array.isArray(raw)) {
      return raw.filter(c => typeof c === 'string' && !c.toLowerCase().includes('all course') && !c.toLowerCase().includes('all strand') && !c.toLowerCase().includes('all degree'));
    }
    if (typeof raw === 'string' && raw.trim()) {
      return raw.split(',').map(s => s.trim()).filter(s => !s.toLowerCase().includes('all course') && !s.toLowerCase().includes('all strand') && !s.toLowerCase().includes('all degree'));
    }
    return [];
  });

  const [courseSearchTerm, setCourseSearchTerm] = useState('');
  const [selectedCourseCategory, setSelectedCourseCategory] = useState<string>('All');
  const [customCourseInput, setCustomCourseInput] = useState('');
  const [customStrandInput, setCustomStrandInput] = useState('');

  // Target Geographic Location & Scope State
  const [availabilityScope, setAvailabilityScope] = useState<string>(
    programToEdit?.availability_scope || programToEdit?.availabilityScope || 'nationwide'
  );
  const [availableRegions, setAvailableRegions] = useState<string[]>(() => {
    const r = programToEdit?.available_regions || programToEdit?.availableRegions || programToEdit?.eligible_regions;
    if (Array.isArray(r)) return r.map(String);
    if (typeof r === 'string' && r) return r.split(',').map(s => s.trim()).filter(Boolean);
    return [];
  });
  const [availableProvinces, setAvailableProvinces] = useState<string[]>(() => {
    const p = programToEdit?.available_provinces || programToEdit?.availableProvinces;
    if (Array.isArray(p)) return p.map(String);
    if (typeof p === 'string' && p) return p.split(',').map(s => s.trim()).filter(Boolean);
    return [];
  });
  const [availableMunicipalities, setAvailableMunicipalities] = useState<string[]>(() => {
    const m = programToEdit?.available_municipalities || programToEdit?.availableMunicipalities;
    if (Array.isArray(m)) return m.map(String);
    if (typeof m === 'string' && m) return m.split(',').map(s => s.trim()).filter(Boolean);
    return [];
  });
  const [availableBarangays, setAvailableBarangays] = useState<string[]>(() => {
    const b = programToEdit?.available_barangays || programToEdit?.availableBarangays;
    if (Array.isArray(b)) return b.map(String);
    if (typeof b === 'string' && b) return b.split(',').map(s => s.trim()).filter(Boolean);
    return [];
  });
  const [availableSchools, setAvailableSchools] = useState<string[]>(() => {
    const s = programToEdit?.available_schools || programToEdit?.availableSchools;
    if (Array.isArray(s)) return s.map(String);
    if (typeof s === 'string' && s) return s.split(',').map(s => s.trim()).filter(Boolean);
    return [];
  });

  // PSGC Location API State
  const [psgcRegions, setPsgcRegions] = useState<PSGCRegion[]>([]);
  const [psgcProvinces, setPsgcProvinces] = useState<PSGCProvince[]>([]);
  const [psgcCities, setPsgcCities] = useState<PSGCCityMunicipality[]>([]);
  const [psgcBarangays, setPsgcBarangays] = useState<PSGCBarangay[]>([]);
  const [loadingPsgc, setLoadingPsgc] = useState<boolean>(false);
  const [psgcSearchTerm, setPsgcSearchTerm] = useState<string>('');

  // Step Validation Error State
  const [stepValidationError, setStepValidationError] = useState<string>('');

  const validateStep = (stepNum: number): { valid: boolean; error: string } => {
    if (stepNum === 1) {
      if (!title.trim()) {
        return { valid: false, error: '⚠️ Step 1 Required: Program Title cannot be empty.' };
      }
      if (!description.trim()) {
        return { valid: false, error: '⚠️ Step 1 Required: Program Description & Overview cannot be empty.' };
      }
      if (!applicationStartDate) {
        return { valid: false, error: '⚠️ Step 1 Required: Application Intake Start Date is required.' };
      }
      if (!applicationEndDate) {
        return { valid: false, error: '⚠️ Step 1 Required: Application Closing Deadline is required.' };
      }
      if (new Date(applicationEndDate) < new Date(applicationStartDate)) {
        return { valid: false, error: '⚠️ Step 1 Error: Application Closing Deadline cannot be earlier than Start Date.' };
      }
    }

    if (stepNum === 2) {
      if (!amount.trim() || isNaN(Number(amount)) || Number(amount) <= 0) {
        return { valid: false, error: '⚠️ Step 2 Required: Please enter a valid Grant Budget Allocation Amount (must be greater than ₱0).' };
      }
      if (coversTuition && tuitionCoverageType === 'fixed_cap' && (!tuitionMaxAmount.trim() || isNaN(Number(tuitionMaxAmount)) || Number(tuitionMaxAmount) <= 0)) {
        return { valid: false, error: '⚠️ Step 2 Required: Please specify the Maximum Tuition Subsidy Cap Amount.' };
      }
      if (coversStipend && (!stipendAmount.toString().trim() || isNaN(Number(stipendAmount)) || Number(stipendAmount) <= 0)) {
        return { valid: false, error: '⚠️ Step 2 Required: Please specify the Stipend / Allowance Amount.' };
      }
      if (coversAllowance && (!allowanceAmount.toString().trim() || isNaN(Number(allowanceAmount)) || Number(allowanceAmount) <= 0)) {
        return { valid: false, error: '⚠️ Step 2 Required: Please specify the Book/Device Allowance Amount.' };
      }
    }

    if (stepNum === 3) {
      if (!gpaRequirement.toString().trim()) {
        return { valid: false, error: '⚠️ Step 3 Required: Please enter the Minimum GWA / GPA Requirement (e.g. 85, 2.0, or N/A).' };
      }
      if (selectedYearLevels.length === 0) {
        return { valid: false, error: '⚠️ Step 3 Required: Please select at least one eligible year level for applicants.' };
      }
      if (!isOpenToAllCourses && selectedCourses.length === 0 && (targetLevel === 'college' || targetLevel === 'incoming_college' || targetLevel === 'senior_high' || targetLevel === 'vocational' || targetLevel === 'graduate')) {
        return { valid: false, error: '⚠️ Step 3 Required: Please select at least one target course/strand or toggle to "Open to All Degree Programs".' };
      }
    }

    if (stepNum === 4) {
      if (requirementsList.length === 0) {
        return { valid: false, error: '⚠️ Step 4 Required: Please include at least one document requirement for applicant submission.' };
      }
      if (isNeedBasedCategory(category)) {
        const hasMandatoryIncomeProof = requirementsList.some(
          r => isIncomeProofRequirement(r) && (typeof r === 'string' || r.required !== false)
        );
        if (!hasMandatoryIncomeProof) {
          return {
            valid: false,
            error: '⚠️ Step 4 Required: For Need-Based scholarships, Proof of Income / Certificate of Indigency is mandatory and must be marked as required in the document requirements checklist.',
          };
        }
      }
    }

    return { valid: true, error: '' };
  };

  const handleGoToStep = (targetStep: number) => {
    if (targetStep < currentStep) {
      setStepValidationError('');
      setCurrentStep(targetStep);
      return;
    }

    for (let s = 1; s < targetStep; s++) {
      const check = validateStep(s);
      if (!check.valid) {
        setStepValidationError(check.error);
        setCurrentStep(s);
        return;
      }
    }

    setStepValidationError('');
    setCurrentStep(targetStep);
  };

  // Cascading Filter Selection State for PSGC Dropdowns
  const [selectedPsgcRegionCode, setSelectedPsgcRegionCode] = useState<string>('');
  const [selectedPsgcProvinceCode, setSelectedPsgcProvinceCode] = useState<string>('');
  const [selectedPsgcCityCode, setSelectedPsgcCityCode] = useState<string>('');

  // Fetch PSGC Regions & Initial Provinces on mount
  React.useEffect(() => {
    let isMounted = true;
    async function loadInitialPsgcData() {
      setLoadingPsgc(true);
      try {
        const [regions, provinces] = await Promise.all([
          getPSGCRegions(),
          getPSGCProvinces(),
        ]);
        if (isMounted) {
          setPsgcRegions(regions);
          setPsgcProvinces(provinces);
        }
      } catch (err) {
        console.warn('Error fetching PSGC API location data:', err);
      } finally {
        if (isMounted) setLoadingPsgc(false);
      }
    }
    loadInitialPsgcData();
    return () => { isMounted = false; };
  }, []);

  // When selectedPsgcRegionCode changes, load filtered provinces
  React.useEffect(() => {
    let isMounted = true;
    async function loadProvincesForRegion() {
      if (!selectedPsgcRegionCode) {
        const all = await getPSGCProvinces();
        if (isMounted) setPsgcProvinces(all);
        return;
      }
      try {
        const filteredProvinces = await getPSGCProvinces(selectedPsgcRegionCode);
        if (isMounted) setPsgcProvinces(filteredProvinces);
      } catch (err) {
        console.warn('Error loading PSGC provinces for region:', err);
      }
    }
    loadProvincesForRegion();
    return () => { isMounted = false; };
  }, [selectedPsgcRegionCode]);

  // When selectedPsgcProvinceCode changes, load cities/municipalities
  React.useEffect(() => {
    let isMounted = true;
    async function loadCitiesForProvince() {
      if (!selectedPsgcProvinceCode) {
        setPsgcCities([]);
        return;
      }
      try {
        const cities = await getPSGCCitiesMunicipalities(selectedPsgcProvinceCode);
        if (isMounted) setPsgcCities(cities);
      } catch (err) {
        console.warn('Error loading PSGC cities for province:', err);
      }
    }
    loadCitiesForProvince();
    return () => { isMounted = false; };
  }, [selectedPsgcProvinceCode]);

  // When selectedPsgcCityCode changes, load barangays
  React.useEffect(() => {
    let isMounted = true;
    async function loadBarangaysForCity() {
      if (!selectedPsgcCityCode) {
        setPsgcBarangays([]);
        return;
      }
      try {
        const barangays = await getPSGCBarangays(selectedPsgcCityCode);
        if (isMounted) setPsgcBarangays(barangays);
      } catch (err) {
        console.warn('Error loading PSGC barangays for city:', err);
      }
    }
    loadBarangaysForCity();
    return () => { isMounted = false; };
  }, [selectedPsgcCityCode]);

  // Re-sync on programToEdit change so editing an existing program always pre-selects its saved values
  React.useEffect(() => {
    if (programToEdit) {
      const normalizedCat = normalizeCategory(programToEdit.category || programToEdit.scholarship_type || (programToEdit as any)?.scholarshipType);
      setTitle(programToEdit.title || '');
      setCategory(normalizedCat);
      const lvl = (programToEdit.target_education_level || programToEdit.targetEducationLevel || 'college') as EducationLevel;
      setTargetLevel(lvl);
      setDescription(programToEdit.description || '');
      setAmount(
        programToEdit.budget_total || programToEdit.amount || programToEdit.budgetTotal
          ? String(programToEdit.budget_total || programToEdit.amount || programToEdit.budgetTotal).replace(/[^0-9.]/g, '')
          : ''
      );
      const rawFreq = programToEdit.funding_frequency || programToEdit.fundingFrequency || 'Per Semester';
      const normalizedFreq = rawFreq === 'Annual' ? 'Once a Year' : rawFreq === 'One-Time Grant' ? 'One-time' : rawFreq;
      setFundingFreq(normalizedFreq);
      setTotalSlots(
        programToEdit.total_slots || programToEdit.totalSlots ? String(programToEdit.total_slots || programToEdit.totalSlots) : ''
      );
      setCoversTuition(programToEdit.covers_tuition ?? programToEdit.coverstuition ?? false);
      setCoversStipend(programToEdit.covers_stipend ?? programToEdit.coversStipend ?? false);
      setStipendAmount(programToEdit.stipend_amount || programToEdit.stipendAmount || '');
      setCoversAllowance(programToEdit.covers_allowance ?? programToEdit.coversAllowance ?? false);
      setAllowanceAmount(programToEdit.allowance_amount || programToEdit.allowanceAmount || '');
      setOtherBenefits(
        Array.isArray(programToEdit.other_benefits)
          ? programToEdit.other_benefits.join(', ')
          : (programToEdit.otherBenefits || '')
      );
      setGpaRequirement(
        programToEdit.gpa_requirement || programToEdit.minimum_gwa || programToEdit.minimumGwa
          ? String(programToEdit.gpa_requirement || programToEdit.minimum_gwa || programToEdit.minimumGwa)
          : ''
      );

      // Sync tuition modes, custom benefits & budget threshold
      setTuitionPayoutMode(programToEdit.tuition_payout_mode || 'direct_to_student');
      setTuitionCoverageType(programToEdit.tuition_coverage_type || 'fixed_cap');
      setTuitionMaxAmount(
        programToEdit.tuition_max_amount ? String(programToEdit.tuition_max_amount) : ''
      );
      if (Array.isArray(programToEdit.custom_benefits)) {
        setCustomBenefitsList(
          programToEdit.custom_benefits.map((b: any) => ({
            title: b.title || b.name || '',
            amount: String(b.amount || ''),
            frequency: b.frequency || 'Per Semester',
          }))
        );
      } else {
        setCustomBenefitsList([]);
      }
      setLowBudgetThreshold(
        programToEdit.low_budget_threshold ? String(Number(programToEdit.low_budget_threshold) * 100) : '20'
      );

      // Pre-select the existing year levels when editing
      const rawYears =
        programToEdit.year_level_eligibility ??
        programToEdit.yearLevelEligibility ??
        programToEdit.eligible_year_levels;
      const parsedYears = parseYearLevelsToNumbers(rawYears);
      setSelectedYearLevels(parsedYears);

      // Pre-select existing courses / strands
      const rawCourses =
        programToEdit.course_eligibility ??
        programToEdit.courseEligibility ??
        programToEdit.eligible_courses;
      if (!rawCourses || (Array.isArray(rawCourses) && rawCourses.length === 0)) {
        setIsOpenToAllCourses(true);
        setSelectedCourses([]);
      } else {
        const isAll = Array.isArray(rawCourses)
          ? rawCourses.some(c => typeof c === 'string' && (c.toLowerCase().includes('all course') || c.toLowerCase().includes('all strand') || c.toLowerCase().includes('all degree') || c === 'All'))
          : typeof rawCourses === 'string' && (rawCourses.toLowerCase().includes('all course') || rawCourses.toLowerCase().includes('all strand') || rawCourses.toLowerCase().includes('all degree') || rawCourses.trim() === 'All');
        setIsOpenToAllCourses(isAll);
        if (isAll) {
          setSelectedCourses([]);
        } else if (Array.isArray(rawCourses)) {
          setSelectedCourses(rawCourses.filter(c => typeof c === 'string' && !c.toLowerCase().includes('all course') && !c.toLowerCase().includes('all strand') && !c.toLowerCase().includes('all degree')));
        } else if (typeof rawCourses === 'string') {
          setSelectedCourses(rawCourses.split(',').map(s => s.trim()).filter(s => !s.toLowerCase().includes('all course') && !s.toLowerCase().includes('all strand') && !s.toLowerCase().includes('all degree')));
        }
      }

      // Pre-populate intake cycle dates from selected open cycle
      const openCyclesList = (programToEdit.cycles || []).filter((c: any) => (c.status || '').toLowerCase() === 'open');
      const cyc = selectedCycleId
        ? programToEdit.cycles?.find((c: any) => c.id === selectedCycleId)
        : (openCyclesList.length > 0 ? openCyclesList[0] : (programToEdit.cycles && programToEdit.cycles.length > 0 ? programToEdit.cycles[0] : null));

      if (cyc) {
        setCycleName(cyc.name || cyc.cycle_name || `AY ${new Date().getFullYear()}-${new Date().getFullYear() + 1}`);
        const sDate = cyc.startDate || cyc.application_start_date;
        const eDate = cyc.endDate || cyc.application_end_date;
        if (sDate) setApplicationStartDate(sDate);
        if (eDate) setApplicationEndDate(eDate);
      }

      // Pre-populate requirements
      const rawReqs =
        programToEdit.application_requirements ??
        programToEdit.applicationRequirements;
      if (Array.isArray(rawReqs) && rawReqs.length > 0) {
        let list: ProgramRequirement[] = rawReqs.map((r: any) => {
          if (typeof r === 'string') return { name: r, description: '', required: true };
          return {
            name: r.name || r.document_name || 'Required Document',
            description: r.description || '',
            required: r.required !== false,
          };
        });
        if (isNeedBasedCategory(normalizedCat)) {
          const hasIncome = list.some(isIncomeProofRequirement);
          if (!hasIncome) {
            list.push({
              name: 'Certificate of Indigency / Proof of Income',
              description: 'ITR, Certificate of Indigency, or Proof of Family Income (Mandatory for Need-Based Programs)',
              required: true,
            });
          } else {
            list = list.map(r => (isIncomeProofRequirement(r) ? { ...r, required: true } : r));
          }
        }
        setRequirementsList(list);
      }

      // Sync location scope & target regions/provinces/municipalities/schools
      setAvailabilityScope(programToEdit.availability_scope || programToEdit.availabilityScope || 'nationwide');
      setAvailableRegions(Array.isArray(programToEdit.available_regions) ? programToEdit.available_regions.map(String) : (Array.isArray(programToEdit.eligible_regions) ? programToEdit.eligible_regions.map(String) : []));
      setAvailableProvinces(Array.isArray(programToEdit.available_provinces) ? programToEdit.available_provinces.map(String) : []);
      setAvailableMunicipalities(Array.isArray(programToEdit.available_municipalities) ? programToEdit.available_municipalities.map(String) : []);
      setAvailableBarangays(Array.isArray(programToEdit.available_barangays) ? programToEdit.available_barangays.map(String) : []);
      setAvailableSchools(Array.isArray(programToEdit.available_schools) ? programToEdit.available_schools.map(String) : []);
    }
  }, [programToEdit, selectedCycleId]);

  // Handle Education Level change and re-sync Year Levels options
  const handleEducationLevelChange = (newLevel: EducationLevel) => {
    setTargetLevel(newLevel);
    // Don't preselect all years when changing education level
    setSelectedYearLevels([]);

    // If level is elementary or high_school, reset courses
    if (newLevel === 'high_school' || newLevel === 'elementary') {
      setSelectedCourses(['General Basic Education Curriculum']);
      setIsOpenToAllCourses(true);
    } else if (newLevel === 'senior_high') {
      setSelectedCourses([]);
      setIsOpenToAllCourses(true);
    }
  };

  const handleToggleYearLevel = (val: number) => {
    setSelectedYearLevels(prev =>
      prev.includes(val) ? prev.filter(v => v !== val) : [...prev, val]
    );
  };

  const handleSelectAllYearLevels = () => {
    const config = YEAR_LEVELS_BY_EDUCATION_LEVEL[targetLevel] || YEAR_LEVELS_BY_EDUCATION_LEVEL.college;
    setSelectedYearLevels(config.options.map(o => o.value));
  };

  const handleClearYearLevels = () => {
    setSelectedYearLevels([]);
  };

  const handleToggleCourse = (course: string) => {
    setSelectedCourses(prev =>
      prev.includes(course) ? prev.filter(c => c !== course) : [...prev, course]
    );
  };

  const handleAddCustomCourse = () => {
    if (!customCourseInput.trim()) return;
    const trimmed = customCourseInput.trim();
    if (!selectedCourses.includes(trimmed)) {
      setSelectedCourses(prev => [...prev, trimmed]);
    }
    setCustomCourseInput('');
  };

  const handleAddCustomStrand = () => {
    if (!customStrandInput.trim()) return;
    const trimmed = customStrandInput.trim();
    if (!selectedCourses.includes(trimmed)) {
      setSelectedCourses(prev => [...prev, trimmed]);
    }
    setCustomStrandInput('');
  };

  const handleCategoryChange = (newCat: string) => {
    const normalized = normalizeCategory(newCat);
    setCategory(normalized);
    if (isNeedBasedCategory(normalized)) {
      const hasIncomeDoc = requirementsList.some(isIncomeProofRequirement);
      if (!hasIncomeDoc) {
        setRequirementsList(prev => [
          ...prev,
          {
            name: 'Certificate of Indigency / Proof of Income',
            description: 'ITR, Certificate of Indigency, or Proof of Family Income (Mandatory for Need-Based Programs)',
            required: true,
          },
        ]);
      } else {
        setRequirementsList(prev =>
          prev.map(r =>
            isIncomeProofRequirement(r)
              ? { ...(typeof r === 'string' ? { name: r, description: '' } : r), required: true }
              : r
          )
        );
      }
    }
  };

  // Step 4: Requirements Checklist
  const [requirementsList, setRequirementsList] = useState<ProgramRequirement[]>(() => {
    const raw = programToEdit?.application_requirements || programToEdit?.applicationRequirements;
    let list: ProgramRequirement[] = [];
    if (Array.isArray(raw) && raw.length > 0) {
      list = raw.map((r: any) => {
        if (typeof r === 'string') {
          return { name: r, description: '', required: true };
        }
        return {
          name: r.name || r.document_name || 'Required Document',
          description: r.description || '',
          required: r.required !== false,
        };
      });
    } else {
      list = [
        { name: 'Transcript of Records / Certificate of Grades', description: 'Official TOR or certified grade slip', required: true },
        { name: 'Certificate of Good Moral Character', description: 'Issued by school dean or principal', required: true },
        { name: 'Certificate of Indigency / Proof of Income', description: 'ITR or Barangay Certificate of Indigency', required: true },
        { name: 'Valid Government / Student ID', description: 'Government-issued ID or current School ID', required: true },
      ];
    }

    const currentCat = normalizeCategory(programToEdit?.category || programToEdit?.scholarship_type || (programToEdit as any)?.scholarshipType);
    if (isNeedBasedCategory(currentCat)) {
      const hasIncome = list.some(isIncomeProofRequirement);
      if (!hasIncome) {
        list.push({
          name: 'Certificate of Indigency / Proof of Income',
          description: 'ITR, Certificate of Indigency, or Proof of Family Income (Mandatory for Need-Based Programs)',
          required: true,
        });
      } else {
        list = list.map(r => (isIncomeProofRequirement(r) ? { ...r, required: true } : r));
      }
    }
    return list;
  });
  const [newRequirementName, setNewRequirementName] = useState('');
  const [newRequirementDesc, setNewRequirementDesc] = useState('');
  const [newRequirementRequired, setNewRequirementRequired] = useState(true);

  // Edit Requirement State
  const [editingReqIdx, setEditingReqIdx] = useState<number | null>(null);
  const [editingReqName, setEditingReqName] = useState('');
  const [editingReqDesc, setEditingReqDesc] = useState('');
  const [editingReqRequired, setEditingReqRequired] = useState(true);

  const handleAddRequirement = () => {
    if (!newRequirementName.trim()) return;
    setRequirementsList(prev => [
      ...prev,
      {
        name: newRequirementName.trim(),
        description: newRequirementDesc.trim(),
        required: newRequirementRequired,
      }
    ]);
    setNewRequirementName('');
    setNewRequirementDesc('');
    setNewRequirementRequired(true);
  };

  const handleStartEditRequirement = (idx: number) => {
    const req = requirementsList[idx];
    setEditingReqIdx(idx);
    setEditingReqName(typeof req === 'string' ? req : req.name);
    setEditingReqDesc(typeof req === 'string' ? '' : req.description || '');
    setEditingReqRequired(typeof req === 'string' ? true : req.required !== false);
  };

  const handleSaveEditRequirement = (idx: number) => {
    if (!editingReqName.trim()) return;
    const isIncome = isIncomeProofRequirement({ name: editingReqName.trim(), description: editingReqDesc.trim(), required: editingReqRequired });
    const enforcedRequired = (isNeedBasedCategory(category) && isIncome) ? true : editingReqRequired;

    setRequirementsList(prev => prev.map((item, i) => {
      if (i === idx) {
        return {
          name: editingReqName.trim(),
          description: editingReqDesc.trim(),
          required: enforcedRequired,
        };
      }
      return item;
    }));
    setEditingReqIdx(null);
  };

  const handleCancelEditRequirement = () => {
    setEditingReqIdx(null);
  };

  const handleRemoveRequirement = (idx: number) => {
    const req = requirementsList[idx];
    if (isNeedBasedCategory(category) && isIncomeProofRequirement(req)) {
      setStepValidationError('⚠️ Proof of Income / Certificate of Indigency is mandatory for Need-Based scholarships and cannot be removed.');
      return;
    }
    setRequirementsList(prev => prev.filter((_, i) => i !== idx));
  };

  const isFreshmanTarget =
    targetLevel === 'incoming_college' ||
    (targetLevel === 'college' && selectedYearLevels.includes(1));

  // Filtered CHED college courses
  const filteredChedCourses = useMemo(() => {
    return CHED_COLLEGE_COURSES.map(cat => {
      if (selectedCourseCategory !== 'All' && cat.category !== selectedCourseCategory) {
        return null;
      }
      const matchingCourses = cat.courses.filter(course =>
        course.toLowerCase().includes(courseSearchTerm.toLowerCase())
      );
      if (matchingCourses.length === 0) return null;
      return { ...cat, courses: matchingCourses };
    }).filter(Boolean) as typeof CHED_COLLEGE_COURSES;
  }, [courseSearchTerm, selectedCourseCategory]);

  const handleSubmitForm = async (e: React.FormEvent) => {
    e.preventDefault();
    for (let s = 1; s <= 4; s++) {
      const check = validateStep(s);
      if (!check.valid) {
        setStepValidationError(check.error);
        setCurrentStep(s);
        return;
      }
    }
    if (isNeedBasedCategory(category)) {
      const hasMandatoryIncomeProof = requirementsList.some(
        r => isIncomeProofRequirement(r) && (typeof r === 'string' || r.required !== false)
      );
      if (!hasMandatoryIncomeProof) {
        setStepValidationError('⚠️ Step 4 Required: For Need-Based scholarships, Proof of Income / Certificate of Indigency is mandatory and must be included in the document requirements.');
        setCurrentStep(4);
        return;
      }
    }
    setIsSubmitting(true);
    try {
      // Compute final eligible courses
      let finalCourses: string[] = [];
      if (targetLevel === 'high_school' || targetLevel === 'elementary') {
        finalCourses = ['General Basic Education Curriculum'];
      } else if (isOpenToAllCourses || selectedCourses.length === 0) {
        if (targetLevel === 'senior_high') {
          finalCourses = ['All Senior High Strands'];
        } else if (targetLevel === 'vocational') {
          finalCourses = ['All TVET Qualifications'];
        } else {
          finalCourses = ['All Degree Programs'];
        }
      } else {
        finalCourses = selectedCourses;
      }

      const payload = {
        title,
        category,
        target_education_level: targetLevel,
        description,
        cycle_name: cycleName || `AY ${new Date().getFullYear()}-${new Date().getFullYear() + 1}`,
        application_start_date: applicationStartDate || defaultStartDate,
        application_end_date: applicationEndDate || defaultEndDate,
        amount: parseFloat(amount) || 0,
        funding_frequency: fundingFreq,
        total_slots: totalSlots && !isNaN(parseInt(totalSlots, 10)) ? parseInt(totalSlots, 10) : null,
        totalSlots: totalSlots && !isNaN(parseInt(totalSlots, 10)) ? parseInt(totalSlots, 10) : null,
        coverstuition: coversTuition,
        coversStipend: coversStipend,
        stipendAmount: parseFloat(stipendAmount) || 0,
        coversAllowance: coversAllowance,
        allowanceAmount: parseFloat(allowanceAmount) || 0,
        otherBenefits,
        grading_system: gradingSystem,
        minimumGwa: gpaRequirement,
        eligible_courses: finalCourses,
        eligible_year_levels: selectedYearLevels,
        availability_scope: availabilityScope,
        available_regions: availableRegions,
        available_provinces: availableProvinces,
        available_municipalities: availableMunicipalities,
        available_barangays: availableBarangays,
        available_schools: availableSchools,
        applicationRequirements: requirementsList,
        allow_freshman_intended_school: allowFreshmanIntendedSchool,
        is_incoming_freshman_supported: isFreshmanTarget,
        disbursement_mode: disbursementMode,
        disbursementMode: disbursementMode,
        online_bank_type: onlineBankType,
        onlineBankType: onlineBankType,
        tuition_payout_mode: tuitionPayoutMode,
        tuition_coverage_type: tuitionCoverageType,
        tuition_max_amount: parseFloat(tuitionMaxAmount) || 0,
        custom_benefits: customBenefitsList,
        low_budget_threshold: (parseFloat(lowBudgetThreshold) || 20) / 100,
      };

      await onSubmit(payload, isEditMode);
    } catch (err) {
      console.error('Failed to submit program:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  const wizardSteps = [
    { num: 1, name: 'Basic Details' },
    { num: 2, name: 'Benefits & Grant' },
    { num: 3, name: 'Eligibility & Strands/Courses' },
    { num: 4, name: 'Document Requirements' },
    { num: 5, name: 'Review & Publish' },
  ];

  const currentYearConfig = YEAR_LEVELS_BY_EDUCATION_LEVEL[targetLevel] || YEAR_LEVELS_BY_EDUCATION_LEVEL.college;

  return (
    <div className="space-y-6 animate-fade-in pb-16">
      {/* Top Header & Wizard Stepper */}
      <div className="bg-white p-6 rounded-3xl border border-[#D9D2C5]/60 shadow-sm space-y-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <button
              onClick={onCancel}
              className="p-2.5 rounded-2xl bg-[#F9F5EF] hover:bg-[#EDE8DE] text-[#1A3C2E] font-bold text-sm border-0 cursor-pointer transition-all flex items-center gap-2"
            >
              <span>←</span> Back to Programs
            </button>
            <div>
              <h2 className="text-2xl font-extrabold text-[#1A3C2E] font-serif">
                {isEditMode ? `Edit Program: ${programToEdit?.title}` : 'Create New Scholarship Program'}
              </h2>
              <p className="text-xs text-[#6C6C70] mt-0.5">
                Configure scholarship details, target student levels, criteria, allowance budget, and documents.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onCancel}
              className="px-4 py-2.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-xs font-bold border-0 cursor-pointer transition-all"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={(e) => handleSubmitForm(e)}
              disabled={isSubmitting || !validateStep(1).valid || !validateStep(2).valid || !validateStep(3).valid || !validateStep(4).valid}
              className="px-6 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer shadow-md transition-all disabled:opacity-50 flex items-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <span className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                  Saving...
                </>
              ) : isEditMode ? (
                'Save Changes'
              ) : (
                'Publish Scholarship'
              )}
            </button>
          </div>
        </div>

        {/* Stepper Progress */}
        <div className="grid grid-cols-5 gap-2 pt-2 border-t border-[#EDE8DE]">
          {wizardSteps.map((step) => {
            const isActive = currentStep === step.num;
            const isCompleted = currentStep > step.num;
            return (
              <button
                key={step.num}
                type="button"
                onClick={() => handleGoToStep(step.num)}
                className={`text-left p-3 rounded-2xl transition-all border-0 cursor-pointer flex flex-col gap-1 ${
                  isActive
                    ? 'bg-[#1A3C2E] text-white shadow-sm'
                    : isCompleted
                    ? 'bg-[#E6F4EA] text-[#137333]'
                    : 'bg-[#F9F5EF] text-[#6C6C70] hover:bg-[#EDE8DE]'
                }`}
              >
                <div className="flex items-center justify-between text-xs font-extrabold">
                  <span>Step {step.num}</span>
                  {isCompleted && <span>✓</span>}
                </div>
                <div className={`text-[11px] font-semibold break-words ${isActive ? 'text-white' : 'text-[#1C1C1E]'}`}>
                  {step.name}
                </div>
              </button>
            );
          })}
        </div>

        {/* Validation Warning Alert Banner */}
        {stepValidationError && (
          <div className="p-3.5 rounded-2xl bg-red-50 border border-red-300 text-red-900 text-xs font-bold flex items-center justify-between gap-2 animate-fade-in">
            <div className="flex items-center gap-2">
              <span className="text-base shrink-0">⚠️</span>
              <span>{stepValidationError}</span>
            </div>
            <button
              type="button"
              onClick={() => setStepValidationError('')}
              className="text-red-700 hover:text-red-900 font-extrabold text-xs bg-transparent border-0 cursor-pointer px-1"
            >
              ✕
            </button>
          </div>
        )}
      </div>

      {/* Form Wizard Body */}
      <form onSubmit={handleSubmitForm} className="bg-white p-8 rounded-3xl border border-[#D9D2C5]/60 shadow-sm space-y-8">
        {/* STEP 1: Basic Details */}
        {currentStep === 1 && (
          <div className="space-y-6">
            <h3 className="text-lg font-extrabold text-[#1A3C2E] font-serif border-b border-[#EDE8DE] pb-3">
              1. Basic Program Details
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Program Title *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. DOST-SEI Science & Tech Scholarship 2026"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Scholarship Category *
                </label>
                <select
                  value={category}
                  onChange={(e) => handleCategoryChange(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] text-sm bg-white cursor-pointer font-medium"
                >
                  <option value="Merit-Based">Merit-Based</option>
                  <option value="Need-Based">Need-Based</option>
                  <option value="Both Merit and Need">Both Merit and Need</option>
                </select>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Target Education Level *
                </label>
                <select
                  value={targetLevel}
                  onChange={(e) => handleEducationLevelChange(e.target.value as EducationLevel)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] text-sm bg-white cursor-pointer font-semibold text-[#1A3C2E]"
                >
                  <option value="incoming_college">🎓 Incoming College Freshmen (Upcoming 1st Year)</option>
                  <option value="college">🏛️ College / University Undergraduate</option>
                  <option value="senior_high">🏫 Senior High School (SHS - Grade 11 & 12)</option>
                  <option value="high_school">🏫 Junior High School (Grade 7 - 10)</option>
                  <option value="elementary">🎒 Elementary School (Grade 1 - 6)</option>
                  <option value="graduate">🎓 Graduate / Master's / Doctorate</option>
                  <option value="vocational">🛠️ Vocational / Technical (TVET / TESDA)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Target Available Slots
                </label>
                <input
                  type="number"
                  placeholder="e.g. 50 (Leave empty if unlimited)"
                  value={totalSlots}
                  onChange={(e) => setTotalSlots(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm"
                />
              </div>
            </div>

            {/* Application Intake Schedule (Opening & Closing Dates) */}
            <div className="p-5 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-4">
              <div>
                <h4 className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wide flex items-center gap-2">
                  <span>📅</span> Application Intake Schedule (Opening & Closing Dates)
                </h4>
                <p className="text-[11px] text-[#6C6C70] mt-0.5 font-medium">
                  Set when student applications open and the closing deadline. The scholarship will automatically close when the deadline passes.
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                    Intake Cycle Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. AY 2026-2027 1st Sem"
                    value={cycleName}
                    onChange={(e) => setCycleName(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] bg-white text-xs font-medium"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                    Opening Date *
                  </label>
                  <input
                    type="date"
                    required
                    value={applicationStartDate}
                    onChange={(e) => setApplicationStartDate(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] bg-white text-xs font-medium"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                    Closing Deadline *
                  </label>
                  <input
                    type="date"
                    required
                    min={applicationStartDate}
                    value={applicationEndDate}
                    onChange={(e) => setApplicationEndDate(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] bg-white text-xs font-medium"
                  />
                </div>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                Program Description & Overview
              </label>
              <textarea
                rows={4}
                placeholder="Describe the objective, background, and vision of this scholarship program..."
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full p-4 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm leading-relaxed"
              />
            </div>
          </div>
        )}

        {/* STEP 2: Benefits & Grant */}
        {currentStep === 2 && (
          <div className="space-y-6">
            <h3 className="text-lg font-extrabold text-[#1A3C2E] font-serif border-b border-[#EDE8DE] pb-3">
              2. Financial Benefits & Allowance Coverage
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Grant Budget Allocation (PHP)
                </label>
                <div className="relative">
                  <span className="absolute left-4 top-3 text-sm font-bold text-[#8E8E93]">₱</span>
                  <input
                    type="number"
                    placeholder="e.g. 40000"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    className="w-full pl-9 pr-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm font-semibold"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Funding Frequency
                </label>
                <select
                  value={fundingFreq}
                  onChange={(e) => setFundingFreq(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm bg-white cursor-pointer font-medium"
                >
                  <option value="Per Semester">Per Semester</option>
                  <option value="Once a Year">Once a Year (Annual)</option>
                  <option value="One-time">One-Time Grant</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Total Available Slots / Applicant Limit
                </label>
                <input
                  type="number"
                  placeholder="e.g. 50 (Leave empty for Unlimited)"
                  value={totalSlots}
                  onChange={(e) => setTotalSlots(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm font-semibold bg-white"
                />
              </div>
            </div>

            {/* Coverage Toggles */}
            <div className="p-5 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-4">
              <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wide">
                Included Allowances & Coverage
              </h4>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <label className="flex items-center gap-3 p-3.5 bg-white rounded-2xl border border-[#D9D2C5]/80 cursor-pointer hover:border-[#1A3C2E] transition-all">
                  <input
                    type="checkbox"
                    checked={coversTuition}
                    onChange={(e) => setCoversTuition(e.target.checked)}
                    className="w-4 h-4 text-[#1A3C2E] rounded cursor-pointer"
                  />
                  <div>
                    <span className="block text-xs font-bold text-[#1C1C1E]">Tuition Subsidy</span>
                    <span className="text-[10px] text-[#6C6C70]">Covers school fees / matriculation</span>
                  </div>
                </label>

                <label className="flex items-center gap-3 p-3.5 bg-white rounded-2xl border border-[#D9D2C5]/80 cursor-pointer hover:border-[#1A3C2E] transition-all">
                  <input
                    type="checkbox"
                    checked={coversStipend}
                    onChange={(e) => setCoversStipend(e.target.checked)}
                    className="w-4 h-4 text-[#1A3C2E] rounded cursor-pointer"
                  />
                  <div>
                    <span className="block text-xs font-bold text-[#1C1C1E]">Stipend / Allowance</span>
                    <span className="text-[10px] text-[#6C6C70]">Living & daily allowance</span>
                  </div>
                </label>

                <label className="flex items-center gap-3 p-3.5 bg-white rounded-2xl border border-[#D9D2C5]/80 cursor-pointer hover:border-[#1A3C2E] transition-all">
                  <input
                    type="checkbox"
                    checked={coversAllowance}
                    onChange={(e) => setCoversAllowance(e.target.checked)}
                    className="w-4 h-4 text-[#1A3C2E] rounded cursor-pointer"
                  />
                  <div>
                    <span className="block text-xs font-bold text-[#1C1C1E]">Book / Device Grant</span>
                    <span className="text-[10px] text-[#6C6C70]">Academic learning resources</span>
                  </div>
                </label>
              </div>

              {(coversStipend || coversAllowance) && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
                  {coversStipend && (
                    <div>
                      <label className="block text-xs font-bold text-[#1C1C1E] mb-1">Stipend / Allowance (₱)</label>
                      <input
                        type="number"
                        placeholder="e.g. 7000"
                        value={stipendAmount}
                        onChange={(e) => setStipendAmount(e.target.value)}
                        className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs bg-white"
                      />
                    </div>
                  )}
                  {coversAllowance && (
                    <div>
                      <label className="block text-xs font-bold text-[#1C1C1E] mb-1">Book Allowance (₱/sem)</label>
                      <input
                        type="number"
                        placeholder="e.g. 5000"
                        value={allowanceAmount}
                        onChange={(e) => setAllowanceAmount(e.target.value)}
                        className="w-full px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs bg-white"
                      />
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Disbursement Release Method & Payout Channel */}
            <div className="p-5 rounded-3xl bg-[#F4F6F4] border border-[#D9D2C5]/80 space-y-4">
              <h4 className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wide flex items-center gap-2">
                <span>💸</span> Disbursement & Payout Release Method
              </h4>
              <p className="text-[11.5px] text-[#6C6C70]">
                Specify how scholars will receive their stipends, allowances, and monetary grants for this program.
              </p>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Release Type: Cash vs Online */}
                <div>
                  <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                    Release Type *
                  </label>
                  <select
                    value={disbursementMode}
                    onChange={(e: any) => setDisbursementMode(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-2xl border border-[#D9D2C5] text-xs font-bold text-[#1A3C2E] bg-white cursor-pointer"
                  >
                    <option value="online_transfer">🌐 Online Bank / Digital E-Wallet Transfer</option>
                    <option value="in_person_cash">💵 Over-the-Counter Cash (On-Site Release)</option>
                  </select>
                </div>

                {/* Online Account Category (if Online Transfer) */}
                {disbursementMode === 'online_transfer' ? (
                  <div>
                    <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                      Online Bank / Account Category *
                    </label>
                    <select
                      value={onlineBankType}
                      onChange={(e: any) => setOnlineBankType(e.target.value)}
                      className="w-full px-4 py-2.5 rounded-2xl border border-[#D9D2C5] text-xs font-bold text-[#1A3C2E] bg-white cursor-pointer"
                    >
                      <option value="personal_bank">📱 Scholar's Personal Bank Account / E-Wallet (GCash, Maya, BDO, BPI, etc.)</option>
                      <option value="provider_issued_card">💳 Provider-Issued ATM Card (New Partner Bank Card)</option>
                    </select>
                  </div>
                ) : (
                  <div>
                    <label className="block text-[11px] font-bold text-[#6C6C70] uppercase tracking-wide mb-1.5">
                      Venue / Payout Location
                    </label>
                    <div className="px-4 py-2.5 rounded-2xl bg-[#EBE7DF] border border-[#D9D2C5] text-xs font-medium text-[#6C6C70]">
                      Campus Cashier / Over-the-Counter Desk
                    </div>
                  </div>
                )}
              </div>

              {/* Explanatory Info Box */}
              {disbursementMode === 'online_transfer' ? (
                <div className="p-3 bg-[#EBF5EE] border border-[#2D5941]/20 rounded-xl text-[11px] text-[#1A3C2E] flex items-start gap-2">
                  <span className="text-base">ℹ️</span>
                  <div>
                    {onlineBankType === 'personal_bank' ? (
                      <p>
                        <strong>Scholar Personal Account:</strong> Applicants will link their existing personal bank or e-wallet account (e.g. GCash, Maya, Landbank, BDO, BPI) during application.
                      </p>
                    ) : (
                      <p>
                        <strong>Provider-Issued ATM Card:</strong> The provider or partner bank will issue and distribute new dedicated ATM cash cards to accepted scholars upon program enrollment.
                      </p>
                    )}
                  </div>
                </div>
              ) : (
                <div className="p-3 bg-[#FFFBEB] border border-[#F59E0B]/30 rounded-xl text-[11px] text-[#92400E] flex items-start gap-2">
                  <span className="text-base">🏛️</span>
                  <p>
                    <strong>Over-the-Counter Cash Mode:</strong> Scholars will collect funds in cash at designated campus offices or provider payout venues. Bank account details are not required.
                  </p>
                </div>
              )}
            </div>

            {/* Tuition Payout & Coverage Details */}
            {coversTuition && (
              <div className="p-5 rounded-3xl bg-[#EBF5EE] border border-[#2D5941]/30 space-y-4">
                <h4 className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wide flex items-center gap-2">
                  <span>🏛️</span> Tuition Subsidy Settings & Disbursement Mode
                </h4>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Tuition Payout Mode */}
                  <div>
                    <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                      Tuition Disbursement Channel *
                    </label>
                    <select
                      value={tuitionPayoutMode}
                      onChange={(e: any) => setTuitionPayoutMode(e.target.value)}
                      className="w-full px-4 py-2.5 rounded-2xl border border-[#D9D2C5] text-xs font-bold text-[#1A3C2E] bg-white cursor-pointer"
                    >
                      <option value="direct_to_student">📱 Direct to Scholar E-Wallet / Bank (In System Scope)</option>
                      <option value="direct_to_school_off_system">🏛️ Direct to University Treasury (Institutional Voucher / Off-System)</option>
                    </select>
                    {tuitionPayoutMode === 'direct_to_school_off_system' && (
                      <p className="text-[10px] text-[#C97B2E] font-medium mt-1">
                        ℹ️ Note: Institutional B2B university wire transfers are processed off-system via university billing invoices.
                      </p>
                    )}
                  </div>

                  {/* Tuition Coverage Mode */}
                  <div>
                    <label className="block text-[11px] font-bold text-[#1C1C1E] uppercase tracking-wide mb-1.5">
                      Tuition Fee Amount Mode *
                    </label>
                    <select
                      value={tuitionCoverageType}
                      onChange={(e: any) => setTuitionCoverageType(e.target.value)}
                      className="w-full px-4 py-2.5 rounded-2xl border border-[#D9D2C5] text-xs font-bold text-[#1A3C2E] bg-white cursor-pointer"
                    >
                      <option value="fixed_cap">💵 Fixed Cap Amount per Semester</option>
                      <option value="actual_matriculation">📑 Actual Matriculation Fee (Extracted from Assessment Bill)</option>
                    </select>
                  </div>
                </div>

                {tuitionCoverageType === 'fixed_cap' && (
                  <div className="pt-1">
                    <label className="block text-[11px] font-bold text-[#1C1C1E] mb-1">Maximum Tuition Cap per Semester (₱)</label>
                    <input
                      type="number"
                      placeholder="e.g. 20000"
                      value={tuitionMaxAmount}
                      onChange={(e) => setTuitionMaxAmount(e.target.value)}
                      className="w-full md:w-1/2 px-4 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white font-semibold text-[#1A3C2E]"
                    />
                  </div>
                )}
              </div>
            )}

            {/* Dynamic Custom Benefits List Builder */}
            <div className="p-5 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-xs font-bold text-[#1C1C1E] uppercase tracking-wide">
                    Custom Included Benefits & Allowances
                  </h4>
                  <p className="text-[11px] text-[#6C6C70] mt-0.5 font-medium">
                    Add custom allowances like Thesis Grant, Laptop Subsidy, Uniform Allowance, or Connectivity Stipend.
                  </p>
                </div>
              </div>

              {/* Added Custom Benefits Chips/List */}
              {customBenefitsList.length > 0 && (
                <div className="space-y-2">
                  {customBenefitsList.map((b, bIdx) => (
                    <div key={bIdx} className="flex items-center justify-between bg-white p-3 rounded-2xl border border-[#D9D2C5]/80 text-xs">
                      <div>
                        <span className="font-extrabold text-[#1A3C2E]">{b.title}</span>
                        <span className="text-[#6C6C70] text-[11px] ml-2 font-mono">
                          ₱{Number(b.amount).toLocaleString()} ({b.frequency})
                        </span>
                      </div>
                      <button
                        type="button"
                        onClick={() => setCustomBenefitsList(prev => prev.filter((_, i) => i !== bIdx))}
                        className="text-xs font-bold text-red-600 hover:text-red-800 cursor-pointer bg-transparent border-0"
                      >
                        ✕ Remove
                      </button>
                    </div>
                  ))}
                </div>
              )}

              {/* Add Custom Benefit Inputs */}
              <div className="grid grid-cols-1 md:grid-cols-4 gap-2 pt-1">
                <input
                  type="text"
                  placeholder="Benefit Title (e.g. Thesis Grant)"
                  value={newBenefitTitle}
                  onChange={(e) => setNewBenefitTitle(e.target.value)}
                  className="px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white"
                />
                <input
                  type="number"
                  placeholder="Amount (₱)"
                  value={newBenefitAmount}
                  onChange={(e) => setNewBenefitAmount(e.target.value)}
                  className="px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white font-semibold"
                />
                <select
                  value={newBenefitFreq}
                  onChange={(e) => setNewBenefitFreq(e.target.value)}
                  className="px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white cursor-pointer"
                >
                  <option value="Per Semester">Per Semester</option>
                  <option value="Monthly">Monthly</option>
                  <option value="Once a Year">Once a Year</option>
                  <option value="One-time">One-Time</option>
                </select>
                <button
                  type="button"
                  onClick={() => {
                    if (!newBenefitTitle.trim() || !newBenefitAmount.trim()) return;
                    setCustomBenefitsList(prev => [
                      ...prev,
                      { title: newBenefitTitle.trim(), amount: newBenefitAmount.trim(), frequency: newBenefitFreq }
                    ]);
                    setNewBenefitTitle('');
                    setNewBenefitAmount('');
                  }}
                  className="px-4 py-2 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer transition-all shadow-2xs"
                >
                  + Add Benefit
                </button>
              </div>
            </div>
          </div>
        )}

        {/* STEP 3: Eligibility & Dynamic Year Levels / Strands / Courses */}
        {currentStep === 3 && (
          <div className="space-y-6">
            <h3 className="text-lg font-extrabold text-[#1A3C2E] font-serif border-b border-[#EDE8DE] pb-3">
              3. Eligibility Criteria, Year Levels & Academic Field Selection
            </h3>

            {/* Special Highlight Banner for Freshmen */}
            <div className={`p-5 rounded-3xl border transition-all ${
              isFreshmanTarget ? 'bg-[#E6F4EA] border-[#CEEAD6] text-[#137333]' : 'bg-[#F9F5EF] border-[#D9D2C5]'
            }`}>
              <div className="flex items-center gap-3">
                <span className="text-2xl">🎓</span>
                <div>
                  <h4 className="text-sm font-extrabold">
                    {isFreshmanTarget ? 'Incoming College Freshmen Intake Mode Enabled' : 'Standard Student Intake Mode'}
                  </h4>
                  <p className="text-xs mt-0.5 opacity-90">
                    {isFreshmanTarget
                      ? 'Students applying for 1st Year college might not have an enrolled school yet. They will be prompted for Current High School, Target / Intended College, and Intended Course choices.'
                      : 'Students will specify their current institution, active course/strand, and enrolled term.'
                    }
                  </p>
                </div>
              </div>

              {isFreshmanTarget && (
                <div className="mt-4 pt-3 border-t border-[#CEEAD6] flex items-center justify-between text-xs">
                  <span className="font-bold">Allow Intended / Target School Inputs for Applicants</span>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      checked={allowFreshmanIntendedSchool}
                      onChange={(e) => setAllowFreshmanIntendedSchool(e.target.checked)}
                      className="sr-only peer"
                    />
                    <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-[#137333]"></div>
                  </label>
                </div>
              )}
            </div>

            {/* Academic Standards */}
            <div className="grid grid-cols-1 gap-6">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Minimum Grade Percentage Requirement (%)
                </label>
                <input
                  type="text"
                  placeholder="e.g. 85"
                  value={gpaRequirement}
                  onChange={(e) => setGpaRequirement(e.target.value)}
                  className="w-full md:w-1/2 px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm font-semibold"
                />
              </div>
            </div>

            {/* DYNAMIC YEAR LEVELS (Interactive Pills - Integer values [1, 2, 3...] for Postgres) */}
            <div className="p-5 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5]/80 space-y-3">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                <div>
                  <label className="block text-xs font-bold text-[#1A3C2E] uppercase tracking-wide">
                    Eligible Year Levels ({currentYearConfig.label}) *
                  </label>
                  <span className="text-[11px] text-[#6C6C70]">
                    Click to toggle which grade / year levels are eligible to apply ({selectedYearLevels.length} selected).
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={handleSelectAllYearLevels}
                    className="px-2.5 py-1 text-[11px] font-bold text-[#1A3C2E] bg-white rounded-lg border border-[#D9D2C5] hover:bg-[#EDE8DE] cursor-pointer"
                  >
                    Select All
                  </button>
                  <button
                    type="button"
                    onClick={handleClearYearLevels}
                    className="px-2.5 py-1 text-[11px] font-bold text-rose-600 bg-white rounded-lg border border-rose-200 hover:bg-rose-50 cursor-pointer"
                  >
                    Clear
                  </button>
                </div>
              </div>

              <div className="flex flex-wrap gap-2 pt-1">
                {currentYearConfig.options.map((option) => {
                  const isSelected = selectedYearLevels.includes(option.value);
                  return (
                    <button
                      key={option.value}
                      type="button"
                      onClick={() => handleToggleYearLevel(option.value)}
                      className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all border cursor-pointer flex items-center gap-2 ${
                        isSelected
                          ? 'bg-[#1A3C2E] text-white border-[#1A3C2E] shadow-sm'
                          : 'bg-white text-[#1C1C1E] border-[#D9D2C5] hover:bg-[#EDE8DE]/60'
                      }`}
                    >
                      <span>{isSelected ? '✓' : '+'}</span>
                      <span>{option.label}</span>
                    </button>
                  );
                })}
              </div>

              {selectedYearLevels.length === 0 && (
                <div className="p-3.5 rounded-2xl bg-red-50 border border-red-300 text-red-900 text-xs font-bold space-y-2 mt-2">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <div className="flex items-center gap-2">
                      <span className="text-base shrink-0">⚠️</span>
                      <span>Selection Required: You must select at least one eligible year level to proceed to the next page.</span>
                    </div>
                    <button
                      type="button"
                      onClick={handleSelectAllYearLevels}
                      className="px-3 py-1 bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold rounded-xl border-0 cursor-pointer shadow-xs"
                    >
                      ✓ Select All Year Levels
                    </button>
                  </div>
                </div>
              )}
            </div>


            {/* DYNAMIC COURSES / STRANDS SECTION */}
            {/* CASE A: Junior High School or Elementary -> DO NOT SHOW COURSE INPUT */}
            {(targetLevel === 'high_school' || targetLevel === 'elementary') && (
              <div className="p-5 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] flex items-start gap-3.5">
                <span className="text-2xl mt-0.5">🏫</span>
                <div>
                  <h4 className="text-sm font-bold text-[#1A3C2E]">
                    {targetLevel === 'elementary' ? 'Elementary Grade School' : 'Junior High School'} General Education
                  </h4>
                  <p className="text-xs text-[#6C6C70] mt-1 leading-relaxed">
                    Standard DepEd basic education curriculum applies automatically to all enrolled students at this grade level. Degree courses and specialized academic track selections are not required.
                  </p>
                </div>
              </div>
            )}

            {/* CASE B: Senior High School -> DEPED SHS STRANDS SELECTOR (Not a plain textbox) */}
            {targetLevel === 'senior_high' && (
              <div className="p-6 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-5">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div>
                    <h4 className="text-sm font-extrabold text-[#1A3C2E] uppercase tracking-wide">
                      Senior High School Strands & Tracks
                    </h4>
                    <p className="text-xs text-[#6C6C70] mt-0.5">
                      Select which official DepEd SHS academic or TVL strands are eligible to apply.
                    </p>
                  </div>

                  {/* Segmented Mode Switcher */}
                  <div className="flex bg-[#EDE8DE] p-1 rounded-2xl">
                    <button
                      type="button"
                      onClick={() => {
                        setIsOpenToAllCourses(true);
                        setSelectedCourses([]);
                      }}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer ${
                        isOpenToAllCourses
                          ? 'bg-[#1A3C2E] text-white shadow-sm'
                          : 'text-[#1C1C1E] bg-transparent hover:text-[#1A3C2E]'
                      }`}
                    >
                      🌟 Open to All Strands
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setIsOpenToAllCourses(false);
                      }}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer ${
                        !isOpenToAllCourses
                          ? 'bg-[#1A3C2E] text-white shadow-sm'
                          : 'text-[#1C1C1E] bg-transparent hover:text-[#1A3C2E]'
                      }`}
                    >
                      🎯 Select Specific Strands {selectedCourses.length > 0 ? `(${selectedCourses.length})` : ''}
                    </button>
                  </div>
                </div>

                {isOpenToAllCourses ? (
                  <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5]/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
                    <div className="flex items-center gap-2.5">
                      <span className="text-lg">🌟</span>
                      <div>
                        <span className="font-bold text-[#1A3C2E] block">Open to All Senior High School Strands</span>
                        <span className="text-[#6C6C70]">Applicants from any Academic or TVL strand can apply for this scholarship.</span>
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => setIsOpenToAllCourses(false)}
                      className="px-4 py-2 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] font-bold text-xs border-0 cursor-pointer self-start sm:self-auto"
                    >
                      + Limit to Specific Strands
                    </button>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {/* Quick Filters */}
                    <div className="flex flex-wrap gap-2 pt-1 border-t border-[#D9D2C5]/60 pt-3">
                      <button
                        type="button"
                        onClick={() => {
                          const academic = SHS_STRANDS.filter(s => s.track === 'Academic Track').map(s => s.name);
                          setSelectedCourses(academic);
                        }}
                        className="px-3 py-1 bg-white hover:bg-[#EDE8DE] text-[#1A3C2E] text-xs font-bold rounded-lg border border-[#D9D2C5] cursor-pointer"
                      >
                        Select Academic Track Only
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          const tvl = SHS_STRANDS.filter(s => s.track === 'Technical-Vocational-Livelihood (TVL)').map(s => s.name);
                          setSelectedCourses(tvl);
                        }}
                        className="px-3 py-1 bg-white hover:bg-[#EDE8DE] text-[#1A3C2E] text-xs font-bold rounded-lg border border-[#D9D2C5] cursor-pointer"
                      >
                        Select TVL Track Only
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          const all = SHS_STRANDS.map(s => s.name);
                          setSelectedCourses(all);
                        }}
                        className="px-3 py-1 bg-white hover:bg-[#EDE8DE] text-[#1A3C2E] text-xs font-bold rounded-lg border border-[#D9D2C5] cursor-pointer"
                      >
                        Select All Listed Strands
                      </button>
                      <button
                        type="button"
                        onClick={() => setSelectedCourses([])}
                        className="px-3 py-1 bg-white hover:bg-rose-50 text-rose-600 text-xs font-bold rounded-lg border border-rose-200 cursor-pointer"
                      >
                        Clear
                      </button>
                    </div>

                    {/* Strands Grid */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                      {SHS_STRANDS.map((strand) => {
                        const isSelected = selectedCourses.includes(strand.name);
                        return (
                          <button
                            key={strand.code}
                            type="button"
                            onClick={() => handleToggleCourse(strand.name)}
                            className={`p-3.5 rounded-2xl text-left transition-all border cursor-pointer flex items-start gap-3 ${
                              isSelected
                                ? 'bg-white border-[#1A3C2E] shadow-sm ring-2 ring-[#1A3C2E]/20'
                                : 'bg-white/80 border-[#D9D2C5]/80 hover:bg-white hover:border-[#1A3C2E]/50'
                            }`}
                          >
                            <span className={`w-5 h-5 rounded-md flex items-center justify-center text-xs font-bold shrink-0 mt-0.5 ${
                              isSelected ? 'bg-[#1A3C2E] text-white' : 'border border-[#D9D2C5] text-transparent'
                            }`}>
                              ✓
                            </span>
                            <div>
                              <span className="block text-xs font-extrabold text-[#1A3C2E]">{strand.name}</span>
                              <span className="text-[10px] text-[#6C6C70] font-semibold">{strand.track}</span>
                            </div>
                          </button>
                        );
                      })}
                    </div>

                    {/* Custom Strand Option */}
                    <div className="flex gap-2 pt-2">
                      <input
                        type="text"
                        placeholder="Add specialized or custom SHS strand..."
                        value={customStrandInput}
                        onChange={(e) => setCustomStrandInput(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') {
                            e.preventDefault();
                            handleAddCustomStrand();
                          }
                        }}
                        className="flex-1 px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none"
                      />
                      <button
                        type="button"
                        onClick={handleAddCustomStrand}
                        className="px-4 py-2.5 rounded-xl bg-[#1A3C2E] text-white text-xs font-bold border-0 cursor-pointer hover:bg-[#2D5941]"
                      >
                        + Add Strand
                      </button>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* CASE C: College / Freshmen / Graduate -> CHED HIGHER EDUCATION DEGREE CATALOG */}
            {(targetLevel === 'college' || targetLevel === 'incoming_college' || targetLevel === 'graduate') && (
              <div className="p-6 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-5">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div>
                    <h4 className="text-sm font-extrabold text-[#1A3C2E] uppercase tracking-wide">
                      Eligible College Degree Programs (CHED Catalog)
                    </h4>
                    <p className="text-xs text-[#6C6C70] mt-0.5">
                      Select specific CHED university degree courses or leave open to all degree majors.
                    </p>
                  </div>

                  {/* Segmented Mode Switcher */}
                  <div className="flex bg-[#EDE8DE] p-1 rounded-2xl">
                    <button
                      type="button"
                      onClick={() => {
                        setIsOpenToAllCourses(true);
                        setSelectedCourses([]);
                      }}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer ${
                        isOpenToAllCourses
                          ? 'bg-[#1A3C2E] text-white shadow-sm'
                          : 'text-[#1C1C1E] bg-transparent hover:text-[#1A3C2E]'
                      }`}
                    >
                      🌐 Open to All Degree Programs
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setIsOpenToAllCourses(false);
                      }}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer ${
                        !isOpenToAllCourses
                          ? 'bg-[#1A3C2E] text-white shadow-sm'
                          : 'text-[#1C1C1E] bg-transparent hover:text-[#1A3C2E]'
                      }`}
                    >
                      🎯 Select Specific Courses {selectedCourses.length > 0 ? `(${selectedCourses.length})` : ''}
                    </button>
                  </div>
                </div>

                {isOpenToAllCourses ? (
                  <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5]/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
                    <div className="flex items-center gap-2.5">
                      <span className="text-lg">🌐</span>
                      <div>
                        <span className="font-bold text-[#1A3C2E] block">Open to All College Degree Programs</span>
                        <span className="text-[#6C6C70]">Applicants from any college major or degree course can apply for this scholarship.</span>
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => setIsOpenToAllCourses(false)}
                      className="px-4 py-2 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] font-bold text-xs border-0 cursor-pointer self-start sm:self-auto"
                    >
                      + Limit to Specific Courses
                    </button>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {/* Search & Category Filter */}
                    <div className="space-y-3 pt-1 border-t border-[#D9D2C5]/60 pt-3">
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <span className="absolute left-3.5 top-2.5 text-xs text-[#6C6C70]">🔍</span>
                          <input
                            type="text"
                            placeholder="Search degree course (e.g., Nursing, Computer Science, Accountancy, Civil Eng)..."
                            value={courseSearchTerm}
                            onChange={(e) => setCourseSearchTerm(e.target.value)}
                            className="w-full pl-9 pr-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none"
                          />
                        </div>
                        {courseSearchTerm && (
                          <button
                            type="button"
                            onClick={() => setCourseSearchTerm('')}
                            className="px-3 py-2 rounded-xl bg-white border border-[#D9D2C5] text-xs font-bold cursor-pointer"
                          >
                            Clear
                          </button>
                        )}
                      </div>

                      {/* Category Pills */}
                      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs">
                        <button
                          type="button"
                          onClick={() => setSelectedCourseCategory('All')}
                          className={`px-3 py-1 rounded-lg font-bold shrink-0 transition-all border cursor-pointer ${
                            selectedCourseCategory === 'All'
                              ? 'bg-[#1A3C2E] text-white border-[#1A3C2E]'
                              : 'bg-white text-[#6C6C70] border-[#D9D2C5] hover:bg-[#EDE8DE]'
                          }`}
                        >
                          All Fields ({CHED_COLLEGE_COURSES.reduce((acc, c) => acc + c.courses.length, 0)})
                        </button>
                        {CHED_COLLEGE_COURSES.map((cat) => (
                          <button
                            key={cat.category}
                            type="button"
                            onClick={() => setSelectedCourseCategory(cat.category)}
                            className={`px-3 py-1 rounded-lg font-bold shrink-0 transition-all border cursor-pointer flex items-center gap-1.5 ${
                              selectedCourseCategory === cat.category
                                ? 'bg-[#1A3C2E] text-white border-[#1A3C2E]'
                                : 'bg-white text-[#6C6C70] border-[#D9D2C5] hover:bg-[#EDE8DE]'
                            }`}
                          >
                            <span>{cat.icon}</span>
                            <span>{cat.category.split('&')[0]}</span>
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Selected Courses Counter / Chips */}
                    {selectedCourses.length > 0 && (
                      <div className="p-3.5 rounded-2xl bg-white border border-[#D9D2C5] space-y-2">
                        <div className="flex items-center justify-between text-xs font-bold text-[#1A3C2E]">
                          <span>Selected Courses ({selectedCourses.length}):</span>
                          <button
                            type="button"
                            onClick={() => setSelectedCourses([])}
                            className="text-rose-600 hover:underline border-0 bg-transparent cursor-pointer text-[11px]"
                          >
                            Remove All
                          </button>
                        </div>
                        <div className="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
                          {selectedCourses.map((c) => (
                            <span
                              key={c}
                              className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-[#E6F4EA] border border-[#CEEAD6] text-xs font-bold text-[#137333]"
                            >
                              <span>{c}</span>
                              <button
                                type="button"
                                onClick={() => handleToggleCourse(c)}
                                className="hover:text-red-700 font-bold border-0 bg-transparent cursor-pointer leading-none text-xs"
                              >
                                ×
                              </button>
                            </span>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Filtered Courses List */}
                    <div className="space-y-4 max-h-72 overflow-y-auto pr-1">
                      {filteredChedCourses.map((catGroup) => (
                        <div key={catGroup.category} className="space-y-2">
                          <h5 className="text-xs font-bold text-[#1A3C2E] flex items-center gap-1.5">
                            <span>{catGroup.icon}</span>
                            <span>{catGroup.category}</span>
                          </h5>
                          <div className="flex flex-wrap gap-1.5">
                            {catGroup.courses.map((courseName) => {
                              const isChecked = selectedCourses.includes(courseName);
                              return (
                                <button
                                  key={courseName}
                                  type="button"
                                  onClick={() => handleToggleCourse(courseName)}
                                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all border cursor-pointer flex items-center gap-1.5 ${
                                    isChecked
                                      ? 'bg-[#1A3C2E] text-white border-[#1A3C2E] font-bold shadow-sm'
                                      : 'bg-white text-[#1C1C1E] border-[#D9D2C5]/80 hover:bg-[#EDE8DE]'
                                  }`}
                                >
                                  <span>{isChecked ? '✓' : '+'}</span>
                                  <span>{courseName}</span>
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      ))}
                    </div>

                    {/* Custom Degree Course Input */}
                    <div className="flex gap-2 pt-2 border-t border-[#D9D2C5]/60">
                      <input
                        type="text"
                        placeholder="Add custom / niche degree program (e.g. BS Artificial Intelligence)..."
                        value={customCourseInput}
                        onChange={(e) => setCustomCourseInput(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') {
                            e.preventDefault();
                            handleAddCustomCourse();
                          }
                        }}
                        className="flex-1 px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none"
                      />
                      <button
                        type="button"
                        onClick={handleAddCustomCourse}
                        className="px-4 py-2.5 rounded-xl bg-[#1A3C2E] text-white text-xs font-bold border-0 cursor-pointer hover:bg-[#2D5941]"
                      >
                        + Add Course
                      </button>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* CASE D: Vocational / TVET Qualifications */}
            {targetLevel === 'vocational' && (
              <div className="p-6 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-5">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div>
                    <h4 className="text-sm font-extrabold text-[#1A3C2E] uppercase tracking-wide">
                      Eligible TVET / TESDA Qualifications
                    </h4>
                    <p className="text-xs text-[#6C6C70] mt-0.5">
                      Select specific TESDA vocational courses or leave open to all technical qualifications.
                    </p>
                  </div>

                  {/* Segmented Mode Switcher */}
                  <div className="flex bg-[#EDE8DE] p-1 rounded-2xl">
                    <button
                      type="button"
                      onClick={() => {
                        setIsOpenToAllCourses(true);
                        setSelectedCourses([]);
                      }}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer ${
                        isOpenToAllCourses
                          ? 'bg-[#1A3C2E] text-white shadow-sm'
                          : 'text-[#1C1C1E] bg-transparent hover:text-[#1A3C2E]'
                      }`}
                    >
                      🛠️ Open to All TVET Qualifications
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setIsOpenToAllCourses(false);
                      }}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all border-0 cursor-pointer ${
                        !isOpenToAllCourses
                          ? 'bg-[#1A3C2E] text-white shadow-sm'
                          : 'text-[#1C1C1E] bg-transparent hover:text-[#1A3C2E]'
                      }`}
                    >
                      🎯 Select Specific Qualifications {selectedCourses.length > 0 ? `(${selectedCourses.length})` : ''}
                    </button>
                  </div>
                </div>

                {isOpenToAllCourses ? (
                  <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5]/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
                    <div className="flex items-center gap-2.5">
                      <span className="text-lg">🛠️</span>
                      <div>
                        <span className="font-bold text-[#1A3C2E] block">Open to All TVET Qualifications</span>
                        <span className="text-[#6C6C70]">Applicants from any TESDA national certificate or TVET course can apply.</span>
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => setIsOpenToAllCourses(false)}
                      className="px-4 py-2 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] font-bold text-xs border-0 cursor-pointer self-start sm:self-auto"
                    >
                      + Limit to Specific Qualifications
                    </button>
                  </div>
                ) : (
                  <div className="space-y-3 pt-2">
                    <div className="flex flex-wrap gap-2">
                      {TESDA_TVET_COURSES.map((tvetName) => {
                        const isChecked = selectedCourses.includes(tvetName);
                        return (
                          <button
                            key={tvetName}
                            type="button"
                            onClick={() => handleToggleCourse(tvetName)}
                            className={`px-3.5 py-2 rounded-xl text-xs font-semibold transition-all border cursor-pointer flex items-center gap-1.5 ${
                              isChecked
                                ? 'bg-[#1A3C2E] text-white border-[#1A3C2E] font-bold shadow-sm'
                                : 'bg-white text-[#1C1C1E] border-[#D9D2C5] hover:bg-[#EDE8DE]'
                            }`}
                          >
                            <span>{isChecked ? '✓' : '+'}</span>
                            <span>{tvetName}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Target Geographic Location & Scope */}
            <div className="p-6 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-5">
              <div>
                <h4 className="text-sm font-extrabold text-[#1A3C2E] uppercase tracking-wide flex items-center gap-2">
                  <span>📍</span>
                  <span>Target Geographic Location & Scope</span>
                </h4>
                <p className="text-xs text-[#6C6C70] mt-1">
                  Specify where applicants must be located or which regions/provinces/schools this program targets.
                </p>
              </div>

              {/* Scope Selection Cards */}
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
                {[
                  { id: 'nationwide', label: 'Nationwide', icon: '🌐', desc: 'Open to all PH applicants' },
                  { id: 'regional', label: 'Regional', icon: '🗺️', desc: 'Specific Regions' },
                  { id: 'provincial', label: 'Provincial', icon: '🏙️', desc: 'Specific Provinces' },
                  { id: 'municipality', label: 'City / Municipality', icon: '🏛️', desc: 'Specific Cities/Towns' },
                  { id: 'barangay', label: 'Barangay', icon: '🏘️', desc: 'Specific Barangays' },
                  { id: 'specific_schools', label: 'Specific Schools', icon: '🏫', desc: 'Targeted Institutions' },
                ].map((scopeItem) => {
                  const isSelected = availabilityScope === scopeItem.id;
                  return (
                    <button
                      key={scopeItem.id}
                      type="button"
                      onClick={() => setAvailabilityScope(scopeItem.id)}
                      className={`p-3 rounded-2xl text-left transition-all border cursor-pointer ${
                        isSelected
                          ? 'bg-[#1A3C2E] text-white border-[#1A3C2E] shadow-sm'
                          : 'bg-white text-[#1C1C1E] border-[#D9D2C5] hover:bg-[#EDE8DE]/60'
                      }`}
                    >
                      <div className="text-lg">{scopeItem.icon}</div>
                      <div className="text-xs font-bold mt-1.5">{scopeItem.label}</div>
                      <div className={`text-[10px] mt-0.5 ${isSelected ? 'text-emerald-200' : 'text-[#6C6C70]'}`}>
                        {scopeItem.desc}
                      </div>
                    </button>
                  );
                })}
              </div>

              {/* Scope Detail Options */}

              {/* 1. NATIONWIDE */}
              {availabilityScope === 'nationwide' && (
                <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5] flex items-center gap-3">
                  <span className="text-xl">🌐</span>
                  <p className="text-xs font-medium text-[#1A3C2E]">
                    This scholarship program will be open to eligible student applicants from all 17 administrative regions across the Philippines.
                  </p>
                </div>
              )}

              {/* 2. REGIONAL */}
              {availabilityScope === 'regional' && (
                <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5] space-y-3">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <div>
                      <span className="text-xs font-bold text-[#1A3C2E] uppercase block">
                        Select Eligible Regions ({availableRegions.length} selected):
                      </span>
                      <span className="text-[10px] text-[#2D5941] font-semibold flex items-center gap-1 mt-0.5">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                        {loadingPsgc ? '⏳ Fetching PSGC API Location Data...' : 'PSGC API Live Location Service'}
                      </span>
                    </div>
                    {availableRegions.length > 0 && (
                      <button
                        type="button"
                        onClick={() => setAvailableRegions([])}
                        className="text-[11px] font-bold text-rose-600 hover:underline border-0 bg-transparent cursor-pointer"
                      >
                        Clear All
                      </button>
                    )}
                  </div>

                  {/* PSGC Region Search Input */}
                  <input
                    type="text"
                    placeholder="Search PSGC region name or code (e.g. CALABARZON, NCR, Region III)..."
                    value={psgcSearchTerm}
                    onChange={(e) => setPsgcSearchTerm(e.target.value)}
                    className="w-full px-3.5 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-[#F9F5EF] focus:outline-none focus:bg-white"
                  />

                  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2 max-h-56 overflow-y-auto pr-1">
                    {(psgcRegions.length > 0 ? psgcRegions : FALLBACK_REGIONS_LIST)
                      .filter(r => 
                        !psgcSearchTerm || 
                        r.name.toLowerCase().includes(psgcSearchTerm.toLowerCase()) || 
                        (r.regionName && r.regionName.toLowerCase().includes(psgcSearchTerm.toLowerCase())) ||
                        r.code.includes(psgcSearchTerm)
                      )
                      .map((r) => {
                        const regionIdentifier = r.name;
                        const isChecked = availableRegions.includes(r.code) || availableRegions.includes(r.name) || availableRegions.includes(r.regionName);
                        return (
                          <button
                            key={r.code}
                            type="button"
                            onClick={() => {
                              if (isChecked) {
                                setAvailableRegions(prev => prev.filter(x => x !== r.code && x !== r.name && x !== r.regionName));
                              } else {
                                setAvailableRegions(prev => [...prev, regionIdentifier]);
                              }
                            }}
                            className={`px-3 py-2 rounded-xl text-xs font-semibold text-left transition-all border cursor-pointer flex items-center justify-between ${
                              isChecked
                                ? 'bg-[#1A3C2E] text-white border-[#1A3C2E]'
                                : 'bg-[#F9F5EF] text-[#1C1C1E] border-[#D9D2C5] hover:bg-[#EDE8DE]'
                            }`}
                          >
                            <span className="break-words">{r.name}</span>
                            <span className="text-[10px] font-bold ml-1 shrink-0">{isChecked ? '✓' : '+'}</span>
                          </button>
                        );
                      })}
                  </div>
                </div>
              )}

              {/* 3. PROVINCIAL */}
              {availabilityScope === 'provincial' && (
                <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5] space-y-3">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <span className="text-xs font-bold text-[#1A3C2E] uppercase">
                      Select Eligible Provinces (PSGC API):
                    </span>
                    <span className="text-[10px] text-[#2D5941] font-semibold flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                      PSGC API Live Data
                    </span>
                  </div>

                  {/* PSGC Province Quick Add Dropdown */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    <div>
                      <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">Filter Region (Optional):</label>
                      <select
                        value={selectedPsgcRegionCode}
                        onChange={(e) => setSelectedPsgcRegionCode(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-[#F9F5EF] focus:outline-none"
                      >
                        <option value="">All Administrative Regions</option>
                        {psgcRegions.map(r => (
                          <option key={r.code} value={r.code}>{r.name}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">Add PSGC Province:</label>
                      <select
                        onChange={(e) => {
                          const val = e.target.value;
                          if (val && !availableProvinces.includes(val)) {
                            setAvailableProvinces(prev => [...prev, val]);
                          }
                          e.target.value = '';
                        }}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none font-semibold text-[#1A3C2E]"
                      >
                        <option value="">-- Choose Province from PSGC API --</option>
                        {psgcProvinces.map(p => (
                          <option key={p.code} value={p.name}>{p.name}</option>
                        ))}
                      </select>
                    </div>
                  </div>

                  <div className="pt-2 border-t border-[#D9D2C5]/60">
                    <span className="text-[11px] font-bold text-[#6C6C70] block mb-1">Selected Target Provinces ({availableProvinces.length}):</span>
                    <TagInput
                      tags={availableProvinces}
                      placeholder="Type province name (e.g. Laguna, Cebu, Cavite) & press Enter..."
                      onAdd={(tag) => setAvailableProvinces(prev => [...prev, tag])}
                      onRemove={(index) => setAvailableProvinces(prev => prev.filter((_, i) => i !== index))}
                    />
                  </div>
                </div>
              )}

              {/* 4. MUNICIPALITY */}
              {availabilityScope === 'municipality' && (
                <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5] space-y-3">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <span className="text-xs font-bold text-[#1A3C2E] uppercase">
                      Select Eligible Cities & Municipalities (PSGC API):
                    </span>
                    <span className="text-[10px] text-[#2D5941] font-semibold flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                      PSGC API Live Data
                    </span>
                  </div>

                  {/* Cascading PSGC Selector: Region -> Province -> City */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    <div>
                      <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">1. Select Province:</label>
                      <select
                        value={selectedPsgcProvinceCode}
                        onChange={(e) => {
                          setSelectedPsgcProvinceCode(e.target.value);
                          setSelectedPsgcCityCode('');
                        }}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-[#F9F5EF] focus:outline-none"
                      >
                        <option value="">-- Choose Province --</option>
                        {psgcProvinces.map(p => (
                          <option key={p.code} value={p.code}>{p.name}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">2. Add City / Municipality:</label>
                      <select
                        disabled={!selectedPsgcProvinceCode || psgcCities.length === 0}
                        onChange={(e) => {
                          const val = e.target.value;
                          if (val && !availableMunicipalities.includes(val)) {
                            setAvailableMunicipalities(prev => [...prev, val]);
                          }
                          e.target.value = '';
                        }}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none font-semibold text-[#1A3C2E] disabled:opacity-50"
                      >
                        <option value="">
                          {!selectedPsgcProvinceCode 
                            ? '-- Select Province First --' 
                            : psgcCities.length === 0 
                            ? 'Loading Cities...' 
                            : '-- Choose City/Municipality --'}
                        </option>
                        {psgcCities.map(c => (
                          <option key={c.code} value={c.name}>{c.name}</option>
                        ))}
                      </select>
                    </div>
                  </div>

                  <div className="pt-2 border-t border-[#D9D2C5]/60">
                    <span className="text-[11px] font-bold text-[#6C6C70] block mb-1">Selected Target Cities/Municipalities ({availableMunicipalities.length}):</span>
                    <TagInput
                      tags={availableMunicipalities}
                      placeholder="Type city/municipality (e.g. Quezon City, Calamba, Davao City) & press Enter..."
                      onAdd={(tag) => setAvailableMunicipalities(prev => [...prev, tag])}
                      onRemove={(index) => setAvailableMunicipalities(prev => prev.filter((_, i) => i !== index))}
                    />
                  </div>
                </div>
              )}

              {/* 5. BARANGAY */}
              {availabilityScope === 'barangay' && (
                <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5] space-y-3">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <span className="text-xs font-bold text-[#1A3C2E] uppercase">
                      Select Eligible Barangays (PSGC API):
                    </span>
                    <span className="text-[10px] text-[#2D5941] font-semibold flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                      PSGC API Live Data
                    </span>
                  </div>

                  {/* Cascading PSGC Selector: Province -> City -> Barangay */}
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                    <div>
                      <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">1. Province:</label>
                      <select
                        value={selectedPsgcProvinceCode}
                        onChange={(e) => {
                          setSelectedPsgcProvinceCode(e.target.value);
                          setSelectedPsgcCityCode('');
                          setPsgcBarangays([]);
                        }}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-[#F9F5EF] focus:outline-none"
                      >
                        <option value="">-- Province --</option>
                        {psgcProvinces.map(p => (
                          <option key={p.code} value={p.code}>{p.name}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">2. City/Municipality:</label>
                      <select
                        value={selectedPsgcCityCode}
                        disabled={!selectedPsgcProvinceCode}
                        onChange={(e) => setSelectedPsgcCityCode(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-[#F9F5EF] focus:outline-none disabled:opacity-50"
                      >
                        <option value="">-- City/Town --</option>
                        {psgcCities.map(c => (
                          <option key={c.code} value={c.code}>{c.name}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">3. Add Barangay:</label>
                      <select
                        disabled={!selectedPsgcCityCode || psgcBarangays.length === 0}
                        onChange={(e) => {
                          const val = e.target.value;
                          if (val && !availableBarangays.includes(val)) {
                            setAvailableBarangays(prev => [...prev, val]);
                          }
                          e.target.value = '';
                        }}
                        className="w-full px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none font-semibold text-[#1A3C2E] disabled:opacity-50"
                      >
                        <option value="">
                          {!selectedPsgcCityCode
                            ? '-- Select City First --'
                            : psgcBarangays.length === 0
                            ? 'Loading Barangays...'
                            : '-- Choose Barangay --'}
                        </option>
                        {psgcBarangays.map(b => (
                          <option key={b.code} value={b.name}>{b.name}</option>
                        ))}
                      </select>
                    </div>
                  </div>

                  <div className="pt-2 border-t border-[#D9D2C5]/60">
                    <span className="text-[11px] font-bold text-[#6C6C70] block mb-1">Selected Target Barangays ({availableBarangays.length}):</span>
                    <TagInput
                      tags={availableBarangays}
                      placeholder="Type barangay name (e.g. Barangay Batasan Hills, Barangay 171) & press Enter..."
                      onAdd={(tag) => setAvailableBarangays(prev => [...prev, tag])}
                      onRemove={(index) => setAvailableBarangays(prev => prev.filter((_, i) => i !== index))}
                    />
                  </div>
                </div>
              )}

              {/* 6. SPECIFIC SCHOOLS */}
              {availabilityScope === 'specific_schools' && (
                <div className="p-4 rounded-2xl bg-white border border-[#D9D2C5] space-y-3">
                  <span className="text-xs font-bold text-[#1A3C2E] uppercase">Target Schools / Universities:</span>
                  <TagInput
                    tags={availableSchools}
                    placeholder="Type school name (e.g. UP Diliman, PUP, Ateneo) & press Enter..."
                    onAdd={(tag) => setAvailableSchools(prev => [...prev, tag])}
                    onRemove={(index) => setAvailableSchools(prev => prev.filter((_, i) => i !== index))}
                  />
                </div>
              )}
            </div>
          </div>
        )}

        {/* STEP 4: Document Requirements */}
        {currentStep === 4 && (
          <div className="space-y-6">
            <h3 className="text-lg font-extrabold text-[#1A3C2E] font-serif border-b border-[#EDE8DE] pb-3">
              4. Document Requirements Checklist
            </h3>

            {isNeedBasedCategory(category) && (
              <div className="p-4 rounded-2xl bg-amber-50 border border-amber-200 text-amber-900 flex items-start gap-3 text-xs">
                <span className="text-xl leading-none">💼</span>
                <div>
                  <span className="font-bold block text-sm text-amber-950 mb-0.5">Need-Based Scholarship Requirement</span>
                  <span className="text-amber-800 leading-relaxed">
                    Proof of Income / Certificate of Indigency is <strong>strictly mandatory</strong> for {category.toLowerCase()} programs. Applicants must upload valid proof (e.g. ITR, Certificate of Indigency, or Payslip) to establish financial eligibility.
                  </span>
                </div>
              </div>
            )}

            <div className="space-y-4">
              <div className="p-4 rounded-2xl bg-[#F9F5EF] border border-[#D9D2C5]/80 space-y-3">
                <h4 className="text-xs font-bold text-[#1A3C2E] uppercase tracking-wide">
                  + Add Required Document
                </h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <input
                    type="text"
                    placeholder="Document Name (e.g., Certificate of Good Moral Character)"
                    value={newRequirementName}
                    onChange={(e) => setNewRequirementName(e.target.value)}
                    className="px-4 py-3 rounded-2xl border border-[#D9D2C5] text-sm focus:outline-none bg-white font-medium"
                  />
                  <input
                    type="text"
                    placeholder="Instructions / Hint (Optional - e.g., From school registrar or dean)"
                    value={newRequirementDesc}
                    onChange={(e) => setNewRequirementDesc(e.target.value)}
                    className="px-4 py-3 rounded-2xl border border-[#D9D2C5] text-sm focus:outline-none bg-white"
                  />
                </div>
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-1">
                  <label className="flex items-center gap-2 text-xs font-bold text-[#1C1C1E] cursor-pointer">
                    <input
                      type="checkbox"
                      checked={newRequirementRequired}
                      onChange={(e) => setNewRequirementRequired(e.target.checked)}
                      className="w-4 h-4 text-[#1A3C2E] rounded cursor-pointer"
                    />
                    <span>Mandatory (Applicant cannot submit application without this document)</span>
                  </label>
                  <button
                    type="button"
                    onClick={handleAddRequirement}
                    className="px-5 py-2.5 rounded-2xl bg-[#1A3C2E] text-white text-xs font-bold border-0 cursor-pointer hover:bg-[#2D5941] shadow-sm transition-all self-end sm:self-auto"
                  >
                    + Add Document
                  </button>
                </div>
              </div>

              <div className="space-y-2 pt-2">
                {requirementsList.map((req, idx) => {
                  const isEditing = editingReqIdx === idx;
                  const reqName = typeof req === 'string' ? req : req.name;
                  const reqDesc = typeof req === 'string' ? '' : req.description;
                  const isRequired = typeof req === 'string' ? true : req.required !== false;
                  const isIncome = isIncomeProofRequirement(req);
                  const isLockedNeedBased = isNeedBasedCategory(category) && isIncome;

                  if (isEditing) {
                    return (
                      <div key={idx} className="p-4 rounded-2xl bg-white border-2 border-[#1A3C2E] shadow-sm space-y-3 text-xs">
                        <div className="flex items-center justify-between">
                          <span className="font-bold text-[#1A3C2E] text-xs uppercase tracking-wider">✏️ Edit Requirement #{idx + 1}</span>
                          <span className="text-[10px] text-[#6C6C70]">Editing Document Rules</span>
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                          <div>
                            <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">Requirement Name *</label>
                            <input
                              type="text"
                              value={editingReqName}
                              onChange={(e) => setEditingReqName(e.target.value)}
                              placeholder="e.g. Official Transcript of Records (TOR)"
                              className="w-full px-3.5 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-[#F9F5EF] focus:bg-white focus:outline-none font-bold text-[#1A3C2E]"
                            />
                          </div>
                          <div>
                            <label className="text-[10px] font-bold text-[#6C6C70] block uppercase mb-1">Instructions / Note for Scholar</label>
                            <input
                              type="text"
                              value={editingReqDesc}
                              onChange={(e) => setEditingReqDesc(e.target.value)}
                              placeholder="e.g. Must be signed by University Registrar"
                              className="w-full px-3.5 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-[#F9F5EF] focus:bg-white focus:outline-none"
                            />
                          </div>
                        </div>
                        <div className="flex items-center justify-between flex-wrap gap-2 pt-1 border-t border-[#EDE8DE]">
                          <label className={`flex items-center gap-2 text-xs font-semibold ${isLockedNeedBased ? 'text-amber-800' : 'text-[#1A3C2E] cursor-pointer'}`}>
                            <input
                              type="checkbox"
                              checked={isLockedNeedBased ? true : editingReqRequired}
                              disabled={isLockedNeedBased}
                              onChange={(e) => setEditingReqRequired(e.target.checked)}
                              className="w-4 h-4 text-[#1A3C2E] rounded cursor-pointer disabled:opacity-50"
                            />
                            <span>
                              Mandatory (Required for submission)
                              {isLockedNeedBased && (
                                <span className="ml-2 text-[10px] font-bold text-amber-700 bg-amber-100 px-2 py-0.5 rounded-md">
                                  🔒 Locked: Mandatory for Need-Based Programs
                                </span>
                              )}
                            </span>
                          </label>
                          <div className="flex items-center gap-2">
                            <button
                              type="button"
                              onClick={handleCancelEditRequirement}
                              className="px-3.5 py-1.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] font-bold text-xs cursor-pointer border-0 transition-all"
                            >
                              Cancel
                            </button>
                            <button
                              type="button"
                              onClick={() => handleSaveEditRequirement(idx)}
                              className="px-4 py-1.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white font-bold text-xs cursor-pointer border-0 shadow-sm transition-all"
                            >
                              Save Changes
                            </button>
                          </div>
                        </div>
                      </div>
                    );
                  }

                  return (
                    <div key={idx} className="flex items-center justify-between p-4 rounded-2xl bg-[#F9F5EF] border border-[#D9D2C5]/60 text-xs hover:border-[#1A3C2E]/30 transition-all">
                      <div className="flex items-start gap-3">
                        <span className="text-base leading-none mt-0.5">📄</span>
                        <div>
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="font-bold text-[#1A3C2E] text-sm">{reqName}</span>
                            {isLockedNeedBased ? (
                              <span className="text-[9px] font-bold px-2 py-0.5 rounded-md bg-amber-100 text-amber-800 border border-amber-300">
                                🔒 MANDATORY (NEED-BASED)
                              </span>
                            ) : (
                              <span className={`text-[9px] font-bold px-2 py-0.5 rounded-md ${isRequired ? 'bg-red-50 text-red-600 border border-red-200' : 'bg-slate-100 text-slate-500'}`}>
                                {isRequired ? 'REQUIRED' : 'OPTIONAL'}
                              </span>
                            )}
                          </div>
                          {reqDesc && (
                            <p className="text-[11px] text-[#6C6C70] mt-0.5">{reqDesc}</p>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <button
                          type="button"
                          onClick={() => handleStartEditRequirement(idx)}
                          className="text-[#1A3C2E] font-extrabold hover:underline border-0 bg-transparent cursor-pointer text-xs flex items-center gap-1"
                        >
                          ✏️ Edit
                        </button>
                        <span className="text-[#D9D2C5]">|</span>
                        <button
                          type="button"
                          onClick={() => handleRemoveRequirement(idx)}
                          disabled={isLockedNeedBased}
                          title={isLockedNeedBased ? "Proof of Income is mandatory for Need-Based scholarships and cannot be removed." : "Remove requirement"}
                          className={`font-bold hover:underline border-0 bg-transparent text-xs ${
                            isLockedNeedBased ? 'text-gray-400 cursor-not-allowed opacity-60' : 'text-rose-600 cursor-pointer'
                          }`}
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        )}

        {/* STEP 5: Review & Publish */}
        {currentStep === 5 && (
          <div className="space-y-6">
            <h3 className="text-lg font-extrabold text-[#1A3C2E] font-serif border-b border-[#EDE8DE] pb-3">
              5. Review & Confirm Program Configuration
            </h3>

            <div className="p-6 rounded-3xl bg-[#F9F5EF] border border-[#D9D2C5] space-y-5 text-xs">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <span className="text-[#6C6C70] block uppercase font-bold text-[10px]">Program Title</span>
                  <span className="text-sm font-extrabold text-[#1A3C2E]">{title || 'Untitled'}</span>
                </div>
                <div>
                  <span className="text-[#6C6C70] block uppercase font-bold text-[10px]">Category & Level</span>
                  <span className="text-sm font-bold text-[#1A3C2E]">{category} • {targetLevel}</span>
                </div>
                <div>
                  <span className="text-[#6C6C70] block uppercase font-bold text-[10px]">Grant Budget</span>
                  <span className="text-sm font-mono font-bold text-[#1A3C2E]">₱{Number(amount).toLocaleString()} {fundingFreq}</span>
                </div>
                <div>
                  <span className="text-[#6C6C70] block uppercase font-bold text-[10px]">Slots</span>
                  <span className="text-sm font-bold text-[#1A3C2E]">{totalSlots || 'Unlimited'} Available Slots</span>
                </div>
                <div className="col-span-2 p-3 bg-white rounded-2xl border border-[#D9D2C5]">
                  <span className="text-[#6C6C70] block uppercase font-bold text-[10px]">📅 Application Intake Period</span>
                  <span className="text-xs font-bold text-[#1A3C2E] block mt-0.5">
                    {cycleName || 'Active Intake Cycle'}: {applicationStartDate} → {applicationEndDate}
                  </span>
                </div>
              </div>

              {/* Year Levels Review */}
              <div className="pt-3 border-t border-[#D9D2C5]/50">
                <span className="text-[#6C6C70] block uppercase font-bold text-[10px] mb-1.5">Eligible Year Levels ({selectedYearLevels.length})</span>
                <div className="flex flex-wrap gap-1.5">
                  {selectedYearLevels.map((val) => (
                    <span key={val} className="px-2.5 py-1 rounded-lg bg-white border border-[#D9D2C5] text-[11px] font-bold text-[#1A3C2E]">
                      ✓ {getYearLevelLabel(targetLevel, val)}
                    </span>
                  ))}
                </div>
              </div>

              {/* Courses / Strands Review */}
              <div className="pt-3 border-t border-[#D9D2C5]/50">
                <span className="text-[#6C6C70] block uppercase font-bold text-[10px] mb-1.5">
                  {targetLevel === 'senior_high' ? 'Eligible Strands' : targetLevel === 'high_school' || targetLevel === 'elementary' ? 'Curriculum' : 'Eligible Degree Programs'}
                </span>
                <div className="flex flex-wrap gap-1.5">
                  {targetLevel === 'high_school' || targetLevel === 'elementary' ? (
                    <span className="px-2.5 py-1 rounded-lg bg-white border border-[#D9D2C5] text-[11px] font-bold text-[#1A3C2E]">
                      📘 General Basic Education Curriculum
                    </span>
                  ) : isOpenToAllCourses || selectedCourses.length === 0 ? (
                    <span className="px-2.5 py-1 rounded-lg bg-white border border-[#D9D2C5] text-[11px] font-bold text-[#1A3C2E]">
                      🌐 {targetLevel === 'senior_high' ? 'Open to All Senior High Strands' : targetLevel === 'vocational' ? 'Open to All TVET Qualifications' : 'Open to All Degree Programs'}
                    </span>
                  ) : (
                    selectedCourses.map((c, i) => (
                      <span key={i} className="px-2.5 py-1 rounded-lg bg-white border border-[#D9D2C5] text-[11px] font-bold text-[#1A3C2E]">
                        🎓 {c}
                      </span>
                    ))
                  )}
                </div>
              </div>

              {/* Coverage & Benefits Review */}
              <div className="pt-3 border-t border-[#D9D2C5]/50">
                <span className="text-[#6C6C70] block uppercase font-bold text-[10px] mb-1.5">Included Benefits & Coverage</span>
                <div className="flex flex-wrap gap-1.5">
                  {coversTuition && (
                    <span className="px-2.5 py-1 rounded-lg bg-[#EBF5EE] border border-[#CEEAD6] text-[11px] font-bold text-[#137333]">
                      🏛️ {tuitionCoverageType === 'fixed_cap' && Number(tuitionMaxAmount) > 0 ? `Tuition Subsidy Cap ₱${Number(tuitionMaxAmount).toLocaleString()}` : 'Full Tuition Covered'}
                    </span>
                  )}
                  {coversStipend && (
                    <span className="px-2.5 py-1 rounded-lg bg-[#EBF5EE] border border-[#CEEAD6] text-[11px] font-bold text-[#137333]">
                      🍱 Stipend / Allowance ₱{Number(stipendAmount).toLocaleString()}
                    </span>
                  )}
                  {coversAllowance && (
                    <span className="px-2.5 py-1 rounded-lg bg-[#EBF5EE] border border-[#CEEAD6] text-[11px] font-bold text-[#137333]">
                      📚 Book / Device ₱{Number(allowanceAmount).toLocaleString()}
                    </span>
                  )}
                  {customBenefitsList.map((cb, i) => (
                    <span key={i} className="px-2.5 py-1 rounded-lg bg-[#EBF5EE] border border-[#CEEAD6] text-[11px] font-bold text-[#137333]">
                      🎁 {cb.title}: ₱{Number(cb.amount).toLocaleString()} ({cb.frequency})
                    </span>
                  ))}
                </div>
              </div>

              {/* Disbursement Release Method Review */}
              <div className="pt-3 border-t border-[#D9D2C5]/50">
                <span className="text-[#6C6C70] block uppercase font-bold text-[10px] mb-1.5">Disbursement Release Channel</span>
                <span className="px-2.5 py-1 rounded-lg bg-[#EBF5EE] border border-[#CEEAD6] text-[11px] font-bold text-[#137333] inline-flex items-center gap-1.5">
                  {disbursementMode === 'online_transfer' ? (
                    <>
                      <span>🌐</span>
                      <span>Online Transfer ({onlineBankType === 'personal_bank' ? "Scholar Personal Bank / E-Wallet" : "Provider-Issued ATM Card"})</span>
                    </>
                  ) : (
                    <>
                      <span>💵</span>
                      <span>Over-the-Counter Cash (On-Site Release)</span>
                    </>
                  )}
                </span>
              </div>

              {isFreshmanTarget && (
                <div className="p-3.5 rounded-2xl bg-[#E6F4EA] text-[#137333] font-bold">
                  ✓ Configured for Incoming College Freshmen. Applicants will be requested to provide High School, Target College, and Option Course choices.
                </div>
              )}

              <div className="pt-3 border-t border-[#D9D2C5]/50">
                <span className="text-[#6C6C70] block uppercase font-bold text-[10px] mb-2">Required Document Checklist ({requirementsList.length})</span>
                <div className="flex flex-wrap gap-1.5">
                  {requirementsList.map((r, i) => {
                    const rName = typeof r === 'string' ? r : r.name;
                    return (
                      <span key={i} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white border border-[#D9D2C5] text-[11px] font-bold text-[#1A3C2E]">
                        📄 {rName}
                      </span>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Bottom Wizard Actions */}
        <div className="flex items-center justify-between pt-6 border-t border-[#EDE8DE]">
          {currentStep > 1 ? (
            <button
              type="button"
              onClick={() => handleGoToStep(currentStep - 1)}
              className="px-5 py-2.5 rounded-xl bg-[#EDE8DE] hover:bg-[#D9D2C5] text-[#1A3C2E] text-xs font-bold border-0 cursor-pointer"
            >
              ← Back to Step {currentStep - 1}
            </button>
          ) : (
            <div></div>
          )}

          {currentStep < 5 ? (
            <button
              type="button"
              onClick={() => handleGoToStep(currentStep + 1)}
              disabled={!validateStep(currentStep).valid}
              className={`px-6 py-2.5 rounded-xl text-xs font-bold border-0 cursor-pointer shadow-sm transition-all flex items-center gap-2 ${
                !validateStep(currentStep).valid
                  ? 'bg-gray-300 text-gray-500 cursor-not-allowed opacity-60'
                  : 'bg-[#1A3C2E] hover:bg-[#2D5941] text-white'
              }`}
              title={
                !validateStep(currentStep).valid
                  ? validateStep(currentStep).error
                  : undefined
              }
            >
              <span>Next: Step {currentStep + 1} →</span>
            </button>
          ) : (
            <button
              type="button"
              onClick={(e) => handleSubmitForm(e)}
              disabled={isSubmitting || !validateStep(1).valid || !validateStep(2).valid || !validateStep(3).valid || !validateStep(4).valid}
              className="px-8 py-3 rounded-2xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-sm font-extrabold border-0 cursor-pointer shadow-lg transition-all disabled:opacity-50 flex items-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                  Processing...
                </>
              ) : isEditMode ? (
                '💾 Save Program Changes'
              ) : (
                '🚀 Publish Scholarship Program'
              )}
            </button>
          )}
        </div>
      </form>
    </div>
  );
};



const FALLBACK_REGIONS_LIST: PSGCRegion[] = [
  { code: '1300000000', name: 'NCR - National Capital Region', regionName: 'NCR' },
  { code: '140000000', name: 'CAR - Cordillera Administrative Region', regionName: 'CAR' },
  { code: '010000000', name: 'Region I - Ilocos Region', regionName: 'Ilocos Region' },
  { code: '020000000', name: 'Region II - Cagayan Valley', regionName: 'Cagayan Valley' },
  { code: '030000000', name: 'Region III - Central Luzon', regionName: 'Central Luzon' },
  { code: '040000000', name: 'Region IV-A - CALABARZON', regionName: 'CALABARZON' },
  { code: '170000000', name: 'MIMAROPA Region', regionName: 'MIMAROPA' },
  { code: '050000000', name: 'Region V - Bicol Region', regionName: 'Bicol Region' },
  { code: '060000000', name: 'Region VI - Western Visayas', regionName: 'Western Visayas' },
  { code: '070000000', name: 'Region VII - Central Visayas', regionName: 'Central Visayas' },
  { code: '080000000', name: 'Region VIII - Eastern Visayas', regionName: 'Eastern Visayas' },
  { code: '090000000', name: 'Region IX - Zamboanga Peninsula', regionName: 'Zamboanga Peninsula' },
  { code: '100000000', name: 'Region X - Northern Mindanao', regionName: 'Northern Mindanao' },
  { code: '110000000', name: 'Region XI - Davao Region', regionName: 'Davao Region' },
  { code: '120000000', name: 'Region XII - SOCCSKSARGEN', regionName: 'SOCCSKSARGEN' },
  { code: '130000000', name: 'Region XIII - Caraga', regionName: 'Caraga' },
  { code: '150000000', name: 'BARMM - Bangsamoro Autonomous Region', regionName: 'BARMM' },
];

const TagInput: React.FC<{
  tags: string[];
  placeholder: string;
  onAdd: (tag: string) => void;
  onRemove: (index: number) => void;
}> = ({ tags, placeholder, onAdd, onRemove }) => {
  const [inputVal, setInputVal] = useState('');

  const handleAdd = () => {
    const trimmed = inputVal.trim();
    if (!trimmed) return;
    const items = trimmed.split(',').map(s => s.trim()).filter(Boolean);
    items.forEach(item => {
      if (!tags.includes(item)) {
        onAdd(item);
      }
    });
    setInputVal('');
  };

  return (
    <div className="space-y-2">
      <div className="flex gap-2">
        <input
          type="text"
          value={inputVal}
          placeholder={placeholder}
          onChange={(e) => setInputVal(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              handleAdd();
            }
          }}
          className="flex-1 px-4 py-2.5 rounded-xl border border-[#D9D2C5] text-xs bg-white focus:outline-none"
        />
        <button
          type="button"
          onClick={handleAdd}
          className="px-4 py-2.5 rounded-xl bg-[#1A3C2E] text-white text-xs font-bold border-0 cursor-pointer hover:bg-[#2D5941]"
        >
          + Add
        </button>
      </div>

      {tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5 pt-1">
          {tags.map((tag, idx) => (
            <span
              key={idx}
              className="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl bg-[#EDE8DE] text-[#1A3C2E] text-xs font-semibold"
            >
              <span>{tag}</span>
              <button
                type="button"
                onClick={() => onRemove(idx)}
                className="hover:text-rose-600 border-0 bg-transparent cursor-pointer text-xs font-bold ml-1"
              >
                ×
              </button>
            </span>
          ))}
        </div>
      )}
    </div>
  );
};

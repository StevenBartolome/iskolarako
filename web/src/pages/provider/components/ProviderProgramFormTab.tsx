import React, { useState, useMemo } from 'react';
import type { Program, EducationLevel, GradingSystem, ProgramRequirement } from '../types';
import {
  YEAR_LEVELS_BY_EDUCATION_LEVEL,
  SHS_STRANDS,
  CHED_COLLEGE_COURSES,
  TESDA_TVET_COURSES,
  parseYearLevelsToNumbers,
  getYearLevelLabel,
} from '../constants/academicCatalog';

interface ProviderProgramFormTabProps {
  programToEdit?: Program | null;
  onCancel: () => void;
  onSubmit: (formData: any, isEditMode: boolean) => Promise<void>;
  providerDetails?: any;
}

export const ProviderProgramFormTab: React.FC<ProviderProgramFormTabProps> = ({
  programToEdit,
  onCancel,
  onSubmit,
}) => {
  const isEditMode = Boolean(programToEdit);

  // Form step state (1 to 5)
  const [currentStep, setCurrentStep] = useState(1);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Step 1: Basic Info
  const [title, setTitle] = useState(programToEdit?.title || '');
  const [category, setCategory] = useState(programToEdit?.category || 'Merit-Based');
  const [targetLevel, setTargetLevel] = useState<EducationLevel>(
    programToEdit?.target_education_level || programToEdit?.targetEducationLevel || 'college'
  );
  const [description, setDescription] = useState(programToEdit?.description || '');

  // Step 1: Application Intake Period (Opening & Closing Dates)
  const defaultStartDate = new Date().toISOString().split('T')[0];
  const defaultEndDate = new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString().split('T')[0];
  const initialCycle = programToEdit?.cycles && programToEdit.cycles.length > 0 ? programToEdit.cycles[0] : null;

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
  const [fundingFreq, setFundingFreq] = useState(
    programToEdit?.funding_frequency || programToEdit?.fundingFrequency || 'Per Semester'
  );
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
  const [gradingSystem, setGradingSystem] = useState<GradingSystem>(
    programToEdit?.grading_system || programToEdit?.gradingSystem || 'scale_5'
  );
  const [gpaRequirement, setGpaRequirement] = useState(
    programToEdit?.gpa_requirement || programToEdit?.minimum_gwa || programToEdit?.minimumGwa
      ? String(programToEdit.gpa_requirement || programToEdit.minimum_gwa || programToEdit.minimumGwa)
      : ''
  );
  const [incomeCeiling, setIncomeCeiling] = useState(
    programToEdit?.income_ceiling ? String(programToEdit.income_ceiling) : ''
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

  // Re-sync on programToEdit change so editing an existing program always pre-selects its saved values
  React.useEffect(() => {
    if (programToEdit) {
      setTitle(programToEdit.title || '');
      setCategory(programToEdit.category || 'Merit-Based');
      const lvl = (programToEdit.target_education_level || programToEdit.targetEducationLevel || 'college') as EducationLevel;
      setTargetLevel(lvl);
      setDescription(programToEdit.description || '');
      setAmount(
        programToEdit.budget_total || programToEdit.amount || programToEdit.budgetTotal
          ? String(programToEdit.budget_total || programToEdit.amount || programToEdit.budgetTotal).replace(/[^0-9.]/g, '')
          : ''
      );
      setFundingFreq(programToEdit.funding_frequency || programToEdit.fundingFrequency || 'Per Semester');
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
      setGradingSystem((programToEdit.grading_system || programToEdit.gradingSystem || 'scale_5') as GradingSystem);
      setGpaRequirement(
        programToEdit.gpa_requirement || programToEdit.minimum_gwa || programToEdit.minimumGwa
          ? String(programToEdit.gpa_requirement || programToEdit.minimum_gwa || programToEdit.minimumGwa)
          : ''
      );
      setIncomeCeiling(programToEdit.income_ceiling ? String(programToEdit.income_ceiling) : '');

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

      // Pre-populate intake cycle dates
      const cyc = programToEdit.cycles && programToEdit.cycles.length > 0 ? programToEdit.cycles[0] : null;
      if (cyc) {
        setCycleName(cyc.name || `AY ${new Date().getFullYear()}-${new Date().getFullYear() + 1}`);
        if (cyc.startDate) setApplicationStartDate(cyc.startDate);
        if (cyc.endDate) setApplicationEndDate(cyc.endDate);
      }

      // Pre-populate requirements
      const rawReqs =
        programToEdit.application_requirements ??
        programToEdit.applicationRequirements;
      if (Array.isArray(rawReqs) && rawReqs.length > 0) {
        setRequirementsList(rawReqs.map((r: any) => {
          if (typeof r === 'string') return { name: r, description: '', required: true };
          return {
            name: r.name || r.document_name || 'Required Document',
            description: r.description || '',
            required: r.required !== false,
          };
        }));
      }
    }
  }, [programToEdit]);

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

  // Step 4: Requirements Checklist
  const [requirementsList, setRequirementsList] = useState<ProgramRequirement[]>(() => {
    const raw = programToEdit?.application_requirements || programToEdit?.applicationRequirements;
    if (Array.isArray(raw) && raw.length > 0) {
      return raw.map((r: any) => {
        if (typeof r === 'string') {
          return { name: r, description: '', required: true };
        }
        return {
          name: r.name || r.document_name || 'Required Document',
          description: r.description || '',
          required: r.required !== false,
        };
      });
    }
    return [
      { name: 'Transcript of Records / Certificate of Grades', description: 'Official TOR or certified grade slip', required: true },
      { name: 'Certificate of Good Moral Character', description: 'Issued by school dean or principal', required: true },
      { name: 'Certificate of Indigency / Proof of Income', description: 'ITR or Barangay Certificate of Indigency', required: true },
      { name: 'Valid Government / Student ID', description: 'Government-issued ID or current School ID', required: true },
    ];
  });
  const [newRequirementName, setNewRequirementName] = useState('');
  const [newRequirementDesc, setNewRequirementDesc] = useState('');
  const [newRequirementRequired, setNewRequirementRequired] = useState(true);

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

  const handleRemoveRequirement = (idx: number) => {
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
        total_slots: parseInt(totalSlots, 10) || 0,
        coverstuition: coversTuition,
        coversStipend: coversStipend,
        stipendAmount: parseFloat(stipendAmount) || 0,
        coversAllowance: coversAllowance,
        allowanceAmount: parseFloat(allowanceAmount) || 0,
        otherBenefits,
        grading_system: gradingSystem,
        minimumGwa: gpaRequirement,
        income_ceiling: incomeCeiling,
        eligible_courses: finalCourses,
        eligible_year_levels: selectedYearLevels,
        applicationRequirements: requirementsList,
        allow_freshman_intended_school: allowFreshmanIntendedSchool,
        is_incoming_freshman_supported: isFreshmanTarget,
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
              disabled={isSubmitting || !title.trim()}
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
                onClick={() => setCurrentStep(step.num)}
                className={`text-left p-3 rounded-2xl transition-all border-0 cursor-pointer flex flex-col gap-1 ${
                  isActive
                    ? 'bg-[#1A3C2E] text-white shadow-sm'
                    : isCompleted
                    ? 'bg-[#E6F4EA] text-[#137333]'
                    : 'bg-[#F9F5EF] text-[#6C6C70] hover:bg-[#EDE8DE]'
                }`}
              >
                <div className="flex items-center justify-between text-[11px] font-bold">
                  <span>Step {step.num}</span>
                  {isCompleted && <span>✓</span>}
                </div>
                <span className="text-xs font-extrabold truncate">{step.name}</span>
              </button>
            );
          })}
        </div>
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
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none focus:border-[#1A3C2E] text-sm bg-white cursor-pointer font-medium"
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

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
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
                    <span className="block text-xs font-bold text-[#1C1C1E]">Monthly Stipend</span>
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
                      <label className="block text-xs font-bold text-[#1C1C1E] mb-1">Stipend Amount (₱/mo)</label>
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

            {/* Low Budget Alert Threshold */}
            <div className="p-5 rounded-3xl bg-[#FFF8EE] border border-[#F5EAD6] space-y-2">
              <h4 className="text-xs font-bold text-[#C97B2E] uppercase tracking-wide flex items-center gap-1.5">
                <span>⚠️</span> Low Budget Warning Alert Threshold
              </h4>
              <p className="text-[11px] text-[#6C6C70] leading-relaxed">
                Set at what percentage of remaining budget the system should trigger a <strong>Low Program Budget Warning Alert</strong>.
              </p>
              <div className="flex items-center gap-3 pt-1">
                <input
                  type="number"
                  min="5"
                  max="50"
                  value={lowBudgetThreshold}
                  onChange={(e) => setLowBudgetThreshold(e.target.value)}
                  className="w-24 px-3 py-2 rounded-xl border border-[#D9D2C5] text-xs bg-white font-bold text-[#1A3C2E] text-center"
                />
                <span className="text-xs font-bold text-[#1A3C2E]">% Remaining Budget</span>
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
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Grading Scale System
                </label>
                <select
                  value={gradingSystem}
                  onChange={(e) => setGradingSystem(e.target.value as GradingSystem)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm bg-white font-medium cursor-pointer"
                >
                  <option value="scale_5">1.00 - 5.00 Scale (PH University System)</option>
                  <option value="scale_4">4.00 Scale (US System)</option>
                  <option value="percentage">Percentage (e.g. 88% - 100%)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                  Minimum Required GWA / GPA
                </label>
                <input
                  type="text"
                  placeholder="e.g. 1.75 or 85%"
                  value={gpaRequirement}
                  onChange={(e) => setGpaRequirement(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm font-semibold"
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
                <p className="text-[11px] font-bold text-amber-700 bg-amber-50 p-2.5 rounded-xl border border-amber-200 mt-2">
                  ⚠️ Please select at least one eligible year level for applicants.
                </p>
              )}
            </div>

            {/* Income Ceiling */}
            <div>
              <label className="block text-xs font-bold text-[#1C1C1E] uppercase tracking-wide mb-2">
                Annual Household Income Ceiling (PHP)
              </label>
              <input
                type="number"
                placeholder="e.g. 300000 (Leave empty if no financial limit)"
                value={incomeCeiling}
                onChange={(e) => setIncomeCeiling(e.target.value)}
                className="w-full px-4 py-3 rounded-2xl border border-[#D9D2C5] focus:outline-none text-sm"
              />
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
          </div>
        )}

        {/* STEP 4: Document Requirements */}
        {currentStep === 4 && (
          <div className="space-y-6">
            <h3 className="text-lg font-extrabold text-[#1A3C2E] font-serif border-b border-[#EDE8DE] pb-3">
              4. Document Requirements Checklist
            </h3>

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
                  const reqName = typeof req === 'string' ? req : req.name;
                  const reqDesc = typeof req === 'string' ? '' : req.description;
                  const isRequired = typeof req === 'string' ? true : req.required !== false;

                  return (
                    <div key={idx} className="flex items-center justify-between p-4 rounded-2xl bg-[#F9F5EF] border border-[#D9D2C5]/60 text-xs hover:border-[#1A3C2E]/30 transition-all">
                      <div className="flex items-start gap-3">
                        <span className="text-base leading-none mt-0.5">📄</span>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-[#1A3C2E] text-sm">{reqName}</span>
                            <span className={`text-[9px] font-bold px-2 py-0.5 rounded-md ${isRequired ? 'bg-red-50 text-red-600 border border-red-200' : 'bg-slate-100 text-slate-500'}`}>
                              {isRequired ? 'REQUIRED' : 'OPTIONAL'}
                            </span>
                          </div>
                          {reqDesc && (
                            <p className="text-[11px] text-[#6C6C70] mt-0.5">{reqDesc}</p>
                          )}
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => handleRemoveRequirement(idx)}
                        className="text-rose-600 font-bold hover:underline border-0 bg-transparent cursor-pointer text-xs"
                      >
                        Remove
                      </button>
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
              onClick={() => setCurrentStep(currentStep - 1)}
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
              onClick={() => setCurrentStep(currentStep + 1)}
              className="px-6 py-2.5 rounded-xl bg-[#1A3C2E] hover:bg-[#2D5941] text-white text-xs font-bold border-0 cursor-pointer shadow-sm"
            >
              Next: Step {currentStep + 1} →
            </button>
          ) : (
            <button
              type="button"
              onClick={(e) => handleSubmitForm(e)}
              disabled={isSubmitting || !title.trim()}
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

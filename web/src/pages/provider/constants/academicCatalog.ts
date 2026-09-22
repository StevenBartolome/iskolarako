export interface YearLevelOption {
  label: string;
  value: number;
}

export const YEAR_LEVELS_BY_EDUCATION_LEVEL: Record<string, { label: string; options: YearLevelOption[] }> = {
  incoming_college: {
    label: 'Incoming College Intake',
    options: [
      { label: 'Incoming 1st Year / Freshmen', value: 1 },
      { label: 'Graduating Senior High (Grade 12)', value: 12 },
    ],
  },
  college: {
    label: 'College / University Undergraduate Years',
    options: [
      { label: '1st Year', value: 1 },
      { label: '2nd Year', value: 2 },
      { label: '3rd Year', value: 3 },
      { label: '4th Year', value: 4 },
      { label: '5th Year', value: 5 },
    ],
  },
  senior_high: {
    label: 'Senior High School Grades',
    options: [
      { label: 'Grade 11', value: 11 },
      { label: 'Grade 12', value: 12 },
    ],
  },
  high_school: {
    label: 'Junior High School Grades',
    options: [
      { label: 'Grade 7', value: 7 },
      { label: 'Grade 8', value: 8 },
      { label: 'Grade 9', value: 9 },
      { label: 'Grade 10', value: 10 },
    ],
  },
  elementary: {
    label: 'Elementary School Grades',
    options: [
      { label: 'Grade 1', value: 1 },
      { label: 'Grade 2', value: 2 },
      { label: 'Grade 3', value: 3 },
      { label: 'Grade 4', value: 4 },
      { label: 'Grade 5', value: 5 },
      { label: 'Grade 6', value: 6 },
    ],
  },
  graduate: {
    label: 'Graduate School Levels',
    options: [
      { label: "Master's Year 1", value: 1 },
      { label: "Master's Year 2", value: 2 },
      { label: 'Doctorate Year 1', value: 3 },
      { label: 'Doctorate Year 2+', value: 4 },
    ],
  },
  vocational: {
    label: 'Vocational / TVET Terms',
    options: [
      { label: 'NC I / 1st Term', value: 1 },
      { label: 'NC II / 2nd Term', value: 2 },
      { label: 'NC III / 3rd Term', value: 3 },
      { label: 'NC IV / 4th Term', value: 4 },
    ],
  },
};

export function parseYearLevelsToNumbers(raw: any): number[] {
  if (!raw) return [];
  const list = Array.isArray(raw) ? raw : String(raw).split(',');
  const numbers: number[] = [];
  for (const item of list) {
    if (typeof item === 'number') {
      if (!numbers.includes(item)) numbers.push(item);
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
  return numbers;
}

export function getYearLevelLabel(educationLevel: string, value: number): string {
  const config = YEAR_LEVELS_BY_EDUCATION_LEVEL[educationLevel] || YEAR_LEVELS_BY_EDUCATION_LEVEL.college;
  const match = config.options.find(o => o.value === value);
  if (match) return match.label;
  if (educationLevel === 'senior_high' || educationLevel === 'high_school' || educationLevel === 'elementary') {
    return `Grade ${value}`;
  }
  return `Year ${value}`;
}

export interface ShsStrandItem {
  track: string;
  name: string;
  code: string;
}

export const SHS_STRANDS: ShsStrandItem[] = [
  { track: 'Academic Track', name: 'STEM (Science, Technology, Engineering, and Mathematics)', code: 'STEM' },
  { track: 'Academic Track', name: 'ABM (Accountancy, Business, and Management)', code: 'ABM' },
  { track: 'Academic Track', name: 'HUMSS (Humanities and Social Sciences)', code: 'HUMSS' },
  { track: 'Academic Track', name: 'GAS (General Academic Strand)', code: 'GAS' },
  { track: 'Technical-Vocational-Livelihood (TVL)', name: 'TVL - Information and Communications Technology (ICT)', code: 'TVL-ICT' },
  { track: 'Technical-Vocational-Livelihood (TVL)', name: 'TVL - Home Economics (HE)', code: 'TVL-HE' },
  { track: 'Technical-Vocational-Livelihood (TVL)', name: 'TVL - Industrial Arts (IA)', code: 'TVL-IA' },
  { track: 'Technical-Vocational-Livelihood (TVL)', name: 'TVL - Agri-Fishery Arts (AFA)', code: 'TVL-AFA' },
  { track: 'Specialized Tracks', name: 'Arts and Design Track', code: 'ARTS' },
  { track: 'Specialized Tracks', name: 'Sports Track', code: 'SPORTS' },
];

export interface CourseCategory {
  category: string;
  icon: string;
  courses: string[];
}

export const CHED_COLLEGE_COURSES: CourseCategory[] = [
  {
    category: 'Information Technology & Computing',
    icon: 'laptop',
    courses: [
      'BS Computer Science',
      'BS Information Technology',
      'BS Information Systems',
      'BS Data Science',
      'BS Cybersecurity',
      'BS Software Engineering',
      'BS Computer Engineering',
      'BS Animation & Game Development',
    ],
  },
  {
    category: 'Engineering & Architecture',
    icon: 'building',
    courses: [
      'BS Civil Engineering',
      'BS Mechanical Engineering',
      'BS Electrical Engineering',
      'BS Electronics Engineering (ECE)',
      'BS Chemical Engineering',
      'BS Industrial Engineering',
      'BS Architecture',
      'BS Geodetic Engineering',
      'BS Aeronautical Engineering',
      'BS Sanitary Engineering',
    ],
  },
  {
    category: 'Health & Medical Sciences',
    icon: 'stethoscope',
    courses: [
      'BS Nursing',
      'BS Medical Technology / Medical Laboratory Science',
      'BS Pharmacy',
      'BS Physical Therapy',
      'BS Radiologic Technology',
      'Doctor of Dental Medicine (DMD)',
      'Doctor of Medicine (MD)',
      'BS Public Health',
      'BS Nutrition and Dietetics',
      'BS Occupational Therapy',
    ],
  },
  {
    category: 'Business, Accountancy & Management',
    icon: 'bar-chart',
    courses: [
      'BS Accountancy',
      'BS Management Accounting',
      'BS Business Administration - Financial Management',
      'BS Business Administration - Marketing Management',
      'BS Business Administration - Human Resource Management',
      'BS Entrepreneurship',
      'BS Real Estate Management',
      'BS Hospitality Management / Hotel & Restaurant Management',
      'BS Tourism Management',
      'BS Customs Administration',
    ],
  },
  {
    category: 'Sciences & Mathematics',
    icon: 'microscope',
    courses: [
      'BS Biology',
      'BS Chemistry',
      'BS Physics',
      'BS Applied Mathematics',
      'BS Statistics',
      'BS Environmental Science',
      'BS Marine Biology',
      'BS Geology',
      'BS Biochemistry',
    ],
  },
  {
    category: 'Teacher Education',
    icon: 'book-open',
    courses: [
      'Bachelor of Elementary Education (BEEd)',
      'Bachelor of Secondary Education - Major in English',
      'Bachelor of Secondary Education - Major in Mathematics',
      'Bachelor of Secondary Education - Major in Science',
      'Bachelor of Secondary Education - Major in Filipino',
      'Bachelor of Secondary Education - Major in Social Studies',
      'Bachelor of Special Needs Education (BSNEd)',
      'Bachelor of Early Childhood Education (BECEd)',
      'Bachelor of Physical Education (BPEd)',
      'Bachelor of Technical-Vocational Teacher Education (BTVTEd)',
    ],
  },
  {
    category: 'Social Sciences, Humanities & Law',
    icon: 'scale',
    courses: [
      'BA Communication / Mass Communication',
      'BA / BS Psychology',
      'BA Political Science',
      'Bachelor of Public Administration',
      'BS Criminology',
      'BS Social Work',
      'Bachelor of Laws (LL.B) / Juris Doctor (J.D.)',
      'BA Journalism',
      'BA Sociology',
      'BA English Language Studies',
      'BA International Studies',
    ],
  },
  {
    category: 'Agriculture, Forestry & Fisheries',
    icon: 'sprout',
    courses: [
      'BS Agriculture',
      'BS Forestry',
      'BS Fisheries',
      'BS Agricultural and Biosystems Engineering',
      'BS Agribusiness',
      'Doctor of Veterinary Medicine (DVM)',
    ],
  },
  {
    category: 'Maritime & Aviation',
    icon: 'anchor',
    courses: [
      'BS Marine Transportation',
      'BS Marine Engineering',
      'BS Aviation / Commercial Aviation',
      'BS Aircraft Maintenance Technology',
    ],
  },
];

export const TESDA_TVET_COURSES = [
  'Automotive Servicing NC I / II / III',
  'Shielded Metal Arc Welding (SMAW) NC I / II',
  'Computer Systems Servicing (CSS) NC II',
  'Cookery & Culinary Arts NC II',
  'Bread and Pastry Production NC II',
  'Food and Beverage Services NC II',
  'Caregiving NC II',
  'Electrical Installation & Maintenance (EIM) NC II',
  'Plumbing NC II',
  'Tile Setting & Carpentry NC II',
  'Tourism Promotion & Tour Guiding NC II',
  'Agricultural Crop Production NC II',
  'Electronic Products Assembly & Servicing (EPAS) NC II',
  'Heavy Equipment Operation NC II',
  'RAC Servicing (Airconditioning) NC II',
];

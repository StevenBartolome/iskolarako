export interface Scholarship {
  id: string;
  title: string;
  provider: string;
  amount: number;
  deadline: string;
  status: 'Approved' | 'Pending' | 'Released';
  category: string;
  description: string;
}

export const MOCK_SCHOLARSHIPS: Scholarship[] = [
  {
    id: '1',
    title: 'DOST SEI Merit Scholarship',
    provider: 'Department of Science and Technology',
    amount: 40000,
    deadline: '2026-08-30',
    status: 'Approved',
    category: 'STEM',
    description: 'Financial assistance for deserving students taking up priority science & technology courses.',
  },
  {
    id: '2',
    title: 'CHED Higher Education Grant',
    provider: 'Commission on Higher Education',
    amount: 30000,
    deadline: '2026-09-15',
    status: 'Pending',
    category: 'General Academic',
    description: 'Grant to support qualified tertiary students studying in recognized institutions.',
  },
  {
    id: '3',
    title: 'SM Foundation College Scholarship',
    provider: 'SM Foundation',
    amount: 50000,
    deadline: '2026-10-01',
    status: 'Released',
    category: 'Engineering & IT',
    description: 'Full tuition and stipend assistance for deserving scholars across the Philippines.',
  },
];

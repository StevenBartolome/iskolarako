const List<String> shsStrands = [
  'STEM (Science, Technology, Engineering, and Mathematics)',
  'ABM (Accountancy, Business, and Management)',
  'HUMSS (Humanities and Social Sciences)',
  'GAS (General Academic Strand)',
  'TVL - Information and Communications Technology (ICT)',
  'TVL - Home Economics (HE)',
  'TVL - Industrial Arts (IA)',
  'TVL - Agri-Fishery Arts (AFA)',
  'Arts and Design Track',
  'Sports Track',
];

const List<String> collegeCourses = [
  // IT & Computing
  'BS Computer Science',
  'BS Information Technology',
  'BS Information Systems',
  'BS Data Science',
  'BS Cybersecurity',
  'BS Software Engineering',
  'BS Computer Engineering',
  'BS Animation & Game Development',
  
  // Engineering & Architecture
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
  
  // Health & Medical
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
  
  // Business & Management
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
  
  // Sciences & Mathematics
  'BS Biology',
  'BS Chemistry',
  'BS Physics',
  'BS Applied Mathematics',
  'BS Statistics',
  'BS Environmental Science',
  'BS Marine Biology',
  'BS Geology',
  'BS Biochemistry',
  
  // Education
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
  
  // Social Sciences & Law
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
  
  // Agriculture & Forestry
  'BS Agriculture',
  'BS Forestry',
  'BS Fisheries',
  'BS Agricultural and Biosystems Engineering',
  'BS Agribusiness',
  'Doctor of Veterinary Medicine (DVM)',
  
  // Maritime & Aviation
  'BS Marine Transportation',
  'BS Marine Engineering',
  'BS Aviation / Commercial Aviation',
  'BS Aircraft Maintenance Technology',
];

const List<String> tesdaTvetCourses = [
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

List<String> getCoursesByEducationLevel(String? educationLevel) {
  if (educationLevel == null) return collegeCourses;
  
  switch (educationLevel.toLowerCase().trim()) {
    case 'senior_high':
      return shsStrands;
    case 'vocational':
      return tesdaTvetCourses;
    case 'college':
    case 'graduate':
    case 'incoming_college':
    default:
      return collegeCourses;
  }
}

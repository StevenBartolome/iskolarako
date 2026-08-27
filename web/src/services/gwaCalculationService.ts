export type GradingScale = 'scale_5' | 'scale_4' | 'percentage';

export interface SubjectGrade {
  subject: string;
  grade: string | number;
  units: string | number;
}

/**
 * Normalizes any GWA/GPA score to a standard 0-100 percentage.
 * - scale_5: 1.0 is highest (100%), 5.0 is lowest/failing (0%)
 * - scale_4: 4.0 is highest (100%), 0.0 or 1.0 is lowest/failing (0%)
 * - percentage: already 0-100%
 */
export function normalizeGwaToPercent(gwa: number, scale: GradingScale): number {
  if (isNaN(gwa) || gwa === 0) return 0;
  
  switch (scale) {
    case 'scale_4':
      // 4.0 = 100%, 1.0 = 0% (or 0.0 = 0%). Standardizing 1.0-4.0 range:
      // (val - 1) / (4 - 1) is standard, but simple linear (gwa / 4) * 100 is cleaner.
      // Let's use (gwa / 4.0) * 100.0, capped at 100.
      return Math.min(100, Math.max(0, (gwa / 4.0) * 100.0));
    case 'percentage':
      return Math.min(100, Math.max(0, gwa));
    case 'scale_5':
    default:
      // 1.0 = 100%, 5.0 = 0% (Inverted PH State University system)
      // Conversion: ((5.0 - gwa) / 4.0) * 100
      return Math.min(100, Math.max(0, ((5.0 - gwa) / 4.0) * 100.0));
  }
}

/**
 * Parses a string grade value to a numeric representation.
 * Handles letter grades by converting them to equivalent numbers on a 4.0 scale if relevant,
 * or returns null if unparseable.
 */
export function parseGradeValue(gradeStr: string | number): number | null {
  if (gradeStr === null || gradeStr === undefined) return null;
  if (typeof gradeStr === 'number') return gradeStr;

  const cleanStr = String(gradeStr).trim().toUpperCase();
  if (!cleanStr) return null;

  // Try direct numeric parse
  const parsed = parseFloat(cleanStr);
  if (!isNaN(parsed)) return parsed;

  // Letter grades to 4.0 scale mapping helper
  const letterMap: Record<string, number> = {
    'A+': 4.0, 'A': 4.0, 'A-': 3.7,
    'B+': 3.3, 'B': 3.0, 'B-': 2.7,
    'C+': 2.3, 'C': 2.0, 'C-': 1.7,
    'D+': 1.3, 'D': 1.0, 'F': 0.0,
    'INC': 0.0, 'DRP': 0.0, 'PASSED': 1.0,
  };

  return letterMap[cleanStr] !== undefined ? letterMap[cleanStr] : null;
}

/**
 * Calculates overall GWA from an array of subject grades.
 * Weighted average formula: Sum of (Grade * Units) / Sum of Units
 */
export function computeGwaFromSubjects(subjects: SubjectGrade[], _scale: GradingScale): number | null {
  if (!subjects || subjects.length === 0) return null;

  let totalPoints = 0;
  let totalUnits = 0;
  let validSubjectsCount = 0;

  for (const sub of subjects) {
    const grade = parseGradeValue(sub.grade);
    const units = typeof sub.units === 'number' ? sub.units : parseFloat(String(sub.units).trim());

    if (grade !== null && !isNaN(grade) && units !== null && !isNaN(units) && units > 0) {
      totalPoints += grade * units;
      totalUnits += units;
      validSubjectsCount++;
    }
  }

  if (totalUnits === 0 || validSubjectsCount === 0) return null;

  const rawGwa = totalPoints / totalUnits;
  
  // Format GWA to 2 or 3 decimal places depending on scale
  return Number(rawGwa.toFixed(3));
}

/**
 * Checks if a scholar GWA meets a program's minimum GWA requirement, 
 * using scale-aware normalized percentage values.
 */
export function meetsGwaRequirement(
  scholarGwa: number,
  scholarScale: GradingScale,
  requiredMinGwa: number,
  programScale: GradingScale
): boolean {
  const scholarPercent = normalizeGwaToPercent(scholarGwa, scholarScale);
  const requiredPercent = normalizeGwaToPercent(requiredMinGwa, programScale);
  
  // Since scale_5 is inverted (lower numeric GWA means better grade), 
  // checking normalized percentages (higher is better) is always: scholarPercent >= requiredPercent
  return scholarPercent >= requiredPercent;
}

export interface SchoolCatalogItem {
  name: string;
  defaultScale: GradingScale;
}

export const PHILIPPINE_SCHOOLS_CATALOG: SchoolCatalogItem[] = [
  // --- National University (NU) System ---
  { name: 'National University Manila', defaultScale: 'scale_4' },
  { name: 'National University Baliwag', defaultScale: 'scale_4' },
  { name: 'National University Clark', defaultScale: 'scale_4' },
  { name: 'National University MOA', defaultScale: 'scale_4' },
  { name: 'National University Laguna', defaultScale: 'scale_4' },
  { name: 'National University Lipa', defaultScale: 'scale_4' },
  { name: 'National University Fairview', defaultScale: 'scale_4' },
  { name: 'National University Dasmariñas', defaultScale: 'scale_4' },
  { name: 'National University Nazareth School', defaultScale: 'scale_4' },
  { name: 'National University', defaultScale: 'scale_4' },

  // --- University of the Philippines (UP) System ---
  { name: 'University of the Philippines Diliman', defaultScale: 'scale_5' },
  { name: 'University of the Philippines Manila', defaultScale: 'scale_5' },
  { name: 'University of the Philippines Los Baños', defaultScale: 'scale_5' },
  { name: 'University of the Philippines Visayas', defaultScale: 'scale_5' },
  { name: 'University of the Philippines Mindanao', defaultScale: 'scale_5' },
  { name: 'University of the Philippines Open University', defaultScale: 'scale_5' },
  { name: 'University of the Philippines Baguio', defaultScale: 'scale_5' },
  { name: 'University of the Philippines Cebu', defaultScale: 'scale_5' },
  { name: 'University of the Philippines', defaultScale: 'scale_5' },

  // --- De La Salle University (DLSU) System ---
  { name: 'De La Salle University Manila', defaultScale: 'scale_4' },
  { name: 'De La Salle University Dasmariñas', defaultScale: 'scale_4' },
  { name: 'De La Salle Santiago Zobel School', defaultScale: 'scale_4' },
  { name: 'De La Salle Araneta University', defaultScale: 'scale_4' },
  { name: 'De La Salle - College of Saint Benilde', defaultScale: 'scale_4' },
  { name: 'De La Salle University', defaultScale: 'scale_4' },

  // --- Ateneo System ---
  { name: 'Ateneo de Manila University', defaultScale: 'scale_4' },
  { name: 'Ateneo de Davao University', defaultScale: 'scale_4' },
  { name: 'Ateneo de Zamboanga University', defaultScale: 'scale_4' },
  { name: 'Ateneo de Naga University', defaultScale: 'scale_4' },
  { name: 'Xavier University - Ateneo de Cagayan', defaultScale: 'scale_4' },

  // --- Far Eastern University (FEU) System ---
  { name: 'Far Eastern University Manila', defaultScale: 'scale_4' },
  { name: 'Far Eastern University Alabang', defaultScale: 'scale_4' },
  { name: 'Far Eastern University Diliman', defaultScale: 'scale_4' },
  { name: 'FEU Institute of Technology (FEU Tech)', defaultScale: 'scale_4' },
  { name: 'FEU Cavite', defaultScale: 'scale_4' },
  { name: 'Far Eastern University', defaultScale: 'scale_4' },

  // --- Polytechnic University of the Philippines (PUP) ---
  { name: 'Polytechnic University of the Philippines Manila', defaultScale: 'scale_5' },
  { name: 'Polytechnic University of the Philippines Taguig', defaultScale: 'scale_5' },
  { name: 'Polytechnic University of the Philippines Quezon City', defaultScale: 'scale_5' },
  { name: 'Polytechnic University of the Philippines Santa Maria', defaultScale: 'scale_5' },
  { name: 'Polytechnic University of the Philippines', defaultScale: 'scale_5' },

  // --- Other Major Philippine HEIs ---
  { name: 'University of Santo Tomas', defaultScale: 'scale_5' },
  { name: 'Mapua University', defaultScale: 'scale_5' },
  { name: 'University of the East', defaultScale: 'scale_5' },
  { name: 'Adamson University', defaultScale: 'scale_5' },
  { name: 'Technological University of the Philippines', defaultScale: 'scale_5' },
  { name: 'Technological Institute of the Philippines', defaultScale: 'scale_5' },
  { name: 'Centro Escolar University', defaultScale: 'scale_5' },
  { name: 'San Beda University', defaultScale: 'scale_5' },
  { name: 'Batangas State University', defaultScale: 'scale_5' },
  { name: 'Bulacan State University', defaultScale: 'scale_5' },
  { name: 'Cavite State University', defaultScale: 'scale_5' },
  { name: 'Pamantasan ng Lungsod ng Maynila', defaultScale: 'scale_5' },
  { name: 'Mindanao State University', defaultScale: 'scale_5' },
  { name: 'Bicol University', defaultScale: 'scale_5' },
  { name: 'Cebu Technological University', defaultScale: 'scale_5' },
  { name: 'West Visayas State University', defaultScale: 'scale_5' },
  { name: 'Central Luzon State University', defaultScale: 'scale_5' },
  { name: 'University of Southeastern Philippines', defaultScale: 'scale_5' },
  { name: 'Silliman University', defaultScale: 'scale_4' },
  { name: 'Saint Louis University Baguio', defaultScale: 'scale_5' },
  { name: 'University of San Carlos', defaultScale: 'scale_5' },
  { name: 'University of San Jose - Recoletos', defaultScale: 'scale_5' },
];

export function getSchoolDefaultScale(schoolName: string): GradingScale | null {
  if (!schoolName) return null;
  const cleanName = schoolName.toLowerCase().trim();
  
  // Find match
  const match = PHILIPPINE_SCHOOLS_CATALOG.find(
    (s) => cleanName === s.name.toLowerCase().trim() || 
           cleanName.includes(s.name.toLowerCase().trim()) || 
           s.name.toLowerCase().trim().includes(cleanName)
  );
  
  return match ? match.defaultScale : null;
}


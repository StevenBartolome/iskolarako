export type GradingScale = 'scale_5' | 'scale_4' | 'percentage';

export interface SubjectGrade {
  subject: string;
  grade: string | number;
  units: string | number;
}

// scale_5 lookup table: [gwaValue, midpointPercent]
// Source: Philippine Standard GWA table (lower GWA = better grade)
const SCALE_5_TABLE: [number, number][] = [
  [1.00, 98.5],
  [1.25, 95.0],
  [1.50, 92.0],
  [1.75, 89.0],
  [2.00, 86.0],
  [2.25, 83.0],
  [2.50, 80.0],
  [2.75, 77.0],
  [3.00, 75.0],
  [5.00, 55.0],
];

// scale_4 lookup table: [gradePoint, midpointPercent]
// Source: NU / DLSU / Ateneo Grade Point System (higher grade point = better)
const SCALE_4_TABLE: [number, number][] = [
  [4.0, 98.0],
  [3.5, 92.5],
  [3.0, 86.5],
  [2.5, 80.5],
  [2.0, 74.5],
  [1.5, 68.5],
  [1.0, 62.5],
  [0.0, 55.0],
];

/** Linearly interpolates within a lookup table sorted ascending by key. */
function interpolateLookup(table: [number, number][], value: number): number {
  if (table.length === 0) return 0;
  if (value <= table[0][0]) return table[0][1];
  if (value >= table[table.length - 1][0]) return table[table.length - 1][1];

  for (let i = 0; i < table.length - 1; i++) {
    const [k0, v0] = table[i];
    const [k1, v1] = table[i + 1];
    if (value >= k0 && value <= k1) {
      const fraction = (value - k0) / (k1 - k0);
      return v0 + fraction * (v1 - v0);
    }
  }
  return table[table.length - 1][1];
}

/**
 * Normalizes any GWA/GPA score to a standard 0-100 percentage
 * using official Philippine grading lookup tables.
 *
 * scale_5: Philippine Standard (1.00 is best → ~98.5%, 3.00 passing → 75%, 5.00 failing → <60%)
 * scale_4: NU/DLSU/Ateneo system (4.0 is best → ~98%, 1.0 passing → ~62.5%, 0.0 failing → <60%)
 * percentage: value is already 0–100
 */
export function normalizeGwaToPercent(gwa: number, scale: GradingScale): number {
  if (isNaN(gwa) || gwa === 0) return 0;
  if (gwa > 5.0 || scale === 'percentage') {
    return Math.min(100, Math.max(0, gwa));
  }

  switch (scale) {
    case 'scale_4': {
      // Table is sorted descending by grade point (4.0 best → 0.0 worst)
      // Reverse to ascending for interpolation, then interpolate, then reverse direction
      const ascTable: [number, number][] = [...SCALE_4_TABLE].reverse();
      return Math.min(100, Math.max(0, interpolateLookup(ascTable, gwa)));
    }
    case 'scale_5':
    default: {
      // Table is sorted ascending by GWA (1.00 best → 5.00 worst), percent descending
      // For interpolation: as GWA increases, percent decreases — handled by interpolateLookup
      return Math.min(100, Math.max(0, interpolateLookup(SCALE_5_TABLE, gwa)));
    }
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


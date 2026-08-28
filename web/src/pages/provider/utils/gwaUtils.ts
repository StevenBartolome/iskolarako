/**
 * Normalizes any student GWA/GPA into a standard 0–100 score regardless of grading scale.
 *
 * Uses the same Philippine Standard lookup tables as the mobile EligibilityHelper
 * (eligibility_helper.dart) with linear interpolation between rows.
 *
 * - Scale 5.0 (PH system: 1.00 is best, 3.00 passing → 75%, 5.00 failing → 55%)
 * - Scale 4.0 (NU/DLSU/Ateneo: 4.00 is best → 98%, 0.00 failing → 55%)
 * - Percentage: passthrough clamped to 0–100.
 */

// Philippine Standard GWA lookup table — lower GWA = better grade
// [gwaValue, midpointPercent]
const SCALE5_TABLE: [number, number][] = [
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

// NU / DLSU / Ateneo grade-point lookup table — higher grade point = better
// [gradePoint, midpointPercent]
const SCALE4_TABLE: [number, number][] = [
  [0.0, 55.0],
  [1.0, 62.5],
  [1.5, 68.5],
  [2.0, 74.5],
  [2.5, 80.5],
  [3.0, 86.5],
  [3.5, 92.5],
  [4.0, 98.0],
];

/** Linearly interpolates a value within a lookup table sorted ascending by key. */
const interpolate = (table: [number, number][], value: number): number => {
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
};

export const normalizeGwa = (rawGrade: any, scale: string = 'scale_5'): number => {
  if (rawGrade === null || rawGrade === undefined || String(rawGrade).trim() === '') {
    return 0;
  }

  const numericGrade = parseFloat(String(rawGrade).replace(/[^0-9\.]/g, ''));
  if (isNaN(numericGrade)) {
    return 0;
  }

  const s = (scale || 'scale_5').toLowerCase().trim();

  if (s.includes('percent') || s === 'percentage' || numericGrade > 5.0) {
    // Percentage scale — passthrough (also handles raw percentage grades > 5)
    return parseFloat(Math.min(100, Math.max(0, numericGrade)).toFixed(2));
  } else if (s.includes('4') || s === 'scale_4') {
    // Scale 4.0 (higher is better) — use lookup table
    const clamped = Math.min(4.0, Math.max(0.0, numericGrade));
    return parseFloat(interpolate(SCALE4_TABLE, clamped).toFixed(2));
  } else {
    // Default: Scale 5.0 (lower is better) — use Philippine Standard lookup table
    const clamped = Math.min(5.0, Math.max(1.0, numericGrade));
    return parseFloat(interpolate(SCALE5_TABLE, clamped).toFixed(2));
  }
};

/**
 * Ranks candidates by Normalized GWA score (highest first), then by submission date (earliest first).
 */
export const rankCandidates = (candidates: any[]): any[] => {
  return [...candidates].sort((a, b) => {
    const scaleA = a.gpa_scale || a.gpaScale || a.scholar?.gpa_scale || 'scale_5';
    const scaleB = b.gpa_scale || b.gpaScale || b.scholar?.gpa_scale || 'scale_5';

    const scoreA = normalizeGwa(a.grade || a.gpa || a.scholar?.gpa, scaleA);
    const scoreB = normalizeGwa(b.grade || b.gpa || b.scholar?.gpa, scaleB);

    if (scoreB !== scoreA) {
      return scoreB - scoreA; // Higher normalized score first
    }

    // Tie-breaker: Submission date (earliest first)
    const dateA = new Date(a.created_at || a.date || 0).getTime();
    const dateB = new Date(b.created_at || b.date || 0).getTime();
    return dateA - dateB;
  });
};

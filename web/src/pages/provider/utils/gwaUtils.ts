/**
 * Normalizes any student GWA/GPA into a standard 0-100 score regardless of grading scale.
 * 
 * - Scale 5.0 (PH system: 1.00 is best, 3.00 passing, 5.00 failing)
 *   Score = max(0, 100 - ((gwa - 1.00) / 4.00) * 100)
 *   e.g. 1.00 -> 100%, 1.25 -> 93.75%, 1.50 -> 87.5%, 3.00 -> 50%
 * 
 * - Scale 4.0 (US system: 4.00 is best, 0.00 worst)
 *   Score = (gpa / 4.00) * 100
 *   e.g. 4.00 -> 100%, 3.50 -> 87.5%
 * 
 * - Percentage (100% is best)
 *   Score = grade
 *   e.g. 95 -> 95%
 */
export const normalizeGwa = (rawGrade: any, scale: string = 'scale_5'): number => {
  if (rawGrade === null || rawGrade === undefined || String(rawGrade).trim() === '') {
    return 0;
  }

  const numericGrade = parseFloat(String(rawGrade).replace(/[^0-9\.]/g, ''));
  if (isNaN(numericGrade)) {
    return 0;
  }

  const s = (scale || 'scale_5').toLowerCase().trim();

  if (s.includes('4') || s === 'scale_4') {
    // 4.0 Scale
    const clamped = Math.min(4.0, Math.max(0, numericGrade));
    return parseFloat(((clamped / 4.0) * 100).toFixed(2));
  } else if (s.includes('percent') || s === 'percentage') {
    // Percentage Scale (75-100)
    const clamped = Math.min(100, Math.max(0, numericGrade));
    return parseFloat(clamped.toFixed(2));
  } else {
    // Default: Scale 5.0 (1.0 - 5.0)
    if (numericGrade > 5.0) {
      return parseFloat(Math.min(100, numericGrade).toFixed(2));
    }
    const clamped = Math.min(5.0, Math.max(1.0, numericGrade));
    const score = 100 - ((clamped - 1.0) / 4.0) * 100;
    return parseFloat(Math.max(0, score).toFixed(2));
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

/**
 * Helper function to sort application cycles from newest to oldest (newest first).
 */
export const sortCyclesNewestFirst = (cyclesList: any[] | undefined | null): any[] => {
  if (!cyclesList || !Array.isArray(cyclesList)) return [];
  return [...cyclesList].sort((a: any, b: any) => {
    // 1. Compare created_at / createdAt timestamp
    const createdA = a.created_at || a.createdAt;
    const createdB = b.created_at || b.createdAt;
    const tCreatedA = createdA ? new Date(createdA).getTime() : 0;
    const tCreatedB = createdB ? new Date(createdB).getTime() : 0;
    if (tCreatedA > 0 && tCreatedB > 0 && tCreatedA !== tCreatedB) {
      return tCreatedB - tCreatedA; // Newest creation timestamp first
    }

    // 2. Compare application_start_date / startDate
    const startA = a.application_start_date || a.startDate;
    const startB = b.application_start_date || b.startDate;
    const tStartA = startA ? new Date(startA).getTime() : 0;
    const tStartB = startB ? new Date(startB).getTime() : 0;
    if (tStartA > 0 && tStartB > 0 && tStartA !== tStartB) {
      return tStartB - tStartA; // Newest start date first
    }

    // 3. Compare Academic Year parsed from name or cycle_name (e.g. "AY 2026-2027 1st Semester")
    const nameA = String(a.name || a.cycle_name || '');
    const nameB = String(b.name || b.cycle_name || '');
    const yearMatchA = nameA.match(/\b(20\d{2})\b/);
    const yearMatchB = nameB.match(/\b(20\d{2})\b/);
    const yearA = yearMatchA ? parseInt(yearMatchA[1], 10) : 0;
    const yearB = yearMatchB ? parseInt(yearMatchB[1], 10) : 0;
    if (yearA !== yearB) {
      return yearB - yearA; // Higher year first
    }

    // 4. Compare Semester rank parsed from name
    const getSemRank = (str: string) => {
      const lower = str.toLowerCase();
      if (lower.includes('2nd') || lower.includes('second')) return 2;
      if (lower.includes('1st') || lower.includes('first')) return 1;
      if (lower.includes('summer')) return 1.5;
      return 0;
    };

    const semA = getSemRank(nameA);
    const semB = getSemRank(nameB);
    if (semA !== semB) {
      return semB - semA; // 2nd sem before 1st sem
    }

    // 5. Fallback comparison using ID
    return String(b.id || '').localeCompare(String(a.id || ''));
  });
};

/**
 * Sanitizes requirements_submitted JSON payload to ensure that metadata fields
 * (_aiVerification, _docStatus) only retain entries for active uploaded document URLs.
 */
export function sanitizeRequirementsSubmitted(reqs: Record<string, any>): Record<string, any> {
  if (!reqs || typeof reqs !== 'object') return {};
  const cleaned: Record<string, any> = { ...reqs };

  // Identify active uploaded file URLs (non-metadata keys with valid URL strings)
  const activeDocKeys = Object.keys(cleaned).filter(
    key => !key.startsWith('_') && typeof cleaned[key] === 'string' && cleaned[key].trim().length > 0
  );

  // Clean _aiVerification so it only retains entries for active uploaded document URLs
  if (cleaned._aiVerification && typeof cleaned._aiVerification === 'object') {
    const cleanedAi: Record<string, any> = {};
    activeDocKeys.forEach(docName => {
      if (cleaned._aiVerification[docName]) {
        cleanedAi[docName] = cleaned._aiVerification[docName];
      }
    });
    if (Object.keys(cleanedAi).length > 0) {
      cleaned._aiVerification = cleanedAi;
    } else {
      delete cleaned._aiVerification;
    }
  }

  // Clean _docStatus so it only retains entries for active uploaded document URLs
  if (cleaned._docStatus && typeof cleaned._docStatus === 'object') {
    const cleanedStatus: Record<string, any> = {};
    activeDocKeys.forEach(docName => {
      if (cleaned._docStatus[docName]) {
        cleanedStatus[docName] = cleaned._docStatus[docName];
      }
    });
    if (Object.keys(cleanedStatus).length > 0) {
      cleaned._docStatus = cleanedStatus;
    } else {
      delete cleaned._docStatus;
    }
  }

  return cleaned;
}

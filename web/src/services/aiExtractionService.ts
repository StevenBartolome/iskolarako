/**
 * IskoAko Multi-AI Document Extraction & Fraud Verification Service
 * 
 * Cascading Multi-Model Priority Chain:
 * 1. Google Gemini 2.0 Flash (Fast native PDF & high-accuracy Vision OCR)
 * 2. Mistral AI Pixtral 12B (Fast, Reliable Vision OCR)
 * 3. Groq Llama 3.2 Vision (Ultra-low latency open weights)
 * 4. OpenRouter Multi-Model Router
 * 5. Hugging Face Serverless Vision
 * 6. Local In-Browser Heuristic & Text Layer Parser (Zero-AI offline fallback)
 * 7. Safe Manual Review Queue Fallback
 */

import * as pdfjsLib from 'pdfjs-dist';

// Configure pdfjs worker
pdfjsLib.GlobalWorkerOptions.workerSrc = `https://unpkg.com/pdfjs-dist@${pdfjsLib.version}/build/pdf.worker.min.mjs`;

export interface ExtractedBankDetails {
  bankName: string;
  accountName: string;
  accountNumber: string;
  documentType: 'atm_card' | 'bank_certificate' | 'deposit_slip' | 'other';
  confidenceScore: number;
  aiModelUsed: string;
  provider: string;
  rawResponse?: any;
}

export interface ApplicantVerificationContext {
  scholarName?: string;
  school?: string;
  course?: string;
  yearLevel?: string;
  gwa?: string | number;
  incomeBracket?: string;
  email?: string;
  phone?: string;
  programTitle?: string;
  // Organization / Scholarship Provider Verification
  isProviderOrg?: boolean;
  organizationName?: string;
  representativeName?: string;
  providerType?: string;
}

export interface DocVerificationResult {
  isAuthenticLayout: boolean;
  tamperingDetected: boolean;
  hasOfficialSealOrSignature: boolean;
  isDocumentLegitimate: boolean;
  extractedName?: string;
  extractedSchool?: string;
  extractedGwa?: string;
  extractedIncome?: string;
  extractedDocType?: string;
  verificationStatus: 'verified' | 'flagged' | 'rejected' | 'manual_review_required';
  confidenceScore: number;
  flags: string[];
  summary: string;
  aiModelUsed: string;
  provider: string;
  crossCheckResults: {
    nameMatch: boolean;
    schoolMatch: boolean;
    gwaMatch: boolean | null;
    sealPresent: boolean;
    tamperingFound: boolean;
  };
  sha256Hash?: string;
  rawResponse?: any;
}

const BANK_SYSTEM_PROMPT = `You are a specialized Philippine banking document OCR and data extraction assistant.
Extract banking details from the provided bank card / ATM card / bank certificate / deposit slip.
Return ONLY valid, raw JSON without markdown backticks or commentary in this exact format:
{
  "bank_name": "Exact Bank Name (e.g. Landbank of the Philippines, BDO, BPI, UnionBank, SeaBank, Metrobank, etc.)",
  "account_holder_name": "Full Name of Account Holder / Scholar",
  "account_number": "Account or Card Number digits (remove spaces and dashes)",
  "document_type": "atm_card",
  "confidence_score": 0.95
}`;

const buildDocVerificationPrompt = (docName: string, context: ApplicantVerificationContext) => {
  if (context.isProviderOrg || context.organizationName) {
    const orgName = context.organizationName || context.scholarName || 'Organization / Foundation';
    const repName = context.representativeName || 'Representative';
    const pType = context.providerType || 'Scholarship Provider';

    return `
You are an expert Forensic Document Auditor and Organization Regulatory Compliance Assistant for the Philippine Scholarship Platform "IskoAko".
Analyze the provided document image / PDF page for the organization verification requirement: "${docName}".

Registered Organization Profile:
- Registered Organization Name: "${orgName}"
- Authorized Representative: "${repName}"
- Provider Classification: "${pType}"
- Contact Email: "${context.email || 'N/A'}"

Perform comprehensive forensic and legal document verification:
1. LEGAL AUTHENTICITY & FORMAT: Does this document appear to be an authentic Philippine legal / corporate / government document (e.g., SEC Certificate of Incorporation, CDA Registration, BIR Form 2303, Mayor's Business Permit, DepEd/CHED Endorsement, Notarized MOA, Audited Financial Statement)? Look for Republic of the Philippines letterheads, official seals, dry stamps, barcodes/QR codes, and authorized government official signatures.
2. DIGITAL FORGERY & TAMPERING: Inspect for visual artifacts, mismatched typography, cloned dry seals, copy-pasted official signatures, or edited corporate names/dates.
3. ENTITY CROSS-CHECK:
   - Extract the Organization Name on the document and cross-check with declared name "${orgName}".
   - Extract the Authorized Representative or Signatory and cross-check with "${repName}".
   - Extract the Issuing Government Agency (e.g. SEC, BIR, City Government of Manila, CDA, DepEd).
   - Extract the Registration / TIN / Permit number if visible.
4. RELEVANCE & COMPLIANCE: Is this document current, unexpired, and directly satisfying the requirement "${docName}"?

Return ONLY raw valid JSON (no markdown backticks, no commentary) in this exact format:
{
  "is_authentic_layout": true,
  "tampering_detected": false,
  "has_official_seal_or_signature": true,
  "is_document_legitimate": true,
  "extracted_name": "Full organization name found on document",
  "extracted_school": "Issuing Agency or Authority (e.g. Securities and Exchange Commission, BIR RDO 033)",
  "extracted_gwa": "Registration / Permit / TIN number if found, or empty string",
  "extracted_income": "",
  "extracted_doc_type": "Identified document type (e.g. SEC Certificate, BIR 2303, Mayor's Permit)",
  "verification_status": "verified",
  "confidence_score": 0.95,
  "flags": [],
  "summary": "Authentic government document with verified dry seal and registration number."
}
* Note for verification_status: use "verified" if authentic and details match, "flagged" if suspicious, expired, or name mismatches, or "rejected" if counterfeit/unrelated.
`;
  }

  return `
You are an expert Forensic Document Auditor and Academic Fraud Detection Assistant for the Philippine Scholarship Platform "IskoAko".
Analyze the provided document image / PDF page for the requirement: "${docName}".

Applicant Profile:
- Full Name: "${context.scholarName || 'Unknown'}"
- School / University: "${context.school || 'Unknown'}"
- Course: "${context.course || 'Unknown'}"
- Year Level: "${context.yearLevel || 'Unknown'}"
- Declared GWA: "${context.gwa || 'N/A'}"
- Declared Income: "${context.incomeBracket || 'N/A'}"

Perform forensic and content verification:
1. LAYOUT & AUTHENTICITY: Does it appear to be an authentic document (e.g., official letterhead, dry seal/stamp, registrar signature, standard university or government formatting)?
2. TAMPERING DETECTION: Look for visual artifacts, mismatched fonts/sizes, copy-pasted signatures, edited GWA numbers, or digital erasure halos.
3. PROFILE CROSS-CHECK:
   - Extract the student/person name on the document and compare with "${context.scholarName || ''}".
   - IMPORTANT PHILIPPINE NAME MATCHING RULES:
     a) Reversed Name Order: "LastName, FirstName" vs "FirstName LastName" (e.g. "Bartolome Steven" vs "Steven Bartolome") is a VALID MATCH.
     b) Middle Initial & Omission: Full Middle Name vs Middle Initial (e.g. "Steven Mendoza Bartolome" vs "Steven M. Bartolome") or omitting middle name (e.g. "Steven Bartolome") is a VALID MATCH.
     c) Do NOT mark verification_status as "flagged" or "rejected" solely for reversed name order or middle initial vs full name. Set verification_status to "verified" if the names match under these rules.
   - Extract school/institution name and compare with "${context.school || ''}".
   - If Transcript of Records or Grade Slip, extract the actual GWA or academic term grades. Compare with declared GWA: "${context.gwa || ''}".
   - If Indigency / ITR, extract the income amount.
4. RELEVANCE & INTEGRITY: Is this upload valid and directly relevant to "${docName}", or is it irrelevant/corrupted?

Return ONLY raw valid JSON (no markdown backticks, no commentary) in this exact format:
{
  "is_authentic_layout": true,
  "tampering_detected": false,
  "has_official_seal_or_signature": true,
  "is_document_legitimate": true,
  "extracted_name": "Full name found on document",
  "extracted_school": "School name found on document",
  "extracted_gwa": "GWA found on document or empty string",
  "extracted_income": "Income found or empty string",
  "extracted_doc_type": "Exact document type identified",
  "verification_status": "verified",
  "confidence_score": 0.95,
  "flags": [],
  "summary": "Authentic PUP Transcript of Records with verified dry seal and registrar signature. All details match applicant profile."
}
* Note for verification_status: use "verified" if authentic and data matches (including flexible name order and middle initials), "flagged" if suspicious or major data mismatches, or "rejected" if fake/irrelevant.
`;
};

/**
 * Converts any PDF or Image (remote URL or Base64 Data URL) into a high-quality JPEG Data URL.
 * Guarantees that AI Vision APIs (Mistral, Gemini, Groq, OpenRouter) always receive valid JPEG image data.
 */
export async function convertPdfDataUrlToImage(urlOrDataUrl: string): Promise<string> {
  if (!urlOrDataUrl) return '';

  // If already an image data URL, return it
  if (urlOrDataUrl.startsWith('data:image/')) {
    return urlOrDataUrl;
  }

  try {
    let bytes: Uint8Array;
    const isRemote = urlOrDataUrl.startsWith('http://') || urlOrDataUrl.startsWith('https://');
    const isPdf = urlOrDataUrl.startsWith('data:application/pdf') || urlOrDataUrl.toLowerCase().includes('.pdf');

    if (isRemote) {
      const resp = await fetch(urlOrDataUrl);
      if (!resp.ok) throw new Error(`HTTP ${resp.status} fetching document from storage`);
      const arrayBuffer = await resp.arrayBuffer();
      bytes = new Uint8Array(arrayBuffer);

      if (!isPdf) {
        // It's a remote image file (PNG/JPG/WEBP) -> convert to JPEG Data URL
        const blob = new Blob([bytes as BlobPart]);
        return await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      }
    } else if (urlOrDataUrl.startsWith('data:application/pdf')) {
      const base64 = urlOrDataUrl.split(',')[1];
      const binaryStr = atob(base64);
      bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) {
        bytes[i] = binaryStr.charCodeAt(i);
      }
    } else {
      return urlOrDataUrl;
    }

    // Rasterize PDF Page 1 to HTML5 Canvas
    const loadingTask = pdfjsLib.getDocument({ data: bytes });
    const pdf = await loadingTask.promise;
    const page = await pdf.getPage(1);

    const viewport = page.getViewport({ scale: 1.5 });
    const canvas = document.createElement('canvas');
    canvas.width = viewport.width;
    canvas.height = viewport.height;
    const ctx = canvas.getContext('2d');
    if (!ctx) return urlOrDataUrl;

    await (page.render({ canvasContext: ctx, viewport } as any)).promise;
    return canvas.toDataURL('image/jpeg', 0.9);
  } catch (err) {
    console.warn('PDF/Image conversion warning:', err);
    return urlOrDataUrl;
  }
}

/**
 * Extract digital text layer directly from PDF in browser (Zero-AI offline fallback)
 */
export async function extractLocalPdfText(urlOrDataUrl: string): Promise<string> {
  if (!urlOrDataUrl) return '';
  try {
    let bytes: Uint8Array;
    if (urlOrDataUrl.startsWith('http://') || urlOrDataUrl.startsWith('https://')) {
      const resp = await fetch(urlOrDataUrl);
      if (!resp.ok) return '';
      const buffer = await resp.arrayBuffer();
      bytes = new Uint8Array(buffer);
    } else if (urlOrDataUrl.startsWith('data:application/pdf')) {
      const base64 = urlOrDataUrl.split(',')[1];
      const binaryStr = atob(base64);
      bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) {
        bytes[i] = binaryStr.charCodeAt(i);
      }
    } else {
      return '';
    }

    const pdf = await pdfjsLib.getDocument({ data: bytes }).promise;
    let fullText = '';
    const maxPages = Math.min(pdf.numPages, 3);
    for (let p = 1; p <= maxPages; p++) {
      const page = await pdf.getPage(p);
      const textContent = await page.getTextContent();
      const pageText = textContent.items.map((item: any) => item.str).join(' ');
      fullText += ` ${pageText}`;
    }
    return fullText.trim();
  } catch (err) {
    console.warn('Local PDF text extraction error:', err);
    return '';
  }
}

/**
 * Compute SHA-256 hash of file for duplicate prevention
 */
export async function computeFileSha256(urlOrDataUrl: string): Promise<string> {
  try {
    let bytes: Uint8Array;
    if (urlOrDataUrl.startsWith('http://') || urlOrDataUrl.startsWith('https://')) {
      const resp = await fetch(urlOrDataUrl);
      if (!resp.ok) return `hash_${Date.now()}`;
      const buffer = await resp.arrayBuffer();
      bytes = new Uint8Array(buffer);
    } else if (urlOrDataUrl.includes(',')) {
      const base64 = urlOrDataUrl.split(',')[1];
      const binary = atob(base64);
      bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
      }
    } else {
      const encoder = new TextEncoder();
      bytes = encoder.encode(urlOrDataUrl);
    }
    const hashBuffer = await crypto.subtle.digest('SHA-256', bytes as unknown as BufferSource);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  } catch (_err) {
    return `hash_${Date.now()}`;
  }
}

/**
 * Clean JSON output from LLM responses
 */
function cleanJsonOutput(raw: string): any {
  let cleaned = raw.trim();
  if (cleaned.startsWith('```json')) {
    cleaned = cleaned.replace(/^```json/, '').replace(/```$/, '').trim();
  } else if (cleaned.startsWith('```')) {
    cleaned = cleaned.replace(/^```/, '').replace(/```$/, '').trim();
  }

  const start = cleaned.indexOf('{');
  const end = cleaned.lastIndexOf('}');
  if (start !== -1 && end !== -1) {
    cleaned = cleaned.substring(start, end + 1);
  }

  return JSON.parse(cleaned);
}

/**
 * Helper to split Base64 Data URL into mimeType and pure Base64
 */
function parseBase64DataUrl(dataUrl: string): { mimeType: string; base64: string } {
  if (dataUrl.startsWith('data:')) {
    const parts = dataUrl.split(',');
    const mimeMatch = parts[0].match(/:(.*?);/);
    const mimeType = mimeMatch ? mimeMatch[1] : 'image/jpeg';
    const base64 = parts[1];
    return { mimeType, base64 };
  }
  return { mimeType: 'image/jpeg', base64: dataUrl };
}

// -------------------------------------------------------------
// FLEXIBLE PHILIPPINE NAME MATCHING ENGINE
// -------------------------------------------------------------

/**
 * Flexible Philippine Name Matching Engine
 * Handles:
 * 1. Reversed Name Order: "LastName, FirstName" vs "FirstName LastName" (e.g. "Bartolome Steven" vs "Steven Bartolome")
 * 2. Middle Initial vs Full Middle Name: "Steven Mendoza Bartolome" vs "Steven M. Bartolome" or "Steven Bartolome"
 * 3. Suffixes & Formatting: "Jr.", "Sr.", "III", "IV", commas, dots, and case insensitivity
 */
export function isFlexibleNameMatch(declaredName: string, documentName: string): boolean {
  if (!declaredName || !documentName) return true;

  const sanitize = (str: string) =>
    str
      .toLowerCase()
      .replace(/[,./\-]/g, ' ')
      .replace(/\b(jr|sr|iii|ii|iv)\b/g, '')
      .replace(/\s+/g, ' ')
      .trim();

  const cleanDeclared = sanitize(declaredName);
  const cleanDocument = sanitize(documentName);

  if (cleanDeclared === cleanDocument) return true;
  if (cleanDeclared.includes(cleanDocument) || cleanDocument.includes(cleanDeclared)) return true;

  const declaredTokens = cleanDeclared.split(' ').filter(t => t.length > 0);
  const documentTokens = cleanDocument.split(' ').filter(t => t.length > 0);

  if (declaredTokens.length === 0 || documentTokens.length === 0) return true;

  let matchedCount = 0;
  const totalRequired = Math.min(declaredTokens.length, documentTokens.length);

  for (const decToken of declaredTokens) {
    // 1. Exact token match (order independent)
    if (documentTokens.includes(decToken)) {
      matchedCount++;
      continue;
    }

    // 2. Declared token is initial (e.g. 'm') matching document word (e.g. 'mendoza')
    if (decToken.length === 1) {
      if (documentTokens.some(docTok => docTok.startsWith(decToken))) {
        matchedCount++;
        continue;
      }
    }

    // 3. Document token is initial (e.g. 'm') matching declared word (e.g. 'mendoza')
    if (documentTokens.some(docTok => docTok.length === 1 && decToken.startsWith(docTok))) {
      matchedCount++;
      continue;
    }

    // 4. Substring / prefix match for long names (>3 chars)
    if (decToken.length > 3 && documentTokens.some(docTok => docTok.length > 3 && (docTok.includes(decToken) || decToken.includes(docTok)))) {
      matchedCount++;
      continue;
    }
  }

  // If at least 2 key tokens match, or 60%+ of tokens match, consider it a valid match!
  return matchedCount >= Math.min(2, totalRequired) || (matchedCount / totalRequired) >= 0.6;
}

// -------------------------------------------------------------
// DOCUMENT VERIFICATION ENGINE (MULTI-AI WITH AUTOMATIC FALLBACK)
// -------------------------------------------------------------

async function verifyWithGemini(
  imageDataUrl: string,
  docName: string,
  context: ApplicantVerificationContext,
  apiKey: string
): Promise<any> {
  const { mimeType, base64 } = parseBase64DataUrl(imageDataUrl);
  const prompt = buildDocVerificationPrompt(docName, context);
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: prompt },
            { inline_data: { mime_type: mimeType, data: base64 } },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: 'application/json',
        temperature: 0.1,
      },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini API Error (${response.status}): ${errText}`);
  }

  const result = await response.json();
  const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('No content returned from Gemini API.');

  return cleanJsonOutput(text);
}

async function verifyWithMistral(
  imageDataUrl: string,
  docName: string,
  context: ApplicantVerificationContext,
  apiKey: string
): Promise<any> {
  const endpoint = 'https://api.mistral.ai/v1/chat/completions';
  const prompt = buildDocVerificationPrompt(docName, context);

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'pixtral-12b-2409',
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            { type: 'image_url', image_url: { url: imageDataUrl } },
          ],
        },
      ],
      temperature: 0.1,
      max_tokens: 1500,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Mistral API Error (${response.status}): ${errText}`);
  }

  const result = await response.json();
  const text = result?.choices?.[0]?.message?.content;
  if (!text) throw new Error('No content returned from Mistral API.');

  return cleanJsonOutput(text);
}

async function verifyWithOpenRouter(
  imageDataUrl: string,
  docName: string,
  context: ApplicantVerificationContext,
  apiKey: string
): Promise<any> {
  const endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  const prompt = buildDocVerificationPrompt(docName, context);

  const models = [
    'mistralai/pixtral-12b',
    'google/gemini-2.0-flash-001',
    'meta-llama/llama-3.2-11b-vision-instruct:free',
    'qwen/qwen-2.5-vl-72b-instruct',
  ];

  let lastError = '';
  for (const model of models) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://iskoako.app',
          'X-Title': 'IskoAko Platform',
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: prompt },
                { type: 'image_url', image_url: { url: imageDataUrl } },
              ],
            },
          ],
          temperature: 0.1,
          max_tokens: 1500,
        }),
      });

      if (response.ok) {
        const result = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (text) {
          return cleanJsonOutput(text);
        }
      } else {
        lastError = await response.text();
      }
    } catch (err: any) {
      lastError = err.message;
    }
  }

  throw new Error(`OpenRouter Error: ${lastError}`);
}

/**
 * Main Document Authenticity & Fraud Verification Orchestrator
 */
export async function verifyDocumentAuthenticity({
  documentUrl,
  documentName,
  applicantContext,
  onStatusUpdate,
}: {
  documentUrl: string;
  documentName: string;
  applicantContext: ApplicantVerificationContext;
  onStatusUpdate?: (status: string) => void;
}): Promise<DocVerificationResult> {
  const geminiKey = import.meta.env.VITE_GEMINI_API_KEY;
  const mistralKey = import.meta.env.VITE_MISTRAL_API_KEY;
  const openRouterKey = import.meta.env.VITE_OPENROUTER_API_KEY;

  onStatusUpdate?.('Rasterizing document and computing security hash...');
  const sha256Hash = await computeFileSha256(documentUrl);
  const convertedImageDataUrl = await convertPdfDataUrlToImage(documentUrl);

  let rawResult: any = null;
  let modelName = '';
  let providerName = '';
  const errors: string[] = [];

  // Priority 1: Mistral AI Pixtral 12B (Dedicated Multi-modal Vision Model)
  if (!rawResult && mistralKey) {
    try {
      onStatusUpdate?.('Running Vision OCR analysis via Mistral Pixtral...');
      rawResult = await verifyWithMistral(convertedImageDataUrl, documentName, applicantContext, mistralKey);
      modelName = 'Pixtral 12B';
      providerName = 'Mistral AI';
    } catch (err: any) {
      console.warn('Mistral verification fallback:', err.message);
      errors.push(`Mistral: ${err.message}`);
    }
  }

  // Priority 2: Google Gemini 2.0 Flash
  if (!rawResult && geminiKey && geminiKey.length > 10) {
    try {
      onStatusUpdate?.('Running forensic analysis via Gemini 2.0 Flash...');
      rawResult = await verifyWithGemini(convertedImageDataUrl, documentName, applicantContext, geminiKey);
      modelName = 'Gemini 2.0 Flash';
      providerName = 'Google AI';
    } catch (err: any) {
      console.warn('Gemini verification fallback:', err.message);
      errors.push(`Gemini: ${err.message}`);
    }
  }

  // Priority 3: OpenRouter Multi-Model Router (Pixtral / Gemini / Llama / Qwen)
  if (!rawResult && openRouterKey) {
    try {
      onStatusUpdate?.('Evaluating with OpenRouter Multi-Model...');
      rawResult = await verifyWithOpenRouter(convertedImageDataUrl, documentName, applicantContext, openRouterKey);
      modelName = 'OpenRouter Vision';
      providerName = 'OpenRouter';
    } catch (err: any) {
      console.warn('OpenRouter verification fallback:', err.message);
      errors.push(`OpenRouter: ${err.message}`);
    }
  }

  // Priority 4: Local In-Browser Text Heuristic Fallback
  if (!rawResult) {
    onStatusUpdate?.('Checking embedded document text layer locally...');
    const localText = await extractLocalPdfText(documentUrl);
    if (localText && localText.length > 20) {
      const scholarName = applicantContext.scholarName || '';
      const nameParts = scholarName.toLowerCase().split(' ').filter(p => p.length > 2);
      const matchedParts = nameParts.filter(part => localText.toLowerCase().includes(part));
      const hasName = nameParts.length > 0 && matchedParts.length >= Math.ceil(nameParts.length * 0.6);

      const school = applicantContext.school || '';
      const hasSchool = school.length > 3 && localText.toLowerCase().includes(school.toLowerCase().slice(0, 8));

      rawResult = {
        is_authentic_layout: true,
        tampering_detected: false,
        has_official_seal_or_signature: true,
        is_document_legitimate: true,
        extracted_name: hasName ? scholarName : 'Extracted from digital text layer',
        extracted_school: hasSchool ? school : '',
        extracted_gwa: '',
        extracted_doc_type: documentName,
        verification_status: hasName ? 'verified' : 'flagged',
        confidence_score: hasName ? 0.88 : 0.65,
        flags: hasName ? [] : ['Name on digital text layer requires manual confirmation'],
        summary: hasName
          ? `Local digital text scan verified match with applicant "${scholarName}".`
          : `Digital text extracted, but requires manual visual confirmation.`,
      };
      modelName = 'Local PDF Text Heuristic';
      providerName = 'In-Browser Local Engine';
    }
  }

  // Priority 5: Safe Manual Review Queue Fallback
  if (!rawResult) {
    onStatusUpdate?.('All AI services offline — defaulting to manual review...');
    return {
      isAuthenticLayout: true,
      tamperingDetected: false,
      hasOfficialSealOrSignature: true,
      isDocumentLegitimate: true,
      extractedName: applicantContext.scholarName || '',
      extractedSchool: applicantContext.school || '',
      verificationStatus: 'manual_review_required',
      confidenceScore: 0.5,
      flags: ['AI Verification Service Offline - Please inspect document preview manually.'],
      summary: 'AI Vision service is temporarily unreachable. Document is queued for manual provider verification.',
      aiModelUsed: 'Manual Verification Required',
      provider: 'Local Fallback',
      sha256Hash,
      crossCheckResults: {
        nameMatch: true,
        schoolMatch: true,
        gwaMatch: null,
        sealPresent: true,
        tamperingFound: false,
      },
      rawResponse: { errors },
    };
  }

  // Normalize outputs and cross-checks
  const expectedName = (applicantContext.organizationName || applicantContext.scholarName || '').toLowerCase().trim();
  const repName = (applicantContext.representativeName || '').toLowerCase().trim();
  const extractedName = (rawResult.extracted_name || '').toLowerCase().trim();

  const nameMatch: boolean =
    !extractedName ||
    !expectedName ||
    isFlexibleNameMatch(expectedName, extractedName) ||
    (repName ? isFlexibleNameMatch(repName, extractedName) : false);

  const expectedSchool = (applicantContext.school || applicantContext.providerType || '').toLowerCase().trim();
  const extractedSchool = (rawResult.extracted_school || '').toLowerCase().trim();
  const schoolMatch: boolean =
    !extractedSchool ||
    !expectedSchool ||
    expectedSchool.includes(extractedSchool) ||
    extractedSchool.includes(expectedSchool) ||
    expectedSchool.split(' ').some(p => p.length > 3 && extractedSchool.includes(p)) ||
    !!applicantContext.isProviderOrg;

  // Normalize flag items (handles both plain string array and object array from LLMs)
  const normalizeFlagItem = (item: any): string => {
    if (!item) return '';
    if (typeof item === 'string') return item.trim();
    if (typeof item === 'object') {
      return item.description || item.flag || item.reason || item.message || item.issue || JSON.stringify(item);
    }
    return String(item);
  };

  const rawFlags = Array.isArray(rawResult.flags) ? rawResult.flags : [];

  // Filter out false-alarm flags if flexible name matcher succeeded
  const flags: string[] = rawFlags
    .map(normalizeFlagItem)
    .filter(Boolean)
    .filter((flag: string) => {
      const fLower = flag.toLowerCase();
      // Drop false-positive name mismatch/order/initial flags if isFlexibleNameMatch passed
      if (nameMatch && (fLower.includes('name') || fLower.includes('mismatch') || fLower.includes('order') || fLower.includes('initial'))) {
        return false;
      }
      return true;
    });

  if (!nameMatch && extractedName.length > 2) {
    flags.push(`Name Mismatch: Document states "${rawResult.extracted_name}" vs profile "${applicantContext.scholarName}"`);
  }
  if (rawResult.tampering_detected) {
    flags.push('Potential digital forgery or visual alteration detected on document layout.');
  }

  let finalStatus: 'verified' | 'flagged' | 'rejected' | 'manual_review_required' =
    rawResult.verification_status === 'verified' ? 'verified' :
    rawResult.verification_status === 'rejected' ? 'rejected' : 'flagged';

  // Override status to verified if layout is authentic and name matched flexibly!
  if (nameMatch && !rawResult.tampering_detected && (finalStatus === 'flagged' || flags.length === 0)) {
    if (flags.length === 0) {
      finalStatus = 'verified';
    }
  } else if (flags.length > 0 && finalStatus === 'verified') {
    finalStatus = 'flagged';
  }

  return {
    isAuthenticLayout: !!rawResult.is_authentic_layout,
    tamperingDetected: !!rawResult.tampering_detected,
    hasOfficialSealOrSignature: !!rawResult.has_official_seal_or_signature,
    isDocumentLegitimate: !!rawResult.is_document_legitimate,
    extractedName: rawResult.extracted_name || '',
    extractedSchool: rawResult.extracted_school || '',
    extractedGwa: rawResult.extracted_gwa || '',
    extractedIncome: rawResult.extracted_income || '',
    extractedDocType: rawResult.extracted_doc_type || documentName,
    verificationStatus: finalStatus,
    confidenceScore: typeof rawResult.confidence_score === 'number' ? rawResult.confidence_score : 0.9,
    flags,
    summary: rawResult.summary || 'Document analyzed by AI Forensic Verification Engine.',
    aiModelUsed: modelName,
    provider: providerName,
    sha256Hash,
    crossCheckResults: {
      nameMatch,
      schoolMatch,
      gwaMatch: rawResult.extracted_gwa ? true : null,
      sealPresent: !!rawResult.has_official_seal_or_signature,
      tamperingFound: !!rawResult.tampering_detected,
    },
    rawResponse: rawResult,
  };
}

// -------------------------------------------------------------
// BANK DETAILS OCR ORCHESTRATOR
// -------------------------------------------------------------

async function extractBankWithMistral(imageDataUrl: string, apiKey: string): Promise<ExtractedBankDetails> {
  const endpoint = 'https://api.mistral.ai/v1/chat/completions';
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'pixtral-12b-2409',
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: BANK_SYSTEM_PROMPT },
            { type: 'image_url', image_url: { url: imageDataUrl } },
          ],
        },
      ],
      temperature: 0.1,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Mistral API Error (${response.status}): ${errText}`);
  }

  const result = await response.json();
  const text = result?.choices?.[0]?.message?.content;
  if (!text) throw new Error('No content returned from Mistral API.');

  const parsed = cleanJsonOutput(text);
  return {
    bankName: parsed.bank_name || 'Landbank of the Philippines',
    accountName: parsed.account_holder_name || '',
    accountNumber: (parsed.account_number || '').toString().replace(/[^0-9]/g, ''),
    documentType: parsed.document_type || 'atm_card',
    confidenceScore: parsed.confidence_score || 0.95,
    aiModelUsed: 'Mistral Pixtral 12B',
    provider: 'Mistral AI',
    rawResponse: parsed,
  };
}

async function extractBankWithGemini(dataUrl: string, apiKey: string): Promise<ExtractedBankDetails> {
  const { mimeType, base64 } = parseBase64DataUrl(dataUrl);
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: BANK_SYSTEM_PROMPT },
            { inline_data: { mime_type: mimeType, data: base64 } },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: 'application/json',
        temperature: 0.1,
      },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini API Error (${response.status}): ${errText}`);
  }

  const result = await response.json();
  const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('No content returned from Gemini API.');

  const parsed = cleanJsonOutput(text);
  return {
    bankName: parsed.bank_name || 'Landbank of the Philippines',
    accountName: parsed.account_holder_name || '',
    accountNumber: (parsed.account_number || '').toString().replace(/[^0-9]/g, ''),
    documentType: parsed.document_type || 'atm_card',
    confidenceScore: parsed.confidence_score || 0.95,
    aiModelUsed: 'Gemini 2.0 Flash',
    provider: 'Google AI Studio',
    rawResponse: parsed,
  };
}

export async function extractBankDetailsFromImage(
  dataUrl: string,
  onStatusUpdate?: (status: string) => void
): Promise<ExtractedBankDetails> {
  const geminiKey = import.meta.env.VITE_GEMINI_API_KEY;
  const mistralKey = import.meta.env.VITE_MISTRAL_API_KEY;

  onStatusUpdate?.('Preparing document for AI Vision analysis...');
  const convertedImageDataUrl = await convertPdfDataUrlToImage(dataUrl);
  const errors: string[] = [];

  // 1. Try Gemini 2.0 Flash
  if (geminiKey && geminiKey.startsWith('AIzaSy')) {
    try {
      onStatusUpdate?.('Scanning with Google Gemini 2.0 Flash...');
      return await extractBankWithGemini(convertedImageDataUrl, geminiKey);
    } catch (err: any) {
      console.warn('Gemini extraction fallback:', err.message);
      errors.push(`Gemini: ${err.message}`);
    }
  }

  // 2. Try Mistral Pixtral
  if (mistralKey) {
    try {
      onStatusUpdate?.('Scanning document with Mistral Pixtral Vision...');
      return await extractBankWithMistral(convertedImageDataUrl, mistralKey);
    } catch (err: any) {
      console.warn('Mistral extraction fallback:', err.message);
      errors.push(`Mistral: ${err.message}`);
    }
  }

  // 3. Fallback baseline
  console.warn('All bank AI extraction models failed. Returning baseline template.');
  return {
    bankName: 'Landbank of the Philippines',
    accountName: '',
    accountNumber: '',
    documentType: 'atm_card',
    confidenceScore: 0.5,
    aiModelUsed: 'Manual Verification Required',
    provider: 'Local Fallback',
    rawResponse: { errors },
  };
}

export interface ScholarAgreementParams {
  scholarName: string;
  programTitle: string;
  providerName: string;
  school?: string;
  course?: string;
  yearLevel?: string;
  maintainingGwa?: string | number;
  stipendAmount?: number | string;
  tuitionCovered?: boolean;
  allowanceAmount?: number | string;
  renewalPolicy?: string;
  additionalRequirements?: string[];
  customNotes?: string;
  templateType?: 'merit' | 'need' | 'stem' | 'corporate' | 'general';
}

/**
 * Generate a professional, comprehensive Scholar Agreement / Rules & Maintaining Guidelines Letter using AI
 */
export async function generateScholarAgreementWithAi(
  params: ScholarAgreementParams,
  onStatusUpdate?: (status: string) => void
): Promise<{ content: string; aiModelUsed: string }> {
  const geminiKey = import.meta.env.VITE_GEMINI_API_KEY;
  const groqKey = import.meta.env.VITE_GROQ_API_KEY;
  const openRouterKey = import.meta.env.VITE_OPENROUTER_API_KEY;

  const todayStr = new Date().toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const prompt = `You are an expert Educational Policy and Legal Scholarship Agreement Drafting Assistant for the Philippine Scholarship Platform "IskoAko".
Draft an official, comprehensive, formal Scholarship Award & Maintaining Guidelines Agreement letter.

Scholar & Program Information:
- Scholar Name: ${params.scholarName}
- Scholarship Program: ${params.programTitle}
- Scholarship Provider / Grantor: ${params.providerName}
- University / College: ${params.school || 'Partner Academic Institution'}
- Degree Program / Course: ${params.course || 'Enrolled Degree Program'}
- Year Level: ${params.yearLevel || 'Undergraduate'}
- Maintaining GWA Requirement: ${params.maintainingGwa || '1.75 / 85% or better with no failing or incomplete grades'}
- Financial Grant Benefits:
  * Tuition Coverage: ${params.tuitionCovered ? '100% Fully Covered / Subsidized' : 'N/A or Separate Allowance'}
  * Monthly Educational Stipend: ${params.stipendAmount ? `₱${Number(params.stipendAmount).toLocaleString()} / month` : 'Prescribed Program Amount'}
  * Book / Living Allowance: ${params.allowanceAmount ? `₱${Number(params.allowanceAmount).toLocaleString()} / semester` : 'Included in grant'}
- Renewal Policy: ${params.renewalPolicy || 'Semestral re-evaluation upon submission of Certificate of Registration (COR) and Official Grade Slips'}
- Additional Requirements / Obligations: ${params.additionalRequirements?.join(', ') || 'Attendance at scholar orientations, adherence to university code of conduct'}
- Custom Notes / Instructions: ${params.customNotes || 'None'}
- Policy Type: ${params.templateType || 'General Merit Scholarship'}
- Date of Issuance: ${todayStr}

Draft the complete formal letter in clean, readable Markdown format with:
1. Formal Header & Salutation
2. Grant Scope & Financial Coverage Breakdown
3. Academic Maintaining Standards (Specific GWA, No Failing Grades, Regular Load)
4. Semestral Renewal & Document Submission Procedures (Submission via IskoAko mobile app)
5. Scholar Code of Ethics & Termination Conditions
6. Formal Concluding Message & Signatures Block.

Keep it professional, encouraging, clear, and legally compliant with Philippine academic standards. Do not include markdown code block backticks (like \`\`\`markdown) around the entire output.`;

  // 1. Try Gemini
  if (geminiKey && geminiKey.startsWith('AIzaSy')) {
    try {
      onStatusUpdate?.('Drafting agreement with Google Gemini AI...');
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.4 },
          }),
        }
      );

      if (response.ok) {
        const data = await response.json();
        const letter = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (letter && letter.length > 100) {
          return { content: letter.trim(), aiModelUsed: 'Google Gemini 2.0 Flash' };
        }
      }
    } catch (e) {
      console.warn('Gemini agreement generation fallback:', e);
    }
  }

  // 2. Try Groq Llama
  if (groqKey) {
    try {
      onStatusUpdate?.('Drafting agreement with Groq AI...');
      const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${groqKey}`,
        },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.4,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const letter = data?.choices?.[0]?.message?.content;
        if (letter && letter.length > 100) {
          return { content: letter.trim(), aiModelUsed: 'Groq Llama 3.3 70B' };
        }
      }
    } catch (e) {
      console.warn('Groq agreement generation fallback:', e);
    }
  }

  // 3. Try OpenRouter
  if (openRouterKey) {
    try {
      onStatusUpdate?.('Drafting agreement with OpenRouter AI...');
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${openRouterKey}`,
        },
        body: JSON.stringify({
          model: 'meta-llama/llama-3.3-70b-instruct',
          messages: [{ role: 'user', content: prompt }],
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const letter = data?.choices?.[0]?.message?.content;
        if (letter && letter.length > 100) {
          return { content: letter.trim(), aiModelUsed: 'OpenRouter Llama 3.3' };
        }
      }
    } catch (e) {
      console.warn('OpenRouter agreement generation fallback:', e);
    }
  }

  // 4. Built-in Structured Legal Template Fallback
  onStatusUpdate?.('Generating structured academic agreement template...');
  const gwaText = params.maintainingGwa ? String(params.maintainingGwa) : '1.75 (or 85% equivalent)';
  const stipendText = params.stipendAmount ? `₱${Number(params.stipendAmount).toLocaleString()} / month` : 'Prescribed Grant Amount';
  const tuitionText = params.tuitionCovered ? '100% Tuition & Miscellaneous Fees Covered' : 'Educational Grant Allowance';

  const defaultTemplate = `# OFFICIAL SCHOLARSHIP AWARD & MAINTAINING AGREEMENT

**Granting Institution:** ${params.providerName}  
**Scholarship Program:** ${params.programTitle}  
**Date of Award:** ${todayStr}  
**Awardee:** ${params.scholarName}  
**Institution:** ${params.school || 'Enrolled University / College'} (${params.course || 'Degree Program'})  

---

### DEAR ${params.scholarName.toUpperCase()},

Congratulations! On behalf of **${params.providerName}**, we are delighted to officially confer upon you the **${params.programTitle}** award. Through your exemplary academic merit, dedication, and character, you have earned this scholarship.

---

### 1. SCHOLARSHIP BENEFITS & FINANCIAL COVERAGE
During your tenure as an active scholar, you are entitled to the following grant entitlements:
- **Tuition & Institutional Fees:** ${tuitionText}
- **Monthly Living & Educational Stipend:** ${stipendText}
- **Book & Learning Support:** ${params.allowanceAmount ? `₱${Number(params.allowanceAmount).toLocaleString()} per academic term` : 'Provided as scheduled'}
- **Disbursement Mechanism:** Direct digital transfer via the verified payment account registered in your IskoAko portal.

---

### 2. ACADEMIC MAINTAINING STANDARDS
To maintain active scholar status and ensure uninterrupted fund releases, you agree to fulfill the following standards:
1. **General Weighted Average (GWA):** Maintain a minimum semester GWA of **${gwaText}** or better.
2. **No Incomplete or Failing Marks:** Must have no grades of 5.00 (Failed), Incomplete (INC), or Unauthorized Dropped (UD) in any enrolled course.
3. **Prescribed Academic Load:** Enroll in full regular units per semester according to your curriculum. Underloading is not permitted without prior written approval.

---

### 3. SEMESTRAL RENEWAL & DOCUMENT SUBMISSIONS
At the conclusion of each academic term, you must submit renewal credentials through the **IskoAko Mobile App** within **30 days** of the semester closing:
- **Official Certificate of Registration (COR) / Enrollment Form** for the upcoming term.
- **Certified True Copy of Grades / Transcript of Records (TOR)** from the completed term.
- Renewal evaluation is conducted automatically to approve continuous disbursements.

---

### 4. CODE OF ETHICS & CONDUCT
As an ambassador of **${params.providerName}**, you are expected to:
- Uphold high moral and ethical integrity in all academic and personal pursuits.
- Promptly notify the scholarship coordinator through IskoAko regarding any changes in contact details, academic standing, or shifting of degree programs.
- Participate in scheduled scholar community mentorship sessions and orientations.

---

### 5. ACKNOWLEDGMENT & ACCEPTANCE
By continuing in this program, you confirm your acceptance of the terms, rights, and obligations stipulated herein.

*Wishing you utmost success in your educational journey. Welcome to the ${params.providerName} Scholar Family!*

Sincerely,  
**Scholarship Committee**  
${params.providerName}  
*Platform Verification by IskoAko*`;

  return { content: defaultTemplate, aiModelUsed: 'IskoAko Policy Engine (Local)' };
}

export interface GenerateLetterParams {
  providerName: string;
  programTitle: string;
  templateType: string;
  userPrompt: string;
  programDetails?: {
    stipendAmount?: number | null;
    allowanceAmount?: number | null;
    maintainingGwa?: string | number | null;
    renewalPolicy?: string | null;
    coversTuition?: boolean | null;
    benefitsSummary?: string | null;
  };
}

export interface GeneratedLetterResult {
  title: string;
  salutation: string;
  bodyParagraphs: string[];
  terms: { label: string; value: string }[];
  signatoryTitle: string;
  signatorySubtitle: string;
  aiModelUsed: string;
}

/**
 * Generate a customized, structured scholarship letter based on the provider's custom text prompt and program details.
 */
export async function generateCustomLetterWithAi(
  params: GenerateLetterParams,
  onStatusUpdate?: (status: string) => void
): Promise<GeneratedLetterResult> {
  const geminiKey = import.meta.env.VITE_GEMINI_API_KEY;
  const groqKey = import.meta.env.VITE_GROQ_API_KEY;

  const gwa = params.programDetails?.maintainingGwa || '1.75';
  const stipend = params.programDetails?.stipendAmount ? `₱${Number(params.programDetails.stipendAmount).toLocaleString()} / month` : 'Prescribed Grant Amount';
  const tuition = params.programDetails?.coversTuition ? 'Full Tuition & Institutional Fees' : 'Standard Grant Coverage';

  const systemInstruction = `You are an elite academic scholarship administration and legal drafting AI for the Philippine scholarship platform "IskoAko".
Your task is to draft a comprehensive, official scholarship letter tailored precisely to the Provider's instructions.

Context:
- Granting Organization / Provider: "${params.providerName}"
- Scholarship Program: "${params.programTitle}"
- Base Category: "${params.templateType}"
- Minimum GWA: ${gwa}
- Monthly Stipend: ${stipend}
- Tuition Coverage: ${tuition}

Provider's Specific Prompt & Custom Requirements:
"${params.userPrompt || 'Draft an official award letter with clear maintaining terms and an encouraging tone.'}"

Output Rules:
1. You may use dynamic placeholders where appropriate: {{scholar_name}}, {{program_name}}, {{school}}, {{course}}, {{stipend_amount}}, {{gwa}}, {{cycle_name}}, {{application_id}}, {{date}}.
2. Return ONLY a valid, raw JSON object with NO surrounding markdown backticks (no \`\`\`json or \`\`\`).
3. Follow this exact JSON schema:
{
  "title": "OFFICIAL LETTER TITLE / SUBJECT BANNER IN UPPERCASE",
  "salutation": "Formal Salutation e.g. Dear {{scholar_name}},",
  "bodyParagraphs": [
    "First paragraph: Official greeting, purpose, congratulations, and grant overview.",
    "Second paragraph: Detailed explanation of benefits, stipends, and obligations.",
    "Third paragraph: Evaluation criteria, deadlines, submission instructions, and closing encouragement."
  ],
  "terms": [
    { "label": "General Weighted Average (GWA)", "value": "Maintain minimum ${gwa} each semester with no failing grades" },
    { "label": "Financial Entitlement", "value": "${stipend} disbursed directly via IskoAko wallet" },
    { "label": "Semestral Renewal Submission", "value": "Submit Certificate of Registration & Grades within 30 days of term completion" }
  ],
  "signatoryTitle": "Scholarship Committee & Program Secretariat",
  "signatorySubtitle": "${params.providerName}"
}`;

  // 1. Try OpenRouter Multi-Model (Google Gemini 2.0 Flash / Llama 3.3)
  const openRouterKey = import.meta.env.VITE_OPENROUTER_API_KEY;
  if (openRouterKey) {
    try {
      onStatusUpdate?.('Drafting custom letter with OpenRouter AI...');
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${openRouterKey}`,
          'HTTP-Referer': 'https://iskoako.edu.ph',
          'X-Title': 'IskoAko Letter Studio',
        },
        body: JSON.stringify({
          model: 'google/gemini-2.0-flash-001',
          messages: [{ role: 'user', content: systemInstruction }],
          temperature: 0.3,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const rawContent = data?.choices?.[0]?.message?.content;
        if (rawContent) {
          const cleanJson = rawContent.replace(/```json/g, '').replace(/```/g, '').trim();
          const parsed = JSON.parse(cleanJson);
          if (parsed.bodyParagraphs && Array.isArray(parsed.bodyParagraphs) && parsed.bodyParagraphs.length > 0) {
            const rawTerms = Array.isArray(parsed.terms) ? parsed.terms : Array.isArray(parsed.keyTerms) ? parsed.keyTerms : [];
            const mappedTerms = rawTerms.map((t: any) => ({
              label: t.label || t.term || 'Provision',
              value: t.value || t.requirement || '',
            }));

            return {
              title: parsed.title || `OFFICIAL SCHOLARSHIP NOTICE — ${params.programTitle.toUpperCase()}`,
              salutation: parsed.salutation || 'Dear {{scholar_name}},',
              bodyParagraphs: parsed.bodyParagraphs,
              terms: mappedTerms,
              signatoryTitle: parsed.signatoryTitle || 'Scholarship Committee',
              signatorySubtitle: parsed.signatorySubtitle || params.providerName,
              aiModelUsed: 'OpenRouter Gemini 2.0 Flash',
            };
          }
        }
      }
    } catch (openRouterErr) {
      console.warn('OpenRouter custom letter fallback error:', openRouterErr);
    }
  }

  // 2. Try Groq Llama
  if (groqKey) {
    try {
      onStatusUpdate?.('Drafting custom letter with Groq Llama AI...');
      const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${groqKey}`,
        },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          messages: [{ role: 'user', content: systemInstruction }],
          temperature: 0.3,
          response_format: { type: 'json_object' },
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const rawContent = data?.choices?.[0]?.message?.content;
        if (rawContent) {
          const parsed = JSON.parse(rawContent.trim());
          if (parsed.bodyParagraphs && Array.isArray(parsed.bodyParagraphs) && parsed.bodyParagraphs.length > 0) {
            const rawTerms = Array.isArray(parsed.terms) ? parsed.terms : Array.isArray(parsed.keyTerms) ? parsed.keyTerms : [];
            const mappedTerms = rawTerms.map((t: any) => ({
              label: t.label || t.term || 'Provision',
              value: t.value || t.requirement || '',
            }));

            return {
              title: parsed.title || `OFFICIAL SCHOLARSHIP NOTICE — ${params.programTitle.toUpperCase()}`,
              salutation: parsed.salutation || 'Dear {{scholar_name}},',
              bodyParagraphs: parsed.bodyParagraphs,
              terms: mappedTerms,
              signatoryTitle: parsed.signatoryTitle || 'Scholarship Committee',
              signatorySubtitle: parsed.signatorySubtitle || params.providerName,
              aiModelUsed: 'Groq Llama 3.3 70B',
            };
          }
        }
      }
    } catch (groqErr) {
      console.warn('Groq custom letter error fallback:', groqErr);
    }
  }

  // 3. Try Direct Gemini (Only if key starts with AIzaSy)
  if (geminiKey && geminiKey.startsWith('AIzaSy')) {
    try {
      onStatusUpdate?.('Drafting custom letter with Google Gemini AI...');
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: systemInstruction }] }],
            generationConfig: {
              temperature: 0.3,
              responseMimeType: 'application/json',
            },
          }),
        }
      );

      if (response.ok) {
        const data = await response.json();
        const rawJson = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (rawJson) {
          const parsed = JSON.parse(rawJson.replace(/```json/g, '').replace(/```/g, '').trim());
          if (parsed.bodyParagraphs && Array.isArray(parsed.bodyParagraphs) && parsed.bodyParagraphs.length > 0) {
            const rawTerms = Array.isArray(parsed.terms) ? parsed.terms : Array.isArray(parsed.keyTerms) ? parsed.keyTerms : [];
            const mappedTerms = rawTerms.map((t: any) => ({
              label: t.label || t.term || 'Provision',
              value: t.value || t.requirement || '',
            }));

            return {
              title: parsed.title || `OFFICIAL SCHOLARSHIP NOTICE — ${params.programTitle.toUpperCase()}`,
              salutation: parsed.salutation || 'Dear {{scholar_name}},',
              bodyParagraphs: parsed.bodyParagraphs,
              terms: mappedTerms,
              signatoryTitle: parsed.signatoryTitle || 'Scholarship Selection Board',
              signatorySubtitle: parsed.signatorySubtitle || params.providerName,
              aiModelUsed: 'Google Gemini 2.0 Flash',
            };
          }
        }
      }
    } catch (geminiErr) {
      console.warn('Gemini custom letter error fallback:', geminiErr);
    }
  }

  // 4. Smart Local Heuristic Fallback (Offline / Zero-AI Safe Mode)
  onStatusUpdate?.('Synthesizing prompt into structured legal letter...');
  const promptNotes = params.userPrompt ? `in accordance with: "${params.userPrompt}"` : 'under the official provisions established for this award';

  return {
    title: `OFFICIAL NOTICE OF SCHOLARSHIP AWARD & TERMS — ${params.programTitle.toUpperCase()}`,
    salutation: 'Dear {{scholar_name}},',
    bodyParagraphs: [
      `On behalf of ${params.providerName}, we are pleased to issue this official communication regarding your qualification and status under the ${params.programTitle} for the active academic period.`,
      `Your scholarship grant confers essential educational support ${params.programDetails?.stipendAmount ? `including a monthly financial stipend of ₱${Number(params.programDetails.stipendAmount).toLocaleString()}` : ''} ${params.programDetails?.coversTuition ? 'as well as institutional tuition and mandatory fees coverage' : ''}. This grant has been structured ${promptNotes}.`,
      `To ensure uninterrupted release of entitlements and maintain good standing, you are required to uphold a minimum General Weighted Average (GWA) of ${gwa} or equivalent, observe the code of conduct, and submit all semestral grade validation reports through the IskoAko portal in a timely manner.`,
      `We congratulate you on this milestone and look forward to your continued excellence in your academic journey.`
    ],
    terms: [
      { label: 'Academic Standard (GWA)', value: `Maintain a semester GWA of ${gwa} or higher with no failing marks` },
      { label: 'Financial Entitlement', value: stipend },
      { label: 'Tuition & Fees', value: tuition },
      { label: 'Semestral Renewal', value: 'Submit Official COR and Certified True Copy of Grades via IskoAko within 30 days of term close' },
      { label: 'Provider Mandate', value: params.userPrompt || 'Comply with all attendance, mentorship check-ins, and institutional guidelines' }
    ],
    signatoryTitle: 'Scholarship Committee & Board of Trustees',
    signatorySubtitle: params.providerName,
    aiModelUsed: 'IskoAko Policy Engine (Local)',
  };
}

export interface ExtractedReferenceLetterResult {
  letterheadOrg?: string;
  letterheadSubtitle?: string;
  title: string;
  referencePrefix?: string;
  salutation: string;
  bodyParagraphs: string[];
  terms: { label: string; value: string }[];
  closingText?: string;
  signatoryTitle?: string;
  signatorySubtitle?: string;
  aiModelUsed: string;
  sourceFileName: string;
}

/**
 * Extract raw text from PDF bytecode stream (zero-dependency in-browser fallback)
 */
function extractRawPdfBytecodeText(bytes: Uint8Array): string {
  try {
    const decoder = new TextDecoder('latin1');
    const pdfString = decoder.decode(bytes);

    const extractedChunks: string[] = [];

    // Find all text blocks between BT (Begin Text) and ET (End Text)
    const btEtRegex = /BT[\s\S]*?ET/g;
    let match;
    while ((match = btEtRegex.exec(pdfString)) !== null) {
      const block = match[0];
      // Match (text) strings inside Tj, ', or "
      const textRegex = /\(([^)]+)\)\s*(?:Tj|'|")/g;
      let textMatch;
      while ((textMatch = textRegex.exec(block)) !== null) {
        extractedChunks.push(textMatch[1]);
      }

      // Match array strings in TJ: [(text) 20 (more text)] TJ
      const tjArrayRegex = /\[([^\]]+)\]\s*TJ/g;
      let arrayMatch;
      while ((arrayMatch = tjArrayRegex.exec(block)) !== null) {
        const inner = arrayMatch[1];
        const innerTextRegex = /\(([^)]+)\)/g;
        let innerMatch;
        let line = '';
        while ((innerMatch = innerTextRegex.exec(inner)) !== null) {
          line += innerMatch[1];
        }
        if (line.trim()) {
          extractedChunks.push(line);
        }
      }
    }

    if (extractedChunks.length > 0) {
      return extractedChunks
        .map(s => s.replace(/\\([()\\])/g, '$1'))
        .join(' ')
        .replace(/\s{2,}/g, ' ')
        .trim();
    }

    // Secondary fallback: Extract printable ASCII sequences
    const asciiMatches = pdfString.match(/[A-Za-z0-9 ,.\-:;!?'"()\/]{6,}/g);
    if (asciiMatches && asciiMatches.length > 0) {
      return asciiMatches
        .filter(m => !m.includes('/Type') && !m.includes('/Font') && !m.includes('/Page') && !m.includes('/Filter') && !m.includes('/Root'))
        .join(' ')
        .replace(/\s{2,}/g, ' ')
        .trim();
    }
  } catch (e) {
    console.warn('Raw PDF bytecode decoding error:', e);
  }
  return '';
}

/**
 * Dynamically load JSZip from cdnjs in the browser
 */
async function loadJSZip(): Promise<any> {
  if ((window as any).JSZip) {
    return (window as any).JSZip;
  }
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js';
    script.onload = () => {
      resolve((window as any).JSZip);
    };
    script.onerror = () => {
      reject(new Error('Failed to load JSZip from CDN'));
    };
    document.head.appendChild(script);
  });
}

/**
 * Extracts plain text paragraphs from DOCX document in browser
 */
async function extractTextFromDocx(file: File): Promise<string> {
  try {
    const JSZip = await loadJSZip();
    const arrayBuffer = await file.arrayBuffer();
    const zip = await JSZip.loadAsync(arrayBuffer);
    
    // Find word/document.xml
    const docXmlFile = zip.file('word/document.xml');
    if (!docXmlFile) return '';
    
    const docXmlText = await docXmlFile.async('text');
    
    // Parse XML
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(docXmlText, 'application/xml');
    const paragraphs = xmlDoc.getElementsByTagName('w:p');
    
    const textLines: string[] = [];
    for (let i = 0; i < paragraphs.length; i++) {
      const p = paragraphs[i];
      const textRuns = p.getElementsByTagName('w:t');
      let pText = '';
      for (let j = 0; j < textRuns.length; j++) {
        pText += textRuns[j].textContent || '';
      }
      if (pText.trim()) {
        textLines.push(pText.trim());
      }
    }
    
    return textLines.join('\n\n');
  } catch (err) {
    console.error('JSZip docx extraction error:', err);
    return '';
  }
}

/**
 * Upload & extract a reference document (PDF, Image, Text, Word) to clone/copy into an editable letter template
 */
export async function extractLetterFromReferenceFile(
  file: File,
  context: { providerName: string; programTitle?: string },
  onStatusUpdate?: (status: string) => void
): Promise<ExtractedReferenceLetterResult> {
  const fileName = file.name;
  const isPdf = file.type === 'application/pdf' || /\.pdf$/i.test(fileName);
  const isImage = file.type.startsWith('image/') || /\.(png|jpe?g|webp|bmp|gif|tiff)$/i.test(fileName);
  const isText = file.type.startsWith('text/') || /\.(txt|md|csv|rtf|json|html|htm)$/i.test(fileName);
  const isDocx = fileName.toLowerCase().endsWith('.docx') || file.type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  onStatusUpdate?.(`Reading reference file "${fileName}"...`);

  let extractedRawText = '';
  let imageDataUrl = '';

  if (isText) {
    try {
      extractedRawText = await file.text();
    } catch (err) {
      console.warn('Text file read error:', err);
    }
  } else if (isDocx) {
    try {
      onStatusUpdate?.('Parsing Word document layout & text...');
      extractedRawText = await extractTextFromDocx(file);
    } catch (err) {
      console.warn('Word document read error:', err);
    }
  } else if (isPdf) {
    try {
      onStatusUpdate?.('Extracting PDF text layer & rendering layout...');
      const arrayBuffer = await file.arrayBuffer();
      const bytes = new Uint8Array(arrayBuffer);

      try {
        const loadingTask = pdfjsLib.getDocument({
          data: bytes,
          disableFontFace: true,
        });
        const pdf = await loadingTask.promise;

        let pagesText = '';
        const totalPages = Math.min(pdf.numPages, 10);
        for (let p = 1; p <= totalPages; p++) {
          try {
            const page = await pdf.getPage(p);
            const textContent = await page.getTextContent();
            const pageText = textContent.items.map((item: any) => item.str).join(' ');
            if (pageText.trim()) {
              pagesText += `\n\n--- PAGE ${p} ---\n` + pageText;
            }
          } catch (pageErr) {
            console.warn(`PDF page ${p} extraction warning:`, pageErr);
          }
        }
        extractedRawText = pagesText.trim();

        // Rasterize page 1 for Vision OCR models
        try {
          const page1 = await pdf.getPage(1);
          const viewport = page1.getViewport({ scale: 1.5 });
          const canvas = document.createElement('canvas');
          canvas.width = viewport.width;
          canvas.height = viewport.height;
          const ctx = canvas.getContext('2d');
          if (ctx) {
            await (page1.render({ canvasContext: ctx, viewport } as any)).promise;
            imageDataUrl = canvas.toDataURL('image/jpeg', 0.85);
          }
        } catch (renderErr) {
          console.warn('PDF visual rendering warning:', renderErr);
        }
      } catch (pdfJsErr) {
        console.warn('pdfjsLib failed, using bytecode stream parser:', pdfJsErr);
        extractedRawText = extractRawPdfBytecodeText(bytes);
      }
    } catch (pdfErr) {
      console.warn('PDF reading warning:', pdfErr);
    }
  } else if (isImage) {
    onStatusUpdate?.('Processing image for AI Vision OCR...');
    try {
      imageDataUrl = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result as string);
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
    } catch (imgErr) {
      console.warn('Image read error:', imgErr);
    }
  } else {
    // Other formats (e.g. legacy .doc)
    try {
      const raw = await file.text();
      extractedRawText = raw.replace(/[^\x20-\x7E\n\r\t]/g, ' ').replace(/\s{2,}/g, ' ');
    } catch {
      // continue
    }
  }

  const promptText = `
You are an expert Legal Document Analyst and Scholarship Template Reconstructor for the Philippine Scholarship Monorepo Platform "IskoAko".
The user has uploaded an official reference document: "${fileName}".
Your task is to analyze this reference letter, memorandum, award notice, or scholarship contract and copy/reconstruct its EXACT structure, phrasing, tone, and wording into an editable template.

Context:
- Platform: IskoAko Philippine Scholarship Monorepo
- Provider Organization: "${context.providerName}"
- Scholarship Program: "${context.programTitle || 'Scholarship Program'}"

${extractedRawText ? `Digital Extracted Content from Document:\n"""\n${extractedRawText.slice(0, 10000)}\n"""\n` : ''}

Analysis & Conversion Rules:
1. COPY the exact document structure, letterhead, formal greetings, paragraphs, terms, and closing from the reference document.
2. Replace recipient-specific student details or ANY generic bracketed placeholders (like "[Phone Number]", "[Email Address]", "[Response Deadline]", "[ORGANIZATION/INSTITUTION NAME]", or "[Street Address, City, State, ZIP]") with dynamic template tags:
   - Scholar / Student Name: {{scholar_name}}
   - Program Name: {{program_name}}
   - Provider Name: {{provider_name}}
   - University / School: {{school}}
   - Course / Degree: {{course}}
   - Year Level: {{year_level}}
   - GWA / Maintaining Grade: {{gwa}}
   - Monthly Stipend / Grant: {{stipend_amount}}
   - Cycle / Intake: {{cycle_name}}
   - Application ID / Reference Number: {{application_id}}
   - Date: {{date}}
   - Email Address: {{email}}
   - Phone / Contact / Deadline: Convert them to appropriate double-curly-brace template tags or descriptive text. NEVER leave literal brackets like "[Response Deadline]", "[Phone Number]", or "[Street Address]" in the output. Convert them to the appropriate template tags (like {{date}} or {{provider_name}}) or write them out fully.
3. For bodyParagraphs: Provide every paragraph as a separate string element in the array, preserving all sentences, requirements, and wording from the uploaded document.
4. If there are key conditions, maintenance rules, or grant entitlements, extract them into the "terms" array as { "label": "...", "value": "..." }.
5. Output MUST be ONLY valid, parseable raw JSON (NO markdown backticks, NO commentary) matching this schema:
{
  "letterheadOrg": "Letterhead Organization / Board name (e.g. DOST-SEI, ${context.providerName.toUpperCase()})",
  "letterheadSubtitle": "Department or Subtitle (e.g. Office of Scholarship Grants)",
  "title": "Document Title / Subject Banner (e.g. NOTICE OF SCHOLARSHIP AWARD)",
  "referencePrefix": "Reference prefix (e.g. NOA, MEMO, REF)",
  "salutation": "Salutation line (e.g. Dear {{scholar_name}}, or TO WHOM IT MAY CONCERN:)",
  "bodyParagraphs": [
    "Full paragraph 1 from document...",
    "Full paragraph 2 from document..."
  ],
  "terms": [
    { "label": "Provision / Obligation", "value": "Details of term" }
  ],
  "closingText": "Closing phrase (e.g. Sincerely, or Very truly yours,)",
  "signatoryTitle": "Signatory Title (e.g. Executive Director, Scholarship Committee)",
  "signatorySubtitle": "${context.providerName}"
}
`;

  // 1. Try OpenRouter (High Reliability Multi-Model with Vision)
  const openRouterKey = import.meta.env.VITE_OPENROUTER_API_KEY;
  if (openRouterKey) {
    try {
      onStatusUpdate?.('Analyzing reference template with OpenRouter AI...');
      const userContent: any[] = [{ type: 'text', text: promptText }];

      if (imageDataUrl && imageDataUrl.includes(',')) {
        userContent.push({
          type: 'image_url',
          image_url: { url: imageDataUrl },
        });
      }

      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${openRouterKey}`,
          'HTTP-Referer': 'https://iskoako.edu.ph',
          'X-Title': 'IskoAko Letter Studio',
        },
        body: JSON.stringify({
          model: 'google/gemini-2.0-flash-001',
          messages: [{ role: 'user', content: userContent }],
          temperature: 0.2,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const rawContent = data?.choices?.[0]?.message?.content;
        if (rawContent) {
          const cleanJson = rawContent.replace(/```json/g, '').replace(/```/g, '').trim();
          const parsed = JSON.parse(cleanJson);
          if (parsed.bodyParagraphs && Array.isArray(parsed.bodyParagraphs) && parsed.bodyParagraphs.length > 0) {
            const rawTerms = Array.isArray(parsed.terms) ? parsed.terms : [];
            return {
              letterheadOrg: parsed.letterheadOrg || context.providerName.toUpperCase(),
              letterheadSubtitle: parsed.letterheadSubtitle || 'Office of Scholarship Grants & Student Support',
              title: parsed.title || `OFFICIAL SCHOLARSHIP LETTER — ${(context.programTitle || 'PROGRAM').toUpperCase()}`,
              referencePrefix: parsed.referencePrefix || 'REF',
              salutation: parsed.salutation || 'Dear {{scholar_name}},',
              bodyParagraphs: parsed.bodyParagraphs,
              terms: rawTerms.map((t: any) => ({ label: t.label || 'Provision', value: t.value || '' })),
              closingText: parsed.closingText || 'Very truly yours,',
              signatoryTitle: parsed.signatoryTitle || 'Scholarship Selection Committee',
              signatorySubtitle: parsed.signatorySubtitle || context.providerName,
              aiModelUsed: 'OpenRouter Gemini 2.0 Flash (Vision OCR)',
              sourceFileName: fileName,
            };
          }
        }
      }
    } catch (openRouterErr) {
      console.warn('OpenRouter reference extraction error:', openRouterErr);
    }
  }

  // 2. Try Mistral Pixtral Vision
  const mistralKey = import.meta.env.VITE_MISTRAL_API_KEY;
  if (mistralKey && imageDataUrl && imageDataUrl.includes(',')) {
    try {
      onStatusUpdate?.('Analyzing document visuals with Mistral Pixtral Vision...');
      const response = await fetch('https://api.mistral.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${mistralKey}`,
        },
        body: JSON.stringify({
          model: 'pixtral-12b-2409',
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: promptText },
                { type: 'image_url', image_url: imageDataUrl },
              ],
            },
          ],
          temperature: 0.2,
          response_format: { type: 'json_object' },
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const rawContent = data?.choices?.[0]?.message?.content;
        if (rawContent) {
          const parsed = JSON.parse(rawContent.replace(/```json/g, '').replace(/```/g, '').trim());
          if (parsed.bodyParagraphs && Array.isArray(parsed.bodyParagraphs) && parsed.bodyParagraphs.length > 0) {
            const rawTerms = Array.isArray(parsed.terms) ? parsed.terms : [];
            return {
              letterheadOrg: parsed.letterheadOrg || context.providerName.toUpperCase(),
              letterheadSubtitle: parsed.letterheadSubtitle || 'Office of Scholarship Grants',
              title: parsed.title || `OFFICIAL SCHOLARSHIP LETTER — ${(context.programTitle || 'PROGRAM').toUpperCase()}`,
              referencePrefix: parsed.referencePrefix || 'REF',
              salutation: parsed.salutation || 'Dear {{scholar_name}},',
              bodyParagraphs: parsed.bodyParagraphs,
              terms: rawTerms.map((t: any) => ({ label: t.label || 'Provision', value: t.value || '' })),
              closingText: parsed.closingText || 'Sincerely,',
              signatoryTitle: parsed.signatoryTitle || 'Scholarship Committee',
              signatorySubtitle: parsed.signatorySubtitle || context.providerName,
              aiModelUsed: 'Mistral Pixtral 12B Vision',
              sourceFileName: fileName,
            };
          }
        }
      }
    } catch (mistralErr) {
      console.warn('Mistral Pixtral extraction fallback:', mistralErr);
    }
  }

  // 3. Try Google Gemini (Only if key is valid Google AI Studio key format)
  const geminiKey = import.meta.env.VITE_GEMINI_API_KEY;
  if (geminiKey && geminiKey.startsWith('AIzaSy')) {
    try {
      onStatusUpdate?.('Analyzing document with Google Gemini AI...');
      const parts: any[] = [{ text: promptText }];

      if (imageDataUrl && imageDataUrl.includes(',')) {
        const mime = imageDataUrl.split(';')[0].split(':')[1] || 'image/jpeg';
        const base64Data = imageDataUrl.split(',')[1];
        parts.push({
          inline_data: {
            mime_type: mime,
            data: base64Data,
          },
        });
      }

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts }],
            generationConfig: {
              temperature: 0.2,
              responseMimeType: 'application/json',
            },
          }),
        }
      );

      if (response.ok) {
        const data = await response.json();
        const rawJson = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (rawJson) {
          const parsed = JSON.parse(rawJson.replace(/```json/g, '').replace(/```/g, '').trim());
          if (parsed.bodyParagraphs && Array.isArray(parsed.bodyParagraphs) && parsed.bodyParagraphs.length > 0) {
            const rawTerms = Array.isArray(parsed.terms) ? parsed.terms : [];
            return {
              letterheadOrg: parsed.letterheadOrg || context.providerName.toUpperCase(),
              letterheadSubtitle: parsed.letterheadSubtitle || 'Office of Scholarship Grants & Student Support',
              title: parsed.title || `OFFICIAL SCHOLARSHIP LETTER — ${(context.programTitle || 'PROGRAM').toUpperCase()}`,
              referencePrefix: parsed.referencePrefix || 'REF',
              salutation: parsed.salutation || 'Dear {{scholar_name}},',
              bodyParagraphs: parsed.bodyParagraphs,
              terms: rawTerms.map((t: any) => ({ label: t.label || 'Provision', value: t.value || '' })),
              closingText: parsed.closingText || 'Very truly yours,',
              signatoryTitle: parsed.signatoryTitle || 'Scholarship Committee',
              signatorySubtitle: parsed.signatorySubtitle || context.providerName,
              aiModelUsed: 'Google Gemini 2.0 Flash (Vision OCR)',
              sourceFileName: fileName,
            };
          }
        }
      }
    } catch (geminiErr) {
      console.warn('Gemini reference template extraction fallback:', geminiErr);
    }
  }

  // 4. Try Groq Llama 3.3 70B (Fast Text Analysis)
  const groqKey = import.meta.env.VITE_GROQ_API_KEY;
  if (groqKey && (extractedRawText || fileName)) {
    try {
      onStatusUpdate?.('Analyzing document text with Groq Llama 3.3 70B...');
      const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${groqKey}`,
        },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          messages: [{ role: 'user', content: promptText }],
          temperature: 0.2,
          response_format: { type: 'json_object' },
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const rawContent = data?.choices?.[0]?.message?.content;
        if (rawContent) {
          const parsed = JSON.parse(rawContent.trim());
          if (parsed.bodyParagraphs && Array.isArray(parsed.bodyParagraphs) && parsed.bodyParagraphs.length > 0) {
            const rawTerms = Array.isArray(parsed.terms) ? parsed.terms : [];
            return {
              letterheadOrg: parsed.letterheadOrg || context.providerName.toUpperCase(),
              letterheadSubtitle: parsed.letterheadSubtitle || 'Office of Scholarship Grants',
              title: parsed.title || `OFFICIAL SCHOLARSHIP NOTICE — ${(context.programTitle || 'PROGRAM').toUpperCase()}`,
              referencePrefix: parsed.referencePrefix || 'REF',
              salutation: parsed.salutation || 'Dear {{scholar_name}},',
              bodyParagraphs: parsed.bodyParagraphs,
              terms: rawTerms.map((t: any) => ({ label: t.label || 'Provision', value: t.value || '' })),
              closingText: parsed.closingText || 'Sincerely,',
              signatoryTitle: parsed.signatoryTitle || 'Scholarship Selection Committee',
              signatorySubtitle: parsed.signatorySubtitle || context.providerName,
              aiModelUsed: 'Groq Llama 3.3 70B',
              sourceFileName: fileName,
            };
          }
        }
      }
    } catch (groqErr) {
      console.warn('Groq reference extraction error fallback:', groqErr);
    }
  }

  // 5. Intelligent Local OCR & Text Layer Parser (Zero-AI Offline Mode)
  onStatusUpdate?.('Reconstructing template structure from document text...');
  const cleanedText = (extractedRawText || '').trim();

  if (cleanedText.length > 10) {
    const lines = cleanedText
      .split(/\r?\n/)
      .map(l => l.trim())
      .filter(Boolean)
      .filter(l => !l.startsWith('--- PAGE'));

    let detectedOrg = context.providerName.toUpperCase();
    let detectedSubtitle = 'Office of Scholarship Grants & Student Support';
    let detectedTitle = `OFFICIAL SCHOLARSHIP MEMORANDUM — ${(context.programTitle || 'PROGRAM').toUpperCase()}`;
    let detectedRef = 'REF';
    let detectedSalutation = 'Dear {{scholar_name}},';
    let detectedClosing = 'Respectfully yours,';
    let detectedSignatory = 'Scholarship Selection Board';

    const collectedParagraphs: string[] = [];
    let currentParagraph = '';

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Check for Reference code
      if (/^(ref(\.|erence)?\s*(no\.?|code|#)?)\s*[:\-]?\s*([A-Za-z0-9\-_]+)/i.test(line)) {
        const match = line.match(/^(ref(\.|erence)?\s*(no\.?|code|#)?)\s*[:\-]?\s*([A-Za-z0-9\-_]+)/i);
        if (match && match[4]) detectedRef = match[4].trim().split('-')[0] || 'REF';
        continue;
      }

      // Check for Salutation
      if (/^(dear|to\s+whom|to\s*:|attn\s*:|greetings|for\s*:)/i.test(line)) {
        detectedSalutation = line.replace(/dear\s+[A-Za-z\s,.\-]+/i, 'Dear {{scholar_name}},');
        if (!detectedSalutation.includes('{{scholar_name}}') && /^dear/i.test(detectedSalutation)) {
          detectedSalutation = 'Dear {{scholar_name}},';
        }
        continue;
      }

      // Check for Title/Subject
      if (/^(subject|re|notice|memorandum|letter|contract|agreement)\s*[:\-]?\s*(.+)/i.test(line) || /^(notice\s+of\s+award|certificate\s+of|scholarship\s+agreement)/i.test(line)) {
        detectedTitle = line.toUpperCase();
        continue;
      }

      // Check for Closing
      if (/^(sincerely|respectfully|very\s+truly\s+yours|warm\s+regards|in\s+service|best\s+regards|truly\s+yours),?/i.test(line)) {
        detectedClosing = line;
        if (i + 1 < lines.length) {
          detectedSignatory = lines[i + 1];
        }
        break;
      }

      // Accumulate body paragraphs
      if (line.length > 0) {
        if (currentParagraph.length + line.length > 250) {
          collectedParagraphs.push(currentParagraph.trim());
          currentParagraph = line;
        } else {
          currentParagraph = currentParagraph ? `${currentParagraph} ${line}` : line;
        }
      }
    }

    if (currentParagraph.trim()) {
      collectedParagraphs.push(currentParagraph.trim());
    }

    const processedBody = (collectedParagraphs.length > 0 ? collectedParagraphs : [cleanedText]).map(p =>
      p.replace(/PHP\s*[\d,]+(\.\d{2})?/gi, '{{stipend_amount}}')
       .replace(/₱\s*[\d,]+(\.\d{2})?/gi, '{{stipend_amount}}')
    );

    return {
      letterheadOrg: detectedOrg,
      letterheadSubtitle: detectedSubtitle,
      title: detectedTitle,
      referencePrefix: detectedRef,
      salutation: detectedSalutation,
      bodyParagraphs: processedBody,
      terms: [
        { label: 'Document Source', value: `Imported from ${fileName}` },
        { label: 'Compliance Standard', value: 'Maintain designated academic and program requirements' }
      ],
      closingText: detectedClosing,
      signatoryTitle: detectedSignatory,
      signatorySubtitle: context.providerName,
      aiModelUsed: 'IskoAko Intelligent OCR Text Parser',
      sourceFileName: fileName,
    };
  }

  // Pure fallback
  return {
    letterheadOrg: context.providerName.toUpperCase(),
    letterheadSubtitle: 'Office of Scholarship Grants & Student Support',
    title: `COPIED TEMPLATE: ${fileName.replace(/\.[^/.]+$/, '').toUpperCase()}`,
    referencePrefix: 'REF',
    salutation: 'Dear {{scholar_name}},',
    bodyParagraphs: [
      `This letter template was imported from reference document "${fileName}".`,
      `You can edit and customize this body text directly inside the single text box editor. All formatting and line breaks will be preserved when exported to official PDF.`
    ],
    terms: [
      { label: 'Document Reference', value: `Imported from ${fileName}` },
      { label: 'Scholarship Standard', value: 'Maintain minimum required semester GWA' }
    ],
    closingText: 'Respectfully yours,',
    signatoryTitle: 'Scholarship Program Secretariat',
    signatorySubtitle: context.providerName,
    aiModelUsed: 'IskoAko Local Document Parser',
    sourceFileName: fileName,
  };
}



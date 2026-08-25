/**
 * PSGC (Philippine Standard Geographic Code) Location API Service
 * Endpoint Base: https://psgc.gitlab.io/api/
 */

export interface PSGCRegion {
  code: string;
  name: string;
  regionName: string;
}

export interface PSGCProvince {
  code: string;
  name: string;
  regionCode?: string;
}

export interface PSGCCityMunicipality {
  code: string;
  name: string;
  provinceCode?: string;
  districtCode?: string;
  isCity?: boolean;
}

export interface PSGCBarangay {
  code: string;
  name: string;
  cityCode?: string;
  municipalityCode?: string;
}

const BASE_URL = 'https://psgc.gitlab.io/api';

// In-memory caches for fast UI response
const cache = {
  regions: null as PSGCRegion[] | null,
  provincesAll: null as PSGCProvince[] | null,
  provincesByRegion: {} as Record<string, PSGCProvince[]>,
  citiesAll: null as PSGCCityMunicipality[] | null,
  citiesByProvince: {} as Record<string, PSGCCityMunicipality[]>,
  barangaysByCity: {} as Record<string, PSGCBarangay[]>,
};

/**
 * Fetch all Philippine Administrative Regions from PSGC API
 */
export async function getPSGCRegions(): Promise<PSGCRegion[]> {
  if (cache.regions && cache.regions.length > 0) {
    return cache.regions;
  }

  try {
    const response = await fetch(`${BASE_URL}/regions/`);
    if (!response.ok) throw new Error(`PSGC API HTTP ${response.status}`);
    const data: PSGCRegion[] = await response.json();
    cache.regions = data.sort((a, b) => a.name.localeCompare(b.name));
    return cache.regions;
  } catch (error) {
    console.warn('Failed to fetch PSGC regions, using fallback:', error);
    return FALLBACK_REGIONS;
  }
}

/**
 * Fetch Provinces from PSGC API (Optionally filtered by Region Code)
 */
export async function getPSGCProvinces(regionCode?: string): Promise<PSGCProvince[]> {
  if (regionCode) {
    if (cache.provincesByRegion[regionCode]) {
      return cache.provincesByRegion[regionCode];
    }
    try {
      const response = await fetch(`${BASE_URL}/regions/${regionCode}/provinces/`);
      if (!response.ok) throw new Error(`PSGC API HTTP ${response.status}`);
      const data: PSGCProvince[] = await response.json();
      const sorted = data.sort((a, b) => a.name.localeCompare(b.name));
      cache.provincesByRegion[regionCode] = sorted;
      return sorted;
    } catch (error) {
      console.warn(`Failed to fetch provinces for region ${regionCode}:`, error);
    }
  }

  if (cache.provincesAll && cache.provincesAll.length > 0) {
    return cache.provincesAll;
  }

  try {
    const response = await fetch(`${BASE_URL}/provinces/`);
    if (!response.ok) throw new Error(`PSGC API HTTP ${response.status}`);
    const data: PSGCProvince[] = await response.json();
    cache.provincesAll = data.sort((a, b) => a.name.localeCompare(b.name));
    return cache.provincesAll;
  } catch (error) {
    console.warn('Failed to fetch all PSGC provinces, using fallback:', error);
    return FALLBACK_PROVINCES;
  }
}

/**
 * Fetch Cities and Municipalities from PSGC API (Optionally filtered by Province Code)
 */
export async function getPSGCCitiesMunicipalities(provinceCode?: string): Promise<PSGCCityMunicipality[]> {
  if (provinceCode) {
    if (cache.citiesByProvince[provinceCode]) {
      return cache.citiesByProvince[provinceCode];
    }
    try {
      const response = await fetch(`${BASE_URL}/provinces/${provinceCode}/cities-municipalities/`);
      if (!response.ok) throw new Error(`PSGC API HTTP ${response.status}`);
      const data: PSGCCityMunicipality[] = await response.json();
      const sorted = data.sort((a, b) => a.name.localeCompare(b.name));
      cache.citiesByProvince[provinceCode] = sorted;
      return sorted;
    } catch (error) {
      console.warn(`Failed to fetch cities for province ${provinceCode}:`, error);
    }
  }

  if (cache.citiesAll && cache.citiesAll.length > 0) {
    return cache.citiesAll;
  }

  try {
    const response = await fetch(`${BASE_URL}/cities-municipalities/`);
    if (!response.ok) throw new Error(`PSGC API HTTP ${response.status}`);
    const data: PSGCCityMunicipality[] = await response.json();
    cache.citiesAll = data.sort((a, b) => a.name.localeCompare(b.name));
    return cache.citiesAll;
  } catch (error) {
    console.warn('Failed to fetch all PSGC cities:', error);
    return [];
  }
}

/**
 * Fetch Barangays for a specific City / Municipality Code from PSGC API
 */
export async function getPSGCBarangays(cityOrMunicipalityCode: string): Promise<PSGCBarangay[]> {
  if (!cityOrMunicipalityCode) return [];
  
  if (cache.barangaysByCity[cityOrMunicipalityCode]) {
    return cache.barangaysByCity[cityOrMunicipalityCode];
  }

  try {
    const response = await fetch(`${BASE_URL}/cities-municipalities/${cityOrMunicipalityCode}/barangays/`);
    if (!response.ok) throw new Error(`PSGC API HTTP ${response.status}`);
    const data: PSGCBarangay[] = await response.json();
    const sorted = data.sort((a, b) => a.name.localeCompare(b.name));
    cache.barangaysByCity[cityOrMunicipalityCode] = sorted;
    return sorted;
  } catch (error) {
    console.warn(`Failed to fetch barangays for city ${cityOrMunicipalityCode}:`, error);
    return [];
  }
}

// Fallback static data if API is unreachable
const FALLBACK_REGIONS: PSGCRegion[] = [
  { code: '010000000', name: 'Region I (Ilocos Region)', regionName: 'Ilocos Region' },
  { code: '020000000', name: 'Region II (Cagayan Valley)', regionName: 'Cagayan Valley' },
  { code: '030000000', name: 'Region III (Central Luzon)', regionName: 'Central Luzon' },
  { code: '040000000', name: 'Region IV-A (CALABARZON)', regionName: 'CALABARZON' },
  { code: '170000000', name: 'MIMAROPA Region', regionName: 'MIMAROPA' },
  { code: '050000000', name: 'Region V (Bicol Region)', regionName: 'Bicol Region' },
  { code: '060000000', name: 'Region VI (Western Visayas)', regionName: 'Western Visayas' },
  { code: '070000000', name: 'Region VII (Central Visayas)', regionName: 'Central Visayas' },
  { code: '080000000', name: 'Region VIII (Eastern Visayas)', regionName: 'Eastern Visayas' },
  { code: '090000000', name: 'Region IX (Zamboanga Peninsula)', regionName: 'Zamboanga Peninsula' },
  { code: '100000000', name: 'Region X (Northern Mindanao)', regionName: 'Northern Mindanao' },
  { code: '110000000', name: 'Region XI (Davao Region)', regionName: 'Davao Region' },
  { code: '120000000', name: 'Region XII (SOCCSKSARGEN)', regionName: 'SOCCSKSARGEN' },
  { code: '130000000', name: 'Region XIII (Caraga)', regionName: 'Caraga' },
  { code: '140000000', name: 'CAR (Cordillera Administrative Region)', regionName: 'CAR' },
  { code: '150000000', name: 'BARMM (Bangsamoro Autonomous Region in Muslim Mindanao)', regionName: 'BARMM' },
  { code: '1300000000', name: 'NCR (National Capital Region)', regionName: 'NCR' },
];

const FALLBACK_PROVINCES: PSGCProvince[] = [
  { code: '043400000', name: 'Laguna', regionCode: '040000000' },
  { code: '042100000', name: 'Cavite', regionCode: '040000000' },
  { code: '041000000', name: 'Batangas', regionCode: '040000000' },
  { code: '045800000', name: 'Rizal', regionCode: '040000000' },
  { code: '072200000', name: 'Cebu', regionCode: '070000000' },
  { code: '112500000', name: 'Davao del Sur', regionCode: '110000000' },
  { code: '031400000', name: 'Bulacan', regionCode: '030000000' },
  { code: '034900000', name: 'Pampanga', regionCode: '030000000' },
  { code: '063000000', name: 'Iloilo', regionCode: '060000000' },
  { code: '064500000', name: 'Negros Occidental', regionCode: '060000000' },
  { code: '133900000', name: 'Metro Manila (NCR)', regionCode: '1300000000' },
];

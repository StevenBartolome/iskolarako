import 'package:iskoako/services/blockchain_service.dart';

class EligibilityHelper {
  static bool isProfileComplete(Map<String, dynamic>? scholar) {
    if (scholar == null) return false;
    final requiredFields = [
      'first_name',
      'last_name',
      'birth_date',
      'gender',
      'phone',
      'school',
      'course',
      'year_level',
      'citizenship',
      'region',
      'province',
      'municipality',
      'barangay',
    ];
    for (final field in requiredFields) {
      if (scholar[field] == null || scholar[field].toString().trim().isEmpty) {
        return false;
      }
    }
    // Face verification and blockchain security anchor are required
    if (scholar['face_verification_status']?.toString() != 'verified') {
      return false;
    }
    if (scholar['profile_blockchain_verified'] != true) {
      return false;
    }
    // Cryptographic profile hash integrity check
    final storedHash = scholar['profile_blockchain_hash']?.toString();
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }
    final currentHash = BlockchainService.computeProfileHash(scholar);
    if (currentHash.toLowerCase() != storedHash.toLowerCase()) {
      return false;
    }
    return true;
  }

  static List<String> getMissingFields(Map<String, dynamic>? scholar) {
    if (scholar == null) {
      return [
        'First Name',
        'Last Name',
        'Birth Date',
        'Gender',
        'Phone Number',
        'Citizenship',
        'Region',
        'Province',
        'Town / Municipality',
        'Barangay',
        'School',
        'Course',
        'Year Level',
        'Identity Verification',
      ];
    }
    final missing = <String>[];
    final fieldLabels = {
      'first_name': 'First Name',
      'last_name': 'Last Name',
      'birth_date': 'Birth Date',
      'gender': 'Gender',
      'phone': 'Phone Number',
      'citizenship': 'Citizenship',
      'region': 'Region',
      'province': 'Province',
      'municipality': 'Town / Municipality',
      'barangay': 'Barangay',
      'school': 'School / University',
      'course': 'Course / Program',
      'year_level': 'Year Level',
    };
    fieldLabels.forEach((field, label) {
      if (scholar[field] == null || scholar[field].toString().trim().isEmpty) {
        missing.add(label);
      }
    });
    // Check face verification and blockchain anchor status
    if (scholar['face_verification_status']?.toString() != 'verified') {
      missing.add('Identity Verification (face check required)');
    } else if (scholar['profile_blockchain_verified'] != true) {
      missing.add('Identity Verification (blockchain security anchor missing or invalidated)');
    } else {
      final storedHash = scholar['profile_blockchain_hash']?.toString();
      if (storedHash == null || storedHash.isEmpty) {
        missing.add('Identity Verification (blockchain hash missing)');
      } else {
        final currentHash = BlockchainService.computeProfileHash(scholar);
        if (currentHash.toLowerCase() != storedHash.toLowerCase()) {
          missing.add('Identity Integrity (tampered profile data detected - re-verification required)');
        }
      }
    }
    return missing;
  }

  // scale_5 lookup table: [gwaValue, midpointPercent]
  // Source: Philippine Standard GWA table (lower GWA = better grade)
  static const List<List<double>> _scale5Table = [
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
  // Sorted ascending for interpolation.
  static const List<List<double>> _scale4Table = [
    [0.0, 55.0],
    [1.0, 62.5],
    [1.5, 68.5],
    [2.0, 74.5],
    [2.5, 80.5],
    [3.0, 86.5],
    [3.5, 92.5],
    [4.0, 98.0],
  ];

  /// Linearly interpolates a value within a lookup table sorted ascending by key.
  static double _interpolate(List<List<double>> table, double value) {
    if (value <= table.first[0]) return table.first[1];
    if (value >= table.last[0]) return table.last[1];
    for (int i = 0; i < table.length - 1; i++) {
      final k0 = table[i][0];
      final v0 = table[i][1];
      final k1 = table[i + 1][0];
      final v1 = table[i + 1][1];
      if (value >= k0 && value <= k1) {
        final fraction = (value - k0) / (k1 - k0);
        return v0 + fraction * (v1 - v0);
      }
    }
    return table.last[1];
  }

  /// Normalises any GPA/grade value to a 0–100 percentage for cross-scale comparison.
  /// Uses official Philippine grading lookup tables with linear interpolation.
  /// scale_5: Philippine Standard (1.00 best → 98.5%, 3.00 passing → 75%, 5.00 failing → 55%)
  /// scale_4: NU/DLSU/Ateneo (4.0 best → 98%, 1.0 passing → 62.5%, 0.0 failing → 55%)
  static double normalizeGpa(double value, String scale) {
    if (value > 5.0 || scale == 'percentage') {
      return value.clamp(0.0, 100.0);
    }
    switch (scale) {
      case 'scale_4':
        return _interpolate(_scale4Table, value).clamp(0.0, 100.0);
      case 'scale_5':
      default:
        return _interpolate(_scale5Table, value).clamp(0.0, 100.0);
    }
  }

  static bool isQualified(Map<String, dynamic> scholar, Map<String, dynamic> program) {
    // 0. Education Level check — most important pre-filter
    final targetEduLevel = program['target_education_level']?.toString();
    if (targetEduLevel != null && targetEduLevel.isNotEmpty) {
      final scholarEduLevel = scholar['education_level']?.toString() ?? 'college';
      if (scholarEduLevel != targetEduLevel) return false;
    }

    // 1. Course eligibility check
    final courseEl = program['course_eligibility'];
    if (courseEl != null && courseEl is List && courseEl.isNotEmpty) {
      final scholarCourse = scholar['course']?.toString().toLowerCase().trim() ?? '';
      bool match = false;
      for (final c in courseEl) {
        final courseStr = c.toString().toLowerCase().trim();
        if (courseStr == '*' || courseStr == 'all' || courseStr.contains('all') || scholarCourse.contains(courseStr) || courseStr.contains(scholarCourse)) {
          match = true;
          break;
        }
      }
      if (!match) return false;
    }

    // 2. Year level eligibility check
    final yearEl = program['year_level_eligibility'];
    if (yearEl != null && yearEl is List && yearEl.isNotEmpty) {
      final scholarYear = scholar['year_level'];
      if (scholarYear == null) return false;
      bool match = false;
      for (final y in yearEl) {
        if (y.toString() == scholarYear.toString()) {
          match = true;
          break;
        }
      }
      if (!match) return false;
    }

    // 3. Availability scope & Location check
    final scope = program['availability_scope']?.toString().toLowerCase() ?? 'nationwide';
    if (scope == 'nationwide') {
      return true;
    } else if (scope == 'regional') {
      final scholarRegion = scholar['region']?.toString().toLowerCase().trim() ?? '';
      final availableRegions = program['available_regions'];
      if (availableRegions is List && availableRegions.isNotEmpty) {
        return availableRegions.any((r) => r.toString().toLowerCase().trim() == scholarRegion);
      }
      return true;
    } else if (scope == 'provincial') {
      final scholarProvince = scholar['province']?.toString().toLowerCase().trim() ?? '';
      final availableProvinces = program['available_provinces'];
      if (availableProvinces is List && availableProvinces.isNotEmpty) {
        return availableProvinces.any((p) => p.toString().toLowerCase().trim() == scholarProvince);
      }
      return true;
    } else if (scope == 'municipality') {
      final scholarMunicipality = scholar['municipality']?.toString().toLowerCase().trim() ?? '';
      final availableMunicipalities = program['available_municipalities'];
      if (availableMunicipalities is List && availableMunicipalities.isNotEmpty) {
        return availableMunicipalities.any((m) => m.toString().toLowerCase().trim() == scholarMunicipality);
      }
      return true;
    } else if (scope == 'barangay') {
      final scholarBarangay = scholar['barangay']?.toString().toLowerCase().trim() ?? '';
      final availableBarangays = program['available_barangays'];
      if (availableBarangays is List && availableBarangays.isNotEmpty) {
        return availableBarangays.any((b) => b.toString().toLowerCase().trim() == scholarBarangay);
      }
      return true;
    } else if (scope == 'specific_schools') {
      final scholarSchool = scholar['school']?.toString().toLowerCase().trim() ?? '';
      final availableSchools = program['available_schools'];
      if (availableSchools is List && availableSchools.isNotEmpty) {
        return availableSchools.any((s) => scholarSchool.contains(s.toString().toLowerCase().trim()) || s.toString().toLowerCase().trim().contains(scholarSchool));
      }
      return true;
    }

    return true;
  }

  /// Checks whether a scholarship program is currently active and has at least one open, unexpired application cycle.
  static bool isProgramOpen(Map<String, dynamic>? program) {
    if (program == null) return false;
    final status = program['status']?.toString().toLowerCase().trim();
    if (status != null && status.isNotEmpty && status == 'closed') return false;

    final cycles = program['cycles'] as List<dynamic>?;
    if (cycles == null || cycles.isEmpty) return true;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Check if there is at least one cycle that is open or active
    final hasOpenCycle = cycles.any((c) {
      if (c is! Map<String, dynamic>) return false;
      final cStatus = c['status']?.toString().toLowerCase().trim();
      if (cStatus == 'closed') return false;

      // Renewal-only cycles are reserved for approved continuing scholars
      final cType = c['cycle_type']?.toString().toLowerCase().trim() ?? '';
      final cName = c['cycle_name']?.toString().toLowerCase() ?? '';
      if (cType == 'renewal' || cName.contains('renewal') || cName.contains('sem renewal')) {
        return false;
      }

      // Check deadline if present
      final endDateStr = c['application_end_date']?.toString() ?? c['end_date']?.toString();
      if (endDateStr != null && endDateStr.trim().isNotEmpty) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null) {
          final endMidnight = DateTime(endDate.year, endDate.month, endDate.day);
          if (endMidnight.isBefore(todayMidnight)) {
            return false; // Deadline has passed
          }
        }
      }
      return true;
    });

    return hasOpenCycle || cycles.isEmpty;
  }
}

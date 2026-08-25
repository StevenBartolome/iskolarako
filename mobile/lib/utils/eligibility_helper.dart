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
    // Face verification is required to be considered a fully verified scholar
    if (scholar['face_verification_status']?.toString() != 'verified') {
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
    // Check face verification separately with a human-readable label
    if (scholar['face_verification_status']?.toString() != 'verified') {
      missing.add('Identity Verification (face check required)');
    }
    return missing;
  }

  /// Normalises any GPA/grade value to a 0–100 percentage for cross-scale comparison.
  static double normalizeGpa(double value, String scale) {
    switch (scale) {
      case 'scale_4':
        // 4.0 = 100%, 0.0 = 0%
        return (value / 4.0) * 100.0;
      case 'percentage':
        // Already in 0–100
        return value.clamp(0.0, 100.0);
      case 'scale_5':
      default:
        // 1.0 = 100%, 5.0 = 0%  (inverted scale)
        return ((5.0 - value) / 4.0) * 100.0;
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

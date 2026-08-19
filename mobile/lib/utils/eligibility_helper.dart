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
      'gpa',
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
        'GPA / GWA'
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
      'gpa': 'GPA / GWA',
    };
    fieldLabels.forEach((field, label) {
      if (scholar[field] == null || scholar[field].toString().trim().isEmpty) {
        missing.add(label);
      }
    });
    return missing;
  }

  /// Normalises any GPA/grade value to a 0–100 percentage for cross-scale comparison.
  static double _normalizeGpa(double value, String scale) {
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

    // 3. GPA / grade check — scale-aware with cross-scale normalization
    final minGwa = program['minimum_gwa'];
    if (minGwa != null) {
      final scholarGpa = scholar['gpa'] != null
          ? double.tryParse(scholar['gpa'].toString())
          : null;
      final programMinGwa = double.tryParse(minGwa.toString());
      final programScale = program['grading_system']?.toString() ?? 'scale_5';
      final scholarScale = scholar['gpa_scale']?.toString() ?? 'scale_5';

      if (scholarGpa != null && programMinGwa != null) {
        final scholarPct = _normalizeGpa(scholarGpa, scholarScale);
        final minPct     = _normalizeGpa(programMinGwa, programScale);
        if (scholarPct < minPct) return false;
      }
    }

    // 4. Availability scope & Location check
    final scope = program['availability_scope']?.toString().toLowerCase() ?? 'nationwide';
    if (scope == 'nationwide') {
      return true;
    } else if (scope == 'regional') {
      final scholarRegion = scholar['region']?.toString().toLowerCase().trim() ?? '';
      final availableRegions = program['available_regions'];
      if (availableRegions is List) {
        return availableRegions.any((r) => r.toString().toLowerCase().trim() == scholarRegion);
      }
      return false;
    } else if (scope == 'provincial') {
      final scholarProvince = scholar['province']?.toString().toLowerCase().trim() ?? '';
      final availableProvinces = program['available_provinces'];
      if (availableProvinces is List) {
        return availableProvinces.any((p) => p.toString().toLowerCase().trim() == scholarProvince);
      }
      return false;
    } else if (scope == 'municipality') {
      final scholarMunicipality = scholar['municipality']?.toString().toLowerCase().trim() ?? '';
      final availableMunicipalities = program['available_municipalities'];
      if (availableMunicipalities is List) {
        return availableMunicipalities.any((m) => m.toString().toLowerCase().trim() == scholarMunicipality);
      }
      return false;
    } else if (scope == 'barangay') {
      final scholarBarangay = scholar['barangay']?.toString().toLowerCase().trim() ?? '';
      final availableBarangays = program['available_barangays'];
      if (availableBarangays is List) {
        return availableBarangays.any((b) => b.toString().toLowerCase().trim() == scholarBarangay);
      }
      return false;
    } else if (scope == 'specific_schools') {
      final scholarSchool = scholar['school']?.toString().toLowerCase().trim() ?? '';
      final availableSchools = program['available_schools'];
      if (availableSchools is List) {
        return availableSchools.any((s) => scholarSchool.contains(s.toString().toLowerCase().trim()) || s.toString().toLowerCase().trim().contains(scholarSchool));
      }
      return false;
    }

    return true;
  }
}

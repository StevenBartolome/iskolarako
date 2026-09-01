import 'package:flutter_test/flutter_test.dart';
import 'package:iskoako/services/duplicate_check_service.dart';
import 'package:iskoako/services/document_validation_service.dart';

void main() {
  group('DuplicateCheckService Tests', () {
    test('DuplicateCheckResult.notDuplicate initializes with false', () {
      const res = DuplicateCheckResult.notDuplicate;
      expect(res.isDuplicate, isFalse);
      expect(res.isSameAccount, isFalse);
    });

    test('DuplicateCheckResult correctly holds duplicate match info', () {
      final now = DateTime.now();
      final res = DuplicateCheckResult(
        isDuplicate: true,
        isSameAccount: false,
        existingApplicationId: 'app-123',
        existingApplicationStatus: 'APPROVED',
        matchedScholarId: 'scholar-456',
        matchedApplicantName: 'Juan Dela Cruz',
        matchedEmail: 'j***z@gmail.com',
        submittedAt: now,
        message: 'Duplicate application detected.',
      );

      expect(res.isDuplicate, isTrue);
      expect(res.isSameAccount, isFalse);
      expect(res.existingApplicationId, 'app-123');
      expect(res.existingApplicationStatus, 'APPROVED');
      expect(res.matchedApplicantName, 'Juan Dela Cruz');
      expect(res.matchedEmail, 'j***z@gmail.com');
      expect(res.submittedAt, now);
    });

    test('checkForDuplicate with empty inputs returns notDuplicate gracefully', () async {
      final res = await DuplicateCheckService.checkForDuplicate(
        cycleId: '',
        firstName: '',
        lastName: '',
      );
      expect(res.isDuplicate, isFalse);
    });

    group('Identity Matching Rules Tests', () {
      test("User Scenario: 'Mark Steven Mendoza Bartolome' vs 'Mark Mendoza Mendoza' with same birth date matches duplicate", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Mark Steven',
          candMiddle: 'Mendoza',
          candLast: 'Bartolome',
          candBirth: '2002-05-15',
          candPhone: '09171234567',
          normFirst: 'Mark',
          normMiddle: 'Mendoza',
          normLast: 'Mendoza',
          normBirthDate: '2002-05-15',
          normPhone: '',
        );

        expect(isDup, isTrue);
      });

      test("Married Woman Scenario: 'Maria Clara Santos Dela Cruz' vs 'Maria Dela Cruz Reyes' with same birth date matches duplicate", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Maria Clara',
          candMiddle: 'Santos',
          candLast: 'Dela Cruz',
          candBirth: '2003-10-20',
          candPhone: '',
          normFirst: 'Maria',
          normMiddle: 'Dela Cruz',
          normLast: 'Reyes',
          normBirthDate: '2003-10-20',
          normPhone: '',
        );

        expect(isDup, isTrue);
      });

      test("Married Woman Surname Change: 'Maria Santos' vs 'Maria Reyes' with same birth date matches duplicate", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Maria',
          candMiddle: '',
          candLast: 'Santos',
          candBirth: '2003-10-20',
          candPhone: '',
          normFirst: 'Maria',
          normMiddle: '',
          normLast: 'Reyes',
          normBirthDate: '2003-10-20',
          normPhone: '',
        );

        expect(isDup, isTrue);
      });

      test('Legitimate Sibling Scenario: Same last name + different first name + different birth date is NOT duplicate', () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Juan',
          candMiddle: 'Santos',
          candLast: 'Dela Cruz',
          candBirth: '2001-01-01',
          candPhone: '09171112233',
          normFirst: 'Maria',
          normMiddle: 'Santos',
          normLast: 'Dela Cruz',
          normBirthDate: '2003-08-14',
          normPhone: '09189998877',
        );

        expect(isDup, isFalse);
      });

      test("Evasion Attempt Scenario: Exact same full name ('Juan Mendoza Dela Cruz') with altered birth date MUST BE BLOCKED as duplicate", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Juan',
          candMiddle: 'Mendoza',
          candLast: 'Dela Cruz',
          candBirth: '2005-10-10',
          candPhone: '09170001122',
          normFirst: 'Juan',
          normMiddle: 'Mendoza',
          normLast: 'Dela Cruz',
          normBirthDate: '2002-05-15',
          normPhone: '09171234567',
        );

        expect(isDup, isTrue);
      });

      test("Evasion Attempt Scenario: Omitted middle name ('Juan Dela Cruz') with altered birth date MUST BE BLOCKED as duplicate", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Juan',
          candMiddle: '',
          candLast: 'Dela Cruz',
          candBirth: '2005-10-10',
          candPhone: '09170001122',
          normFirst: 'Juan',
          normMiddle: 'Mendoza',
          normLast: 'Dela Cruz',
          normBirthDate: '2002-05-15',
          normPhone: '09171234567',
        );

        expect(isDup, isTrue);
      });

      test("Middle Initial Matching: Declared 'Juan Mendoza Dela Cruz' vs ID 'Juan M. Dela Cruz' with same birth date MUST BE MATCHED as duplicate", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Juan',
          candMiddle: 'M.',
          candLast: 'Dela Cruz',
          candBirth: '2002-05-15',
          candPhone: '09171234567',
          normFirst: 'Juan',
          normMiddle: 'Mendoza',
          normLast: 'Dela Cruz',
          normBirthDate: '2002-05-15',
          normPhone: '09171234567',
        );

        expect(isDup, isTrue);
      });

      test("Middle Initial Conflict: Declared 'Juan M. Dela Cruz' vs 'Juan S. Dela Cruz' with altered birth date MUST BE ALLOWED as distinct individuals", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Juan',
          candMiddle: 'M.',
          candLast: 'Dela Cruz',
          candBirth: '2003-04-12',
          candPhone: '09170001122',
          normFirst: 'Juan',
          normMiddle: 'S.',
          normLast: 'Dela Cruz',
          normBirthDate: '2002-05-15',
          normPhone: '09171234567',
        );

        expect(isDup, isFalse);
      });

      test("Two People Same Name Scenario: Same First & Last Name but DIFFERENT Middle Name ('Juan Mendoza Dela Cruz' vs 'Juan Martez Dela Cruz') MUST BE ALLOWED", () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Juan',
          candMiddle: 'Martez',
          candLast: 'Dela Cruz',
          candBirth: '2003-04-12',
          candPhone: '09170001122',
          normFirst: 'Juan',
          normMiddle: 'Mendoza',
          normLast: 'Dela Cruz',
          normBirthDate: '2002-05-15',
          normPhone: '09171234567',
        );

        expect(isDup, isFalse);
      });

      test('Different Person Scenario: Completely different names and birth dates is NOT duplicate', () {
        final isDup = DuplicateCheckService.isIdentityDuplicateForTesting(
          candFirst: 'Juan',
          candMiddle: 'Ramos',
          candLast: 'Santos',
          candBirth: '2001-01-01',
          candPhone: '09171112233',
          normFirst: 'Pedro',
          normMiddle: 'Gomez',
          normLast: 'Garcia',
          normBirthDate: '2002-05-15',
          normPhone: '09189998877',
        );

        expect(isDup, isFalse);
      });
    });

    group('Document Student Name Verification Tests', () {
      test("User Document Scenario: Declared 'Steven Bartolome Mendoza' vs Document 'Mark Steven M. Bartolome' MUST BE REJECTED (Surname mismatch)", () {
        final isValidMatch = DocumentValidationService.validateStudentNameMatch(
          declaredFullName: 'Steven Bartolome Mendoza',
          declaredFirstName: 'Steven',
          declaredMiddleName: 'Bartolome',
          declaredLastName: 'Mendoza',
          documentStudentName: 'Mark Steven M. Bartolome',
        );

        expect(isValidMatch, isFalse);
      });

      test("Valid Inverted Name: Declared 'Mark Steven Bartolome' vs Document 'Bartolome, Mark Steven M.' MUST BE ACCEPTED", () {
        final isValidMatch = DocumentValidationService.validateStudentNameMatch(
          declaredFullName: 'Mark Steven Bartolome',
          declaredFirstName: 'Mark Steven',
          declaredMiddleName: 'Mendoza',
          declaredLastName: 'Bartolome',
          documentStudentName: 'Bartolome, Mark Steven M.',
        );

        expect(isValidMatch, isTrue);
      });

      test("Valid Married Woman: Declared 'Maria Santos Dela Cruz' vs Document 'Maria Dela Cruz-Reyes' MUST BE ACCEPTED", () {
        final isValidMatch = DocumentValidationService.validateStudentNameMatch(
          declaredFullName: 'Maria Santos Dela Cruz',
          declaredFirstName: 'Maria',
          declaredMiddleName: 'Santos',
          declaredLastName: 'Dela Cruz',
          documentStudentName: 'Maria Dela Cruz Reyes',
        );

        expect(isValidMatch, isTrue);
      });
    });

    group('Profile Integrity & Name Modification Tests', () {
      test("User Discrepancy Scenario: Verified ID 'Mark Steven Bartolome' vs Profile 'Steven Bartolome Mendoza' MUST BE BLOCKED (Tampered)", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'Mark Steven Bartolome',
          'first_name': 'Steven',
          'middle_name': 'Bartolome',
          'last_name': 'Mendoza',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isTrue);
        expect(integrity.verifiedIdName, 'Mark Steven Bartolome');
      });

      test("User Discrepancy Scenario: Verified ID 'Mark Steven Bartolome' vs Profile 'Mark Joseph Bartolome' MUST BE BLOCKED (First name tampered)", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'Mark Steven Bartolome',
          'first_name': 'Mark Joseph',
          'middle_name': '',
          'last_name': 'Bartolome',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isTrue);
        expect(integrity.verifiedIdName, 'Mark Steven Bartolome');
      });

      test("User Discrepancy Scenario: Verified ID 'Mark Steven Bartolome' vs Profile 'Mark Bartolome' MUST BE BLOCKED (Omitted second given name)", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'Mark Steven Bartolome',
          'first_name': 'Mark',
          'middle_name': '',
          'last_name': 'Bartolome',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isTrue);
        expect(integrity.verifiedIdName, 'Mark Steven Bartolome');
      });

      test("Allowed Minor Change: Verified ID 'Mark Steven Bartolome' vs Profile 'Mark Steven Mendoza Bartolome' MUST BE ALLOWED", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'Mark Steven Bartolome',
          'first_name': 'Mark Steven',
          'middle_name': 'Mendoza',
          'last_name': 'Bartolome',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isFalse);
      });

      test("Allowed Married Woman Change: Verified ID 'Maria Santos Dela Cruz' vs Profile 'Maria Dela Cruz Reyes' MUST BE ALLOWED", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'Maria Santos Dela Cruz',
          'first_name': 'Maria',
          'middle_name': 'Dela Cruz',
          'last_name': 'Reyes',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isFalse);
      });

      test("Identical Name Scenario: Verified ID 'LANIE MAE DELA CRUZ' vs Profile 'lanie mae dela cruz' MUST BE ALLOWED", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'LANIE MAE DELA CRUZ',
          'first_name': 'lanie mae',
          'middle_name': '',
          'last_name': 'dela cruz',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isFalse);
      });

      test("Multi-word Surname Scenario: Verified ID 'MARK PULONG BARIT' vs Profile 'Mark' / 'Pulong Barit' MUST BE ALLOWED", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'MARK PULONG BARIT',
          'first_name': 'Mark',
          'middle_name': '',
          'last_name': 'Pulong Barit',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isFalse);
      });

      test("Standard 3-Field Name Scenario: Verified ID 'MARK REYES CRUZ' vs Profile First 'Mark', Middle 'Reyes', Last 'Cruz' MUST BE ALLOWED", () {
        final scholar = {
          'face_verification_status': 'verified',
          'verified_id_name': 'MARK REYES CRUZ',
          'first_name': 'Mark',
          'middle_name': 'Reyes',
          'last_name': 'Cruz',
        };

        final integrity = DuplicateCheckService.checkProfileIntegrity(scholar: scholar);
        expect(integrity.isTampered, isFalse);
      });
    });
  });
}

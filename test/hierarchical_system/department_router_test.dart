import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sevasetu/hierarchical_system/models/enums.dart';
import 'package:sevasetu/hierarchical_system/services/department_router.dart';

void main() {
  late DepartmentRouter router;

  setUp(() {
    router = DepartmentRouter();
  });

  group('DepartmentRouter', () {
    // Feature: sevasetu-hierarchical-system, Property 2: Department Routing Totality and Determinism
    // Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
    group('Property 2: Department Routing Totality and Determinism', () {
      test('every valid category maps to exactly one department', () {
        // For all valid categories, there must be exactly one department mapping
        for (final category in IssueCategory.all) {
          final department = router.mapCategoryToDepartment(category);

          // Verify it returns a valid department (not null)
          expect(
            department,
            isA<Department>(),
            reason: 'Category $category should map to a department',
          );

          // Verify determinism: same input always produces same output
          final department2 = router.mapCategoryToDepartment(category);
          expect(
            department,
            equals(department2),
            reason:
                'Category $category should always map to the same department',
          );
        }
      });

      test('POTHOLE and DRAINAGE_PROBLEM route to PWD', () {
        expect(
          router.mapCategoryToDepartment(IssueCategory.pothole),
          equals(Department.pwd),
        );
        expect(
          router.mapCategoryToDepartment(IssueCategory.drainageProblem),
          equals(Department.pwd),
        );
      });

      test('GARBAGE and SEWAGE_OVERFLOW route to SANITATION', () {
        expect(
          router.mapCategoryToDepartment(IssueCategory.garbage),
          equals(Department.sanitation),
        );
        expect(
          router.mapCategoryToDepartment(IssueCategory.sewageOverflow),
          equals(Department.sanitation),
        );
      });

      test('STREETLIGHT and POWER_CUT route to ELECTRICITY', () {
        expect(
          router.mapCategoryToDepartment(IssueCategory.streetlight),
          equals(Department.electricity),
        );
        expect(
          router.mapCategoryToDepartment(IssueCategory.powerCut),
          equals(Department.electricity),
        );
      });

      test('WATER_LEAK routes to WATER', () {
        expect(
          router.mapCategoryToDepartment(IssueCategory.waterLeak),
          equals(Department.water),
        );
      });

      test('OTHER routes to GENERAL', () {
        expect(
          router.mapCategoryToDepartment(IssueCategory.other),
          equals(Department.general),
        );
      });

      test('invalid categories route to GENERAL', () {
        final invalidCategories = ['INVALID', 'unknown', '', 'random123'];

        for (final category in invalidCategories) {
          expect(
            router.mapCategoryToDepartment(category),
            equals(Department.general),
            reason: 'Invalid category "$category" should route to GENERAL',
          );
        }
      });

      test('routing is case-insensitive', () {
        // Test with different cases
        expect(
          router.mapCategoryToDepartment('pothole'),
          equals(Department.pwd),
        );
        expect(
          router.mapCategoryToDepartment('POTHOLE'),
          equals(Department.pwd),
        );
        expect(
          router.mapCategoryToDepartment('Pothole'),
          equals(Department.pwd),
        );
        expect(
          router.mapCategoryToDepartment('PoThOlE'),
          equals(Department.pwd),
        );
      });

      test('property: routing is deterministic over 100 random iterations', () {
        final random = Random(42);
        final allCategories = [...IssueCategory.all, 'INVALID', '', 'random'];

        for (int i = 0; i < 100; i++) {
          final category = allCategories[random.nextInt(allCategories.length)];
          final result1 = router.mapCategoryToDepartment(category);
          final result2 = router.mapCategoryToDepartment(category);

          expect(
            result1,
            equals(result2),
            reason: 'Routing should be deterministic for category: $category',
          );
        }
      });
    });

    group('getCategoriesForDepartment', () {
      test('returns correct categories for each department', () {
        expect(
          router.getCategoriesForDepartment(Department.pwd),
          containsAll([IssueCategory.pothole, IssueCategory.drainageProblem]),
        );

        expect(
          router.getCategoriesForDepartment(Department.sanitation),
          containsAll([IssueCategory.garbage, IssueCategory.sewageOverflow]),
        );

        expect(
          router.getCategoriesForDepartment(Department.electricity),
          containsAll([IssueCategory.streetlight, IssueCategory.powerCut]),
        );

        expect(
          router.getCategoriesForDepartment(Department.water),
          contains(IssueCategory.waterLeak),
        );

        expect(
          router.getCategoriesForDepartment(Department.general),
          contains(IssueCategory.other),
        );
      });

      test('inverse relationship: category maps back to its department', () {
        for (final department in Department.values) {
          final categories = router.getCategoriesForDepartment(department);

          for (final category in categories) {
            expect(
              router.mapCategoryToDepartment(category),
              equals(department),
              reason: 'Category $category should map back to $department',
            );
          }
        }
      });
    });
  });
}

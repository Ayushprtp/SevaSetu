import '../models/enums.dart';

/// Routes civic issues to the appropriate government department based on category.
class DepartmentRouter {
  /// Maps an issue category to the responsible department.
  ///
  /// Category to Department mapping:
  /// - POTHOLE, DRAINAGE_PROBLEM → PWD (Public Works)
  /// - GARBAGE, SEWAGE_OVERFLOW → SANITATION
  /// - STREETLIGHT, POWER_CUT → ELECTRICITY
  /// - WATER_LEAK → WATER
  /// - OTHER → GENERAL
  Department mapCategoryToDepartment(String category) {
    final normalizedCategory = category.toUpperCase();

    switch (normalizedCategory) {
      case IssueCategory.pothole:
      case IssueCategory.drainageProblem:
        return Department.pwd;

      case IssueCategory.garbage:
      case IssueCategory.sewageOverflow:
        return Department.sanitation;

      case IssueCategory.streetlight:
      case IssueCategory.powerCut:
        return Department.electricity;

      case IssueCategory.waterLeak:
        return Department.water;

      case IssueCategory.other:
      default:
        return Department.general;
    }
  }

  /// Returns all categories handled by a specific department.
  List<String> getCategoriesForDepartment(Department department) {
    switch (department) {
      case Department.pwd:
        return [IssueCategory.pothole, IssueCategory.drainageProblem];

      case Department.sanitation:
        return [IssueCategory.garbage, IssueCategory.sewageOverflow];

      case Department.electricity:
        return [IssueCategory.streetlight, IssueCategory.powerCut];

      case Department.water:
        return [IssueCategory.waterLeak];

      case Department.general:
        return [IssueCategory.other];
    }
  }

  /// Validates that a category is valid and returns the normalized form.
  String validateCategory(String category) {
    return IssueCategory.normalize(category);
  }

  /// Checks if a category is valid.
  bool isValidCategory(String category) {
    return IssueCategory.isValid(category);
  }
}

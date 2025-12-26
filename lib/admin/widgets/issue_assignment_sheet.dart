import 'package:flutter/material.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:sevasetu/admin/admin_service.dart';
import 'package:sevasetu/services/push_notification_service.dart';

/// Bottom sheet for assigning issues to workers
class IssueAssignmentSheet extends StatefulWidget {
  final String issueId;
  final String officeId;
  final String issueCategory;
  final String issueAddress;
  final VoidCallback? onAssigned;

  const IssueAssignmentSheet({
    super.key,
    required this.issueId,
    required this.officeId,
    required this.issueCategory,
    required this.issueAddress,
    this.onAssigned,
  });

  @override
  State<IssueAssignmentSheet> createState() => _IssueAssignmentSheetState();
}

class _IssueAssignmentSheetState extends State<IssueAssignmentSheet> {
  final AdminService _adminService = AdminService();
  final PushNotificationService _notificationService =
      PushNotificationService();

  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  bool _isAssigning = false;
  String? _selectedWorkerId;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workers = await _adminService.getOfficeWorkers(widget.officeId);
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
      }
    }
  }

  Future<void> _assignToWorker() async {
    if (_selectedWorkerId == null) return;

    setState(() => _isAssigning = true);
    try {
      await _adminService.assignIssueToWorker(
        widget.issueId,
        _selectedWorkerId!,
      );

      // Send notification to worker
      await _notificationService.notifyWorkerAssignment(
        workerId: _selectedWorkerId!,
        issueId: widget.issueId,
        issueCategory: widget.issueCategory,
        issueAddress: widget.issueAddress,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue assigned successfully')),
        );
        widget.onAssigned?.call();
      }
    } catch (e) {
      setState(() => _isAssigning = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error assigning issue: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text('Assign Issue', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select a worker to assign this issue',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Issue info
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.report_problem_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.issueCategory,
                        style: AppTextStyles.labelLarge,
                      ),
                      Text(
                        widget.issueAddress,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.neutral600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Workers list
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_workers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      size: 48,
                      color: AppColors.neutral400,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No workers available',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _workers.length,
                itemBuilder: (context, index) {
                  final worker = _workers[index];
                  final userData = worker['users'] as Map<String, dynamic>?;
                  final workerId = worker['user_id'] as String;
                  final email = userData?['email'] as String? ?? 'Unknown';
                  final firstName = userData?['first_name'] as String?;
                  final lastName = userData?['last_name'] as String?;

                  String displayName = email;
                  if (firstName != null || lastName != null) {
                    displayName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
                  }

                  final isSelected = _selectedWorkerId == workerId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: isSelected
                          ? const BorderSide(color: AppColors.primary, width: 2)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      onTap: () => setState(() => _selectedWorkerId = workerId),
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.neutral200,
                        child: Icon(
                          Icons.person_rounded,
                          color: isSelected
                              ? Colors.white
                              : AppColors.neutral500,
                        ),
                      ),
                      title: Text(displayName, style: AppTextStyles.bodyLarge),
                      subtitle: Text(
                        email,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Assign button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedWorkerId != null && !_isAssigning
                  ? _assignToWorker
                  : null,
              child: _isAssigning
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Assign Issue'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Show the assignment sheet
void showIssueAssignmentSheet({
  required BuildContext context,
  required String issueId,
  required String officeId,
  required String issueCategory,
  required String issueAddress,
  VoidCallback? onAssigned,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => IssueAssignmentSheet(
      issueId: issueId,
      officeId: officeId,
      issueCategory: issueCategory,
      issueAddress: issueAddress,
      onAssigned: onAssigned,
    ),
  );
}

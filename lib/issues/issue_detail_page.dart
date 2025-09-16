import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sevasetu/utils/app_styles.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for map, call, message
import 'package:audioplayers/audioplayers.dart'; // Added for voice note playback

class IssueDetailPage extends StatefulWidget {
  final String issueId;

  const IssueDetailPage({super.key, required this.issueId});

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  Map<String, dynamic>? _issueDetails;
  Map<String, dynamic>? _reporterDetails;
  bool _isLoading = true;
  String? _errorMessage;
  final AudioPlayer _audioPlayer = AudioPlayer(); // Initialize AudioPlayer
  String? _currentUserId; // To store the current user's ID
  bool _hasUpvoted = false; // To track if the current user has upvoted
  String? _issueReporterId; // To store the ID of the user who reported the issue

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id; // Get current user ID
    _fetchIssueDetails();
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Dispose AudioPlayer
    super.dispose();
  }

  Future<void> _fetchIssueDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        // Reset reporter details on new fetch
        _reporterDetails = null;
      });

      final supabase = Supabase.instance.client;
      
      // Fetch issue details with user join
      final response = await supabase
          .from('civic_issues')
          .select('''
            *,
            user_id,
            users:user_id(username, first_name, last_name)
          ''')
          .eq('id', widget.issueId)
          .single();
      
      print('Issue details response: $response');
      
      // Extract reporter data from the join
      final usersData = response['users'];
      print('Joined users data: $usersData');
      print('Response keys: ${response.keys}');
      
      Map<String, dynamic>? reporterData = usersData is Map<String, dynamic> ? usersData : null;
      
      // Check if joined user data is valid (has non-null username, first_name or last_name)
      bool hasValidJoinedUserData = reporterData != null &&
          (reporterData['username'] != null || reporterData['first_name'] != null || reporterData['last_name'] != null);
      
      // If user data is not in the join or is invalid, fetch it separately
      if (!hasValidJoinedUserData) {
        final userId = response['user_id'] as String?;
        if (userId != null) {
          try {
            final userResponse = await supabase
                .from('users')
                .select('username, first_name, last_name')
                .eq('id', userId)
                .maybeSingle();
            // Only set reporterData if the separate fetch was successful and returned data
            print('Separate user fetch result: $userResponse');
            if (userResponse != null) {
              reporterData = userResponse as Map<String, dynamic>;
            }
          } catch (userFetchError) {
            // If we can't fetch user data, reporterData remains null
            print('Error fetching user data for user_id $userId: $userFetchError');
          }
        }
      }

      print('Final reporterData: $reporterData');
      
      // Determine if the current user has upvoted this issue by querying the issue_upvotes table
      bool hasUpvoted = false;
      if (_currentUserId != null) {
        final upvoteResponse = await supabase
            .from('issue_upvotes')
            .select('issue_id')
            .eq('user_id', _currentUserId!)
            .eq('issue_id', widget.issueId)
            .limit(1);
        hasUpvoted = upvoteResponse.isNotEmpty;
      }

      // Get the reporter's user ID
      final String? reporterId = response['user_id'] as String?;

      setState(() {
        _issueDetails = response;
        _reporterDetails = reporterData;
        _hasUpvoted = hasUpvoted;
        _issueReporterId = reporterId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching issue details: $e';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching issue details: $e')),
        );
      }
    }
  }

  void _openFullScreenImage(BuildContext context, List<dynamic> mediaFiles, int initialIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FullScreenImageViewer(
          mediaFiles: mediaFiles,
          initialIndex: initialIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop(); // Use go_router's pop for back navigation
          },
        ),
        title: Text(
          'Issue Details',
          style: AppTextStyles.titleMedium,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _issueDetails == null
                  ? const Center(child: Text('Issue not found.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIssueHeader(context),
                          const SizedBox(height: 24),
                          _buildMediaSection(context),
                          const SizedBox(height: 24),
                          _buildDescriptionSection(context),
                          const SizedBox(height: 24),
                          _buildLocationSection(context),
                          const SizedBox(height: 24),
                          _buildStatusSection(context),
                          const SizedBox(height: 24),
                          _buildFieldWorkerSection(context),
                          const SizedBox(height: 24),
                          _buildUpvoteSection(context),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildIssueHeader(BuildContext context) {
    final category = _issueDetails!['category'] as String? ?? 'Unknown';
    final address = _issueDetails!['address'] as String? ?? 'Unknown location';
    final createdAt = DateTime.parse(_issueDetails!['created_at'] as String);
    
    // Use separately fetched reporter details if available, otherwise fall back to joined data
    String reporterName = '';
    
    // Helper function to build name from available fields
    String _buildDisplayName(Map<String, dynamic> userData) {
      final firstName = userData['first_name'] as String?;
      final lastName = userData['last_name'] as String?;
      final username = userData['username'] as String?;
      
      if (firstName != null && lastName != null) {
        return '$firstName $lastName';
      } else if (firstName != null) {
        return firstName;
      } else if (lastName != null) {
        return lastName;
      } else if (username != null) {
        return username;
      }
      return '';
    }
    
    if (_reporterDetails != null) {
      reporterName = _buildDisplayName(_reporterDetails!);
    } else if (_issueDetails!['users'] != null) {
      final usersData = _issueDetails!['users'] as Map<String, dynamic>?;
      // Check if usersData is valid (has non-null username, first_name or last_name)
      bool hasValidUsersData = usersData != null &&
          (usersData['username'] != null || usersData['first_name'] != null || usersData['last_name'] != null);
      
      if (hasValidUsersData) {
        reporterName = _buildDisplayName(usersData!);
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: AppTextStyles.titleLarge.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Theme.of(context).hintColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (reporterName.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person, size: 18, color: Theme.of(context).hintColor),
                  const SizedBox(width: 8),
                  Text(
                    'Reported by: $reporterName',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: Theme.of(context).hintColor),
                const SizedBox(width: 8),
                Text(
                  'On: ${DateFormat('MMM dd, yyyy HH:mm').format(createdAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context) {
    final mediaFiles = _issueDetails!['media_files'] as List<dynamic>?;

    if (mediaFiles == null || mediaFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidence (${mediaFiles.length} media files)',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: mediaFiles.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  _openFullScreenImage(context, mediaFiles, index);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      mediaFiles[index] as String,
                      fit: BoxFit.cover,
                      width: 150,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 150,
                        height: 200,
                        color: Colors.grey[300],
                        child: Icon(Icons.broken_image, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    final description = _issueDetails!['description'] as String?;
    final voiceNoteUrl = _issueDetails!['voice_note_url'] as String?;

    if (description == null && voiceNoteUrl == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 16),
        if (description != null && description.isNotEmpty)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                description,
                style: AppTextStyles.bodyLarge,
              ),
            ),
          ),
        if (voiceNoteUrl != null && voiceNoteUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.audiotrack, color: Theme.of(context).primaryColor),
              title: const Text(
                'Voice Note Available',
                style: AppTextStyles.bodyLarge,
              ),
              trailing: Icon(Icons.play_arrow),
              onTap: () async {
                if (voiceNoteUrl != null && voiceNoteUrl.isNotEmpty) {
                  try {
                    await _audioPlayer.play(UrlSource(voiceNoteUrl));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Playing voice note')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error playing voice note: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    final location = _issueDetails!['location'] as String?;
    final address = _issueDetails!['address'] as String? ?? 'N/A';

    if (location == null) {
      return const SizedBox.shrink();
    }

    // Parse the location string to extract coordinates
    // The format is: "POINT(longitude latitude)"
    final RegExp pointRegExp = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)');
    final Match? match = pointRegExp.firstMatch(location);
    
    if (match == null) {
      return const SizedBox.shrink();
    }
    
    final double longitude = double.parse(match.group(1)!);
    final double latitude = double.parse(match.group(2)!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Details',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address: $address',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Latitude: ${latitude.toStringAsFixed(6)}',
                  style: AppTextStyles.bodyLarge,
                ),
                Text(
                  'Longitude: ${longitude.toStringAsFixed(6)}',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final lat = latitude.toString();
                      final lng = longitude.toString();
                      final mapUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng'); // Generic geo URI
                      if (await canLaunchUrl(mapUrl)) {
                        await launchUrl(mapUrl);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open map application')),
                          );
                        }
                      }
                    },
                    icon: Icon(Icons.map),
                    label: const Text('View on Map', style: AppTextStyles.button),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final status = _issueDetails!['status'] as String? ?? 'reported';
    final assignedDepartment = _issueDetails!['assigned_department'] as String? ?? 'Not Assigned';
    // Placeholder for expected fix time - not in schema yet
    final expectedFixTime = '2-3 business days'; 

    double progressValue;
    String statusText;
    Color progressColor;

    switch (status) {
      case 'reported':
        progressValue = 0.2;
        statusText = 'Reported';
        progressColor = Colors.red;
        break;
      case 'in_progress':
        progressValue = 0.6;
        statusText = 'In Progress';
        progressColor = Colors.orange;
        break;
      case 'completed':
        progressValue = 1.0;
        statusText = 'Completed';
        progressColor = Colors.green;
        break;
      default:
        progressValue = 0.0;
        statusText = 'Unknown';
        progressColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status & Assignment',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Status: $statusText',
                  style: AppTextStyles.titleSmall.copyWith(color: progressColor),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Colors.grey[300],
                  color: progressColor,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Assigned Department: $assignedDepartment',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Expected Resolution: $expectedFixTime',
                  style: AppTextStyles.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldWorkerSection(BuildContext context) {
    // Placeholder data for field worker
    final fieldWorkerName = 'Rajesh Sharma';
    final fieldWorkerPicture = 'https://via.placeholder.com/150'; // Placeholder image
    final fieldWorkerNumber = '+91 98765 43210';

    // Only show if assigned
    final assignedDepartment = _issueDetails!['assigned_department'] as String?;
    if (assignedDepartment == null || assignedDepartment == 'Not Assigned') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Field Worker Details',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(fieldWorkerPicture),
                  onBackgroundImageError: (exception, stackTrace) {
                    // Handle image loading errors
                    print('Error loading image: $exception');
                  },
                  child: fieldWorkerPicture.isEmpty ? Icon(Icons.person, size: 30) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fieldWorkerName,
                        style: AppTextStyles.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact: $fieldWorkerNumber',
                        style: AppTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final Uri launchUri = Uri(
                                scheme: 'tel',
                                path: fieldWorkerNumber.replaceAll(' ', ''), // Remove spaces for URI
                              );
                              if (await canLaunchUrl(launchUri)) {
                                await launchUrl(launchUri);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not launch call')),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.call),
                            label: const Text('Call', style: AppTextStyles.button),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final Uri launchUri = Uri(
                                scheme: 'sms',
                                path: fieldWorkerNumber.replaceAll(' ', ''), // Remove spaces for URI
                              );
                              if (await canLaunchUrl(launchUri)) {
                                await launchUrl(launchUri);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not launch message')),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.message),
                            label: const Text('Message', style: AppTextStyles.button),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpvoteSection(BuildContext context) {
    final upvotes = _issueDetails!['upvotes'] as int? ?? 0;
    final issueId = _issueDetails!['id'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Community Support',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$upvotes Upvotes',
                  style: AppTextStyles.titleSmall,
                ),
                ElevatedButton.icon(
                  onPressed: (_currentUserId == null || _currentUserId == _issueReporterId || _hasUpvoted)
                      ? null
                      : () => _upvoteIssue(issueId),
                  icon: _hasUpvoted
                      ? const Icon(Icons.check)
                      : (_currentUserId == _issueReporterId ? const Icon(Icons.person) : const Icon(Icons.arrow_upward)),
                  label: Text(
                    _hasUpvoted
                        ? 'Upvoted'
                        : (_currentUserId == _issueReporterId ? 'Your Issue' : 'Upvote'),
                    style: AppTextStyles.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    backgroundColor: _hasUpvoted ? Colors.green : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _upvoteIssue(String issueId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await supabase.rpc('upvote_issue', params: {
        'p_user_id': user.id,
        'p_issue_id': issueId,
      });

      // Refresh issue details to show updated upvote count
      await _fetchIssueDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue upvoted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error upvoting issue: $e')),
        );
      }
    }
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<dynamic> mediaFiles;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.mediaFiles,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header with close button and image counter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentIndex + 1} of ${widget.mediaFiles.length}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Full-screen image viewer
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaFiles.length,
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      widget.mediaFiles[index] as String,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.black,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                );
              },
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
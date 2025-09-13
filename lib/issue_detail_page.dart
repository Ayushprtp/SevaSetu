import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class IssueDetailPage extends StatefulWidget {
  final String issueId;

  const IssueDetailPage({super.key, required this.issueId});

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  Map<String, dynamic>? _issueDetails;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchIssueDetails();
  }

  Future<void> _fetchIssueDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('civic_issues')
          .select('''
            *,
            users!civic_issues_user_id_fkey(first_name, last_name)
          ''')
          .eq('id', widget.issueId)
          .single();

      setState(() {
        _issueDetails = response;
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
        title: const Text(
          'Issue Details',
          style: TextStyle(fontFamily: 'SFProRounded Medium'),
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
    final reporterFirstName = _issueDetails!['users']['first_name'] as String? ?? 'Anonymous';
    final reporterLastName = _issueDetails!['users']['last_name'] as String? ?? '';

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
              style: TextStyle(
                fontFamily: 'SFProRounded Medium',
                fontSize: 22,
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
                    style: TextStyle(
                      fontFamily: 'SFProRounded Regular',
                      fontSize: 16,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 18, color: Theme.of(context).hintColor),
                const SizedBox(width: 8),
                Text(
                  'Reported by: $reporterFirstName $reporterLastName',
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    fontSize: 14,
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
                  style: TextStyle(
                    fontFamily: 'SFProRounded Regular',
                    fontSize: 14,
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
          'Evidence',
          style: TextStyle(
            fontFamily: 'SFProRounded Medium',
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: mediaFiles.length,
            itemBuilder: (context, index) {
              return Padding(
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
          style: TextStyle(
            fontFamily: 'SFProRounded Medium',
            fontSize: 20,
          ),
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
                style: TextStyle(
                  fontFamily: 'SFProRounded Regular',
                  fontSize: 16,
                ),
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
                style: TextStyle(fontFamily: 'SFProRounded Regular'),
              ),
              trailing: Icon(Icons.play_arrow),
              onTap: () {
                // TODO: Implement voice note playback
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice note playback not implemented')),
                );
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
          style: TextStyle(
            fontFamily: 'SFProRounded Medium',
            fontSize: 20,
          ),
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
                  style: TextStyle(fontFamily: 'SFProRounded Regular', fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Latitude: ${latitude.toStringAsFixed(6)}',
                  style: TextStyle(fontFamily: 'SFProRounded Regular', fontSize: 16),
                ),
                Text(
                  'Longitude: ${longitude.toStringAsFixed(6)}',
                  style: TextStyle(fontFamily: 'SFProRounded Regular', fontSize: 16),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Open in map application
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Open in map not implemented')),
                      );
                    },
                    icon: Icon(Icons.map),
                    label: const Text('View on Map'),
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
          style: TextStyle(
            fontFamily: 'SFProRounded Medium',
            fontSize: 20,
          ),
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
                  style: TextStyle(fontFamily: 'SFProRounded Medium', fontSize: 18, color: progressColor),
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
                  style: TextStyle(fontFamily: 'SFProRounded Regular', fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expected Resolution: $expectedFixTime',
                  style: TextStyle(fontFamily: 'SFProRounded Regular', fontSize: 16),
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
          style: TextStyle(
            fontFamily: 'SFProRounded Medium',
            fontSize: 20,
          ),
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
                        style: TextStyle(fontFamily: 'SFProRounded Medium', fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact: $fieldWorkerNumber',
                        style: TextStyle(fontFamily: 'SFProRounded Regular', fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement call functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Call functionality not implemented')),
                              );
                            },
                            icon: Icon(Icons.call),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement message functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Message functionality not implemented')),
                              );
                            },
                            icon: Icon(Icons.message),
                            label: const Text('Message'),
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
          style: TextStyle(
            fontFamily: 'SFProRounded Medium',
            fontSize: 20,
          ),
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
                  style: TextStyle(fontFamily: 'SFProRounded Medium', fontSize: 18),
                ),
                ElevatedButton.icon(
                  onPressed: () => _upvoteIssue(issueId),
                  icon: Icon(Icons.thumb_up),
                  label: const Text('Upvote'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        'user_id': user.id,
        'issue_id': issueId,
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
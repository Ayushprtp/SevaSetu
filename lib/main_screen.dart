import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sevasetu/main.dart'; // Import main.dart to access themeNotifier
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:sevasetu/home/feed_page.dart';
import 'package:sevasetu/home/report_problem_page.dart';
import 'package:sevasetu/home/settings_page.dart';
import 'package:sevasetu/utils/app_styles.dart'; // Added import

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      FeedPage(onReportPressed: () {
        setState(() {
          _currentIndex = 1;
        });
      }),
      ReportProblemPage(onReportSubmitted: () {
        setState(() {
          _currentIndex = 0; // Navigate to Feed page (index 0)
        });
      }),
      const SettingsPage()
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        height: 60.0,
        items: const <Widget>[
          Icon(Icons.feed, size: 35),
          Icon(Icons.add, size: 35),
          Icon(Icons.person, size: 35),
        ],
        color: Theme.of(context).colorScheme.primary,
        buttonBackgroundColor: Theme.of(context).colorScheme.primary,
        backgroundColor: CupertinoColors.transparent,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Feed';
      case 1:
        return 'Raise Issues';
      case 2:
        return 'Profile';
      default:
        return 'SevaSetu'; // Default title
    }
  }
}

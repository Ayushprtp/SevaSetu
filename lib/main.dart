import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_router.dart'; // Import the router

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://urpijfugdwxzhqjbktrx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVycGlqZnVnZHd4emhxamJrdHJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3MzgzMjksImV4cCI6MjA3MzMxNDMyOX0.XymZB_EPdD_ybNoFiQjS63jjSg6hbO3RH1qnrA6M7Ag',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'JanSahayak',
          theme: ThemeData(
            fontFamily: 'SFProRounded Regular', // Default font for light mode
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            dropdownMenuTheme: DropdownMenuThemeData( // Apply to light theme
              menuStyle: MenuStyle(
                shape: MaterialStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                elevation: MaterialStateProperty.all<double>(8.0),
              ),
            ),
          ),
          darkTheme: ThemeData(
            fontFamily: 'SFProRounded Regular', // Default font for dark mode
            scaffoldBackgroundColor: Colors.black, // Black background for Scaffold
            canvasColor: Colors.black, // Black background for other surfaces
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
              primary: Colors.deepPurple[400], // Adjust primary color for dark mode buttons
            ),
            useMaterial3: true,
            dropdownMenuTheme: DropdownMenuThemeData( // Apply to dark theme
              menuStyle: MenuStyle(
                shape: MaterialStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                elevation: MaterialStateProperty.all<double>(8.0),
              ),
            ),
          ),
          themeMode: mode,
          routerConfig: appRouter,
        );
      },
    );
  }
}

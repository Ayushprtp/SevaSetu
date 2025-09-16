import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_router.dart'; // Import the router
import 'main_screen.dart'; // Import the main screen

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

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: true,
          title: 'SevaSetu',
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
            appBarTheme: AppBarTheme(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              actionsIconTheme: const IconThemeData(color: Colors.white),
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
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
              actionsIconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          themeMode: mode,
          routerConfig: appRouter,
        );
      },
    );
  }
}

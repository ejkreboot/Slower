import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'pages/audio_player_page.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Slower');
    setWindowMinSize(const Size(600, 700)); 
    setWindowMaxSize(Size.infinite);
    setWindowFrame(const Rect.fromLTWH(100, 100, 600, 700)); 
  }
  runApp(const SlowerApp());
}

class SlowerApp extends StatelessWidget {
  const SlowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slower',
      theme: _buildSlowerTheme(),
      home: const AudioPlayerPage(),
    );
  }
}

ThemeData _buildSlowerTheme() {
  const primaryColor = Color(0xFF1E1E2E); // Deep midnight blue
  const secondaryColor = Color(0xFF0095F2); // Vibrant violet
  const lightGray = Color(0xFFCBD5E1); // Soft cool gray
  const accentColor = Color(0xFF00D1FF); // Bright cyan
  const lightBackground = Color(0xFFF8FAFC); // Almost white

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Text',
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: secondaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.w300),
      bodySmall: TextStyle(color: secondaryColor, fontSize: 12, fontWeight: FontWeight.w300),
      titleLarge: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w400),
      titleSmall: TextStyle(color: secondaryColor, fontSize: 16, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: lightGray, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: lightGray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: secondaryColor, width: 2),
      ),
      filled: true,
      fillColor: Color(0xFFF1F5F9), // slightly blue-gray fill for input fields
      labelStyle: TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: TextStyle(
        color: Color(0xFF0095F2),
        fontSize: 16,
        fontWeight: FontWeight.w400)
    ),
    cardTheme: const CardTheme(
      color: Colors.white,
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      elevation: 3,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        backgroundColor: lightBackground,
        foregroundColor: primaryColor,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    dialogTheme: const DialogTheme(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      backgroundColor: Colors.white,
      elevation: 6,
    ),
  );
}



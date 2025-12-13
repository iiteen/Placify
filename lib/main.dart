import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/background_service.dart';
import 'utils/applogger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WorkManager background dispatcher
  await BackgroundService.initialize();
  await AppLogger.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Placement Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

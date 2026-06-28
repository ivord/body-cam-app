import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';

class NvrApp extends StatelessWidget {
  const NvrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NVR Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

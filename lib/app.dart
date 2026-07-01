import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';

class NvrApp extends StatelessWidget {
  const NvrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LGS Body Camera',
      theme: buildAppTheme(),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

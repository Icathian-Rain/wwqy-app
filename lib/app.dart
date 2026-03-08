import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/lineup_provider.dart';
import 'screens/home_screen.dart';

class WwqyApp extends StatelessWidget {
  const WwqyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LineupProvider(),
      child: MaterialApp(
        title: '游戏点位助手',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

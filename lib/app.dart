import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/lineup_provider.dart';
import 'screens/home_screen.dart';

class WwqyApp extends StatelessWidget {
  const WwqyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Windows 桌面端设置中文字体
    final fontFamily = Platform.isWindows ? 'Microsoft YaHei' : null;

    return ChangeNotifierProvider(
      create: (_) => LineupProvider(),
      child: MaterialApp(
        title: '游戏点位助手',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: fontFamily,
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

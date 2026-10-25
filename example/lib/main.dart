import 'package:flutter/material.dart';

import 'animators_screen.dart';
import 'tracking_screen.dart';

void main() {
  runApp(const MyApp());
}

/// Try the package: a simulated vehicle on a route, and each animator.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'polyline_animation_plus',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0)),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          // Each screen has its own map; only the visible one is built.
          if (_index == 0) const TrackingScreen() else const SizedBox(),
          if (_index == 1) const AnimatorsScreen() else const SizedBox(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car),
            label: 'Vehicle tracking',
          ),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'Animators'),
        ],
      ),
    );
  }
}

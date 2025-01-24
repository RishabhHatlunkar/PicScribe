import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixelsheet/screens/home_page.dart';
import 'package:pixelsheet/screens/settings_page.dart';
import 'package:pixelsheet/screens/learning_page.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image to Text Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _pageController = PageController();

  /// Controller to handle PageView and also handles initial page
  final _controller = NotchBottomBarController(index: 0);

  final List<Widget> _pages = [
    const HomePage(),
    LearningPage(),
    const SettingsPage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Added here so that FAB will not be hidden
        body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
           children: _pages
          ),
        bottomNavigationBar: (
          AnimatedNotchBottomBar(
            notchBottomBarController: _controller,
            color: Colors.white,
             showLabel: false,
            notchColor: Colors.blue,
            removeMargins: false,
             bottomBarItems: const [
              BottomBarItem(
                inActiveItem: Icon(Icons.home_outlined, color: Colors.grey,),
                activeItem: Icon(Icons.home, color: Colors.white,),
                itemLabel: 'Home',
              ),
              BottomBarItem(
                inActiveItem: Icon(Icons.school_outlined, color: Colors.grey),
                activeItem: Icon(Icons.school, color: Colors.white,),
                itemLabel: 'Learning',
              ),
               BottomBarItem(
                inActiveItem: Icon(Icons.settings_outlined, color: Colors.grey),
                activeItem: Icon(Icons.settings, color: Colors.white,),
                itemLabel: 'Settings',
              ),
            ],
           onTap: (index) {
              _pageController.animateToPage(
                 index,
                 duration: const Duration(milliseconds: 250),
                 curve: Curves.easeIn,
                );
            }, kIconSize: 20, kBottomRadius: 30,
          )
        ),
    );
  }
}
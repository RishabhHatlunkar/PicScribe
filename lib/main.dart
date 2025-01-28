import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixelsheet/screens/home_page.dart';
import 'package:pixelsheet/screens/settings_page.dart';
import 'package:pixelsheet/screens/learning_page.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:pixelsheet/screens/history_page.dart';
import 'package:pixelsheet/services/database_service.dart';
import 'package:pixelsheet/providers/providers.dart';
import 'package:hive/hive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);

  // Open Hive Box for settings
  await Hive.openBox('settings');


  runApp(
    ProviderScope(
      child:  MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return  MaterialApp(
      title: 'Image to Text Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home:   const MainScreen(),

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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      // LearningPage(),
      const HistoryPage(),
      const SettingsPage(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final isLoading = ref.watch(loadingStateProvider);
          return IgnorePointer(
            ignoring: isLoading,
            child:  Scaffold(
              extendBody: true,
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
                    bottomBarItems: [
                      BottomBarItem(
                        inActiveItem: const Icon(Icons.home_outlined, color: Colors.grey,),
                        activeItem: const Icon(Icons.home, color: Colors.white,),
                        itemLabel: 'Home',
                      ),
                      BottomBarItem(
                        inActiveItem: const Icon(Icons.history_outlined, color: Colors.grey),
                        activeItem: const Icon(Icons.history, color: Colors.white,),
                        itemLabel: 'History',
                      ),
                      BottomBarItem(
                        inActiveItem: const Icon(Icons.settings_outlined, color: Colors.grey),
                        activeItem: const Icon(Icons.settings, color: Colors.white,),
                        itemLabel: 'Settings',
                      ),
                    ],
                    onTap: (index) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeIn,
                      );
                    }, kIconSize: 20,kBottomRadius: 40,
                  )
              ),
            ),
          );}
    );
  }
}
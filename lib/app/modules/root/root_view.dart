import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/notification_service.dart';
import '../explore/explore_view.dart';
import '../home/home_view.dart';
import '../library/library_view.dart';
import '../schedule/schedule_view.dart';

/// Bottom-navigation shell hosting Home, Explore, Schedule and Library.
/// Home + Schedule controllers are provided by RootBinding (see app_pages.dart).
class RootView extends StatefulWidget {
  const RootView({super.key});
  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  int _index = 0;
  // Tabs are built on first visit only, then kept alive by the IndexedStack.
  // This stops Explore/Schedule/Library (and Schedule's launch API fetch) from
  // building off-screen during the most contended moment of startup.
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    // Once the shell is up, re-arm episode reminders. (Push routing + in-app
    // messages are kicked off from main()'s post-frame callback after their
    // services finish initializing.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<NotificationService>().rescheduleAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeView(),
          _visited.contains(1) ? const ExploreView() : const SizedBox.shrink(),
          _visited.contains(2) ? const ScheduleView() : const SizedBox.shrink(),
          _visited.contains(3) ? const LibraryView() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explore'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Schedule'),
          NavigationDestination(
              icon: Icon(Icons.video_library_outlined),
              selectedIcon: Icon(Icons.video_library),
              label: 'Library'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/inapp_message_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/push_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Once the shell is up: re-arm episode reminders, route any notification
    // that cold-started the app, and surface a pending in-app message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<NotificationService>().rescheduleAll();
      Get.find<PushService>().flushInitialMessage();
      Get.find<InAppMessageService>().maybeShowOnLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeView(),
          ExploreView(),
          ScheduleView(),
          LibraryView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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

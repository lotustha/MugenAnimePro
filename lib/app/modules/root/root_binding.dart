import 'package:get/get.dart';

import '../home/home_controller.dart';
import '../schedule/schedule_controller.dart';

/// Provides the controllers for the persistent bottom-nav tabs
/// (Home and Schedule live for the app session).
class RootBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<ScheduleController>(() => ScheduleController());
  }
}

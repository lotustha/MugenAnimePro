import 'package:get/get.dart';

import '../../data/models/schedule_item.dart';
import '../../data/repositories/anime_repository.dart';

class ScheduleController extends GetxController {
  final AnimeRepository _repo = Get.find();

  /// Seven selectable days starting today.
  late final List<DateTime> days;
  final RxInt selectedIndex = 0.obs;

  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final RxList<ScheduleItem> items = <ScheduleItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    days = List.generate(7, (i) => base.add(Duration(days: i)));
    load();
  }

  DateTime get selectedDay => days[selectedIndex.value];

  String get _selectedDateParam {
    final d = selectedDay;
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  void selectDay(int index) {
    if (index == selectedIndex.value) return;
    selectedIndex.value = index;
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      items.assignAll(await _repo.schedule(_selectedDateParam));
    } catch (e) {
      error.value = '$e';
      items.clear();
    } finally {
      loading.value = false;
    }
  }
}

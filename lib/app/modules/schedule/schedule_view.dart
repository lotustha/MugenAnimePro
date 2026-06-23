import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/schedule_item.dart';
import '../../routes/app_pages.dart';
import '../../widgets/state_views.dart';
import 'schedule_controller.dart';

class ScheduleView extends GetView<ScheduleController> {
  const ScheduleView({super.key});

  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: Column(
        children: [
          _dayPicker(),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) return const LoadingView();
              if (controller.error.value != null) {
                return ErrorRetryView(
                  message: controller.error.value!,
                  onRetry: controller.load,
                );
              }
              if (controller.items.isEmpty) {
                return const EmptyView(
                  message: 'No episodes scheduled',
                  icon: Icons.event_busy,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: controller.items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (_, i) => _row(controller.items[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dayPicker() {
    return SizedBox(
      height: 96,
      child: Obx(() => ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: controller.days.length,
            itemBuilder: (_, i) {
              final d = controller.days[i];
              final selected = i == controller.selectedIndex.value;
              return GestureDetector(
                onTap: () => controller.selectDay(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        i == 0 ? 'Today' : _weekdays[(d.weekday - 1) % 7],
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white : Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                      Text(
                        _months[d.month - 1],
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white70 : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )),
    );
  }

  Widget _row(ScheduleItem item) {
    return ListTile(
      onTap: () => Get.toNamed(Routes.detail, arguments: item.id),
      leading: Container(
        width: 60,
        alignment: Alignment.center,
        child: Text(
          item.airingTime,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            fontSize: 15,
          ),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: item.japaneseTitle != null && item.japaneseTitle!.isNotEmpty
          ? Text(item.japaneseTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54))
          : null,
      trailing: item.airingEpisode.isEmpty
          ? null
          : Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('EP ${item.airingEpisode}',
                  style: const TextStyle(fontSize: 12)),
            ),
    );
  }
}

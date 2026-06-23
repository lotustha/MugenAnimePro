import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../../widgets/anime_card.dart';
import '../../widgets/state_views.dart';
import 'search_controller.dart';

class SearchView extends GetView<SearchScreenController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search anime…',
            prefixIcon: Icon(Icons.search),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: controller.onQueryChanged,
        ),
      ),
      body: Obx(() {
        if (controller.loading.value) return const LoadingView();
        if (controller.error.value != null) {
          return ErrorRetryView(
            message: controller.error.value!,
            onRetry: controller.retry,
          );
        }
        if (controller.query.value.trim().isEmpty) {
          return const EmptyView(
            message: 'Find your next anime',
            icon: Icons.movie_filter_outlined,
          );
        }
        if (controller.results.isEmpty) {
          return const EmptyView(message: 'No results', icon: Icons.search_off);
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
              controller.loadMore();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: controller.results.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: 0.52,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) {
              final a = controller.results[i];
              return AnimeCard(
                anime: a,
                width: 150,
                onTap: () => Get.toNamed(Routes.detail, arguments: a.id),
              );
            },
          ),
        );
      }),
    );
  }
}

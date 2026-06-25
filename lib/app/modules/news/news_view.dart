import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/post.dart';
import '../../data/repositories/content_repository.dart';
import '../../routes/app_pages.dart';

class NewsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewsController>(() => NewsController());
  }
}

class NewsController extends GetxController {
  final ContentRepository _repo = Get.find();

  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxnString error = RxnString();
  final RxList<Post> items = <Post>[].obs;

  int _page = 1;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    refreshList();
  }

  Future<void> refreshList() async {
    loading.value = true;
    error.value = null;
    _page = 1;
    _hasMore = true;
    try {
      final res = await _repo.posts(page: 1);
      items.assignAll(res);
      _hasMore = res.isNotEmpty;
    } catch (e) {
      error.value = '$e';
      items.clear();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !_hasMore || loading.value) return;
    loadingMore.value = true;
    try {
      final res = await _repo.posts(page: _page + 1);
      _page += 1;
      if (res.isEmpty) {
        _hasMore = false;
      } else {
        items.addAll(res);
      }
    } catch (_) {
      // non-fatal
    } finally {
      loadingMore.value = false;
    }
  }
}

class NewsView extends StatelessWidget {
  const NewsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<NewsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.error.value != null && c.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.error.value!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: c.refreshList, child: const Text('Retry')),
              ],
            ),
          );
        }
        if (c.items.isEmpty) {
          return const Center(
            child: Text('No articles yet',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return RefreshIndicator(
          onRefresh: c.refreshList,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
                c.loadMore();
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: c.items.length,
              itemBuilder: (_, i) => _PostTile(post: c.items[i]),
            ),
          ),
        );
      }),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Post post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.newsDetail, arguments: post.slug),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.featuredImage != null && post.featuredImage!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: post.featuredImage!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppTheme.surfaceVariant),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppTheme.surfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (post.summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(post.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

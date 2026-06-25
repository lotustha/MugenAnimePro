import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/post.dart';
import '../../data/repositories/content_repository.dart';

class NewsDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewsDetailController>(() => NewsDetailController());
  }
}

class NewsDetailController extends GetxController {
  final ContentRepository _repo = Get.find();

  final Rxn<Post> post = Rxn<Post>();
  final RxBool loading = true.obs;
  final RxnString error = RxnString();

  late final String slug;

  @override
  void onInit() {
    super.onInit();
    slug = (Get.arguments as String?) ?? '';
    _load();
  }

  Future<void> _load() async {
    loading.value = true;
    error.value = null;
    try {
      post.value = await _repo.post(slug);
    } catch (e) {
      error.value = '$e';
    } finally {
      loading.value = false;
    }
  }
}

class NewsDetailView extends StatelessWidget {
  const NewsDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<NewsDetailController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = c.post.value;
        if (p == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.error.value ?? 'Not found',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                FilledButton(onPressed: Get.back, child: const Text('Go back')),
              ],
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            if (p.featuredImage != null && p.featuredImage!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: p.featuredImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) =>
                    Container(height: 200, color: AppTheme.surfaceVariant),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  if (p.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(_formatDate(p.createdAt!),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  if ((p.content ?? '').isNotEmpty)
                    HtmlWidget(
                      p.content!,
                      textStyle: const TextStyle(
                          color: Colors.white70, fontSize: 15, height: 1.5),
                      onTapUrl: (url) async {
                        try {
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                          return true;
                        } catch (_) {
                          return false;
                        }
                      },
                    )
                  else
                    Text(p.summary,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15, height: 1.5)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

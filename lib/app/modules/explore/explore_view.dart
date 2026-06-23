import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_pages.dart';
import '../category/category_args.dart';

class ExploreView extends StatelessWidget {
  const ExploreView({super.key});

  void _openCategory(String title, CategoryKind kind, String value) {
    Get.toNamed(
      Routes.category,
      arguments: CategoryArgs(title: title, kind: kind, value: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Search entry.
          GestureDetector(
            onTap: () => Get.toNamed(Routes.search),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, color: Colors.white38),
                  SizedBox(width: 10),
                  Text('Search anime…',
                      style: TextStyle(color: Colors.white38, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: [
              for (final c in AppConstants.categories)
                _CategoryTile(
                  label: c.label,
                  onTap: () =>
                      _openCategory(c.label, CategoryKind.category, c.kind),
                ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Genres',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in AppConstants.genres)
                ActionChip(
                  label: Text(g),
                  onPressed: () => _openCategory(
                    g,
                    CategoryKind.genre,
                    AppConstants.genreSlug(g),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CategoryTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.35),
                AppTheme.surfaceVariant,
              ],
            ),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

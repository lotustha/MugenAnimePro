import 'package:get/get.dart';

import '../modules/category/category_binding.dart';
import '../modules/category/category_view.dart';
import '../modules/detail/detail_binding.dart';
import '../modules/detail/detail_view.dart';
import '../modules/history/history_view.dart';
import '../modules/news/news_detail_view.dart';
import '../modules/news/news_view.dart';
import '../modules/wallpapers/wallpaper_detail_view.dart';
import '../modules/wallpapers/wallpaper_search_view.dart';
import '../modules/wallpapers/wallpapers_view.dart';
import '../modules/player/player_binding.dart';
import '../modules/player/player_view.dart';
import '../modules/root/root_binding.dart';
import '../modules/root/root_view.dart';
import '../modules/search/search_binding.dart';
import '../modules/search/search_view.dart';
import '../modules/settings/settings_binding.dart';
import '../modules/settings/settings_view.dart';
import '../modules/watch/watch_binding.dart';
import '../modules/watch/watch_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.root;

  static final routes = <GetPage>[
    GetPage(
      name: Routes.root,
      page: () => const RootView(),
      // Home + Schedule tab controllers live for the app session.
      binding: RootBinding(),
    ),
    GetPage(
      name: Routes.search,
      page: () => const SearchView(),
      binding: SearchBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.detail,
      page: () => const DetailView(),
      binding: DetailBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: Routes.player,
      page: () => const PlayerView(),
      binding: PlayerBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.watch,
      page: () => const WatchView(),
      binding: WatchBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.category,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: Routes.history,
      page: () => const HistoryView(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: Routes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: Routes.wallpapers,
      page: () => const WallpapersView(),
      binding: WallpapersBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: Routes.wallpaperSearch,
      page: () => const WallpaperSearchView(),
      binding: WallpaperSearchBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.wallpaperDetail,
      page: () => const WallpaperDetailView(),
      binding: WallpaperDetailBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.news,
      page: () => const NewsView(),
      binding: NewsBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: Routes.newsDetail,
      page: () => const NewsDetailView(),
      binding: NewsDetailBinding(),
      transition: Transition.cupertino,
    ),
  ];
}

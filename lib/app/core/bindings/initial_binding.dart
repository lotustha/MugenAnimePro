import 'package:get/get.dart';

import '../../data/providers/anilist_client.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/site_client.dart';
import '../../data/repositories/anime_repository.dart';
import '../../data/repositories/content_repository.dart';

/// App-wide dependencies available to every route.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ApiClient>(ApiClient(), permanent: true);
    Get.put<AnimeRepository>(AnimeRepository(Get.find()), permanent: true);
    Get.put<AniListClient>(AniListClient(), permanent: true);

    // Website content (news + wallpapers).
    Get.put<SiteClient>(SiteClient(), permanent: true);
    Get.put<ContentRepository>(ContentRepository(Get.find()), permanent: true);
  }
}

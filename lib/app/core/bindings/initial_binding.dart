import 'package:get/get.dart';

import '../../data/providers/anilist_client.dart';
import '../../data/providers/api_client.dart';
import '../../data/repositories/anime_repository.dart';

/// App-wide dependencies available to every route.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ApiClient>(ApiClient(), permanent: true);
    Get.put<AnimeRepository>(AnimeRepository(Get.find()), permanent: true);
    Get.put<AniListClient>(AniListClient(), permanent: true);
  }
}

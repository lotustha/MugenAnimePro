/// An entry from `GET /anime/anizen/schedule/{YYYY-MM-DD}`.
/// Note: schedule items carry no poster image.
class ScheduleItem {
  final String id;
  final String title;
  final String? japaneseTitle;
  final String airingTime; // "HH:mm"
  final String airingEpisode;

  const ScheduleItem({
    required this.id,
    required this.title,
    this.japaneseTitle,
    this.airingTime = '',
    this.airingEpisode = '',
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? 'Unknown'}',
        japaneseTitle: json['japaneseTitle'] as String?,
        airingTime: '${json['airingTime'] ?? ''}',
        airingEpisode: '${json['airingEpisode'] ?? ''}',
      );
}

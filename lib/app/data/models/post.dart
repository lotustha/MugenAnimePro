/// A news article from the Mugenstream website (/api/posts).
class Post {
  final String id;
  final String title;
  final String slug;
  final String summary;
  final String? content; // HTML, only on the single-post endpoint
  final String? featuredImage;
  final DateTime? createdAt;

  const Post({
    required this.id,
    required this.title,
    required this.slug,
    this.summary = '',
    this.content,
    this.featuredImage,
    this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> j) {
    return Post(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? ''}',
      slug: '${j['slug'] ?? ''}',
      summary: '${j['summary'] ?? ''}',
      content: j['content'] as String?,
      featuredImage:
          (j['featuredImage'] ?? j['featured_image']) as String?,
      createdAt: DateTime.tryParse('${j['createdAt'] ?? j['created_at'] ?? ''}'),
    );
  }
}

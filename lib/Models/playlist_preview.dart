class PlaylistPreview {
  final String screenName;
  final String name;
  final String? previewImageUrl;
  final int itemCount;

  PlaylistPreview({
    required this.screenName,
    required this.name,
    this.previewImageUrl,
    required this.itemCount,
  });
}

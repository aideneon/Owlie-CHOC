class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    this.videoAssetPath,
  });

  final String id;
  final String name;
  final String description;
  final String? videoAssetPath;
}

class FavoriteEntry {
  const FavoriteEntry({
    required this.exerciseId,
    required this.intensity,
  });

  final String exerciseId;
  final int intensity;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'intensity': intensity,
      };

  factory FavoriteEntry.fromJson(Map<String, dynamic> json) {
    return FavoriteEntry(
      exerciseId: json['exerciseId'] as String,
      intensity: json['intensity'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FavoriteEntry &&
        other.exerciseId == exerciseId &&
        other.intensity == intensity;
  }

  @override
  int get hashCode => Object.hash(exerciseId, intensity);
}

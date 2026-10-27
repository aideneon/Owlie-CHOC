import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content_repository.dart';
import '../data/owllie_clips.dart';
import '../models/emotion.dart';
import '../models/exercise.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/emotion_controls.dart';
import '../widgets/exercise_header_video.dart';
import '../widgets/session_video_player.dart';

enum _SessionPhase { exerciseList, exerciseVideo }

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.emotionId,
    required this.intensity,
    this.directExerciseId,
  });

  final EmotionId? emotionId;
  final int intensity;
  final String? directExerciseId;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late _SessionPhase _phase;
  late int _selectedIntensity;
  Exercise? _activeExercise;
  List<Exercise> _exercises = [];

  /// After an exercise, the header asks how the rating changed.
  bool _hasDoneAnExercise = false;

  /// Outcome clip chosen from a post-exercise rating. Null plays the tough clip.
  String? _outcomeAsset;

  /// Bumps so re-tapping the same band replays its outcome clip.
  int _headerGeneration = 0;

  Emotion? get _emotion {
    final id = widget.emotionId;
    if (id == null) return null;
    return ContentRepository.emotionById(id);
  }

  @override
  void initState() {
    super.initState();
    _selectedIntensity = widget.intensity;
    if (widget.directExerciseId != null) {
      _activeExercise = ContentRepository.exerciseById(
        widget.directExerciseId!,
      );
      _phase = _SessionPhase.exerciseVideo;
    } else {
      _reloadExercises();
      _phase = _SessionPhase.exerciseList;
    }
  }

  List<String> get _headerLeads {
    final outcome = _outcomeAsset;
    if (outcome != null) return <String>[outcome];
    if (_hasDoneAnExercise) {
      return const <String>[OwllieClips.usingASkillCanBeTough];
    }
    final emotionId = widget.emotionId;
    if (emotionId == null) return const <String>[];
    return OwllieClips.exerciseIntro(emotionId);
  }

  void _reloadExercises() {
    if (widget.emotionId == null) {
      _exercises = [];
      return;
    }
    _exercises = ContentRepository.exercisesForEmotionAndIntensity(
      widget.emotionId!,
      _selectedIntensity,
    );
  }

  void _showExerciseList({bool afterExercise = false}) {
    setState(() {
      if (afterExercise) {
        _hasDoneAnExercise = true;
        _outcomeAsset = null;
        _headerGeneration++;
      }
      _activeExercise = null;
      _phase = _SessionPhase.exerciseList;
    });
  }

  void _playExercise(Exercise exercise) {
    setState(() {
      _activeExercise = exercise;
      _phase = _SessionPhase.exerciseVideo;
    });
  }

  void _onIntensitySelected(int intensity) {
    if (!_hasDoneAnExercise) {
      if (intensity == _selectedIntensity) return;
      setState(() {
        _selectedIntensity = intensity;
        _reloadExercises();
      });
      return;
    }

    final outcome = OwllieClips.outcomeFor(
      previous: _selectedIntensity,
      next: intensity,
    );
    setState(() {
      _outcomeAsset = outcome;
      _headerGeneration++;
      if (intensity != _selectedIntensity) {
        _selectedIntensity = intensity;
        _reloadExercises();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final emotion = _emotion;

    return AppShell(
      title: emotion?.label,
      titleColor: const Color(0xFF424242),
      backgroundColor: AppTheme.homeBackground,
      // Intensity buttons stay on the exercise picker so users can switch
      // bands and see a different set. Videos stay full-screen.
      showBottomControls: _phase == _SessionPhase.exerciseList,
      bottomControls: _phase == _SessionPhase.exerciseList
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntensityScale(
                selectedIntensity: _selectedIntensity,
                onIntensitySelected: _onIntensitySelected,
              ),
            )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_phase == _SessionPhase.exerciseVideo && _activeExercise != null)
            SessionVideoPlayer(
              key: ValueKey('${_activeExercise!.id}-$_selectedIntensity'),
              assetPath: _activeExercise!.videoAssetPath,
              label: '${_activeExercise!.name} video',
              accentColor: emotion?.accentColor ?? Colors.purpleAccent,
              actionLabel: widget.directExerciseId != null ? 'Close' : 'Skip',
              actionIcon: widget.directExerciseId != null
                  ? Icons.close_rounded
                  : Icons.skip_next_rounded,
              onFinished: widget.directExerciseId != null
                  ? () => Navigator.of(context).pop()
                  : () => _showExerciseList(afterExercise: true),
            ),
          if (_phase == _SessionPhase.exerciseList)
            _ExerciseListOverlay(
              exercises: _exercises,
              intensity: _selectedIntensity,
              onExerciseSelected: _playExercise,
              leadAssetPaths: _headerLeads,
              headerGeneration: _headerGeneration,
            ),
        ],
      ),
    );
  }
}

class _ExerciseListOverlay extends StatelessWidget {
  const _ExerciseListOverlay({
    required this.exercises,
    required this.intensity,
    required this.onExerciseSelected,
    required this.leadAssetPaths,
    required this.headerGeneration,
  });

  final List<Exercise> exercises;
  final int intensity;
  final ValueChanged<Exercise> onExerciseSelected;
  final List<String> leadAssetPaths;
  final int headerGeneration;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Column(
      children: [
        // 30% companion clip on top, 70% exercise list below.
        Expanded(
          flex: 3,
          child: ExerciseHeaderVideo(
            key: ValueKey<String>(
              '${leadAssetPaths.join('|')}-$headerGeneration',
            ),
            leadAssetPaths: leadAssetPaths,
          ),
        ),
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                const Text(
                  'Choose an exercise',
                  style: TextStyle(
                    color: Color(0xFF424242),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the star to save a favorite',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 16),
                ...exercises.map((exercise) {
                  final isFavorite = appState.isFavorite(exercise.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => onExerciseSelected(exercise),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise.name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF424242),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      exercise.description,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.3,
                                        color: Colors.black.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _FavoriteStarButton(
                                isFavorite: isFavorite,
                                onPressed: () =>
                                    _toggleFavorite(context, exercise),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(BuildContext context, Exercise exercise) async {
    final appState = context.read<AppState>();
    final wasFavorite = appState.isFavorite(exercise.id);

    await appState.toggleFavorite(
      exerciseId: exercise.id,
      intensity: intensity,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        persist: false,
        content: Text(
          wasFavorite
              ? 'Removed "${exercise.name}" from favorites'
              : 'Saved "${exercise.name}" to favorites',
        ),
        action: wasFavorite
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  appState.removeFavorite(exercise.id);
                },
              ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _FavoriteStarButton extends StatelessWidget {
  const _FavoriteStarButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Icon(
          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          key: ValueKey(isFavorite),
          color: isFavorite ? const Color(0xFFFFB300) : Colors.grey,
          size: 28,
        ),
      ),
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
    );
  }
}

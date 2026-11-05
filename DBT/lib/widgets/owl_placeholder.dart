import 'package:flutter/material.dart';

import 'owlie_sequence_player.dart';

/// Plays [speechAssets] once each, then eases into a looping idle clip.
class OwlPlaceholder extends StatelessWidget {
  const OwlPlaceholder({
    super.key,
    required this.speechAssets,
    this.restartWithHome = false,
    this.replayToken = 0,
  });

  final List<String> speechAssets;

  /// Home is the only screen that should rewind when the header Home button
  /// is pressed. Other Owllie players ignore that signal.
  final bool restartWithHome;

  /// Bump to replay [speechAssets] from the first clip with a crossfade.
  final int replayToken;

  static final ValueNotifier<int> _restartToken = ValueNotifier<int>(0);

  /// Rewind the home Owllie to the first speech clip.
  static void requestRestart() {
    _restartToken.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (!restartWithHome) {
      return OwlieSequencePlayer(
        speechAssets: speechAssets,
        replayToken: replayToken,
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: _restartToken,
      builder: (context, token, _) {
        return OwlieSequencePlayer(
          speechAssets: speechAssets,
          replayToken: replayToken + token,
          deferReplayWhileCovered: true,
        );
      },
    );
  }
}

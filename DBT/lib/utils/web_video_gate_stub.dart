/// Native players block in `initialize()` until the first frame is available.
Future<void> prefetchAsset(String assetPath) async {}

Future<void> waitUntilCanPlayThrough(String fileName) async {}

Future<void> waitUntilVisible(String fileName) async {}

Future<void> waitUntilFramePresented(String fileName) async {}

String? claimClipElement(String fileName) => null;

void setOwnedOpacity(String id, double opacity, {bool circular = false}) {}

int ownedFrameCount(String id) => -1;

void setClipOpacity(
  String fileName,
  double opacity,
  double mediaSeconds, {
  bool circular = false,
}) {}

Future<void> dissolveUnderStill({
  required String fromId,
  required String toId,
  required Future<void> Function() swapUnderStill,
  bool circular = false,
  int milliseconds = 420,
}) async {
  await swapUnderStill();
}

/// `-1` means presented-frame counts are unavailable.
int presentedFrameCount(String fileName, double mediaSeconds) => -1;

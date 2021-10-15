import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';

Ambience? ambience;
AudioTrack? track;

final volumeInput = querySelector('#volume') as InputElement;

void main() {
  querySelector('button')
    ?..text = 'Change tha World'
    ..onClick.listen((_) => changeStuff());

  var init = false;

  document.onClick.listen((_) {
    if (!init) {
      init = true;
      setupAmbience();
    }
  });

  volumeInput.onInput.listen((_) {
    ambience!.volume = volumeInput.valueAsNumber!;
  });
}

void setupAmbience() {
  ambience = Ambience()..volume = volumeInput.valueAsNumber!;
  track = AudioTrack(
    ambience!,
    'http://localhost:7070/resources/trois-gymnopedies.mp3',
  )..fadeIn();
}

void changeStuff() {
  if (track!.isActive) {
    track!.fadeOut();
  } else {
    track!.fadeIn();
  }
}

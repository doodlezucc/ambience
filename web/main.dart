import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';

Ambience? ambience;
AudioTrack? track;

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
}

void setupAmbience() {
  ambience = Ambience();
  track = AudioTrack(
    ambience!,
    'https://www2.cs.uic.edu/~i101/SoundFiles/CantinaBand60.wav',
  );
}

void changeStuff() {
  if (track!.isActive) {
    track!.fadeOut();
  } else {
    track!.fadeIn();
  }
}

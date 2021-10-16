import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';
import 'package:http/http.dart' as http;

Ambience? ambience;
AudioTrack? track;

final volumeInput = querySelector('#volume') as InputElement;
final filterInput = querySelector('#filter') as InputElement;

final httpClient = http.Client();

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
  filterInput.onInput.listen((_) {
    track!.filter = filterInput.valueAsNumber!;
  });
}

void setupAmbience() async {
  ambience = Ambience()..volume = volumeInput.valueAsNumber!;
  track = AudioTrack(
    ambience!,
    'http://localhost:7070/resources/rain.mp3',
  )
    ..filter = filterInput.valueAsNumber!
    ..fadeIn(transition: 2);

  // var response = await httpClient.get(Uri.parse('http://localhost:7070/audio'));

  AudioTrack(
    ambience!,
    'http://localhost:7070/audio',
  ).fadeIn(transition: 5);
}

void changeStuff() {
  if (track!.isActive) {
    track!.fadeOut();
  } else {
    track!.fadeIn();
  }
}

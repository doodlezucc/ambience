import 'dart:html';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_clip.dart';
import 'package:http/http.dart' as http;

Ambience? ambience;
Filterable? clip;

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
    clip!.filter = filterInput.valueAsNumber!;
  });
}

void setupAmbience() async {
  ambience = Ambience()..volume = volumeInput.valueAsNumber!;
  clip = FilterableAudioClip(
    ambience!,
    'http://localhost:7070/resources/rain.mp3',
  )
    ..filter = filterInput.valueAsNumber!
    ..fadeIn(transition: 2);

  var response = await httpClient.get(Uri.parse('http://localhost:7070/audio'));
  CrossOriginAudioClip(ambience!, response.body).fadeIn();
}

void changeStuff() {
  if (clip!.isActive) {
    clip!.fadeOut();
  } else {
    clip!.fadeIn();
  }
}

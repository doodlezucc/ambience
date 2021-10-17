import 'dart:html';

import 'custom_ambience.dart';

CustomAmbience? ambience;

final volumeInput = querySelector('#volume') as InputElement;
final filterInput = querySelector('#filter') as InputElement;

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
    ambience!.weather.filter = filterInput.valueAsNumber!;
  });
}

void setupAmbience() async {
  ambience = CustomAmbience()..volume = volumeInput.valueAsNumber!;
}

void changeStuff() {
  ambience?.changeWeather(ambience?.weather.activeClip == null);
}

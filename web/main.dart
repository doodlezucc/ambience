import 'dart:html';

import 'custom_ambience.dart';

CustomAmbience? ambience;

final volumeInput = querySelector('#volume') as InputElement;
final filterInput = querySelector('#filter') as InputElement;
final weatherInput = querySelector('#weather') as InputElement;
final weatherVInput = querySelector('#weatherV') as InputElement;
final crowdInput = querySelector('#crowd') as InputElement;
final crowdVInput = querySelector('#crowdV') as InputElement;
final musicVInput = querySelector('#musicV') as InputElement;

void main() {
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
  weatherInput.onInput.listen((_) {
    ambience?.changeWeather(weatherInput.valueAsNumber!.toInt());
  });
  weatherVInput.onInput.listen((_) {
    ambience?.weather.volume = weatherVInput.valueAsNumber!;
  });
  crowdInput.onInput.listen((_) {
    ambience?.changeCrowd(crowdInput.valueAsNumber!.toInt());
  });
  crowdVInput.onInput.listen((_) {
    ambience?.crowd.volume = crowdVInput.valueAsNumber!;
  });
  musicVInput.onInput.listen((_) {
    ambience?.music.track.volume = musicVInput.valueAsNumber!;
  });

  querySelector('#skip')!.onClick.listen((_) => ambience!.music.skip());
}

void setupAmbience() {
  ambience = CustomAmbience()..volume = volumeInput.valueAsNumber!;
}

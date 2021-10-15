import 'dart:html';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:ambience/ambience.dart';

final Map<String, AudioBuffer> resources = {};

class AudioTrack extends Track {
  final AudioBufferSourceNode sourceNode;
  final BiquadFilterNode filterNode;

  num get filter => filterNode.frequency!.value!;
  set filter(num filter) => filterNode.frequency!.value = filter;

  AudioTrack(Ambience ambience, String url)
      : sourceNode = AudioBufferSourceNode(ambience.ctx),
        filterNode = BiquadFilterNode(ambience.ctx),
        super(ambience) {
    sourceNode.connectNode(filterNode);
    filterNode
      ..connectNode(trackGain)
      ..type = 'lowpass'
      ..frequency!.value = 800;

    // Load URL as audio buffer
    getBuffer(url).then((buffer) {
      sourceNode
        ..buffer = buffer
        ..loop = true
        ..start();
    });
  }

  Future<AudioBuffer> getBuffer(String url) async {
    if (resources[url] != null) return resources[url]!;

    var req = await HttpRequest.request(url, responseType: 'blob');
    var response = req.response;

    var reader = FileReader();
    reader.readAsArrayBuffer(response);
    var loadEndEvent = await reader.onLoadEnd.first;

    print('Loaded ${loadEndEvent.total} bytes');

    var bytes = (reader.result as Uint8List);

    var audioBuffer = await ambience.ctx.decodeAudioData(bytes.buffer);
    resources[url] = audioBuffer;
    return audioBuffer;
  }
}

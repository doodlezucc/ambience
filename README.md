# Ambience

A web audio tool granting control over ambient sounds and musical playlists.

## Downloading Playlists
Audio tracks can be downloaded by supplying a [source.json](https://github.com/doodlezucc/ambience/blob/master/resources/music/source.json) file with IDs of YouTube playlists. This requires an installation of [yt-dlp](https://github.com/yt-dlp/yt-dlp/wiki/Installation) as well as [ffmpeg](https://ffmpeg.org/download.html) (used for volume normalization).
## Applying Filters/Nodes to Audio Tracks

In order to make use of `FilterableAudioTrack` and `FilterableAudioClip`, your server needs to provide valid [CORS response headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#functional_overview) for the requested resources. It's recommended to include the following headers:

```yaml
Access-Control-Allow-Origin: http://CLIENT-URL
Access-Control-Allow-Methods: GET
```

## Sound Credits

Most sounds in the resources directory come without a license.
Some sound effects are taken from https://www.zapsplat.com ([License](https://www.zapsplat.com/license-type/standard-license/))
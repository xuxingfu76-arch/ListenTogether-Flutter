import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'server_config.dart';
const String kQjyUA = 'Mozilla/5.0 (Linux; Android)';
const String kN163Referer = 'http://music.163.com';
String? extractNeteaseId(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(s)) return s;
  var m = RegExp(r'[?&]id=(\d+)').firstMatch(s);
  if (m != null) return m.group(1);
  m = RegExp(r'/song/(\d+)').firstMatch(s);
  if (m != null) return m.group(1);
  final all = RegExp(r'\d{5,}').allMatches(s).map((e) => e.group(0)!).toList();
  if (all.isEmpty) return null;
  all.sort((a, b) => b.length.compareTo(a.length));
  return all.first;
}
String? extractIdFromUrl(String s) {
  var m = RegExp(r'[?&]id=(\d+)').firstMatch(s);
  if (m != null) return m.group(1);
  m = RegExp(r'/song/(\d+)').firstMatch(s);
  if (m != null) return m.group(1);
  m = RegExp(r'song\?id=(\d+)').firstMatch(s);
  if (m != null) return m.group(1);
  return null;
}
Future<String?> resolveIdWithRedirect(String line) async {
  if (extractNeteaseId(line) != null) return extractNeteaseId(line);
  final raw = RegExp(r'https?://[^\s"<>]+').firstMatch(line)?.group(0);
  if (raw == null) return null;
  var current = raw.trim();
  while (current.isNotEmpty && (current.endsWith(')') || current.endsWith(']') || current.endsWith('.') || current.endsWith(',') || current.endsWith(';') || current.endsWith('!'))) {
    current = current.substring(0, current.length - 1);
  }
  final client = http.Client();
  try {
    for (var i = 0; i < 4; i++) {
      final req = http.Request('GET', Uri.parse(current));
      req.headers['User-Agent'] = kQjyUA;
      req.headers['Referer'] = kN163Referer;
      req.followRedirects = false;
      final streamed = await client.send(req).timeout(const Duration(seconds: 15));
      final code = streamed.statusCode;
      if (code >= 300 && code < 400) {
        final loc = streamed.headers['location'];
        if (loc == null) return null;
        final next = Uri.parse(current).resolve(loc).toString();
        final id = extractIdFromUrl(next);
        if (id != null) return id;
        if (!next.startsWith('http')) return null;
        current = next;
      } else if (code >= 200 && code < 300) {
        final body = await streamed.stream.bytesToString();
        var m = RegExp(r'song\?id=(\d+)').firstMatch(body);
        if (m != null) return m.group(1);
        m = RegExp(r'[?&]id=(\d+)').firstMatch(body);
        return m?.group(1);
      } else {
        return null;
      }
    }
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
  return null;
}
Future<Track?> fetchTrack(String id) async {
  try {
    final uri = Uri.parse('https://api.qijieya.cn/meting/?type=song&id=${Uri.encodeComponent(id)}');
    final resp = await http.get(uri, headers: {'User-Agent': kQjyUA, 'Referer': kN163Referer}).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    Map<String, dynamic>? o;
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      o = Map<String, dynamic>.from(decoded.first);
    } else if (decoded is Map) {
      o = Map<String, dynamic>.from(decoded);
    }
    if (o == null) return null;
    String lyric = '${o['lrc'] ?? o['lyric'] ?? ''}';
    final lrcUrl = '${o['lrcUrl'] ?? o['lrc_url'] ?? ''}';
    if (lyric.isEmpty && lrcUrl.startsWith('http')) {
      try {
        final lr = await http.get(Uri.parse(lrcUrl), headers: {'User-Agent': kQjyUA}).timeout(const Duration(seconds: 10));
        if (lr.statusCode == 200) lyric = lr.body;
      } catch (_) {}
    }
    return Track(
      id: id,
      title: '${o['name'] ?? o['title'] ?? '未知歌曲'}',
      artist: '${o['artist'] ?? o['singer'] ?? '未知'}',
      album: '${o['album'] ?? ''}',
      cover: '${o['pic'] ?? o['cover'] ?? o['picUrl'] ?? ''}',
      link: '${o['url'] ?? o['link'] ?? ''}',
      lyric: lyric,
    );
  } catch (_) {
    return null;
  }
}
Future<bool> uploadTrackAudio(Track track, {void Function(double, String)? onProgress}) async {
  if (track.link.isEmpty) return false;
  if (track.link.startsWith('${ServerConfig.httpBase}/audio/')) return true;
  try {
    onProgress?.call(0, '正在下载 ${track.title}');
    final dl = await http.get(Uri.parse(track.link), headers: {'User-Agent': kQjyUA, 'Referer': kN163Referer}).timeout(const Duration(seconds: 60));
    if (dl.statusCode != 200 || dl.bodyBytes.isEmpty) return false;
    final bytes = dl.bodyBytes;
    if (bytes.length > 50 * 1024 * 1024) return false;
    onProgress?.call(0.5, '正在上传 ${track.title}');
    final uri = Uri.parse('${ServerConfig.httpBase}/upload/audio?id=${Uri.encodeComponent(track.id)}');
    final req = http.Request('POST', uri);
    req.headers['Content-Type'] = 'application/octet-stream';
    req.bodyBytes = bytes;
    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final ok = streamed.statusCode >= 200 && streamed.statusCode < 300;
    if (ok) onProgress?.call(1, '上传完成');
    return ok;
  } catch (_) {
    return false;
  }
}

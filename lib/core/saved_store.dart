import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'server_config.dart';
class SavedStore {
  static const _k = 'saved_tracks_v1';
  Future<List<Track>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.isEmpty) return [];
    try {
      final arr = jsonDecode(raw);
      if (arr is List) return arr.whereType<Map>().map((e) => Track.fromJson(Map<String,dynamic>.from(e))).toList();
    } catch (_) {}
    return [];
  }
  Future<void> _saveAll(List<Track> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
  Future<bool> contains(String id) async => (await load()).any((e) => e.id == id);
  Future<bool> add(Track t) async {
    final list = await load();
    if (list.any((e) => e.id == t.id)) return false;
    list.add(t);
    await _saveAll(list);
    return true;
  }
  Future<void> remove(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _saveAll(list);
  }
  Map<String,dynamic> toUploadJson(Track t) {
    var link = t.link;
    if (link.startsWith('${ServerConfig.httpBase}/audio/')) {} 
    return {'id': t.id, 'title': t.title, 'artist': t.artist, 'album': t.album, 'cover': t.cover, 'link': link, 'lyric': t.lyric};
  }
}

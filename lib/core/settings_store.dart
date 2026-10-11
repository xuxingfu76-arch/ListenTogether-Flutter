import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persistence mirroring native SettingsStore (DataStore) keys:
/// nick / avatar / device_token / last_room / room_name.
/// Uses shared_preferences on Flutter.
class SettingsStore {
  static const _kNick = 'nick';
  static const _kAvatar = 'avatar';
  static const _kDeviceToken = 'device_token';
  static const _kLastRoom = 'last_room';
  static const _kRoomName = 'room_name';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<(String, String)> snapshotProfile() async {
    final p = await _prefs();
    return (p.getString(_kNick) ?? '', p.getString(_kAvatar) ?? '');
  }

  Future<void> setNick(String v) async {
    final p = await _prefs();
    final s = v.trim();
    await p.setString(_kNick, s.length > 20 ? s.substring(0, 20) : s);
  }

  Future<void> setAvatar(String v) async {
    final p = await _prefs();
    final s = v.trim();
    await p.setString(_kAvatar, s.length > 32 ? s.substring(0, 32) : s);
  }

  Future<String> ensureDeviceToken() async {
    final p = await _prefs();
    final cur = p.getString(_kDeviceToken) ?? '';
    if (cur.isNotEmpty) return cur;
    final fresh = const Uuid().v4().replaceAll('-', '');
    await p.setString(_kDeviceToken, fresh);
    return fresh;
  }

  Future<void> setLastRoom(String? v) async {
    final p = await _prefs();
    if (v == null || v.trim().isEmpty) {
      await p.remove(_kLastRoom);
    } else {
      await p.setString(_kLastRoom, v.trim());
    }
  }

  Future<String?> snapshotLastRoom() async {
    final p = await _prefs();
    final v = p.getString(_kLastRoom) ?? '';
    return v.isEmpty ? null : v;
  }

  Future<void> setRoomName(String v) async {
    final p = await _prefs();
    final s = v.trim();
    await p.setString(_kRoomName, s.length > 32 ? s.substring(0, 32) : s);
  }

  Future<String> snapshotRoomName() async {
    final p = await _prefs();
    return p.getString(_kRoomName) ?? '';
  }
}

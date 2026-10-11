import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

/// Protocol layer mirroring native ListenSocket.kt.
///
/// C->S: create_room / join_room / leave_room / resolve /
///   upload_playlist / play / pause / seek / next / prev / set_mode /
///   sync / chat / upload_avatar / get_avatar / update_profile /
///   delete_track / list_rooms / list_songs / set_room_name / set_visibility
///
/// S->C: hello / room / state / chat / left / error /
///   avatar_uploaded / avatar_data / rooms / songs / songs_updated
///
/// Auth: password goes in the ws query string, otherwise the server
/// closes the connection with code 4001.
/// Heartbeat: the server pings every 30s and drops silent peers after
/// 60s (PEER_TIMEOUT_MS). The underlying WebSocket implementation
/// answers ping frames with pong automatically, which refreshes the
/// server-side last-message timestamp. No app-level ping needed.
sealed class SocketEvent {
  const SocketEvent();
}

class HelloEvent extends SocketEvent {
  final String id;
  const HelloEvent(this.id);
}

class RoomEvent extends SocketEvent {
  final String room;
  final RoomState state;
  const RoomEvent(this.room, this.state);
}

class StateEvent extends SocketEvent {
  final RoomState state;
  final String? by;
  final String byNickname;
  final String byAvatar;
  const StateEvent(this.state, this.by,
      {this.byNickname = '', this.byAvatar = ''});
}

class ChatEvent extends SocketEvent {
  final ChatMsg item;
  const ChatEvent(this.item);
}

class LeftEvent extends SocketEvent {
  const LeftEvent();
}

class ErrorEvent extends SocketEvent {
  final String message;
  final String code;
  const ErrorEvent(this.message, {this.code = ''});
}

class ConnEvent extends SocketEvent {
  final bool connected;
  final String? reason;
  const ConnEvent(this.connected, {this.reason});
}

class AvatarUploadedEvent extends SocketEvent {
  final String avatarId;
  const AvatarUploadedEvent(this.avatarId);
}

class AvatarDataEvent extends SocketEvent {
  final String id;
  final String data;
  const AvatarDataEvent(this.id, this.data);
}

class RoomsEvent extends SocketEvent {
  final List<PublicRoom> rooms;
  const RoomsEvent(this.rooms);
}

class SongsEvent extends SocketEvent {
  final List<Track> tracks;
  const SongsEvent(this.tracks);
}

class SongsUpdatedEvent extends SocketEvent {
  const SongsUpdatedEvent();
}

class ListenSocket {
  void Function(SocketEvent event)? onEvent;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  bool get isOpen => _channel != null;

  void connect(String baseUrl, String password) {
    close(1000, 'reconnect');
    final base = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), ''));
    final mergedQuery = Map<String, String>.from(base.queryParameters)
      ..['password'] = password;
    final url = base.replace(queryParameters: mergedQuery);
    final channel = WebSocketChannel.connect(url);
    _channel = channel;
    _sub = channel.stream.listen(
      (data) => dispatch('$data'),
      onDone: () {
        if (identical(_channel, channel)) {
          _channel = null;
        }
        onEvent?.call(const ConnEvent(false, reason: 'closed'));
      },
      onError: (Object e) {
        if (identical(_channel, channel)) {
          _channel = null;
        }
        onEvent?.call(ConnEvent(false, reason: '$e'));
      },
      cancelOnError: true,
    );
    onEvent?.call(const ConnEvent(true));
  }

  Future<void> close([int code = 1000, String? reason]) async {
    final c = _channel;
    _channel = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await c?.sink.close(code, reason);
    } catch (_) {
      // ignore: already closed
    }
  }

  void dispatch(String text) {
    Map<String, dynamic> o;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      o = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    switch ('${o['type'] ?? ''}') {
      case 'hello':
        onEvent?.call(HelloEvent('${o['id'] ?? ''}'));
      case 'room':
        final st = o['state'];
        if (st is Map) {
          onEvent?.call(RoomEvent(
            '${o['room'] ?? ''}',
            RoomState.fromJson(Map<String, dynamic>.from(st)),
          ));
        }
      case 'state':
        final st = o['state'];
        if (st is Map) {
          final rawBy = '${o['by'] ?? ''}';
          final by = (rawBy.isEmpty || rawBy == 'null') ? null : rawBy;
          final bp = o['byProfile'];
          final nick = bp is Map ? '${bp['nickname'] ?? ''}' : '';
          final av = bp is Map ? '${bp['avatar'] ?? ''}' : '';
          onEvent?.call(StateEvent(
            RoomState.fromJson(Map<String, dynamic>.from(st)),
            by,
            byNickname: nick,
            byAvatar: av,
          ));
        }
      case 'chat':
        onEvent?.call(ChatEvent(ChatMsg.fromJson(o)));
      case 'left':
        onEvent?.call(const LeftEvent());
      case 'avatar_uploaded':
        onEvent?.call(AvatarUploadedEvent('${o['avatarId'] ?? ''}'));
      case 'avatar_data':
        onEvent?.call(AvatarDataEvent('${o['id'] ?? ''}', '${o['data'] ?? ''}'));
      case 'rooms':
        final list = <PublicRoom>[];
        final arr = o['rooms'];
        if (arr is List) {
          for (final e in arr) {
            if (e is Map) {
              list.add(PublicRoom.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
        onEvent?.call(RoomsEvent(list));
      case 'songs':
        final list = <Track>[];
        final arr = o['songs'];
        if (arr is List) {
          for (final e in arr) {
            if (e is Map) {
              list.add(Track.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
        onEvent?.call(SongsEvent(list));
      case 'songs_updated':
        onEvent?.call(const SongsUpdatedEvent());
      case 'error':
        onEvent?.call(ErrorEvent(
          '${o['message'] ?? 'unknown error'}',
          code: '${o['code'] ?? ''}',
        ));
    }
  }

  bool _send(String type, [Map<String, dynamic>? fields]) {
    final c = _channel;
    if (c == null) return false;
    final o = <String, dynamic>{'type': type, ...?fields};
    try {
      c.sink.add(jsonEncode(o));
      return true;
    } catch (_) {
      return false;
    }
  }

  bool createRoom({
    String name = '',
    String nickname = '',
    String avatar = '',
    String deviceToken = '',
  }) =>
      _send('create_room', {
        'name': name,
        'nickname': nickname,
        'avatar': avatar,
        'deviceToken': deviceToken,
      });

  bool joinRoom(
    String room, {
    String nickname = '',
    String avatar = '',
    String deviceToken = '',
  }) =>
      _send('join_room', {
        'room': room.trim(),
        'nickname': nickname,
        'avatar': avatar,
        'deviceToken': deviceToken,
      });

  bool leaveRoom() => _send('leave_room');
  bool resolve(String input) => _send('resolve', {'input': input});

  bool uploadPlaylist(
    List<Map<String, dynamic>> tracks, {
    String name = '',
    bool merge = false,
  }) =>
      _send('upload_playlist', {
        'tracks': tracks,
        'name': name,
        if (merge) 'merge': true,
      });

  bool play() => _send('play');
  bool pause() => _send('pause');
  bool seek(double positionSec) => _send('seek', {'position': positionSec});
  bool next() => _send('next');
  bool prev() => _send('prev');
  bool setMode(String mode) => _send('set_mode', {'mode': mode});
  bool sync(double positionSec) => _send('sync', {'position': positionSec});
  bool chat(String msg) => _send('chat', {'msg': msg});

  bool uploadAvatar(String dataBase64, {String deviceToken = ''}) =>
      _send('upload_avatar', {'data': dataBase64, 'deviceToken': deviceToken});
  bool getAvatar(String id) => _send('get_avatar', {'id': id});
  bool updateProfile(String nickname, String avatar,
          {String deviceToken = ''}) =>
      _send('update_profile', {
        'nickname': nickname,
        'avatar': avatar,
        'deviceToken': deviceToken,
      });

  bool deleteTrackById(String trackId) =>
      _send('delete_track', {'trackId': trackId});
  bool deleteTrackAt(int index) => _send('delete_track', {'index': index});

  bool listRooms() => _send('list_rooms');
  bool listSongs() => _send('list_songs');
  bool setRoomName(String name) =>
      _send('set_room_name', {'name': name.trim().substring(0, name.trim().length > 32 ? 32 : name.trim().length)});
  bool setVisibility(String v) => _send('set_visibility', {'visibility': v});
}

/// Data models mirroring native Models.kt and server snapshot().
/// Wire format follows server/index.js snapshot()/normalizeTrack()/chat broadcast.

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String cover;
  final String link;
  final String lyric;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.cover = '',
    this.link = '',
    this.lyric = '',
  });

  factory Track.fromJson(Map<String, dynamic> o) => Track(
        id: '${o['id'] ?? ''}',
        title: '${o['title'] ?? o['name'] ?? ''}',
        artist: '${o['artist'] ?? o['singer'] ?? '未知'}',
        album: '${o['album'] ?? ''}',
        cover: '${o['cover'] ?? o['pic'] ?? o['picUrl'] ?? ''}',
        link: '${o['link'] ?? o['url'] ?? ''}',
        lyric: '${o['lyric'] ?? o['lrc'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'cover': cover,
        'link': link,
        'lyric': lyric,
      };
}

class Member {
  final String id;
  final String nickname;
  final String avatar;

  const Member({required this.id, this.nickname = '', this.avatar = ''});

  factory Member.fromJson(Map<String, dynamic> o) => Member(
        id: '${o['id'] ?? ''}',
        nickname: '${o['nickname'] ?? ''}',
        avatar: '${o['avatar'] ?? ''}',
      );

  factory Member.bare(String id) => Member(id: id);
}

String displayName(Member m) =>
    m.nickname.isNotEmpty ? m.nickname : shortId(m.id);

String shortId(String id) => id.length <= 4 ? id : id.substring(id.length - 4);

class RoomState {
  final String room;
  final String name;
  final List<Track> tracks;
  final int index;
  final double position;
  final bool playing;
  final String mode;
  final int updatedAt;
  final List<Member> members;
  final String? host;
  final int seq;
  final String trackId;
  final String visibility;

  const RoomState({
    required this.room,
    required this.name,
    required this.tracks,
    required this.index,
    required this.position,
    required this.playing,
    required this.mode,
    required this.updatedAt,
    required this.members,
    required this.host,
    this.seq = 0,
    this.trackId = '',
    this.visibility = 'private',
  });

  double realPositionSec({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (playing) {
      return position + (now - updatedAt) / 1000.0;
    }
    return position;
  }

  Track? currentTrack() =>
      (index >= 0 && index < tracks.length) ? tracks[index] : null;

  factory RoomState.fromJson(Map<String, dynamic> o) {
    final tracks = <Track>[];
    final arr = o['tracks'];
    if (arr is List) {
      for (final e in arr) {
        if (e is Map<String, dynamic>) {
          tracks.add(Track.fromJson(e));
        } else if (e is Map) {
          tracks.add(Track.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    // memberProfiles first, then members (string ids reuse profiles).
    final profileById = <String, Member>{};
    final parr = o['memberProfiles'];
    if (parr is List) {
      for (final e in parr) {
        if (e is Map) {
          final m = Member.fromJson(Map<String, dynamic>.from(e));
          if (m.id.isNotEmpty) profileById[m.id] = m;
        }
      }
    }
    final members = <Member>[];
    final marr = o['members'];
    if (marr is List) {
      for (final e in marr) {
        if (e is Map) {
          final m = Member.fromJson(Map<String, dynamic>.from(e));
          if (m.id.isNotEmpty) members.add(m);
        } else {
          final id = '$e';
          if (id.isNotEmpty && id != 'null') {
            members.add(profileById[id] ?? Member.bare(id));
          }
        }
      }
    }

    final idx = (o['index'] as num?)?.toInt() ?? 0;
    final fallbackTrackId =
        (idx >= 0 && idx < tracks.length) ? tracks[idx].id : '';
    final rawTrackId = '${o['trackId'] ?? ''}';

    return RoomState(
      room: '${o['room'] ?? ''}',
      name: '${o['name'] ?? ''}',
      tracks: tracks,
      index: idx,
      position: (o['position'] as num?)?.toDouble() ?? 0.0,
      playing: o['playing'] == true,
      mode: '${o['mode'] ?? 'list'}',
      updatedAt: (o['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      members: members,
      host: '${o['host'] ?? ''}'.isEmpty ? null : '${o['host']}',
      seq: (o['seq'] as num?)?.toInt() ?? 0,
      trackId: rawTrackId.isEmpty ? fallbackTrackId : rawTrackId,
      visibility:
          '${o['visibility'] ?? 'private'}'.isEmpty ? 'private' : '${o['visibility']}',
    );
  }
}

class ChatMsg {
  final String from;
  final String msg;
  final int at;
  final String nickname;
  final String avatar;

  const ChatMsg({
    required this.from,
    required this.msg,
    required this.at,
    this.nickname = '',
    this.avatar = '',
  });

  factory ChatMsg.fromJson(Map<String, dynamic> o) => ChatMsg(
        from: '${o['from'] ?? ''}',
        msg: '${o['msg'] ?? ''}',
        at: (o['at'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        nickname: '${o['nickname'] ?? ''}',
        avatar: '${o['avatar'] ?? ''}',
      );
}

class PublicRoom {
  final String room;
  final String name;
  final int members;
  final String visibility;
  final bool playing;
  final String? current;

  const PublicRoom({
    required this.room,
    this.name = '',
    this.members = 0,
    this.visibility = 'public',
    this.playing = false,
    this.current,
  });

  factory PublicRoom.fromJson(Map<String, dynamic> o) {
    final cur = '${o['current'] ?? ''}';
    return PublicRoom(
      room: '${o['room'] ?? ''}',
      name: '${o['name'] ?? ''}',
      members: (o['members'] as num?)?.toInt() ?? 0,
      visibility: '${o['visibility'] ?? 'public'}',
      playing: o['playing'] == true,
      current: cur.isEmpty ? null : cur,
    );
  }
}

String modeLabel(String mode) => switch (mode) {
      'single' => '单曲循环',
      'shuffle' => '随机播放',
      _ => '顺序播放',
    };

String formatSec(double sec) {
  final s = sec < 0 ? 0 : sec.toInt();
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

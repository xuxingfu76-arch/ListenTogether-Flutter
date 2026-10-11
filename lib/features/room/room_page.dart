import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/avatar.dart';
import '../../core/models.dart';
import '../../core/room_controller.dart';
import '../chat/chat_overlay.dart';
import '../chat/chat_sheet.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key});
  @override
  State<RoomPage> createState() => _R();
}

class _R extends State<RoomPage> {
  bool _quick = false;
  void _openChat() {
    context.read<RoomController>().markChatRead();
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const ChatSheet());
  }
  void _openPlaylist() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const PlaylistSheet());
  }
  void _openSettings() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const RoomSettingsSheet());
  }
  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoomController>();
    final st = c.room;
    if (st == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final track = st.currentTrack();
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.name.isEmpty ? '房间 ${st.room}' : st.name),
          Text('房号 ${st.room} · ${st.members.length} 人', style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: '离开房间', onPressed: c.leaveRoom)],
      ),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('正在播放', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  ActionChip(label: Text(modeLabel(st.mode)), onPressed: c.cycleMode),
                  const SizedBox(width: 8),
                  Chip(label: Text(st.playing ? '播放中' : '已暂停')),
                ]),
                const SizedBox(height: 8),
                if (track != null && track.cover.isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(track.cover, width: 180, height: 180, fit: BoxFit.cover,
                          errorBuilder: (a, b, d) => const SizedBox.shrink()),
                    ),
                  ),
                Text(track == null ? '歌单是空的' : track.title, style: Theme.of(context).textTheme.headlineSmall),
                if (track != null) Text(track.artist, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(formatSec(c.progressSec), style: Theme.of(context).textTheme.bodySmall),
                Slider(
                  value: c.progressSec.clamp(0, 3600).toDouble(),
                  min: 0, max: 3600,
                  onChangeStart: (_) => c.setDragging(true),
                  onChanged: (v) { c.progressSec = v; },
                  onChangeEnd: (v) { c.setDragging(false); c.seekTo(v); },
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(icon: const Icon(Icons.skip_previous), tooltip: '上一首', onPressed: c.prev),
                  FilledButton.icon(
                    onPressed: c.togglePlay,
                    icon: Icon(st.playing ? Icons.pause : Icons.play_arrow),
                    label: Text(st.playing ? '暂停' : '播放'),
                  ),
                  IconButton(icon: const Icon(Icons.skip_next), tooltip: '下一首', onPressed: c.next),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(
                    icon: Badge(
                      label: Text('${c.unread}'),
                      isLabelVisible: c.unread > 0,
                      child: const Icon(Icons.chat_bubble_outline),
                    ),
                    tooltip: '聊天（点按输入，长按看记录）',
                    onPressed: () { c.markChatRead(); setState(() => _quick = true); },
                    onLongPress: _openChat,
                  ),
                  IconButton(icon: const Icon(Icons.queue_music), tooltip: '歌单', onPressed: _openPlaylist),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text('成员（${st.members.length}）', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final m in st.members)
                Chip(
                  avatar: MemberAvatar(name: m.nickname, id: m.id, avatar: m.avatar, image: c.avatarImageOf(m.avatar), radius: 12),
                  label: Text('${displayName(m)}${m.id == st.host ? '（房主）' : ''}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(onPressed: _openSettings, icon: const Icon(Icons.settings_outlined), label: const Text('房间设置')),
          if (c.lastError != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(title: Text(c.lastError!), trailing: IconButton(icon: const Icon(Icons.close), onPressed: c.clearError)),
            ),
        ]),
        const ChatOverlay(),
        if (_quick)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Row(children: [
              const Expanded(child: QuickChatBarInner()),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _quick = false)),
            ]),
          ),
      ]),
    );
  }
}

class QuickChatBarInner extends StatefulWidget {
  const QuickChatBarInner({super.key});
  @override
  State<QuickChatBarInner> createState() => _QI();
}

class _QI extends State<QuickChatBarInner> {
  final _t = TextEditingController();
  @override
  void dispose() { _t.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = context.read<RoomController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _t, autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '输入消息', isDense: true),
              onSubmitted: (v) { c.sendChat(v); _t.clear(); },
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: () { c.sendChat(_t.text); _t.clear(); }, child: const Text('发送')),
        ]),
      ),
    );
  }
}

class PlaylistSheet extends StatefulWidget {
  const PlaylistSheet({super.key});
  @override
  State<PlaylistSheet> createState() => _P();
}

class _P extends State<PlaylistSheet> {
  String _q = '';
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoomController>();
    final st = c.room;
    final roomTracks = st?.tracks ?? [];
    final rq = _q.trim().toLowerCase();
    final fRoom = rq.isEmpty ? roomTracks : roomTracks.where((t) => (t.title + t.artist).toLowerCase().contains(rq)).toList();
    final fCloud = rq.isEmpty ? c.cloudSongs : c.cloudSongs.where((t) => (t.title + t.artist).toLowerCase().contains(rq)).toList();
    final inRoomIds = roomTracks.map((e) => e.id).toSet();
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.8, maxChildSize: 0.92, minChildSize: 0.4,
      builder: (ctx, sc) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Text('歌单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            ChoiceChip(label: const Text('房间歌单'), selected: _tab == 0, onSelected: (_) => setState(() => _tab = 0)),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('云端歌库'), selected: _tab == 1, onSelected: (_) => setState(() => _tab = 1)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SearchBar(hintText: _tab == 0 ? '搜索房间歌曲' : '搜索云端歌曲', leading: const Icon(Icons.search), onChanged: (v) => setState(() => _q = v)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _tab == 0
              ? (fRoom.isEmpty
                  ? const Center(child: Text('房间歌单是空的'))
                  : ListView.builder(
                      itemCount: fRoom.length,
                      itemBuilder: (ctx, i) {
                        final t = fRoom[i];
                        final cur = st != null && st.currentTrack()?.id == t.id;
                        return ListTile(
                          leading: cur ? const Icon(Icons.equalizer) : Text('${i + 1}'),
                          title: Text(t.title),
                          subtitle: Text(t.artist),
                          trailing: (st != null && (st.host == null || st.host == c.myId))
                              ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => c.deleteTrack(t.id))
                              : null,
                        );
                      },
                    ))
              : (fCloud.isEmpty
                  ? const Center(child: Text('云端还没有歌，先去本地页解析'))
                  : ListView.builder(
                      itemCount: fCloud.length,
                      itemBuilder: (ctx, i) {
                        final t = fCloud[i];
                        final inRoom = inRoomIds.contains(t.id);
                        final saved = c.isSaved(t.id);
                        return ListTile(
                          title: Text(t.title),
                          subtitle: Text(t.artist),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            TextButton(onPressed: inRoom ? null : () => c.joinCloudTrackToRoom(t), child: Text(inRoom ? '已在房间' : '加入房间')),
                            IconButton(icon: Icon(saved ? Icons.favorite : Icons.favorite_border), onPressed: () => c.toggleSave(t)),
                          ]),
                        );
                      },
                    )),
        ),
      ]),
    );
  }
}

class RoomSettingsSheet extends StatefulWidget {
  const RoomSettingsSheet({super.key});
  @override
  State<RoomSettingsSheet> createState() => _S();
}

class _S extends State<RoomSettingsSheet> {
  final _name = TextEditingController();
  bool _init = false;
  @override
  void dispose() { _name.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoomController>();
    final st = c.room;
    if (st == null) return const SizedBox.shrink();
    if (!_init) { _name.text = st.name; _init = true; }
    final isHost = st.host == null || st.host == c.myId;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('房间设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(controller: _name, maxLength: 32, enabled: isHost, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '房间名'), onSubmitted: isHost ? (v) => c.setRoomName(v) : null),
          const SizedBox(height: 8),
          SwitchListTile(title: const Text('所有人可见（公开房间）'), value: st.visibility == 'public', onChanged: isHost ? (v) => c.setVisibility(v ? 'public' : 'private') : null),
          FilledButton.tonal(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ]),
      ),
    );
  }
}

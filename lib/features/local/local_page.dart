import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/room_controller.dart';

class LocalPage extends StatefulWidget {
  const LocalPage({super.key});
  @override
  State<LocalPage> createState() => _L();
}

class _L extends State<LocalPage> {
  final _input = TextEditingController();
  String _q = '';
  @override
  void dispose() { _input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoomController>();
    final rq = _q.trim().toLowerCase();
    final saved = rq.isEmpty ? c.saved : c.saved.where((t) => (t.title + t.artist).toLowerCase().contains(rq)).toList();
    final cloud = rq.isEmpty ? c.cloudSongs : c.cloudSongs.where((t) => (t.title + t.artist).toLowerCase().contains(rq)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('本地'), actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: '刷新云端', onPressed: c.refreshSongs),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('解析保存（每行一个链接或ID）', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(controller: _input, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '网易云分享链接 / 163cn.tv 短链 / 纯数字ID')),
              const SizedBox(height: 8),
              if (c.audioUpload != null) ...[
                LinearProgressIndicator(value: c.audioUpload),
                const SizedBox(height: 4),
                Text(c.audioUploadText ?? '', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Expanded(child: FilledButton.tonalIcon(onPressed: c.resolvingLocal ? null : () => c.resolveLocalSave(_input.text), icon: const Icon(Icons.download_outlined), label: const Text('解析保存到本地'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(onPressed: c.resolvingLocal ? null : () => c.resolveLocalSaveAndSync(_input.text), icon: const Icon(Icons.sync), label: const Text('解析并同步房间'))),
              ]),
              if (c.resolveReport != null) ...[
                const SizedBox(height: 8),
                Text(c.resolveReport!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SearchBar(hintText: '搜索本地 / 云端', leading: const Icon(Icons.search), onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 8),
        Row(children: [
          Text('我的收藏（${saved.length}）', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          TextButton(onPressed: c.saved.isEmpty ? null : c.uploadSavedAsPlaylist, child: const Text('全选同步房间')),
        ]),
        if (saved.isEmpty)
          const Card(child: ListTile(title: Text('本地还是空的，先在上方解析保存')))
        else
          for (final t in saved) _SavedTile(t: t),
        const SizedBox(height: 12),
        Row(children: [
          Text('云端歌库（${cloud.length}）', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          TextButton(onPressed: c.syncSavedMerge, child: const Text('收藏同步房间')),
        ]),
        if (cloud.isEmpty)
          const Card(child: ListTile(title: Text('云端还没有歌')))
        else
          for (final t in cloud) _CloudTile(t: t),
        if (c.lastError != null)
          Card(color: Theme.of(context).colorScheme.errorContainer, child: ListTile(title: Text(c.lastError!), trailing: IconButton(icon: const Icon(Icons.close), onPressed: c.clearError))),
      ]),
    );
  }
}

class _SavedTile extends StatelessWidget {
  final Track t;
  const _SavedTile({required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.read<RoomController>();
    return Card(
      child: ListTile(
        title: Text(t.title),
        subtitle: Text(t.artist),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => c.removeSaved(t.id)),
        ]),
      ),
    );
  }
}

class _CloudTile extends StatelessWidget {
  final Track t;
  const _CloudTile({required this.t});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoomController>();
    final inRoom = c.room?.tracks.any((e) => e.id == t.id) ?? false;
    final saved = c.isSaved(t.id);
    return Card(
      child: ListTile(
        title: Text(t.title),
        subtitle: Text(t.artist),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(onPressed: inRoom ? null : () => c.joinCloudTrackToRoom(t), child: Text(inRoom ? '已在房间' : '加入房间')),
          IconButton(icon: Icon(saved ? Icons.favorite : Icons.favorite_border), onPressed: () => c.toggleSave(t)),
        ]),
      ),
    );
  }
}

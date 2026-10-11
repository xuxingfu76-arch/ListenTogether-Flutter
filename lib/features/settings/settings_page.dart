import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/avatar.dart';
import '../../core/room_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _S();
}

class _S extends State<SettingsPage> {
  final _nick = TextEditingController();
  bool _ns = false;
  @override
  void dispose() { _nick.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoomController>();
    if (!_ns && c.nick.isNotEmpty) { _nick.text = c.nick; _ns = true; }
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('身份', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(children: [
                MemberAvatar(name: c.nick, id: c.myId.isEmpty ? c.deviceToken : c.myId, avatar: c.avatar, image: c.avatarImageOf(c.avatar), radius: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.nick.isEmpty ? '未设置昵称' : c.nick, style: Theme.of(context).textTheme.titleMedium),
                    Text('ID: ${c.myId.isEmpty ? '未连接' : c.myId}', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _nick, maxLength: 20, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '昵称', hintText: '大家能看到的名字'), onChanged: c.setNickname),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: FilledButton.tonalIcon(onPressed: c.pickAndUploadAvatar, icon: const Icon(Icons.image_outlined), label: const Text('上传头像'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: c.clearAvatarImage, child: const Text('清除头像'))),
              ]),
              const SizedBox(height: 8),
              SelectableText('设备码: ${c.deviceToken}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('服务器'),
            subtitle: Text('${c.connInfo}\nws://160.202.238.160:10169'),
            trailing: c.connected
                ? FilledButton(onPressed: c.disconnect, child: const Text('断开'))
                : FilledButton(onPressed: c.connect, child: const Text('连接')),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.battery_saver_outlined),
            title: Text('后台保活'),
            subtitle: Text('Android 请在系统设置中允许自启动与后台运行，聊天与播放需要保持连接'),
          ),
        ),
        if (c.lastError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(title: Text(c.lastError!), trailing: IconButton(icon: const Icon(Icons.close), onPressed: c.clearError)),
          ),
      ]),
    );
  }
}
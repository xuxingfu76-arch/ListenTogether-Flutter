import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/room_controller.dart';
import '../../core/models.dart';
class JoinPage extends StatefulWidget { const JoinPage({super.key}); @override State<JoinPage> createState()=>_J(); }
class _J extends State<JoinPage> {
  final _room=TextEditingController(); final _name=TextEditingController(); final _nick=TextEditingController();
  bool _ns=false;
  @override void dispose(){ _room.dispose(); _name.dispose(); _nick.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    final c=context.watch<RoomController>();
    if(!_ns&&c.nick.isNotEmpty){ _nick.text=c.nick; _ns=true; }
    if(_name.text!=c.roomName&&c.roomName.isNotEmpty&&_name.text.isEmpty){ _name.text=c.roomName; }
    return Scaffold(
      appBar:AppBar(title:const Text('加入房间'),actions:[Padding(padding:const EdgeInsets.only(right:12),child:Chip(label:Text(c.connected?'已连接':'未连接'),avatar:Icon(c.connected?Icons.cloud_done_outlined:Icons.cloud_off_outlined,size:16)))],),
      body:RefreshIndicator(onRefresh:()async=>c.refreshRooms(),child:ListView(padding:const EdgeInsets.all(16),children:[
        if(c.joinResult is JoinFailed) Card(color:Theme.of(context).colorScheme.errorContainer,child:ListTile(leading:const Icon(Icons.error_outline),title:Text((c.joinResult as JoinFailed).msg),trailing:IconButton(icon:const Icon(Icons.close),onPressed:c.clearJoinResult))),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('我的昵称',style:Theme.of(context).textTheme.titleSmall),
          const SizedBox(height:8),
          TextField(controller:_nick,maxLength:20,decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'昵称',hintText:'大家能看到的名字'),onChanged:c.setNickname),
          const SizedBox(height:8),
          TextField(controller:_room,maxLength:6,keyboardType:TextInputType.number,decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'房号',hintText:'6 位数字'),onSubmitted:c.joinRoom),
          const SizedBox(height:8),
          FilledButton.icon(onPressed:()=>c.joinRoom(_room.text),icon:const Icon(Icons.login),label:const Text('加入房间')),
        ]))),
        const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('创建房间',style:Theme.of(context).textTheme.titleSmall),
          const SizedBox(height:8),
          TextField(controller:_name,maxLength:32,decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'房间名（可选）',hintText:'不填只显示房号'),onChanged:c.setRoomNameField),
          const SizedBox(height:8),
          FilledButton.tonalIcon(onPressed:c.createRoom,icon:const Icon(Icons.add_home_outlined),label:const Text('创建并进入')),
        ]))),
        const SizedBox(height:12),
        Row(children:[Text('公开房间（${c.publicRooms.length}）',style:Theme.of(context).textTheme.titleSmall),const Spacer(),IconButton(icon:const Icon(Icons.refresh),onPressed:c.refreshRooms)]),
        if(c.publicRooms.isEmpty) const Card(child:ListTile(leading:Icon(Icons.meeting_room_outlined),title:Text('暂无公开房间'))),
        for(final r in c.publicRooms) Card(child:ListTile(
          leading:const Icon(Icons.meeting_room_outlined),
          title:Text(r.name.isEmpty?'房间 ${r.room}':'${r.name} · ${r.room}'),
          subtitle:Text('${r.members} 人${r.current==null?'':' · 在播 $r.current'}'),
          trailing:const Icon(Icons.chevron_right),
          onTap:()=>c.joinRoom(r.room),
        )),
        if(c.lastError!=null) Card(color:Theme.of(context).colorScheme.errorContainer,child:ListTile(title:Text(c.lastError!),trailing:IconButton(icon:const Icon(Icons.close),onPressed:c.clearError))),
      ])),
    );
  }
}

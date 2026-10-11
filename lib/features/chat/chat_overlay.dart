import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/avatar.dart';
import '../../core/models.dart';
import '../../core/room_controller.dart';
String _fmt(int ms){ final d=DateTime.fromMillisecondsSinceEpoch(ms); return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'; }
class ChatOverlay extends StatelessWidget {
  const ChatOverlay({super.key});
  @override Widget build(BuildContext context){
    final c=context.watch<RoomController>();
    final toasts=c.chatToasts;
    final myId=c.myId;
    if(toasts.isEmpty) return const SizedBox.shrink();
    return Positioned(top:8,left:8,right:8,child:Column(children:[
      for(final t in toasts) _ToastItem(t:t,me:t.from==myId,img:c.avatarImageOf(t.avatar)),
    ]));
  }
}
class _ToastItem extends StatelessWidget {
  final ChatMsg t; final bool me; final ImageProvider? img;
  const _ToastItem({required this.t,required this.me,this.img});
  @override Widget build(BuildContext context){
    return Dismissible(key:ValueKey('${t.from}_${t.at}_${t.msg.hashCode}'),direction:DismissDirection.up,onDismissed:(_)=>context.read<RoomController>().removeToast(t),child:GestureDetector(onTap:()=>context.read<RoomController>().removeToast(t),child:Container(margin:const EdgeInsets.only(bottom:8),child:Row(mainAxisAlignment:me?MainAxisAlignment.end:MainAxisAlignment.start,children:[
      Flexible(child:AnimatedSlide(duration:const Duration(milliseconds:250),offset:Offset.zero,child:AnimatedOpacity(duration:const Duration(milliseconds:250),opacity:1,child:Card(elevation:3,child:Padding(padding:const EdgeInsets.all(10),child:Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(!me) MemberAvatar(name:t.nickname,id:t.from,avatar:t.avatar,image:img,radius:14),
        if(!me) const SizedBox(width:8),
        Flexible(child:Column(crossAxisAlignment:me?CrossAxisAlignment.end:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
          Text('${t.nickname.isEmpty?shortId(t.from):t.nickname}  ${_fmt(t.at)}',style:Theme.of(context).textTheme.bodySmall),
          Text(t.msg,style:Theme.of(context).textTheme.bodyMedium),
        ])),
        if(me) const SizedBox(width:8),
        if(me) MemberAvatar(name:t.nickname,id:t.from,avatar:t.avatar,image:img,radius:14),
      ]))))),
    ]))));
  }
}
class QuickChatBar extends StatefulWidget { const QuickChatBar({super.key}); @override State<QuickChatBar> createState()=>_Q(); }
class _Q extends State<QuickChatBar> {
  final _t=TextEditingController();
  @override void dispose(){ _t.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    final c=context.read<RoomController>();
    return Positioned(left:0,right:0,bottom:0,child:Material(elevation:8,child:SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[
      Expanded(child:TextField(controller:_t,autofocus:true,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'输入消息',isDense:true),onSubmitted:(v){ c.sendChat(v); _t.clear(); })),
      const SizedBox(width:8),
      FilledButton(onPressed:(){ c.sendChat(_t.text); _t.clear(); },child:const Text('发送')),
    ])))));
  }
}

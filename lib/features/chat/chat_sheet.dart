import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/avatar.dart';
import '../../core/models.dart';
import '../../core/room_controller.dart';
String _fmtTime(int ms){ final d=DateTime.fromMillisecondsSinceEpoch(ms); return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'; }
class ChatSheet extends StatefulWidget { const ChatSheet({super.key}); @override State<ChatSheet> createState()=>_C(); }
class _C extends State<ChatSheet> {
  final _sc=ScrollController();
  @override void initState(){ super.initState(); WidgetsBinding.instance.addPostFrameCallback((_){ _jump(); }); }
  void _jump(){ if(!_sc.hasClients) return; try{ _sc.jumpTo(_sc.position.maxScrollExtent); }catch(_){} Future.delayed(const Duration(milliseconds:80),(){ if(!_sc.hasClients) return; try{ _sc.jumpTo(_sc.position.maxScrollExtent); }catch(_){} }); }
  @override void dispose(){ _sc.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    final c=context.watch<RoomController>();
    final myId=c.myId;
    final items=c.chats;
    WidgetsBinding.instance.addPostFrameCallback((_){ _jump(); });
    return DraggableScrollableSheet(expand:false,initialChildSize:0.75,maxChildSize:0.92,minChildSize:0.4,builder:(ctx,sc)=>Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:Row(children:[Text('聊天记录（${items.length}）',style:Theme.of(context).textTheme.titleMedium),const Spacer(),IconButton(icon:const Icon(Icons.close),onPressed:()=>Navigator.pop(context))])),
      Expanded(child:ListView.builder(controller:_sc,itemCount:items.length,itemBuilder:(ctx,i){
        final m=items[i]; final me=m.from==myId;
        return _Bubble(m:m,me:me,img:c.avatarImageOf(m.avatar));
      })),
      _InputRow(onSend:(t){ c.sendChat(t); }),
    ]));
  }
}
class _Bubble extends StatefulWidget { final ChatMsg m; final bool me; final ImageProvider? img; const _Bubble({required this.m,required this.me,this.img}); @override State<_Bubble> createState()=>_B(); }
class _B extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ac; late final Animation<Offset> _off; late final Animation<double> _op;
  @override void initState(){ super.initState(); _ac=AnimationController(vsync:this,duration:const Duration(milliseconds:220)); _off=Tween(begin:Offset(widget.me?1:-1,0),end:Offset.zero).animate(CurvedAnimation(parent:_ac,curve:Curves.easeOut)); _op=Tween(begin:0.0,end:1.0).animate(_ac); _ac.forward(); }
  @override void dispose(){ _ac.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    final m=widget.m;
    return FadeTransition(opacity:_op,child:SlideTransition(position:_off,child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:Row(mainAxisAlignment:widget.me?MainAxisAlignment.end:MainAxisAlignment.start,crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(!widget.me) MemberAvatar(name:m.nickname,id:m.from,avatar:m.avatar,image:widget.img,radius:16),
      if(!widget.me) const SizedBox(width:8),
      Flexible(child:Column(crossAxisAlignment:widget.me?CrossAxisAlignment.end:CrossAxisAlignment.start,children:[
        Text('${m.nickname.isEmpty?shortId(m.from):m.nickname}  ${_fmtTime(m.at)}',style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:2),
        Card(color:widget.me?Theme.of(context).colorScheme.primaryContainer:null,child:Padding(padding:const EdgeInsets.all(10),child:Text(m.msg))),
      ])),
      if(widget.me) const SizedBox(width:8),
      if(widget.me) MemberAvatar(name:m.nickname,id:m.from,avatar:m.avatar,image:widget.img,radius:16),
    ]))));
  }
}
class _InputRow extends StatefulWidget { final void Function(String) onSend; const _InputRow({required this.onSend}); @override State<_InputRow> createState()=>_I(); }
class _I extends State<_InputRow> {
  final _t=TextEditingController();
  @override void dispose(){ _t.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    return SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[
      Expanded(child:TextField(controller:_t,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'输入消息',isDense:true),onSubmitted:(v){ widget.onSend(v); _t.clear(); })),
      const SizedBox(width:8),
      FilledButton(onPressed:(){ widget.onSend(_t.text); _t.clear(); },child:const Text('发送')),
    ])));
  }
}

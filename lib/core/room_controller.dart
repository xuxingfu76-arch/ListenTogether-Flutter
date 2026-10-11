import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'audio_player.dart';
import 'avatar.dart';
import 'listen_socket.dart';
import 'models.dart';
import 'resolve_service.dart';
import 'saved_store.dart';
import 'server_config.dart';
import 'settings_store.dart';
sealed class JoinResult { const JoinResult(); }
class JoinIdle extends JoinResult { const JoinIdle(); }
class JoinJoined extends JoinResult { final String room; final bool isCreate; const JoinJoined(this.room,{this.isCreate=false}); }
class JoinFailed extends JoinResult { final String msg; const JoinFailed(this.msg); }
class RoomController extends ChangeNotifier {
  final ListenSocket socket = ListenSocket();
  final SettingsStore settings = SettingsStore();
  final SavedStore savedStore = SavedStore();
  final RoomAudio audio = RoomAudio();
  static const _joinErrorCodes = {'invalid_room','room_not_found','room_full'};
  String nick=''; String avatar=''; String deviceToken=''; String roomName='';
  JoinResult joinResult = const JoinIdle();
  bool connected=false; String connInfo='未连接'; String myId='';
  RoomState? room; List<ChatMsg> chats=[]; List<PublicRoom> publicRooms=[];
  int unread=0; double progressSec=0; String? lastError;
  List<Track> saved=[]; List<Track> cloudSongs=[];
  List<ChatMsg> chatToasts=[];
  Map<String, ImageProvider> avatarImages={};
  final Set<String> _pendingAvatarFetch={};
  bool resolving=false; bool resolvingLocal=false;
  double? audioUpload; String? audioUploadText; String? resolveReport;
  bool isDragging=false;
  int _lastSeq=-1; String? _lastTrackId;
  String? _lastRoomId; String? _pendingJoinId; bool _pendingCreate=false;
  bool _wantConnection=false; bool _inited=false;
  int _lastSocketEventAt=0; int _lastSyncAt=0; int _lastLocalSeekAt=0;
  Timer? _reconnectTimer; Duration _reconnectDelay=const Duration(seconds:2);
  Timer? _tickTimer;
  Future<void> init() async {
    if (_inited) return; _inited=true;
    final (n,a)=await settings.snapshotProfile();
    nick=n; avatar=a;
    deviceToken=await settings.ensureDeviceToken();
    roomName=await settings.snapshotRoomName();
    _lastRoomId=await settings.snapshotLastRoom();
    saved=await savedStore.load();
    await audio.init();
    socket.onEvent=onSocketEvent;
    connect();
    _tickTimer=Timer.periodic(const Duration(milliseconds:500),(_)=>tick());
  }
  @override void dispose(){ _tickTimer?.cancel(); _reconnectTimer?.cancel(); socket.close(); audio.dispose(); super.dispose(); }
  void connect(){
    unawaited(settings.setNick(nick)); unawaited(settings.setAvatar(avatar));
    if(deviceToken.isEmpty){ unawaited(settings.ensureDeviceToken().then((v)=>deviceToken=v)); }
    lastError=null; _wantConnection=true; _reconnectTimer?.cancel();
    connInfo='连接中...'; notifyListeners();
    socket.connect(ServerConfig.wsUrl, ServerConfig.password);
  }
  void disconnect(){
    _wantConnection=false; _reconnectTimer?.cancel(); socket.close();
    connected=false; connInfo='未连接';
    _lastRoomId=null; unawaited(settings.setLastRoom(null));
    _clearRoomState(); joinResult=const JoinIdle(); audio.stop(); notifyListeners();
  }
  void onAppResumed(){
    _lastSocketEventAt=DateTime.now().millisecondsSinceEpoch;
    if(!connected&&_wantConnection){ connect(); }
  }
  void _scheduleReconnect(){
    if(!_wantConnection||(_reconnectTimer?.isActive==true))return;
    _reconnectDelay=const Duration(seconds:2);
    void attempt(){
      if(!_wantConnection||connected)return;
      connInfo='已断开，重连中...'; notifyListeners();
      socket.connect(ServerConfig.wsUrl, ServerConfig.password);
      _reconnectDelay=Duration(milliseconds:(_reconnectDelay.inMilliseconds*2).clamp(2000,15000));
      _reconnectTimer=Timer(_reconnectDelay,attempt);
    }
    _reconnectTimer=Timer(_reconnectDelay,attempt);
  }
  void onSocketEvent(SocketEvent ev){
    _lastSocketEventAt=DateTime.now().millisecondsSinceEpoch;
    switch(ev){
      case HelloEvent(:final id):
        myId=id; socket.listRooms(); socket.listSongs();
        final target=_pendingJoinId??_lastRoomId;
        if(target!=null){ socket.joinRoom(target,nickname:nick,avatar:avatar,deviceToken:deviceToken); }
      case RoomEvent(:final room,:final state):
        _lastRoomId=room; unawaited(settings.setLastRoom(room));
        _pendingJoinId=null; final was=_pendingCreate; _pendingCreate=false;
        _lastSeq=state.seq; _lastTrackId=state.trackId.isEmpty?state.currentTrack()?.id:state.trackId;
        if(this.room?.room!=room){ chats=[]; unread=0; chatToasts=[]; }
        this.room=state; joinResult=JoinJoined(room,isCreate:was);
        for(final m in state.members){ ensureAvatar(m.avatar); }
        applyState(state,force:true);
      case StateEvent(:final state):
        if(state.seq<_lastSeq)break;
        _lastSeq=state.seq;
        final first=room==null;
        if(first){ _lastRoomId=state.room; unawaited(settings.setLastRoom(state.room)); }
        final jt=_pendingJoinId; _pendingJoinId=null; _pendingCreate=false;
        if(jt!=null){ joinResult=JoinJoined(state.room); }
        else if(first&&joinResult is JoinIdle){ joinResult=JoinJoined(state.room); }
        room=state;
        for(final m in state.members){ ensureAvatar(m.avatar); }
        applyState(state,force:first||jt!=null);
      case ChatEvent(:final item):
        final dup=chats.any((c)=>c.from==item.from&&c.msg==item.msg&&(c.at-item.at).abs()<3000);
        if(!dup){
          chats=[...chats,item]; if(chats.length>200)chats=chats.sublist(chats.length-200);
          if(item.from!=myId){unread+=1;}
        }
        ensureAvatar(item.avatar);
        _pushToast(item);
      case LeftEvent():
        _lastRoomId=null; unawaited(settings.setLastRoom(null));
        _clearRoomState(); joinResult=const JoinIdle(); audio.stop();
      case RoomsEvent(:final rooms): publicRooms=rooms;
      case SongsEvent(:final tracks): cloudSongs=tracks;
      case SongsUpdatedEvent(): socket.listSongs();
      case AvatarUploadedEvent(:final avatarId): avatar='$kImgPrefix$avatarId'; unawaited(settings.setAvatar(avatar)); notifyListeners();
      case AvatarDataEvent(:final id,:final data):
        try{
          final bytes=base64Decode(data);
          avatarImages[id]=MemoryImage(bytes);
        }catch(_){}
        _pendingAvatarFetch.remove(id);
      case ErrorEvent(:final message,:final code):
        final joinFailed=_joinErrorCodes.contains(code)||message.contains('不存在')||message.contains('已满')||message.contains('6 位');
        if(joinFailed){
          final target=_pendingJoinId;
          final friendly=switch(code){
            'room_not_found'=>target!=null?'房间 $target 不存在':message,
            'room_full'=>message.isEmpty?'房间已满，换个房间试试':message,
            'invalid_room'=>'房号是 6 位数字',
            _=>message.isEmpty?'加入失败，请重试':message,
          };
          joinResult=JoinFailed(friendly);
          if(code=='room_not_found'){ _lastRoomId=null; unawaited(settings.setLastRoom(null)); _pendingJoinId=null; _pendingCreate=false; _clearRoomState(); }
          else{ if(room==null){_lastRoomId=null; unawaited(settings.setLastRoom(null)); _clearRoomState();} _pendingJoinId=null; _pendingCreate=false; }
        } else {
          if(message.contains('resolve')) resolving=false;
          lastError=message;
        }
      case ConnEvent(:final connected,:final reason):
        this.connected=connected;
        if(connected){ connInfo='服务器已连接'; _reconnectTimer?.cancel(); _reconnectDelay=const Duration(seconds:2); socket.listRooms(); socket.listSongs(); }
        else{ connInfo=reason==null?'已断开，重连中...':'已断开($reason)，重连中...'; _scheduleReconnect(); }
    }
    notifyListeners();
  }
  void _clearRoomState(){ room=null; chats=[]; unread=0; chatToasts=[]; progressSec=0; _lastSeq=-1; _lastTrackId=null; }
  void applyState(RoomState st,{bool force=false}){
    final track=st.currentTrack();
    if(track==null||track.link.isEmpty){ progressSec=0; return; }
    final incoming=st.trackId.isEmpty?track.id:st.trackId;
    final now=DateTime.now().millisecondsSinceEpoch;
    final inCooldown=(now-_lastLocalSeekAt)<3000;
    final needSwitch=_lastTrackId!=incoming||audio.currentUrl!=track.link||force;
    if(needSwitch){
      _lastTrackId=incoming;
      audio.playUrl(track.link,positionSec:st.realPositionSec(),playing:st.playing);
      progressSec=st.realPositionSec();
    } else {
      final target=st.realPositionSec();
      if(!inCooldown&&(target-progressSec).abs()>1.5){
        audio.seekTo(target); progressSec=target;
      } else if(!st.playing){ progressSec=target; }
      audio.applyPlaying(st.playing);
    }
  }
  void tick(){
    final st=room; if(st==null)return;
    final next=st.realPositionSec();
    if((next-progressSec).abs()>0.05){ progressSec=next; notifyListeners(); }
    final now=DateTime.now().millisecondsSinceEpoch;
    if(st.playing&&connected&&!isDragging&&(now-_lastLocalSeekAt)>3000&&(now-_lastSyncAt)>5000){
      if((next-progressSec).abs()<60){ _lastSyncAt=now; socket.sync(next); }
    }
  }
  void createRoom(){
    lastError=null; _lastRoomId=null; unawaited(settings.setLastRoom(null));
    _lastSeq=-1; _lastTrackId=null; _pendingCreate=true; _pendingJoinId=null;
    joinResult=const JoinIdle();
    final name=roomName.trim().length>32?roomName.trim().substring(0,32):roomName.trim();
    unawaited(settings.setRoomName(name));
    socket.createRoom(name:name,nickname:nick,avatar:avatar,deviceToken:deviceToken);
    notifyListeners();
  }
  void joinRoom(String roomId){
    final target=roomId.trim();
    if(target.length!=6){ joinResult=const JoinFailed('房号是 6 位数字'); notifyListeners(); return; }
    joinResult=const JoinIdle(); _pendingJoinId=target; _pendingCreate=false;
    if(!connected){ connect(); } else { socket.joinRoom(target,nickname:nick,avatar:avatar,deviceToken:deviceToken); }
    notifyListeners();
  }
  void leaveRoom(){
    socket.leaveRoom(); _lastRoomId=null; unawaited(settings.setLastRoom(null));
    _clearRoomState(); _pendingJoinId=null; _pendingCreate=false;
    joinResult=const JoinIdle(); audio.stop(); notifyListeners();
  }
  void togglePlay(){ final st=room; if(st==null)return; if(st.playing){socket.pause();}else{socket.play();} }
  void seekTo(double sec){ progressSec=sec; _lastLocalSeekAt=DateTime.now().millisecondsSinceEpoch; audio.seekTo(sec); socket.seek(sec); notifyListeners(); }
  void setDragging(bool v){ isDragging=v; notifyListeners(); }
  void next()=>socket.next(); void prev()=>socket.prev();
  void cycleMode(){
    final cur=room?.mode??'list';
    final nx=cur=='list'?'shuffle':(cur=='shuffle'?'single':'list');
    socket.setMode(nx);
  }
  void deleteTrack(String id){ if(room==null||id.isEmpty)return; socket.deleteTrackById(id); }
  void refreshRooms()=>socket.listRooms();
  void refreshSongs()=>socket.listSongs();
  void setRoomName(String name){ if(room==null)return; socket.setRoomName(name); }
  void setVisibility(String v)=>socket.setVisibility(v);
  void sendChat(String raw){
    final text=raw.trim(); if(text.isEmpty||room==null)return;
    final local=ChatMsg(from:myId,msg:text,at:DateTime.now().millisecondsSinceEpoch,nickname:nick,avatar:avatar);
    final dup=chats.any((c)=>c.from==local.from&&c.msg==local.msg&&(c.at-local.at).abs()<3000);
    if(!dup){ chats=[...chats,local]; if(chats.length>200)chats=chats.sublist(chats.length-200); }
    _pushToast(local);
    socket.chat(text); notifyListeners();
  }
  void _pushToast(ChatMsg item){
    if(chatToasts.any((c)=>c.from==item.from&&c.msg==item.msg&&(c.at-item.at).abs()<3000))return;
    chatToasts=[...chatToasts,item];
    if(chatToasts.length>4)chatToasts=chatToasts.sublist(chatToasts.length-4);
    Timer(const Duration(seconds:10),(){ chatToasts.removeWhere((c)=>c.from==item.from&&c.msg==item.msg&&c.at==item.at); notifyListeners(); });
  }
  void removeToast(ChatMsg item){ chatToasts.removeWhere((c)=>c.from==item.from&&c.msg==item.msg&&c.at==item.at); notifyListeners(); }
  void markChatRead(){ unread=0; notifyListeners(); }
  void ensureAvatar(String v){
    final id=avatarIdOf(v); if(id==null)return;
    if(avatarImages.containsKey(id)||_pendingAvatarFetch.contains(id))return;
    _pendingAvatarFetch.add(id); socket.getAvatar(id);
  }
  ImageProvider? avatarImageOf(String v){ final id=avatarIdOf(v); if(id==null)return null; return avatarImages[id]; }
  void setNickname(String v){ nick=v.trim().length>20?v.trim().substring(0,20):v.trim(); unawaited(settings.setNick(nick)); if(room!=null){socket.updateProfile(nick,avatar,deviceToken:deviceToken);} notifyListeners(); }
  void setRoomNameField(String v){ roomName=v; notifyListeners(); }
  Future<void> pickAndUploadAvatar() async {
    try{
      final picker=ImagePicker();
      final x=await picker.pickImage(source:ImageSource.gallery,maxWidth:256,maxHeight:256,imageQuality:80);
      if(x==null)return;
      final bytes=await x.readAsBytes();
      if(bytes.lengthInBytes>200*1024){ lastError='图片太大，请选 200KB 以内'; notifyListeners(); return; }
      if(!connected){ lastError='未连接服务器，稍后重试'; notifyListeners(); return; }
      socket.uploadAvatar(base64Encode(bytes),deviceToken:deviceToken);
    }catch(e){ lastError='选择图片失败'; notifyListeners(); }
  }
  void clearAvatarImage(){ avatar=''; unawaited(settings.setAvatar('')); if(room!=null){socket.updateProfile(nick,'',deviceToken:deviceToken);} notifyListeners(); }
  bool isSaved(String id)=>saved.any((e)=>e.id==id);
  Future<void> toggleSave(Track t) async { if(await savedStore.contains(t.id)){await savedStore.remove(t.id);}else{await savedStore.add(t);} saved=await savedStore.load(); notifyListeners(); }
  Future<void> removeSaved(String id) async { await savedStore.remove(id); saved=await savedStore.load(); notifyListeners(); }
  Future<void> saveCloudTrack(Track t) async { await savedStore.add(t); saved=await savedStore.load(); notifyListeners(); }
  void joinCloudTrackToRoom(Track t){ if(room==null){lastError='先在房间页开房或进房，再加入'; notifyListeners(); return;} lastError=null; socket.uploadPlaylist([savedStore.toUploadJson(t)],merge:true); notifyListeners(); }
  void uploadSavedAsPlaylist(){ if(saved.isEmpty){lastError='本地还是空的，先在本地页解析保存'; notifyListeners(); return;} lastError=null; socket.uploadPlaylist(saved.map(savedStore.toUploadJson).toList(),name:'我的收藏'); notifyListeners(); }
  void syncSavedMerge(){ if(saved.isEmpty){lastError='本地还是空的，先解析保存'; notifyListeners(); return;} if(room==null){lastError='先在房间页开房或进房，再同步'; notifyListeners(); return;} lastError=null; socket.uploadPlaylist(saved.map(savedStore.toUploadJson).toList(),name:'我的收藏',merge:true); notifyListeners(); }
  Future<void> resolveLocalSave(String rawInput) async {
    final lines=rawInput.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toSet().take(50).toList();
    if(lines.isEmpty){ resolveReport='先粘贴歌曲链接或 ID，每行一个'; notifyListeners(); return; }
    if(resolvingLocal)return; resolvingLocal=true; resolveReport=null; lastError=null; audioUpload=0; audioUploadText='开始解析'; notifyListeners();
    var ok=0; var dup=0; final failed=<String>[];
    for(var i=0;i<lines.length;i++){
      final line=lines[i];
      final id=extractNeteaseId(line)??await resolveIdWithRedirect(line);
      if(id==null){ failed.add(line.length>24?line.substring(0,24):line); continue; }
      final track=await fetchTrack(id);
      if(track==null||track.link.isEmpty){ failed.add(line.length>24?line.substring(0,24):line); continue; }
      final uploaded=await uploadTrackAudio(track,onProgress:(p,t){ audioUpload=(i+p)/lines.length; audioUploadText=t; notifyListeners(); });
      Track effective=track;
      if(uploaded){ effective=Track(id:track.id,title:track.title,artist:track.artist,album:track.album,cover:track.cover,link:'${ServerConfig.httpBase}/audio/${Uri.encodeComponent(track.id)}',lyric:track.lyric); }
      if(!uploaded&&await savedStore.contains(track.id)){ dup++; }
      else{ if(!uploaded){await savedStore.add(track);} else {await savedStore.add(effective);} ok++; }
    }
    saved=await savedStore.load();
    audioUpload=null; audioUploadText=null; resolvingLocal=false;
    final buf=StringBuffer('保存成功 $ok 首');
    if(dup>0)buf.write('（跳过重复 $dup 首）');
    if(failed.isNotEmpty){ buf.write('，失败 ${failed.length} 个：${failed.take(5).join('、')}'); if(failed.length>5)buf.write('...'); }
    resolveReport=buf.toString(); notifyListeners();
  }
  Future<void> resolveLocalSaveAndSync(String rawInput) async {
    final lines=rawInput.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toSet().take(50).toList();
    if(lines.isEmpty){ resolveReport='先粘贴歌曲链接或 ID，每行一个'; notifyListeners(); return; }
    if(room==null){ lastError='先在房间页开房或进房，再同步'; notifyListeners(); return; }
    if(resolvingLocal)return; resolvingLocal=true; resolveReport=null; lastError=null; audioUpload=0; notifyListeners();
    var ok=0; var dup=0; final failed=<String>[]; final fresh=<Track>[];
    for(var i=0;i<lines.length;i++){
      final line=lines[i];
      final id=extractNeteaseId(line)??await resolveIdWithRedirect(line);
      if(id==null){ failed.add(line.length>24?line.substring(0,24):line); continue; }
      final track=await fetchTrack(id);
      if(track==null||track.link.isEmpty){ failed.add(line.length>24?line.substring(0,24):line); continue; }
      final uploaded=await uploadTrackAudio(track,onProgress:(p,t){ audioUpload=(i+p)/lines.length; audioUploadText=t; notifyListeners(); });
      final effective=uploaded?Track(id:track.id,title:track.title,artist:track.artist,album:track.album,cover:track.cover,link:'${ServerConfig.httpBase}/audio/${Uri.encodeComponent(track.id)}',lyric:track.lyric):track;
      if(!uploaded&&await savedStore.contains(track.id)){ dup++; }
      else{ if(!uploaded){await savedStore.add(track);} else {await savedStore.add(effective);} fresh.add(effective); ok++; }
    }
    saved=await savedStore.load();
    audioUpload=null; audioUploadText=null; resolvingLocal=false;
    if(fresh.isNotEmpty){ socket.uploadPlaylist(fresh.map(savedStore.toUploadJson).toList(),name:'我的收藏',merge:true); }
    final buf=StringBuffer('保存成功 $ok 首，已同步到房间');
    if(dup>0)buf.write('（跳过重复 $dup 首）');
    if(failed.isNotEmpty){ buf.write('，失败 ${failed.length} 个：${failed.take(5).join('、')}'); }
    resolveReport=buf.toString(); notifyListeners();
  }
  void clearError(){ lastError=null; notifyListeners(); }
  void clearJoinResult(){ joinResult=const JoinIdle(); notifyListeners(); }
  void clearReport(){ resolveReport=null; notifyListeners(); }
}

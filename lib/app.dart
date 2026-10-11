import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/room_controller.dart';
import 'features/room/join_page.dart';
import 'features/room/room_page.dart';
import 'features/local/local_page.dart';
import 'features/settings/settings_page.dart';
class ListenApp extends StatelessWidget {
  const ListenApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Listen Together',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6750A4)),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6750A4), brightness: Brightness.dark),
      home: const RootSwitch(),
    );
  }
}
class RootSwitch extends StatefulWidget { const RootSwitch({super.key}); @override State<RootSwitch> createState()=>_RootSwitchState(); }
class _RootSwitchState extends State<RootSwitch> with WidgetsBindingObserver {
  int _tab=0;
  @override void initState(){ super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override void dispose(){ WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state){ if(state==AppLifecycleState.resumed){ context.read<RoomController>().onAppResumed(); } }
  @override Widget build(BuildContext context){
    final ctrl=context.watch<RoomController>();
    final inRoom=ctrl.room!=null;
    final pages=<Widget>[inRoom?const RoomPage():const JoinPage(), const LocalPage(), const SettingsPage()];
    return Scaffold(
      body: IndexedStack(index:_tab, children:pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex:_tab, onDestinationSelected:(i)=>setState(()=>_tab=i),
        destinations: const [
          NavigationDestination(icon:Icon(Icons.meeting_room_outlined), label:'房间'),
          NavigationDestination(icon:Icon(Icons.library_music_outlined), label:'本地'),
          NavigationDestination(icon:Icon(Icons.settings_outlined), label:'设置'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
const String kImgPrefix = 'img:';
bool isImgAvatar(String v) => v.trim().startsWith(kImgPrefix);
String? avatarIdOf(String v) {
  final s = v.trim();
  if (!s.startsWith(kImgPrefix)) return null;
  final id = s.substring(kImgPrefix.length).trim();
  return id.isEmpty ? null : id;
}
const List<int> _palette = [
  0xFF5C9CF5, 0xFF48C09A, 0xFFF0A35E, 0xFFB07CEB,
  0xFF4FB8D4, 0xFFEF7DA0, 0xFF8DB14F, 0xFFF2B90D,
];
Color avatarColor(String id) {
  final h = id.hashCode & 0x7fffffff;
  return Color(_palette[h % _palette.length]);
}
String avatarInitial(String name, String id) {
  final n = name.trim();
  if (n.isNotEmpty) return String.fromCharCode(n.runes.first).toUpperCase();
  final c = id.trim();
  if (c.isEmpty) return '?';
  final tail = c.length <= 4 ? c : c.substring(c.length - 4);
  return String.fromCharCode(tail.runes.first).toUpperCase();
}
class MemberAvatar extends StatelessWidget {
  final String name; final String id; final String avatar;
  final ImageProvider? image; final double radius;
  const MemberAvatar({super.key, required this.name, required this.id, required this.avatar, this.image, this.radius = 18});
  @override
  Widget build(BuildContext context) {
    if (image != null) return CircleAvatar(radius: radius, backgroundImage: image);
    return CircleAvatar(radius: radius, backgroundColor: avatarColor(id), child: Text(avatarInitial(name, id), style: TextStyle(fontSize: radius * 0.9, color: Colors.white)));
  }
}

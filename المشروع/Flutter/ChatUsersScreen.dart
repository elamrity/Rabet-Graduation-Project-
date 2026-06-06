import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as database;
import 'package:intl/intl.dart';
import 'Chat_Screen.dart';
import 'SignInPage.dart';

class ChatUsersScreen extends StatelessWidget {
  const ChatUsersScreen({super.key});

  String _formatLastMessageTime(int? ts) {
    if (ts == null) return "";
    var date = DateTime.fromMillisecondsSinceEpoch(ts);
    var now = DateTime.now();

    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat('hh:mm a').format(date);
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }

  // 👈 تم تعديل الدالة لاستقبال حالة التعديل وإظهار علامة القلم
  String _getInboxMessageText(String text, String type, bool isEdited) {
    if (type == 'image') return "📷 صورة";
    if (type == 'audio') return "🎵 فويس نوت";
    if (type == 'file') return "📄 مستند";
    if (type == 'deleted') return "🚫 تم حذف هذه الرسالة";

    // إضافة علامة القلم إذا كانت الرسالة معدلة
    return isEdited ? "✏️ $text" : text;
  }

  Future<void> _handleSignOut(BuildContext context, String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': 'offline'});
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => const SignInPage()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error during sign out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        elevation: 1,
        title: const Text("WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.groups, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ChatScreen()))),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF233138),
            onSelected: (value) { if (value == 'logout') _handleSignOut(context, currentUid); },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(children: [Icon(Icons.logout, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text("تسجيل الخروج", style: TextStyle(color: Colors.white))]),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
          final users = snapshot.data!.docs.where((doc) => doc.id != currentUid).toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index];
              List<String> ids = [currentUid, user.id];
              ids.sort();
              String chatId = ids.join('_');

              database.Query lastMsgQuery = database.FirebaseDatabase.instance.ref("private_chats/$chatId").orderByChild("timestamp").limitToLast(1);

              return StreamBuilder<database.DatabaseEvent>(
                stream: lastMsgQuery.onValue,
                builder: (context, dbSnapshot) {
                  String lastMessageText = "لا توجد رسائل بعد";
                  String lastMessageTime = "";
                  bool isMeText = false;
                  String status = "sent";
                  String type = "text";

                  if (dbSnapshot.hasData && dbSnapshot.data!.snapshot.value != null) {
                    final Map data = dbSnapshot.data!.snapshot.value as Map;
                    final lastMsgData = data.values.first;

                    type = lastMsgData['type'] ?? "text";
                    bool isEdited = lastMsgData['isEdited'] ?? false; // 👈 قراءة حالة التعديل
                    lastMessageText = _getInboxMessageText(lastMsgData['text'] ?? "", type, isEdited);
                    lastMessageTime = _formatLastMessageTime(lastMsgData['timestamp']);
                    isMeText = lastMsgData['senderId'] == currentUid;
                    status = lastMsgData['status'] ?? "sent";
                  }

                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(receiverId: user.id, receiverName: user['name']))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 26, backgroundColor: const Color(0xFF202C33), child: Text(user['name'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF00A884), fontSize: 20, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(user['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                                    Text(lastMessageTime, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    if (isMeText && lastMessageText != "لا توجد رسائل بعد") ...[ _buildInboxStatusIcon(status), const SizedBox(width: 4)],
                                    Expanded(child: Text(lastMessageText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: lastMessageText == "لا توجد رسائل بعد" ? Colors.white30 : (type != 'text' ? const Color(0xFF00A884) : Colors.white60), fontSize: 14))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInboxStatusIcon(String status) {
    switch (status) {
      case 'read': return const Row(children: [Icon(Icons.check, size: 16, color: Color(0xFF53BDEB)), SizedBox(width: -10), Icon(Icons.check, size: 16, color: Color(0xFF53BDEB))]);
      case 'delivered': return const Row(children: [Icon(Icons.check, size: 16, color: Colors.white30), SizedBox(width: -10), Icon(Icons.check, size: 16, color: Colors.white30)]);
      case 'sent': return const Icon(Icons.check, size: 16, color: Colors.white30);
      default: return const Icon(Icons.access_time_rounded, size: 14, color: Colors.white30);
    }
  }
}
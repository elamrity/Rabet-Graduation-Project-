import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as db;
import 'Chat_Screen.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  Future<void> _banUser(BuildContext context, String uid, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text("تأكيد الحظر", style: TextStyle(color: Colors.white)),
        content: Text("هل أنت متأكد من حظر $name وحذف بياناته نهائياً؟", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حظر"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        await db.FirebaseDatabase.instance.ref("private_chats").orderByKey().get().then((snapshot) {
          if (snapshot.exists) {
            for (var child in snapshot.children) {
              if (child.key!.contains(uid)) child.ref.remove();
            }
          }
        });
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم حظر $name بنجاح")));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return DefaultTabController(
      length: 2, // تبويبين: المتصلون وكل المستخدمين
      child: Scaffold(
        backgroundColor: const Color(0xFF03030F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F2C34),
          title: const Text("USERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.groups, color: Colors.cyanAccent),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const ChatScreen()),
              ),
            ),
          ],
          // شريط التبديل العلوي السفلي داخل الـ App Bar
          bottom: const TabBar(
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.bolt), text: "المتصلون الآن"),
              Tab(icon: Icon(Icons.people), text: "كل المستخدمين"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
            }

            // تحديد ما إذا كان المستخدم الحالي Admin
            bool isAdmin = false;
            for (var doc in snapshot.data!.docs) {
              if (doc.id == currentUid) {
                final data = doc.data() as Map<String, dynamic>;
                if (data.containsKey('role') && data['role'].toString().toLowerCase() == 'admin') {
                  isAdmin = true;
                }
                break;
              }
            }

            // القائمة الكاملة لكل المستخدمين
            final allUsers = snapshot.data!.docs;

            // تصفية القائمة لعرض المتصلين فقط (يملك حقل isOnline وقيمته true)
            final onlineUsers = allUsers.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data.containsKey('isOnline') && data['isOnline'] == true;
            }).toList();

            return TabBarView(
              children: [
                // 🟢 لستة المتصلين فقط
                onlineUsers.isEmpty
                    ? const Center(child: Text("لا يوجد مستخدمين متصلين حالياً", style: TextStyle(color: Colors.white54)))
                    : _buildUsersList(onlineUsers, currentUid, isAdmin, context),

                // 👥 لستة كل المستخدمين المسجلين
                allUsers.isEmpty
                    ? const Center(child: Text("لا يوجد مستخدمين مسجلين", style: TextStyle(color: Colors.white54)))
                    : _buildUsersList(allUsers, currentUid, isAdmin, context),
              ],
            );
          },
        ),
      ),
    );
  }

  // دالة بناء القائمة البرمجية لمنع تكرار الكود
  Widget _buildUsersList(List<QueryDocumentSnapshot> usersList, String currentUid, bool isAdmin, BuildContext context) {
    return ListView.builder(
      itemCount: usersList.length,
      itemBuilder: (context, index) {
        var user = usersList[index];
        var data = user.data() as Map<String, dynamic>;
        String name = data['name'] ?? "مستخدم";
        bool isMe = user.id == currentUid;
        bool userOnline = data['isOnline'] ?? false;

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF202C33),
                child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.cyanAccent)),
              ),
              // نقطة خضراء صغيرة تظهر فوق الرمز التعبيري إذا كان المستخدم أونلاين
              if (userOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF03030F), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(isMe ? "$name (أنت)" : name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(data['role'] ?? "طالب", style: const TextStyle(color: Colors.white54)),
          trailing: (isAdmin && !isMe)
              ? IconButton(
            icon: const Icon(Icons.block, color: Colors.redAccent),
            onPressed: () => _banUser(context, user.id, name),
          )
              : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => ChatScreen(receiverId: user.id, receiverName: name)),
          ),
        );
      },
    );
  }
}
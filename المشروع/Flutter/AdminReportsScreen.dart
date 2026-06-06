import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03030F),
      appBar: AppBar(
        title: const Text('ريبورتات المستخدمين', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F0F25),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب البيانات من كوليكشن reports وترتيبها من الأحدث للأقدم تلقائياً
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد بلاغات أو ريبورتات حالياً', style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              var reportData = reports[index].data() as Map<String, dynamic>;
              String reportDocId = reports[index].id;

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  iconColor: Colors.cyanAccent,
                  collapsedIconColor: Colors.white54,
                  leading: const Icon(Icons.assignment_late_outlined, color: Colors.redAccent),
                  // 🎯 إظهار اسم المرسل بوضوح في العنوان
                  title: Text(
                    reportData['senderName'] ?? 'مستخدم غير معروف',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  // 🎯 إظهار الـ ID ذو الـ 8 أرقام الخاص بالمرسل في العنوان الفرعي
                  subtitle: Text(
                    "كود المستخدم: ${reportData['senderId8Digit'] ?? '--------'}",
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // البريد الإلكتروني للمرسل
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, color: Colors.white38, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "البريد: ${reportData['senderEmail'] ?? '---'}",
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),

                          // نص الريبورت والشكوى
                          const Text(
                            "محتوى الشكوى / الريبورت:",
                            style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            reportData['reportContent'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // زر لمسح أو حذف الريبورت بعد قراءته وحل المشكلة
                              TextButton.icon(
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('reports').doc(reportDocId).delete();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("تم حذف الريبورت")),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                label: const Text("حذف الريبورت", style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
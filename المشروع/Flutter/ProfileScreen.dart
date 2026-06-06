import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // مكتبة إرسال طلبات الـ API
import 'main.dart'; // للوصول للـ Extension بتاع الترجمة
import 'AdminReportsScreen.dart';

// 📥 نقوم بعمل import لصفحة الأدمن لرؤية الريبورتات (سنقوم بإنشائها بالأسفل)
// import 'AdminReportsScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _reportController = TextEditingController(); // 🎯 متحكم نص الريبورت الخاص باليوزر

  File? _imageFile;
  String? _profileImageUrl;
  String _eightDigitId = '--------'; // 🎯 المتغير الخاص بالـ ID المكون من 8 أرقام
  String _role = '--------'; // 🎯 المتغير الجديد الخاص بالرول
  bool _isLoading = false;
  bool _isSaving = false;

  // 🔥 مفتاح الـ API الخاص بك من موقع ImgBB
  final String _imgBbApiKey = '8c7299bb1d2a54975921077cd52c2e81';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  // 📥 جلب بيانات المستخدم الحالية من الفايرستور
  Future<void> _loadUserData() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        var data = userDoc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        setState(() {
          _profileImageUrl = data['profileImage'] ?? '';
          // 🎯 قراءة حقل الـ userId المكون من 8 أرقام والثابت
          _eightDigitId = data['userId'] ?? '--------';
          // 🎯 قراءة حقل الـ role من الفايرستور
          _role = data['role'] ?? 'User';
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📸 اختيار صورة من المعرض (Gallery)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // 🌐 دالة الرفع إلى ImgBB والحصول على الرابط المباشر
  Future<String?> _uploadToImgBb(File image) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgbb.com/1/upload?key=$_imgBbApiKey'),
      );

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);
        // أخذ الرابط المباشر للصورة المرفوعة
        return jsonResponse['data']['url'];
      } else {
        debugPrint("ImgBB Upload Failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error uploading to ImgBB: $e");
      return null;
    }
  }

  // 💾 حفظ التعديلات في الفايربيز وتحديث التطبيق تلقائياً
  Future<void> _saveProfileChanges() async {
    if (_currentUser == null) return;
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      String updatedImageUrl = _profileImageUrl ?? '';

      // 1. لو المستخدم اختار صورة جديدة، يتم رفعها لـ ImgBB
      if (_imageFile != null) {
        String? imgBbUrl = await _uploadToImgBb(_imageFile!);
        if (imgBbUrl != null) {
          updatedImageUrl = imgBbUrl;
        } else {
          throw Exception("Failed to upload image to ImgBB");
        }
      }

      // 2. تحديث البيانات في الـ Firestore (الـ StreamBuilder في الـ main هيلقطه فوراً)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'name': _nameController.text.trim(),
        'profileImage': updatedImageUrl,
      });

      // 3. تحديث الـ State المحلي بعد الحفظ بنجاح
      setState(() {
        _profileImageUrl = updatedImageUrl;
        _imageFile = null; // تفريغ الملف المحلي لاعتماد رابط النت الجديد
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('update_success')), backgroundColor: Colors.cyanAccent),
        );
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("حدث خطأ أثناء حفظ البيانات"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🚨 دالة إرسال الريبورت من اليوزر إلى الفايرستور
  Future<void> _sendReportToAdmin() async {
    if (_reportController.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'senderUid': _currentUser?.uid,
        'senderId8Digit': _eightDigitId,
        'senderName': _nameController.text.trim(),
        'senderEmail': _currentUser?.email ?? '---',
        'reportContent': _reportController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _reportController.clear(); // مسح النص بعد الإرسال

      if (mounted) {
        Navigator.pop(context); // إغلاق النافذة المنبثقة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إرسال بلاغك بنجاح للأدمن"), backgroundColor: Colors.greenAccent),
        );
      }
    } catch (e) {
      debugPrint("Error sending report: $e");
    }
  }

  // 💬 نافذة منبثقة تظهر لليوزر لكتابة الريبورت
  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("إرسال بلاغ للأدمن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _reportController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "اكتب تفاصيل المشكلة أو البلاغ هنا...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: _sendReportToAdmin,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("إرسال", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03030F),
      appBar: AppBar(
        title: Text(context.tr('profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🎯 قسم الصورة الشخصية
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white10,
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? NetworkImage(_profileImageUrl!)
                        : const NetworkImage('https://placeholder.co/150')) as ImageProvider,
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.cyanAccent,
                    child: Icon(Icons.camera_alt, size: 18, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 🔐 حقل كود الـ ID المكون من 8 أرقام (ثابت وللقراءة فقط)
            _buildProfileField(
              label: context.tr('user_id'),
              value: _eightDigitId,
              icon: Icons.fingerprint,
              isReadOnly: true,
            ),
            const SizedBox(height: 16),

            // 📧 حقل البريد الإلكتروني (للقراءة فقط)
            _buildProfileField(
              label: context.tr('email'),
              value: _currentUser?.email ?? '---',
              icon: Icons.email_outlined,
              isReadOnly: true,
            ),
            const SizedBox(height: 16),

            // 🛡️ حقل الرول (للقراءة فقط)
            _buildProfileField(
              label: context.tr('role'),
              value: _role,
              icon: Icons.admin_panel_settings_outlined,
              isReadOnly: true,
            ),
            const SizedBox(height: 16),

            // ✏️ حقل الاسم (قابل للتعديل)
            Card(
              color: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    labelText: context.tr('name'),
                    labelStyle: const TextStyle(color: Colors.white54),
                    icon: const Icon(Icons.person_outline, color: Colors.cyanAccent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 35),

            // 🔘 زر حفظ التعديلات
            _isSaving
                ? const CircularProgressIndicator(color: Colors.cyanAccent)
                : ElevatedButton.icon(
              onPressed: _saveProfileChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save),
              label: Text(
                context.tr('save_changes'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // 🎯 هنا فحص الرول لعرض الأزرار بناء على هوية الشخص 🎯
            if (_role == 'Admin') ...[
              // 👑 زر للأدمن يدخله على صفحة البلاغات الكاملة
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminReportsScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.view_list_rounded),
                label: const Text("عرض كل ريبورتات المستخدمين", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              // 👤 زر للمستخدم العادي يفتح نافذة إرسال ريبورت
              OutlinedButton.icon(
                onPressed: _showReportDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text("إرسال ريبورت للأدمن", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required IconData icon,
    required bool isReadOnly,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: isReadOnly ? Colors.white38 : Colors.cyanAccent),
        title: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        subtitle: SelectableText(
          value,
          style: TextStyle(
            color: isReadOnly ? Colors.white70 : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
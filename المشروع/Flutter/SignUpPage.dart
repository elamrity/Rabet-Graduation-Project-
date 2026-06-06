import 'package:flutter/material.dart';
import 'AuthService.dart';
import 'SignInPage.dart'; // تأكد من استيراد صفحة تسجيل الدخول

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'User';
  bool _isLoading = false;

  void _showMsg(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03030F),
      appBar: AppBar(title: const Text("إنشاء حساب جديد")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "الاسم الكامل",
                      labelStyle: TextStyle(color: Colors.white70)
                  )
              ),
              const SizedBox(height: 15),
              TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "البريد الإلكتروني",
                      labelStyle: TextStyle(color: Colors.white70)
                  )
              ),
              const SizedBox(height: 15),
              TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "كلمة المرور",
                      labelStyle: TextStyle(color: Colors.white70)
                  ),
                  obscureText: true
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedRole,
                dropdownColor: const Color(0xFF1E1E2E),
                decoration: const InputDecoration(labelText: "نوع الحساب", labelStyle: TextStyle(color: Colors.white70)),
                items: ['User', 'Admin'].map((role) => DropdownMenuItem(value: role, child: Text(role, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),

              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.cyanAccent)
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50)
                ),
                child: const Text("إنشاء الحساب", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
                    _showMsg("يرجى ملء جميع الخانات", Colors.orange);
                    return;
                  }

                  setState(() => _isLoading = true);

                  // استدعاء دالة الـ signUp المحدثة
                  String? result = await AuthService().signUp(
                    email: _emailController.text.trim(),
                    password: _passwordController.text.trim(),
                    name: _nameController.text.trim(),
                    role: _selectedRole,
                  );

                  if (mounted) setState(() => _isLoading = false);

                  if (result == "success") {
                    _showMsg("تم إنشاء الحساب بنجاح! يرجى تسجيل الدخول.", Colors.green);

                    // ✅ التعديل هنا: التوجيه الصحيح لصفحة تسجيل الدخول
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const SignInPage()),
                    );
                  } else {
                    _showMsg(result ?? "حدث خطأ غير متوقع", Colors.red);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
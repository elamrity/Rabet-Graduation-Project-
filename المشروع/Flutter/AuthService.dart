import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. دالة إنشاء حساب جديد (مع توليد ID وتسجيل خروج إجباري)
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // إنشاء الحساب في Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      await result.user!.updateDisplayName(name);

      // توليد رقم عشوائي ثابت من 8 أرقام
      String randomEightDigitId = (10000000 + Random().nextInt(90000000)).toString();

      // حفظ البيانات في Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'userId': randomEightDigitId, // 👈 الرقم الذي سيظهر في البروفايل
        'name': name,
        'email': email,
        'role': role,
        'profileImage': '',
        'status': 'offline',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔥 الحل السحري: تسجيل خروج إجباري فوراً
      // هذا يضمن أن المستخدم لن يدخل التطبيق تلقائياً
      // وسيعود لصفحة اللوجن (SignInPage) عبر الـ AuthWrapper في main.dart
      await _auth.signOut();

      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // 2. دالة تسجيل الدخول
  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .get();

      if (doc.exists) {
        // تحديث الحالة لـ online
        await _firestore.collection('users').doc(result.user!.uid).update({'status': 'online'});
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 3. دالة تسجيل الخروج
  Future<void> signOut() async {
    try {
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'status': 'offline',
        });
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
    await _auth.signOut();
  }
}
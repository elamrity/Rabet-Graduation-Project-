import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'SignInPage.dart';
import 'IndoorPositioningScreen.dart';
import 'RadarScreen.dart';
import 'UsersListScreen.dart';
import 'BleDevicesScreen.dart';
import 'ProfileScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const OpticVerseWrapper());
}

// 🌐 القاموس الموحد للترجمة
class AppLocalizations {
  final String languageCode;
  AppLocalizations(this.languageCode);

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'title_admin': 'Indoor Positioning System - Admin',
      'title_user': 'Indoor Positioning System - User',
      'ips': 'IPS', 'radar': 'Radar', 'ble': 'BLE', 'chat': 'Chat', 'profile': 'Profile',
      'loading': 'Loading...', 'logout': 'Logout',
    },
    'ar': {
      'title_admin': 'نظام تحديد المواقع الداخلي - المشرف',
      'title_user': 'نظام تحديد المواقع الداخلي - المستخدم',
      'ips': 'الموقع الداخلي', 'radar': 'الرادار', 'ble': 'البلوتوث', 'chat': 'المحادثة', 'profile': 'الملف الشخصي',
      'loading': 'جاري التحميل...', 'logout': 'خروج',
    },
  };
  String translate(String key) => _localizedValues[languageCode]?[key] ?? key;
}

// 🌐 Provider لتغيير اللغة بدون إعادة بناء التطبيق بالكامل
class LanguageProvider extends InheritedWidget {
  final String locale;
  final Function(String) changeLanguage;

  const LanguageProvider({
    super.key,
    required this.locale,
    required this.changeLanguage,
    required super.child,
  });

  static LanguageProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LanguageProvider>()!;
  }

  @override
  bool updateShouldNotify(LanguageProvider oldWidget) => locale != oldWidget.locale;
}

extension LocalizationExtension on BuildContext {
  String tr(String key) {
    final lang = LanguageProvider.of(this).locale;
    return AppLocalizations(lang).translate(key);
  }
}

class OpticVerseWrapper extends StatefulWidget {
  const OpticVerseWrapper({super.key});
  @override
  State<OpticVerseWrapper> createState() => _OpticVerseWrapperState();
}

class _OpticVerseWrapperState extends State<OpticVerseWrapper> {
  String _locale = 'ar';
  void _changeLanguage(String code) => setState(() => _locale = code);

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      locale: _locale,
      changeLanguage: _changeLanguage,
      child: Builder(builder: (context) {
        final lang = LanguageProvider.of(context).locale;
        return Directionality(
          textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF03030F),
              // 🎨 تحسين ارتفاع وحجم الخطوط لمنع التداخل والتخريب البصري
              textTheme: lang == 'en'
                  ? GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme).copyWith(
                titleLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                bodyMedium: const TextStyle(fontSize: 14, height: 1.2),
              )
                  : GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).copyWith(
                titleLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
                bodyMedium: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            home: const AuthWrapper(),
          ),
        );
      }),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
        }

        if (authSnapshot.hasData) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(authSnapshot.data!.uid).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
              }
              var data = userSnapshot.data!.data() as Map<String, dynamic>;
              return MainNavigationScreen(role: data['role'] ?? 'User');
            },
          );
        }
        return const SignInPage();
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final String role;
  const MainNavigationScreen({super.key, required this.role});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateOnlineStatus(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'isOnline': isOnline});
      } catch (e) {
        debugPrint("Error updating status: $e");
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else {
      _updateOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.role == 'Admin';
    List<Widget> screens = isAdmin
        ? [const IndoorPositioningScreen(), const RadarScreen(), const BleDevicesScreen(), const UsersListScreen(), const ProfileScreen()]
        : [const UsersListScreen(), const ProfileScreen()];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1F2C34),
        // 🎯 ضبط حجم نص العنوان لمنع التفافه لسطرين في الشاشات الصغيرة
        title: Text(
          context.tr(isAdmin ? 'title_admin' : 'title_user'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontSize: LanguageProvider.of(context).locale == 'ar' ? 15 : 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // زر تغيير اللغة منسق ومحاذى هندسياً
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: TextButton(
              onPressed: () {
                final provider = LanguageProvider.of(context);
                provider.changeLanguage(provider.locale == 'ar' ? 'en' : 'ar');
              },
              child: Text(
                LanguageProvider.of(context).locale == 'ar' ? "EN" : "AR",
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
            onPressed: () async {
              _updateOnlineStatus(false);
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        // 🎯 ضبط أحجام نصوص الأيقونات السفلية لمنع التشوه
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: isAdmin
            ? [
          BottomNavigationBarItem(icon: const Icon(Icons.location_on, size: 22), label: context.tr('ips')),
          BottomNavigationBarItem(icon: const Icon(Icons.radar, size: 22), label: context.tr('radar')),
          BottomNavigationBarItem(icon: const Icon(Icons.bluetooth, size: 22), label: context.tr('ble')),
          BottomNavigationBarItem(icon: const Icon(Icons.chat, size: 22), label: context.tr('chat')),
          BottomNavigationBarItem(icon: const Icon(Icons.person, size: 22), label: context.tr('profile')),
        ]
            : [
          BottomNavigationBarItem(icon: const Icon(Icons.chat, size: 22), label: context.tr('chat')),
          BottomNavigationBarItem(icon: const Icon(Icons.person, size: 22), label: context.tr('profile')),
        ],
      ),
    );
  }
}
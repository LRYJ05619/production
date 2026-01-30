import 'package:flutter/material.dart';
import 'package:production_app/pages/login_page.dart';
import 'package:production_app/pages/main_page.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 添加超时处理，避免卡住
  try {
    await StorageService.init().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('StorageService初始化失败: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '生产管理平台',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          centerTitle: true,
        ),
      ),
      home: const SplashPage(),
    );
  }
}

/// 启动页，检查登录状态
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // 使用addPostFrameCallback确保在build完成后执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    try {
      // 短暂延迟显示启动页
      await Future.delayed(const Duration(milliseconds: 300));

      // 检查StorageService是否已初始化
      if (!StorageService.isInitialized) {
        try {
          await StorageService.init().timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('StorageService重新初始化失败: $e');
        }
      }

      if (!mounted) return;

      // 检查Token有效性
      bool tokenValid = false;
      try {
        tokenValid = StorageService.isTokenValid();
      } catch (e) {
        debugPrint('检查Token失败: $e');
      }

      if (tokenValid) {
        final token = StorageService.getToken();
        final userInfo = StorageService.getUserInfo();

        if (token != null && userInfo != null) {
          ApiService.setToken(token);
          ApiService.setCurrentUser(userInfo);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainPage(userInfo: userInfo)),
            );
          }
          return;
        }
      }

      // Token无效或不存在，跳转登录页
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('检查登录状态异常: $e');
      // 发生任何异常都跳转到登录页
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.factory, size: 80, color: Colors.orange),
            SizedBox(height: 24),
            Text('生产管理平台', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}




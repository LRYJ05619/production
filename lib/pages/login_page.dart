import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'main_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberPassword = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  List<Map<String, String>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() {
    _savedAccounts = StorageService.getSavedAccounts();
    final savedUsername = StorageService.getSavedUsername();
    final savedPassword = StorageService.getSavedPassword();

    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
    }
    if (savedPassword != null && savedPassword.isNotEmpty) {
      _passwordController.text = savedPassword;
      _rememberPassword = true;
    }
  }

  void _switchAccount(Map<String, String> account) {
    setState(() {
      _usernameController.text = account['username'] ?? '';
      _passwordController.text = account['password'] ?? '';
      _errorMessage = null;
    });
  }

  void _showAccountSwitcher() {
    if (_savedAccounts.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('切换账号', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 账号较多时列表内部滚动，避免撑破弹窗高度
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _savedAccounts.length,
                  itemBuilder: (context, index) {
                    final account = _savedAccounts[index];
                    final username = account['username'] ?? '';
                    final isCurrent = username == _usernameController.text;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent ? Colors.orange.shade100 : Colors.grey.shade100,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: isCurrent ? Colors.orange : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(username),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            const Icon(Icons.check_circle, color: Colors.orange, size: 18),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            onPressed: () async {
                              await StorageService.removeAccount(username);
                              setSheetState(() {
                                _savedAccounts = StorageService.getSavedAccounts();
                              });
                              setState(() {
                                _savedAccounts = StorageService.getSavedAccounts();
                              });
                              if (_savedAccounts.isEmpty && ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _usernameController.text = account['username'] ?? '';
                        _passwordController.text = account['password'] ?? '';
                        _login();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入用户名');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = '请输入密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final loginResp = await ApiService().login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (loginResp != null) {
      // 保存登录信息
      if (_rememberPassword) {
        await StorageService.saveCredentials(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }
      await StorageService.saveToken(loginResp.token, loginResp.expiresAt);
      await StorageService.saveUserInfo(loginResp.user);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainPage(userInfo: loginResp.user),
          ),
        );
      }
    } else {
      setState(() => _errorMessage = '登录失败，请检查用户名和密码');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              const Center(
                child: Column(
                  children: [
                    Icon(Icons.factory, size: 60, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      '生产管理平台',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: '用户名',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  if (_savedAccounts.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _showAccountSwitcher,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Icon(Icons.people_alt_outlined, size: 22),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _rememberPassword,
                      onChanged: (value) => setState(() => _rememberPassword = value ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('记住密码'),
                ],
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700))),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('登 录', style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 40),

            ],
          ),
        ),
      ),
    );
  }
}
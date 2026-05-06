import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/test_credentials.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/community_social_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';
import '../community/social_inbox_unread.dart';

/// 全屏登录 / 注册（Segmented Tab）。
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  final TextEditingController _loginEmail = TextEditingController();
  final TextEditingController _loginPassword = TextEditingController();

  final TextEditingController _regEmail = TextEditingController();
  final TextEditingController _regPassword = TextEditingController();
  final TextEditingController _regPassword2 = TextEditingController();
  final TextEditingController _regDisplayName = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regPassword2.dispose();
    _regDisplayName.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final AppStrings s = AppStrings.of(context);
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = ref.read(appDataServiceProvider);
      if (kDebugMode &&
          _loginEmail.text == TestCredentials.account &&
          _loginPassword.text == TestCredentials.password) {
        ref.read(devMockLoginProvider.notifier).state = true;
        if (!mounted) {
          return;
        }
        context.pop();
        showAppTopSnackBarAfterPop(
          Text(s.tr('本地测试登录成功（数据仅存本机）', 'Local test login succeeded (data stays on device)')),
        );
        return;
      }
      await svc.signInWithPassword(
            email: _loginEmail.text,
            password: _loginPassword.text,
          );
      if (!mounted) {
        return;
      }
      ref.read(devMockLoginProvider.notifier).state = false;
      context.pop();
      unawaited(ref.read(communitySocialRepositoryProvider).ensureDemoSocialScenario());
      unawaited(refreshSocialInboxUnreadBadge(ref));
      showAppTopSnackBarAfterPop(Text(s.tr('登录成功', 'Login succeeded')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      showAppTopSnackBar(context, Text(s.tr('登录失败：$e', 'Login failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    final AppStrings s = AppStrings.of(context);
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = ref.read(appDataServiceProvider);
      if (kDebugMode &&
          _regEmail.text == TestCredentials.account &&
          _regPassword.text == TestCredentials.password) {
        ref.read(devMockLoginProvider.notifier).state = true;
        if (!mounted) {
          return;
        }
        context.pop();
        showAppTopSnackBarAfterPop(
          Text(s.tr('本地测试注册成功（数据仅存本机）', 'Local registration succeeded (data stays on device)')),
        );
        return;
      }
      final String? name = _regDisplayName.text.trim().isEmpty ? null : _regDisplayName.text.trim();
      final res = await svc.signUpWithPassword(
            email: _regEmail.text,
            password: _regPassword.text,
            displayName: name,
          );
      if (!mounted) {
        return;
      }
      ref.read(devMockLoginProvider.notifier).state = false;
      context.pop();
      unawaited(ref.read(communitySocialRepositoryProvider).ensureDemoSocialScenario());
      final bool sessionReady = res.session != null;
      if (sessionReady) {
        unawaited(refreshSocialInboxUnreadBadge(ref));
      }
      showAppTopSnackBarAfterPop(
        Text(
          sessionReady
              ? s.tr('注册成功', 'Register succeeded')
              : s.tr('注册成功，请到邮箱完成验证后再登录', 'Register succeeded. Please verify email before login'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showAppTopSnackBar(context, Text(s.tr('注册失败：$e', 'Register failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _fillTestCredentials() {
    final String a = TestCredentials.account;
    final String p = TestCredentials.password;
    _loginEmail.text = a;
    _loginPassword.text = p;
    _regEmail.text = a;
    _regPassword.text = p;
    _regPassword2.text = p;
    _regDisplayName.text = TestCredentials.displayName;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: HtmlDesignTokens.textMain, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.tr('账号', 'Account'),
          style: TextStyle(
            color: HtmlDesignTokens.textMain,
            fontWeight: FontWeight.w600,
            fontFamily: 'system-ui',
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: HtmlDesignTokens.accent,
          labelColor: HtmlDesignTokens.textMain,
          unselectedLabelColor: HtmlDesignTokens.textSub,
          tabs: <Widget>[
            Tab(text: s.tr('登录', 'Login')),
            Tab(text: s.tr('注册', 'Register')),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _LoginForm(
                  formKey: _loginFormKey,
                  emailController: _loginEmail,
                  passwordController: _loginPassword,
                  busy: _busy,
                  onSubmit: _submitLogin,
                ),
                _RegisterForm(
                  formKey: _registerFormKey,
                  emailController: _regEmail,
                  passwordController: _regPassword,
                  password2Controller: _regPassword2,
                  displayNameController: _regDisplayName,
                  busy: _busy,
                  onSubmit: _submitRegister,
                ),
              ],
            ),
          ),
          if (TestCredentials.showDevHelpers)
            Material(
              color: Colors.black.withValues(alpha: 0.4),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          s.tr(
                            '测试：账号 ${TestCredentials.account}　密码 ${TestCredentials.password}',
                            'Test: account ${TestCredentials.account}  password ${TestCredentials.password}',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _fillTestCredentials,
                        child: Text(
                          s.tr('一键填入', 'Autofill'),
                          style: TextStyle(fontFamily: 'system-ui'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _LabeledField(
              label: AppStrings.of(context).tr('账号', 'Account'),
              child: TextFormField(
                controller: emailController,
                keyboardType: TextInputType.text,
                autocorrect: false,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                decoration: _inputDecoration(hint: AppStrings.of(context).tr('6～12 位字母或数字', '6-12 letters or numbers')),
                validator: (String? v) => _validateAccount(context, v),
              ),
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: AppStrings.of(context).tr('密码', 'Password'),
              child: TextFormField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                decoration: _inputDecoration(hint: AppStrings.of(context).tr('6～12 位字母或数字', '6-12 letters or numbers')),
                validator: (String? v) => _validatePassword(context, v),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: HtmlDesignTokens.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        AppStrings.of(context).tr('登录', 'Login'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'system-ui'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.password2Controller,
    required this.displayNameController,
    required this.busy,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController password2Controller;
  final TextEditingController displayNameController;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _LabeledField(
              label: AppStrings.of(context).tr('昵称（可选）', 'Nickname (optional)'),
              child: TextFormField(
                controller: displayNameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                decoration: _inputDecoration(hint: AppStrings.of(context).tr('将在个人页展示', 'Shown on profile page')),
              ),
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: AppStrings.of(context).tr('账号', 'Account'),
              child: TextFormField(
                controller: emailController,
                keyboardType: TextInputType.text,
                autocorrect: false,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                decoration: _inputDecoration(hint: AppStrings.of(context).tr('6～12 位字母或数字', '6-12 letters or numbers')),
                validator: (String? v) => _validateAccount(context, v),
              ),
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: AppStrings.of(context).tr('密码', 'Password'),
              child: TextFormField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                decoration: _inputDecoration(hint: AppStrings.of(context).tr('6～12 位字母或数字', '6-12 letters or numbers')),
                validator: (String? v) => _validatePassword(context, v),
              ),
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: AppStrings.of(context).tr('确认密码', 'Confirm Password'),
              child: TextFormField(
                controller: password2Controller,
                obscureText: true,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                decoration: _inputDecoration(hint: AppStrings.of(context).tr('再次输入', 'Enter again')),
                validator: (String? v) {
                  if (v == null || v.isEmpty) {
                    return AppStrings.of(context).tr('请确认密码', 'Please confirm password');
                  }
                  if (v != passwordController.text) {
                    return AppStrings.of(context).tr('两次密码不一致', 'Two passwords do not match');
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: HtmlDesignTokens.accentDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        AppStrings.of(context).tr('注册', 'Register'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'system-ui'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _inputDecoration({required String hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: HtmlDesignTokens.textSub.withValues(alpha: 0.7), fontFamily: 'system-ui'),
    filled: true,
    fillColor: HtmlDesignTokens.glassCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
      borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
      borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
      borderSide: const BorderSide(color: HtmlDesignTokens.primaryLight, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

/// 账号与密码：仅英文字母与数字，长度 6～12。
final RegExp _kAlphanumeric6to12 = RegExp(r'^[a-zA-Z0-9]{6,12}$');

String? _validateAccount(BuildContext context, String? v) {
  final AppStrings s = AppStrings.of(context);
  if (v == null || v.isEmpty) {
    return s.tr('请输入账号', 'Please enter account');
  }
  if (!_kAlphanumeric6to12.hasMatch(v)) {
    return s.tr('账号须为 6～12 位英文字母或数字', 'Account must be 6-12 letters or numbers');
  }
  return null;
}

String? _validatePassword(BuildContext context, String? v) {
  final AppStrings s = AppStrings.of(context);
  if (v == null || v.isEmpty) {
    return s.tr('请输入密码', 'Please enter password');
  }
  if (!_kAlphanumeric6to12.hasMatch(v)) {
    return s.tr('密码须为 6～12 位英文字母或数字', 'Password must be 6-12 letters or numbers');
  }
  return null;
}

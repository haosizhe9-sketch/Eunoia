import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/display_name_utils.dart';
import '../../core/auth/test_credentials.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';

const int _kMaxDisplayNameLen = 32;
const int _kMaxBioLen = 200;

/// 底部弹层：修改昵称与个性签名（写入 [AppDataService] 本地存档）。
Future<void> showProfileEditSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const _ProfileEditSheetBody(),
      );
    },
  );
}

class _ProfileEditSheetBody extends ConsumerStatefulWidget {
  const _ProfileEditSheetBody();

  @override
  ConsumerState<_ProfileEditSheetBody> createState() => _ProfileEditSheetBodyState();
}

class _ProfileEditSheetBodyState extends ConsumerState<_ProfileEditSheetBody> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitial);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final bool mock = ref.read(devMockLoginProvider);
      if (mock) {
        final DevMockProfile? local = ref.read(devMockProfileProvider);
        _nameCtrl.text = (local?.displayName ?? TestCredentials.displayName).trim();
        _bioCtrl.text = local?.bio ?? '';
      } else {
        final svc = ref.read(appDataServiceProvider);
        final uid = svc.currentUser?.id;
        if (uid == null) {
          _loadError = '未登录';
        } else {
          final fields = await svc.fetchProfilePublicFields(uid);
          final user = svc.currentUser!;
          _nameCtrl.text = fields?.displayName?.isNotEmpty == true
              ? fields!.displayName!
              : syncDisplayNameOrRoastDuckUid(user);
          _bioCtrl.text = fields?.bio?.trim() ?? '';
        }
      }
    } catch (e) {
      _loadError = '$e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final String name = _nameCtrl.text.trim();
      final String bio = _bioCtrl.text.trim();
      if (ref.read(devMockLoginProvider)) {
        ref.read(devMockProfileProvider.notifier).state = DevMockProfile(displayName: name, bio: bio);
      } else {
        await ref.read(appDataServiceProvider).updateProfileDisplayNameAndBio(
              displayName: name,
              bio: bio,
            );
      }
      ref.read(profileRevisionProvider.notifier).state++;
      if (mounted) {
        Navigator.of(context).pop();
        showAppTopSnackBar(context, const Text('资料已保存'));
      }
    } catch (e) {
      if (mounted) {
        showAppTopSnackBar(context, Text('保存失败：$e'));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: HtmlDesignTokens.textSub.withValues(alpha: 0.75), fontFamily: 'system-ui'),
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HtmlDesignTokens.gachaSubBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _loading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: HtmlDesignTokens.textSub.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '编辑资料',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: HtmlDesignTokens.textMain,
                          fontFamily: 'system-ui',
                        ),
                      ),
                      if (_loadError != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        '昵称',
                        style: TextStyle(fontSize: 13, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        maxLength: _kMaxDisplayNameLen,
                        style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                        decoration: _decoration('1～32 个字符'),
                        validator: (String? v) {
                          final String t = v?.trim() ?? '';
                          if (t.isEmpty) {
                            return '请输入昵称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '个性签名',
                        style: TextStyle(fontSize: 13, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bioCtrl,
                        maxLines: 3,
                        maxLength: _kMaxBioLen,
                        style: const TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
                        decoration: _decoration('一句话介绍自己（可选）'),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HtmlDesignTokens.textSub,
                                side: BorderSide(color: HtmlDesignTokens.glassBorder),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                                ),
                              ),
                              child: const Text('取消', style: TextStyle(fontFamily: 'system-ui')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving || _loadError != null ? null : _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: HtmlDesignTokens.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('保存', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'system-ui')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

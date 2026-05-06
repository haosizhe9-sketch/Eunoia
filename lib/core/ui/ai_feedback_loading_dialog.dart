import 'package:flutter/material.dart';

import '../i18n/app_strings.dart';

/// 提交后等待 AI / 模型返回评价时展示；结束后须调用 [Navigator.of(context).pop] 关闭。
void showAiFeedbackGeneratingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (BuildContext ctx) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          color: const Color(0xFF2D1B69),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(color: Color(0xFFF59E0B)),
                const SizedBox(height: 16),
                Text(
                  AppStrings.of(ctx).practiceAiGeneratingFeedback,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

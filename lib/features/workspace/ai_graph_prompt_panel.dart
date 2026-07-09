import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AiGraphPromptPanel extends StatelessWidget {
  const AiGraphPromptPanel({
    required this.prompt,
    required this.triggerPrompt,
    super.key,
  });

  final String prompt;
  final String triggerPrompt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI 图例生成提示词',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => copyAiGraphPrompt(context, triggerPrompt),
                  icon: const Icon(Icons.content_copy),
                  label: const Text('复制提示词'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '触发语',
              style: textTheme.labelLarge?.copyWith(
                color: const Color(0xFF1D4ED8),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: SelectableText(
                  triggerPrompt,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1E3A8A),
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '完整协议已内置',
                      style: textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF526276),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '复制后会让 AI 按 AI_GRAPH_PACKAGE_GUIDE.md 生成 GraphIndex.json 图包；这里只显示触发语，避免长文本占满概览。',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF526276),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CopyAiGraphPromptButton extends StatelessWidget {
  const CopyAiGraphPromptButton({
    required this.prompt,
    this.label = '复制提示词',
    this.icon = Icons.content_copy,
    this.onCopy,
    super.key,
  });

  final String prompt;
  final String label;
  final IconData icon;
  final ValueChanged<String>? onCopy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () {
        final copy = onCopy;
        if (copy != null) {
          copy(prompt);
          return;
        }

        copyAiGraphPrompt(context, prompt);
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

Future<void> copyAiGraphPrompt(BuildContext context, String prompt) async {
  await Clipboard.setData(ClipboardData(text: prompt));
  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('已复制 AI 图例生成提示词'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

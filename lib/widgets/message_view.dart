import 'package:flutter/material.dart';

/// Centered empty or error state. Scrollable, so it works inside a
/// RefreshIndicator.
class MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      children: [
        Icon(icon, size: 72, color: Colors.white24),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 17),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

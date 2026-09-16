import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small pill showing where an appointment is in its lifecycle.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const StatusBadge(this.status, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status, Theme.of(context).brightness);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 13 : 15, color: style.color),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

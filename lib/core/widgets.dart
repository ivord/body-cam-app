import 'package:flutter/material.dart';

import 'theme.dart';

/// The rounded teal (or red, for destructive actions) pill CTA used across
/// Home/Settings/Edit/Talk for Add NVR, Save, Talk and End.
class TealButton extends StatelessWidget {
  const TealButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.danger = false,
    this.expand = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppColors.red : AppColors.teal;
    final fg = danger ? Colors.white : AppColors.tealOn;
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: .35),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Colored dot + small mono label, e.g. Online/Offline/Checking status.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: monoText(fontSize: 11, color: color)),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Botão personalizado reutilizável, com suporte opcional para ícone à esquerda do texto.
class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Widget? icon;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.backgroundColor = const Color(0xFF1E8050), // cor primária verde da app (kPrimaryGreen)
    this.textColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    this.borderRadius = 20.0,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        padding: padding,
      ),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon!,
                SizedBox(width: 8),
                Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            )
          : Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

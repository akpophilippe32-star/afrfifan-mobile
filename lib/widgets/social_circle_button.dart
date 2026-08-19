import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SocialCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const SocialCircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.inputFill, width: 1.5),
        ),
        child: Icon(icon, color: AppColors.textDark),
      ),
    );
  }
}

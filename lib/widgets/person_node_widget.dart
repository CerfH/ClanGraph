import 'package:flutter/material.dart';
import '../models/person.dart';
import '../theme/app_theme.dart';

class PersonNodeWidget extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;
  final bool isSelected;

  const PersonNodeWidget({
    super.key,
    required this.person,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell( // 改用 InkWell，它在 InteractiveViewer 里的命中测试通常比 GestureDetector 更稳
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.minimalistBlue.withValues(alpha: 0.8) 
              : AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.electricBlue : AppTheme.minimalistBlue,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.electricBlue.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon or Avatar placeholder
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.deepSpaceGrey,
              child: Icon(
                person.gender == 'Male' ? Icons.face : Icons.face_3,
                color: AppTheme.electricBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              person.relationship,
              style: const TextStyle(
                color: AppTheme.electricBlue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              person.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'controllers/family_controller.dart';
import 'theme/app_theme.dart';
import 'views/family_tree_view.dart';

void main() {
  runApp(const ClanGraphApp());
}

class ClanGraphApp extends StatelessWidget {
  const ClanGraphApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    final familyController = FamilyController();

    return MaterialApp(
      title: 'ClanGraph',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: FamilyTreeView(controller: familyController),
    );
  }
}

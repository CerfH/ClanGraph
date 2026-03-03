import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'controllers/family_controller.dart';
import 'theme/app_theme.dart';
import 'views/family_tree_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Failed to load .env file: $e");
    // Continue running even if .env fails to load
  }
  runApp(const ClanGraphApp());
}

class ClanGraphApp extends StatefulWidget {
  const ClanGraphApp({super.key});

  @override
  State<ClanGraphApp> createState() => _ClanGraphAppState();
}

class _ClanGraphAppState extends State<ClanGraphApp> {
  late final FamilyController _familyController;

  @override
  void initState() {
    super.initState();
    // Initialize controller once
    _familyController = FamilyController();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClanGraph',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: FamilyTreeView(controller: _familyController),
    );
  }
}

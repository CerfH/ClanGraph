import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/family_controller.dart';
import '../models/export_config.dart';
import '../models/person.dart';
import '../services/dfs_extractor.dart';
import '../services/export_filter.dart';
import '../theme/app_theme.dart';

class ShareConfigPage extends StatefulWidget {
  final FamilyController controller;

  const ShareConfigPage({super.key, required this.controller});

  @override
  State<ShareConfigPage> createState() => _ShareConfigPageState();
}

class _ShareConfigPageState extends State<ShareConfigPage> {
  // 维度勾选状态
  bool _basicInfo = true;
  bool _relations = true;
  bool _giftHistory = false;
  bool _bio = false;

  // 搜索与中心人物
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Person? _centerPerson;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Person> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return widget.controller.allPeople
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.relationship.toLowerCase().contains(q),
        )
        .toList();
  }

  Set<ExportDimension> get _enabledDimensions {
    final dims = <ExportDimension>{};
    if (_basicInfo) dims.add(ExportDimension.basicInfo);
    if (_relations) dims.add(ExportDimension.relations);
    if (_giftHistory) dims.add(ExportDimension.giftHistory);
    if (_bio) dims.add(ExportDimension.bio);
    return dims;
  }

  Future<void> _doExport() async {
    if (_centerPerson == null) return;
    final peopleMap = {for (final p in widget.controller.allPeople) p.id: p};
    final ids = DfsExtractor.extract(
      people: peopleMap,
      centerId: _centerPerson!.id,
    );
    final subset = ids.map((id) => peopleMap[id]!);
    final config = ExportConfig(
      enabledDimensions: _enabledDimensions,
      centerId: _centerPerson!.id,
    );
    final json = ExportFilter.filter(people: subset, config: config);
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canExport = _centerPerson != null;

    return Scaffold(
      backgroundColor: AppTheme.surfaceGrey,
      appBar: AppBar(
        title: const Text('亲友分享'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 维度勾选
            const Text(
              '导出字段',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _DimCheckbox(
              label: '基本信息',
              value: _basicInfo,
              onChanged: (v) => setState(() => _basicInfo = v!),
            ),
            _DimCheckbox(
              label: '亲缘关系',
              value: _relations,
              onChanged: (v) => setState(() => _relations = v!),
            ),
            _DimCheckbox(
              label: '礼金记录',
              value: _giftHistory,
              onChanged: (v) => setState(() => _giftHistory = v!),
            ),
            _DimCheckbox(
              label: '备注',
              value: _bio,
              onChanged: (v) => setState(() => _bio = v!),
            ),
            const SizedBox(height: 20),
            // 中心人物搜索
            const Text(
              '选择中心人物',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索姓名或关系…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 18,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),

            // 搜索结果列表
            if (_searchQuery.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) {
                    final p = _searchResults[i];
                    return ListTile(
                      title: Text(
                        p.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        p.relationship,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        setState(() {
                          _centerPerson = p;
                          _searchCtrl.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            // 已选中心人物
            if (_centerPerson != null && _searchQuery.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.electricBlue.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _centerPerson!.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _centerPerson!.relationship,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _centerPerson = null),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white38,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            // 导出按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canExport ? _doExport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricBlue,
                  disabledBackgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '开始导出',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DimCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _DimCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.electricBlue,
      checkColor: Colors.white,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

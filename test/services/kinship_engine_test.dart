import 'dart:convert';

import 'package:clangraph/controllers/family_controller.dart';
import 'package:clangraph/services/ai_service.dart';
import 'package:clangraph/services/kinship_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试用 Mock AIService：返回固定称呼。
class _MockAIService extends AIService {
  final Future<String> Function(String question, String contextData) onAsk;

  _MockAIService({required this.onAsk});

  @override
  Future<String> askAgent(
    String question,
    String contextData, {
    List<Map<String, dynamic>> history = const [],
  }) async {
    return onAsk(question, contextData);
  }
}

/// 构建测试用家族数据
Future<(FamilyController, KinshipEngine)> _setupEngine(
  List<Map<String, dynamic>> members, {
  AIService? aiService,
}) async {
  SharedPreferences.setMockInitialValues({});
  final controller = FamilyController();
  await controller.importFromJSON(json.encode({'members': members}));
  final engine = KinshipEngine(controller, aiService: aiService);
  return (controller, engine);
}

Map<String, dynamic> _p({
  required String id,
  required String name,
  String rel = '',
  String gender = '男',
  List<String> parents = const [],
  List<String> children = const [],
  String? spouseId,
}) {
  return {
    'id': id,
    'name': name,
    'relationship': rel,
    'gender': gender,
    'bio': '',
    'parents': parents,
    'children': children,
    if (spouseId != null) 'spouseId': spouseId,
    'giftHistory': <Map<String, dynamic>>[],
  };
}

void main() {
  // ──────────────────────────────────────────────
  // 1 步硬编码规则（同步，零延迟）
  // ──────────────────────────────────────────────
  group('1 步规则（同步）', () {
    late KinshipEngine engine;

    setUp(() async {
      final (_, e) = await _setupEngine([
        _p(id: 'root', name: '我', rel: '本人', gender: '男',
           parents: ['father', 'mother'],
           children: ['son'],
           spouseId: 'wife'),
        _p(id: 'father', name: '黄伟', rel: '爸爸', gender: '男',
           children: ['root'], spouseId: 'mother'),
        _p(id: 'mother', name: '刘书秀', rel: '妈妈', gender: '女',
           children: ['root', 'sister'], spouseId: 'father'),
        _p(id: 'wife', name: '小红', rel: '老婆', gender: '女',
           spouseId: 'root'),
        _p(id: 'son', name: '小明', rel: '儿子', gender: '男',
           parents: ['root']),
        _p(id: 'sister', name: '小妹', rel: '妹妹', gender: '女',
           parents: ['mother']),
      ]);
      engine = e;
    });

    test('本人', () {
      expect(engine.computeSync('root', 'root'), '本人');
    });
    test('爸爸', () {
      expect(engine.computeSync('root', 'father'), '爸爸');
    });
    test('妈妈', () {
      expect(engine.computeSync('root', 'mother'), '妈妈');
    });
    test('儿子', () {
      expect(engine.computeSync('root', 'son'), '儿子');
    });
    test('老公', () {
      expect(engine.computeSync('wife', 'root'), '老公');
    });
    test('老婆', () {
      expect(engine.computeSync('root', 'wife'), '老婆');
    });
    test('妹妹（长幼判断）', () {
      // mother.children = ['root', 'sister'] → root 在前 = 哥哥
      expect(engine.computeSync('root', 'sister'), '妹妹');
    });
    test('哥哥（从妹妹视角）', () {
      expect(engine.computeSync('sister', 'root'), '哥哥');
    });
  });

  // ──────────────────────────────────────────────
  // 2 步及以上：同步返回 null → 走 AI
  // ──────────────────────────────────────────────
  group('2 步以上 → 触发 AI', () {
    late KinshipEngine engine;

    setUp(() async {
      final (_, e) = await _setupEngine([
        _p(id: 'root', name: '我', gender: '男',
           parents: ['father']),
        _p(id: 'father', name: '黄伟', gender: '男',
           parents: ['grandpa'], children: ['root']),
        _p(id: 'grandpa', name: '爷爷', gender: '男',
           children: ['father']),
      ]);
      engine = e;
    });

    test('爷爷：computeSync 返回 null（需要 AI）', () {
      expect(engine.computeSync('root', 'grandpa'), isNull);
    });

    test('爷爷：compute（无 AI）回退到手填值', () async {
      final result = await engine.compute('root', 'grandpa');
      // grandpa 的 relationship 为空，没有 AI → 返回空
      expect(result, '');
    });
  });

  // ──────────────────────────────────────────────
  // AI 兜底
  // ──────────────────────────────────────────────
  group('AI 兜底', () {
    late KinshipEngine engine;

    setUp(() async {
      final ai = _MockAIService(
        onAsk: (question, _) async {
          if (question.contains('爷爷')) return '爷爷';
          if (question.contains('奶奶')) return '奶奶';
          if (question.contains('外公')) return '外公';
          return '远亲';
        },
      );
      final (_, e) = await _setupEngine([
        _p(id: 'root', name: '我', gender: '男',
           parents: ['father', 'mother']),
        _p(id: 'father', name: '黄伟', gender: '男',
           parents: ['p_gf', 'p_gm'], children: ['root']),
        _p(id: 'mother', name: '刘书秀', gender: '女',
           parents: ['m_gf', 'm_gm'], children: ['root']),
        _p(id: 'p_gf', name: '黄爷爷', gender: '男',
           children: ['father']),
        _p(id: 'p_gm', name: '黄奶奶', gender: '女',
           children: ['father']),
        _p(id: 'm_gf', name: '刘外公', gender: '男',
           children: ['mother']),
        _p(id: 'm_gm', name: '刘外婆', gender: '女',
           children: ['mother']),
      ], aiService: ai);
      engine = e;
    });

    test('爷爷 → AI 返回"爷爷"', () async {
      expect(await engine.compute('root', 'p_gf'), '爷爷');
    });

    test('奶奶 → AI 返回"奶奶"', () async {
      expect(await engine.compute('root', 'p_gm'), '奶奶');
    });

    test('外公 → AI 返回"外公"', () async {
      expect(await engine.compute('root', 'm_gf'), '外公');
    });

    test('AI 结果写入缓存（第二次不调 AI）', () async {
      // 第一次：调 AI
      final r1 = await engine.compute('root', 'p_gf');
      expect(r1, '爷爷');

      // 第二次：走缓存（验证方式：如果调了 AI 会返回不同的值）
      // 清除对 mock 的"监听"不可行，这里只验证缓存命中
      final r2 = engine.computeSync('root', 'p_gf');
      // computeSync 检查缓存，应该返回之前 AI 写入的值
      expect(r2, '爷爷');
    });
  });

  // ──────────────────────────────────────────────
  // 切换中心人物
  // ──────────────────────────────────────────────
  group('切换中心人物', () {
    late FamilyController controller;

    setUp(() async {
      final (c, _) = await _setupEngine([
        _p(id: 'root', name: '我', gender: '男',
           parents: ['father'], rel: '本人'),
        _p(id: 'father', name: '黄伟', gender: '男',
           parents: ['grandpa'], children: ['root'], rel: '爸爸'),
        _p(id: 'grandpa', name: '爷爷', gender: '男',
           children: ['father'], rel: '爷爷'),
      ]);
      controller = c;
    });

    test('以我为中心 → 父亲是"爸爸"', () {
      controller.setMainPerson('root');
      expect(controller.getDisplayName('father'), '爸爸');
    });

    test('以父亲为中心 → 爷爷是"爸爸"', () {
      controller.setMainPerson('father');
      expect(controller.getDisplayName('grandpa'), '爸爸');
    });

    test('以父亲为中心 → 我是"儿子"', () {
      controller.setMainPerson('father');
      expect(controller.getDisplayName('root'), '儿子');
    });

    test('以我为中心 → 爷爷回退到手填值', () {
      controller.setMainPerson('root');
      // 2 步关系，sync 返回 null，fallback 到手填 "爷爷"
      expect(controller.getDisplayName('grandpa'), '爷爷');
    });
  });

  // ──────────────────────────────────────────────
  // 预热缓存
  // ──────────────────────────────────────────────
  group('预热缓存', () {
    test('warmUp 不会崩溃，所有目标都得到非空称呼', () async {
      final ai = _MockAIService(
        onAsk: (question, _) async => '远房亲戚',
      );
      final (_, engine) = await _setupEngine([
        _p(id: 'root', name: '我', gender: '男',
           parents: ['father']),
        _p(id: 'father', name: '黄伟', gender: '男',
           parents: ['grandpa'], children: ['root']),
        _p(id: 'grandpa', name: '爷爷', gender: '男',
           children: ['father', 'uncle']),
        _p(id: 'uncle', name: '叔叔', gender: '男',
           parents: ['grandpa']),
      ], aiService: ai);

      await engine.warmUp('root');

      // 1 步：sync 命中
      expect(engine.computeSync('root', 'father'), '爸爸');
      // 2 步：已被 AI 预热
      expect(engine.computeSync('root', 'grandpa'), isNotNull);
      expect(engine.computeSync('root', 'uncle'), isNotNull);
    });
  });
}

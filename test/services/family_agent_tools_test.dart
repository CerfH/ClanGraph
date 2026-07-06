import 'dart:convert';

import 'package:clangraph/controllers/family_controller.dart';
import 'package:clangraph/services/family_agent_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FamilyController controller;
  late FamilyAgentTools tools;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = FamilyController();
    await controller.importFromJSON(
      json.encode({
        'members': [
          {
            'id': 'root',
            'name': '我',
            'relationship': '本人',
            'gender': '男',
            'bio': '',
            'parents': ['father'],
            'children': <String>[],
            'giftHistory': <Map<String, dynamic>>[],
          },
          {
            'id': 'father',
            'name': '黄伟',
            'relationship': '爸爸',
            'gender': '男',
            'bio': '',
            'parents': <String>[],
            'children': ['root'],
            'spouse': 'mother',
            'giftHistory': [
              {
                'id': 'gift-1',
                'amount': 800,
                'event': '满月礼',
                'date': '2026-03-09T00:00:00.000',
              },
            ],
          },
          {
            'id': 'mother',
            'name': '刘书秀',
            'relationship': '妈妈',
            'gender': '女',
            'bio': '',
            'parents': <String>[],
            'children': ['root', 'sister'],
            'spouse': 'father',
            'giftHistory': <Map<String, dynamic>>[],
          },
          {
            'id': 'sister',
            'name': '黄雅萱',
            'relationship': '妹妹',
            'gender': '女',
            'bio': '',
            'parents': ['mother'],
            'children': <String>[],
            'giftHistory': <Map<String, dynamic>>[],
          },
        ],
      }),
    );
    tools = FamilyAgentTools(controller);
  });

  test('搜索工具可按称呼定位成员', () {
    final result = tools.execute('search_family_members', {'query': '爸爸'});
    expect(result['ok'], isTrue);
    expect(result['count'], 1);
    expect((result['members'] as List).first['id'], 'father');
  });

  test('礼金工具返回确定性统计', () {
    final result = tools.execute('get_gift_summary', {'member': '爸爸'});
    expect(result['ok'], isTrue);
    expect(result['count'], 1);
    expect(result['totalAmount'], 800.0);
  });

  test('人物详情按共同子女规则返回父亲的两个孩子', () {
    final result = tools.execute('get_member_details', {'member': '爸爸'});
    final children = result['children'] as List;
    expect(children.map((item) => item['id']), containsAll(['root', 'sister']));
    expect(children, hasLength(2));
  });

  test('家族分支工具递归返回后代', () {
    final result = tools.execute('get_family_branch', {'member': '爸爸'});
    expect(result['ok'], isTrue);
    expect(result['count'], 2);
  });

  test('切换中心工具会实际更新控制器状态', () {
    final result = tools.execute('set_graph_center', {'member': '爸爸'});
    expect(result['ok'], isTrue);
    expect(controller.mainPersonId, 'father');
  });
}

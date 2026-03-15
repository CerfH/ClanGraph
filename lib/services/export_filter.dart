import 'dart:convert';
import 'package:clangraph/models/export_config.dart';
import 'package:clangraph/models/person.dart';

/// 字段清洗与 JSON 序列化服务
///
/// 根据 [ExportConfig] 对 Person 集合执行字段清洗，
/// 输出与 exportToJSON 格式兼容的 JSON 字符串。
class ExportFilter {
  /// 对 [people] 中的每个 Person 按 [config.enabledDimensions] 清洗字段，
  /// 返回 `{"members": [...]}` 格式的 JSON 字符串。
  ///
  /// - `basicInfo` 未勾选：`name`、`relationship`、`gender` 置为 `""`
  /// - `giftHistory` 未勾选：`giftHistory` 置为 `[]`
  /// - `relations` 未勾选：`parents`、`children` 置为 `[]`，`spouseId` 置为 `null`
  /// - `bio` 未勾选：`bio` 置为 `""`
  /// - `id` 字段始终保留
  ///
  /// 输入空集合时返回 `{"members":[]}`.
  static String filter({
    required Iterable<Person> people,
    required ExportConfig config,
  }) {
    final dims = config.enabledDimensions;
    final members = people.map((p) {
      final map = p.toMap();

      if (!dims.contains(ExportDimension.basicInfo)) {
        map['name'] = '';
        map['relationship'] = '';
        map['gender'] = '';
      }

      if (!dims.contains(ExportDimension.giftHistory)) {
        map['giftHistory'] = <dynamic>[];
      }

      if (!dims.contains(ExportDimension.relations)) {
        map['parents'] = <dynamic>[];
        map['children'] = <dynamic>[];
        map['spouseId'] = null;
      }

      if (!dims.contains(ExportDimension.bio)) {
        map['bio'] = '';
      }

      return map;
    }).toList();

    return jsonEncode({'members': members});
  }
}

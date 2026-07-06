import '../controllers/family_controller.dart';
import '../models/person.dart';
import 'ai_service.dart';

/// 路径中的一步
enum _Dir { up, down, across }

class _Step {
  final Person person;
  final _Dir dir;
  final String token; // F/M/S/D/H/W/B/Z

  const _Step({required this.person, required this.dir, required this.token});
}

/// 智能称呼引擎
///
/// 1 步以内的关系用硬编码规则（零延迟）。
/// 2 步及以上交给 AI（智谱），结果会缓存避免重复调用。
class KinshipEngine {
  final FamilyController controller;
  final AIService? aiService;

  /// 缓存：key = "$centerId→$targetId"
  final Map<String, String> _cache = {};

  KinshipEngine(this.controller, {this.aiService});

  // ─── 公开接口 ───────────────────────────────────────────────

  /// 同步计算称呼（仅 1 步规则 + 缓存，无 AI）。
  /// 返回 null 表示需要走 AI。
  String? computeSync(String centerId, String targetId) {
    if (centerId == targetId) return '本人';

    final cacheKey = '$centerId→$targetId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final path = _findPath(centerId, targetId);
    if (path == null || path.length > 1) return null;

    // 只有 1 步路径才用硬编码规则
    final term = _oneStepTerm(path.first, centerId);
    if (term != null) _cache[cacheKey] = term;
    return term;
  }

  /// 异步计算称呼，1 步规则命中则同步返回，否则调用 AI。
  Future<String> compute(String centerId, String targetId) async {
    if (centerId == targetId) return '本人';

    final cacheKey = '$centerId→$targetId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // 1 步规则
    final path = _findPath(centerId, targetId);
    if (path != null && path.length == 1) {
      final term = _oneStepTerm(path.first, centerId);
      if (term != null) {
        _cache[cacheKey] = term;
        return term;
      }
    }

    // 2 步及以上 → AI
    final stored = controller.getPerson(targetId)?.relationship ?? '';
    if (aiService != null) {
      final aiTerm = await _aiFallback(centerId, targetId, path);
      if (aiTerm != null && aiTerm.isNotEmpty) {
        _cache[cacheKey] = aiTerm;
        return aiTerm;
      }
    }

    // 最终 fallback：手填值
    _cache[cacheKey] = stored;
    return stored;
  }

  /// 清除缓存（切换中心人物或数据变更时调用）。
  void invalidateCache() => _cache.clear();

  /// 预热缓存：后台异步计算所有未命中的称呼。
  Future<void> warmUp(String centerId) async {
    for (final person in controller.allPeople) {
      final key = '$centerId→${person.id}';
      if (_cache.containsKey(key)) continue;
      try {
        final term = await compute(centerId, person.id);
        if (term.isNotEmpty) _cache[key] = term;
      } catch (_) {
        // 单条失败不影响整体
      }
    }
  }

  // ─── 1 步硬编码规则 ────────────────────────────────────────

  String? _oneStepTerm(_Step step, String centerId) {
    return switch (step.dir) {
      _Dir.up => step.person.gender == '男' ? '爸爸' : '妈妈',
      _Dir.down => step.person.gender == '男' ? '儿子' : '女儿',
      _Dir.across => switch (step.token) {
          'H' => '老公',
          'W' => '老婆',
          'B' => _siblingTerm(centerId, step.person.id, 'B'),
          'Z' => _siblingTerm(centerId, step.person.id, 'Z'),
          _ => null,
        },
    };
  }

  String _siblingTerm(String centerId, String siblingId, String genderToken) {
    final older = _isOlder(siblingId, centerId);
    if (genderToken == 'B') {
      if (older == true) return '哥哥';
      if (older == false) return '弟弟';
      return '兄弟';
    }
    if (older == true) return '姐姐';
    if (older == false) return '妹妹';
    return '姐妹';
  }

  /// 判断 a 是否比 b 年长（基于共享父母的 children 顺序）
  bool? _isOlder(String aId, String bId) {
    final a = controller.getPerson(aId);
    if (a == null) return null;
    for (final pid in a.parents) {
      final parent = controller.getPerson(pid);
      if (parent == null) continue;
      if (!parent.children.contains(bId)) continue;
      final idxA = parent.children.indexOf(aId);
      final idxB = parent.children.indexOf(bId);
      if (idxA >= 0 && idxB >= 0) return idxA < idxB;
    }
    return null;
  }

  // ─── BFS 最短路径（用于 1 步判断 + AI prompt）─────────────

  List<_Step>? _findPath(String from, String to) {
    if (from == to) return [];

    final visited = <String>{from};
    final queue = <_QueueItem>[_QueueItem(from, [])];

    while (queue.isNotEmpty) {
      final item = queue.removeAt(0);
      for (final step in _neighbors(item.personId)) {
        if (!visited.add(step.person.id)) continue;
        final newPath = [...item.path, step];
        if (step.person.id == to) return newPath;
        queue.add(_QueueItem(step.person.id, newPath));
      }
    }
    return null;
  }

  List<_Step> _neighbors(String personId) {
    final person = controller.getPerson(personId);
    if (person == null) return [];
    final steps = <_Step>[];

    // 向上：父母
    for (final pid in person.parents) {
      final p = controller.getPerson(pid);
      if (p != null) {
        steps.add(_Step(
          person: p,
          dir: _Dir.up,
          token: p.gender == '男' ? 'F' : 'M',
        ));
      }
    }
    for (final candidate in controller.allPeople) {
      if (candidate.children.contains(personId) &&
          !person.parents.contains(candidate.id)) {
        steps.add(_Step(
          person: candidate,
          dir: _Dir.up,
          token: candidate.gender == '男' ? 'F' : 'M',
        ));
      }
    }

    // 向下：子女
    for (final cid in person.children) {
      final c = controller.getPerson(cid);
      if (c != null) {
        steps.add(_Step(
          person: c,
          dir: _Dir.down,
          token: c.gender == '男' ? 'S' : 'D',
        ));
      }
    }
    for (final candidate in controller.allPeople) {
      if (candidate.parents.contains(personId) &&
          !person.children.contains(candidate.id)) {
        steps.add(_Step(
          person: candidate,
          dir: _Dir.down,
          token: candidate.gender == '男' ? 'S' : 'D',
        ));
      }
    }

    // 平级：配偶
    final spouseIds = <String>{};
    if (person.spouseId != null) spouseIds.add(person.spouseId!);
    if (person.spouse != null) spouseIds.add(person.spouse!);
    for (final candidate in controller.allPeople) {
      if (candidate.spouseId == personId || candidate.spouse == personId) {
        spouseIds.add(candidate.id);
      }
    }
    for (final sid in spouseIds) {
      if (sid == personId) continue;
      final s = controller.getPerson(sid);
      if (s != null) {
        steps.add(_Step(
          person: s,
          dir: _Dir.across,
          token: s.gender == '男' ? 'H' : 'W',
        ));
      }
    }

    // 平级：兄弟姐妹（共享父母）
    for (final candidate in controller.allPeople) {
      if (candidate.id == personId) continue;
      final sharesParent = person.parents.any(
        (pid) => candidate.parents.contains(pid),
      );
      if (sharesParent) {
        final alreadyAdded = steps.any((s) => s.person.id == candidate.id);
        if (!alreadyAdded) {
          steps.add(_Step(
            person: candidate,
            dir: _Dir.across,
            token: candidate.gender == '男' ? 'B' : 'Z',
          ));
        }
      }
    }

    return steps;
  }

  // ─── AI 兜底 ─────────────────────────────────────────────────

  Future<String?> _aiFallback(
    String centerId,
    String targetId,
    List<_Step>? path,
  ) async {
    if (aiService == null) return null;

    final center = controller.getPerson(centerId);
    final target = controller.getPerson(targetId);
    if (center == null || target == null) return null;

    // 用人类可读的方式描述路径
    String pathDesc;
    if (path != null && path.isNotEmpty) {
      final parts = <String>[];
      for (final step in path) {
        parts.add(switch (step.dir) {
          _Dir.up => '${step.person.name}(${step.person.gender == '男' ? '父亲' : '母亲'}侧)',
          _Dir.down => '${step.person.name}(${step.person.gender == '男' ? '儿子' : '女儿'}侧)',
          _Dir.across => '${step.person.name}(${step.token == 'H' || step.token == 'W' ? '配偶' : '兄弟姐妹'}侧)',
        });
      }
      pathDesc = '路径：${center.name} → ${parts.join(' → ')}';
    } else {
      pathDesc = '未找到直达路径';
    }

    final prompt =
        '在家族图谱中，从"${center.name}"到"${target.name}"，$pathDesc。'
        '请给出"${target.name}"相对于"${center.name}"的中文口语亲属称呼。'
        '只回答称呼本身（如：舅舅、堂弟、表姐、姑婆等），不要解释。'
        '如果实在无法确定，回答"远亲"。';

    try {
      final result = await aiService!.askAgent(prompt, controller.aiContextSummary);
      final term = result.trim();
      // 过滤明显不是称呼的回复
      if (term.length > 15 || term.contains('\n') || term.contains('，')) return null;
      return term;
    } catch (_) {
      return null;
    }
  }
}

class _QueueItem {
  final String personId;
  final List<_Step> path;
  const _QueueItem(this.personId, this.path);
}

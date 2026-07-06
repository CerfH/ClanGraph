import '../controllers/family_controller.dart';
import '../models/person.dart';
import 'ai_service.dart';

/// 关系路径中的一步
class _Step {
  final Person person; // 这一步到达的人
  final _Dir dir; // 方向
  final String token; // 单字符标记，用于模式匹配

  const _Step({required this.person, required this.dir, required this.token});

  @override
  String toString() => '$dir→${person.name}($token)';
}

enum _Dir { up, down, across }

/// 智能称呼引擎
///
/// 根据家族图谱中两人之间的最短路径，动态计算中文亲属口语称呼。
/// 优先使用规则引擎（覆盖 1-3 步常见路径），无法匹配时回退到 AI。
class KinshipEngine {
  final FamilyController controller;
  final AIService? aiService;

  KinshipEngine(this.controller, {this.aiService});

  // ─── 公开接口 ───────────────────────────────────────────────

  /// 同步计算称呼（不含 AI 回退）。
  /// 返回 null 表示路径存在但规则无法覆盖。
  String? computeSync(String centerId, String targetId) {
    if (centerId == targetId) return '本人';
    final path = _findPath(centerId, targetId);
    if (path == null) return null;
    return _pathToTerm(path, centerId);
  }

  /// 异步计算称呼，规则无法覆盖时自动调用 AI。
  Future<String> compute(String centerId, String targetId) async {
    if (centerId == targetId) return '本人';

    final target = controller.getPerson(targetId);

    final path = _findPath(centerId, targetId);
    if (path != null) {
      final term = _pathToTerm(path, centerId);
      if (term != null) return term;
    }

    // 规则无法覆盖 → AI 兜底
    if (aiService != null) {
      final aiTerm =
          await _aiFallback(centerId, targetId, path);
      if (aiTerm != null && aiTerm.isNotEmpty) return aiTerm;
    }

    // 最后 fallback：手填的 relationship
    return target?.relationship ?? '';
  }

  /// 批量预计算：为一批目标人物返回称呼（同步，无 AI）。
  Map<String, String> computeBatch(String centerId, List<String> targetIds) {
    final result = <String, String>{};
    for (final id in targetIds) {
      result[id] = computeSync(centerId, id) ??
          controller.getPerson(id)?.relationship ??
          '';
    }
    return result;
  }

  // ─── BFS 最短路径 ───────────────────────────────────────────

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

  /// 获取某人的所有相邻节点
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
    // 也通过反向 children 找父母（数据可能不完全双向）
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
    // 反向 parents
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
      // 直接共享 parent
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

  // ─── 称呼规则引擎 ───────────────────────────────────────────

  /// 将路径转换为中文口语称呼。
  /// Token 说明: F=父亲 M=母亲 S=儿子 D=女儿
  ///             H=丈夫 W=妻子 B=兄弟 Z=姐妹
  String? _pathToTerm(List<_Step> path, String centerId) {
    if (path.isEmpty) return '本人';

    final tokens = path.map((s) => s.token).join();
    final upCount = path.where((s) => s.dir == _Dir.up).length;
    final downCount = path.where((s) => s.dir == _Dir.down).length;
    final acrossCount = path.where((s) => s.dir == _Dir.across).length;

    // ── 纯向上：直系祖先 ──
    if (downCount == 0 && acrossCount == 0) {
      return _ancestorTerm(tokens);
    }

    // ── 纯向下：直系后代 ──
    if (upCount == 0 && acrossCount == 0) {
      return _descendantTerm(tokens);
    }

    // ── 纯平级（1 步）──
    if (upCount == 0 && downCount == 0 && path.length == 1) {
      return _spouseOrSiblingTerm(path.first, centerId);
    }

    // ── 2 步路径 ──
    if (path.length == 2) {
      return _twoStepTerm(path, centerId, tokens, upCount, downCount, acrossCount);
    }

    // ── 3 步路径 ──
    if (path.length == 3) {
      return _threeStepTerm(path, centerId, tokens, upCount, downCount, acrossCount);
    }

    // ── 4+ 步：尝试递归描述 ──
    return _longPathTerm(path, centerId, tokens);
  }

  // ── 直系祖先 ──
  String? _ancestorTerm(String tokens) {
    return switch (tokens) {
      'F' => '爸爸',
      'M' => '妈妈',
      'FF' => '爷爷',
      'FM' => '奶奶',
      'MF' => '外公',
      'MM' => '外婆',
      'FFF' => '曾祖父',
      'FFM' => '曾祖母',
      'FMF' => '曾外祖父',  // 爸爸的妈妈的爸爸 → 奶奶的爸爸
      'MFF' => '外曾祖父',
      'MMF' => '外曾外祖父',
      'MMM' => '外曾外祖母',
      _ when tokens.length >= 4 => _distantAncestor(tokens),
      _ => null,
    };
  }

  String? _distantAncestor(String tokens) {
    final n = tokens.length;
    final firstIsPaternal = tokens[0] == 'F';
    final prefix = switch ((firstIsPaternal, n)) {
      (true, 4) => '高祖父',  // 爸爸的爷爷
      (false, 4) => '外高祖父',
      (true, 5) => '天祖父',
      (false, 5) => '外天祖父',
      _ => null,
    };
    if (prefix != null && tokens.endsWith('M')) {
      return prefix.replaceAll('父', '母');
    }
    return prefix;
  }

  // ── 直系后代 ──
  String? _descendantTerm(String tokens) {
    return switch (tokens) {
      'S' => '儿子',
      'D' => '女儿',
      'SS' => '孙子',
      'SD' => '孙女',
      'DS' => '外孙',
      'DD' => '外孙女',
      'SSS' => '曾孙',
      'SSD' => '曾孙女',
      'DSS' => '外曾孙',
      'DSD' => '外曾孙女',
      _ when tokens.length >= 4 => '玄孙辈',
      _ => null,
    };
  }

  // ── 1 步平级 ──
  String? _spouseOrSiblingTerm(_Step step, String centerId) {
    return switch (step.token) {
      'H' => '老公',
      'W' => '老婆',
      'B' => _siblingTerm(centerId, step.person.id, 'B'),
      'Z' => _siblingTerm(centerId, step.person.id, 'Z'),
      _ => null,
    };
  }

  /// 根据共享父母 children 顺序推断长幼
  String _siblingTerm(String centerId, String siblingId, String genderToken) {
    final older = _isOlder(siblingId, centerId); // sibling 是否比 center 大
    if (genderToken == 'B') {
      if (older == true) return '哥哥';
      if (older == false) return '弟弟';
      return '兄弟'; // 无法判断年龄
    } else {
      if (older == true) return '姐姐';
      if (older == false) return '妹妹';
      return '姐妹';
    }
  }

  /// 判断 a 是否比 b 年长（基于共享父母的 children 顺序）
  bool? _isOlder(String aId, String bId) {
    final a = controller.getPerson(aId);
    if (a == null) return null;
    for (final pid in a.parents) {
      final parent = controller.getPerson(pid);
      if (parent == null) continue;
      // b 也在这个父母的 children 里
      if (!parent.children.contains(bId)) continue;
      final idxA = parent.children.indexOf(aId);
      final idxB = parent.children.indexOf(bId);
      if (idxA >= 0 && idxB >= 0) {
        return idxA < idxB; // children 顺序靠前 = 更年长
      }
    }
    return null;
  }

  // ── 2 步路径 ──
  String? _twoStepTerm(
    List<_Step> path,
    String centerId,
    String tokens,
    int upCount,
    int downCount,
    int acrossCount,
  ) {
    final s1 = path[0];
    final s2 = path[1];

    // 上-平：父母的兄弟姐妹 = 伯伯/叔叔/姑姑/舅舅/姨妈
    if (upCount == 1 && acrossCount == 1 && s1.dir == _Dir.up) {
      return _parentSiblingTerm(s1, s2);
    }

    // 平-上：配偶的父母 = 公婆/岳父母
    if (acrossCount == 1 && upCount == 1 && s1.dir == _Dir.across) {
      return _spouseParentTerm(s1, s2, centerId);
    }

    // 上-上：祖父母（已在 ancestorTerm 里处理）
    // 下-下：孙辈（已在 descendantTerm 里处理）

    // 平-下：两种可能
    //   A. 配偶 → 配偶的子女 = 继子/继女
    //   B. 兄弟姐妹 → 兄弟姐妹的子女 = 侄子/侄女/外甥/外甥女
    if (acrossCount == 1 && downCount == 1 && s1.dir == _Dir.across) {
      if (s1.token == 'H' || s1.token == 'W') {
        return s2.token == 'S' ? '继子' : '继女';
      } else {
        // 兄弟姐妹的子女
        final siblingIsBrother = s1.token == 'B';
        return siblingIsBrother
            ? (s2.token == 'S' ? '侄子' : '侄女')
            : (s2.token == 'S' ? '外甥' : '外甥女');
      }
    }

    // 下-平：子女的配偶 = 儿媳/女婿
    if (downCount == 1 && acrossCount == 1 && s1.dir == _Dir.down) {
      return s2.token == 'W' ? '儿媳妇' : '女婿';
    }

    // 上-下：通过父母找到的非本人的子女 → 实际就是兄弟姐妹
    // 但这种情况 BFS 会优先走 across(sibling)，不应该到这里
    // 兜底处理
    if (upCount == 1 && downCount == 1) {
      if (s1.dir == _Dir.up && s2.dir == _Dir.down) {
        // center → parent → other child
        return _siblingTerm(centerId, s2.person.id, s2.token == 'S' ? 'B' : 'Z');
      }
    }

    return null;
  }

  /// 父母的兄弟姐妹
  String _parentSiblingTerm(_Step parent, _Step sibling) {
    final isPaternal = parent.token == 'F'; // 父亲这边
    final isMale = sibling.token == 'B';

    if (isPaternal) {
      if (isMale) {
        // 父亲的兄弟 → 按长幼分 伯伯/叔叔
        final older = _isOlder(sibling.person.id, parent.person.id);
        if (older == true) return '伯伯';
        if (older == false) return '叔叔';
        return '叔叔'; // 默认
      } else {
        return '姑姑';
      }
    } else {
      // 母亲这边
      if (isMale) {
        return '舅舅';
      } else {
        // 母亲的姐妹 → 按长幼分 大姨/小姨
        final older = _isOlder(sibling.person.id, parent.person.id);
        if (older == true) return '大姨';
        if (older == false) return '小姨';
        return '姨妈';
      }
    }
  }

  /// 配偶的父母
  String _spouseParentTerm(_Step spouse, _Step parent, String centerId) {
    final center = controller.getPerson(centerId);
    final isMale = center?.gender == '男';
    final isFather = parent.token == 'F';

    if (isMale) {
      // 男方视角：配偶的父母
      return isFather ? '岳父' : '岳母';
    } else {
      // 女方视角：配偶的父母
      return isFather ? '公公' : '婆婆';
    }
  }

  // ── 3 步路径 ──
  String? _threeStepTerm(
    List<_Step> path,
    String centerId,
    String tokens,
    int upCount,
    int downCount,
    int acrossCount,
  ) {
    final s1 = path[0];
    final s2 = path[1];
    final s3 = path[2];

    // 上-上-下：祖父母的子女（非第一个up）= 伯叔姑舅姨 → 但2步路径应该已经处理了
    // 这里处理 祖父的子女且不是自己父母 → 伯公/叔公/姑婆/舅公/姨婆
    if (upCount == 2 && downCount == 1) {
      return _grandparentSiblingTerm(path);
    }

    // 上-平-下：需要区分两种路径
    //   A. center → parent → parent的兄弟/姐妹 → child = 堂/表亲
    //   B. center → parent → center的兄弟/姐妹 → child = 侄子/外甥
    if (upCount == 1 && acrossCount == 1 && downCount == 1) {
      final center = controller.getPerson(centerId);
      final s2IsCenterSibling =
          center?.parents.contains(s1.person.id) == true &&
          s2.person.parents.contains(s1.person.id);
      if (s2IsCenterSibling) {
        // 我的兄弟姐妹的子女
        return _nephewNieceTerm(path, centerId);
      } else {
        // 父母的兄弟姐妹的子女
        return _cousinTerm(s1, s2, s3, centerId);
      }
    }

    // 上-下-下：兄弟姐妹的子女 = 侄子/侄女/外甥/外甥女
    // （BFS 没有 across 边直接连 sibling 时的备用路径）
    if (upCount == 1 && downCount == 2) {
      return _nephewNieceTerm(path, centerId);
    }

    // 平-上-上：配偶的祖父母
    if (acrossCount == 1 && upCount == 2) {
      return '亲家' + (s3.token == 'F' ? '公' : '婆');
    }

    // 下-下-平：孙辈的配偶
    if (downCount == 2 && acrossCount == 1) {
      return s3.token == 'W' ? '孙媳妇' : '孙女婿';
    }

    // 下-平-下：子女的配偶带来的孩子（继孙）
    if (downCount == 2 && acrossCount == 1) {
      return null; // 太罕见，交给 AI
    }

    return null;
  }

  /// 祖父母的兄弟姐妹 → 伯公/叔公/姑婆/舅公/姨婆
  String? _grandparentSiblingTerm(List<_Step> path) {
    final s1 = path[0]; // 父母
    final s2 = path[1]; // 祖父母
    final s3 = path[2]; // 祖父母的子女（非 s1）
    final paternal = s1.token == 'F'; // 父系还是母系

    if (s3.token == 'B' || s3.token == 'S') {
      // 男性
      final older = _isOlder(s3.person.id, s2.person.id);
      if (paternal) {
        if (older == true) return '伯公';
        if (older == false) return '叔公';
        return '叔公';
      } else {
        return '舅公';
      }
    } else {
      // 女性
      if (paternal) return '姑婆';
      return '姨婆';
    }
  }

  /// 堂/表兄弟姐妹
  String _cousinTerm(_Step parent, _Step auntUncle, _Step cousin, String centerId) {
    final paternal = parent.token == 'F';
    final cousinMale = cousin.token == 'S';

    // 堂：父亲的兄弟的子女 → 同姓
    // 表：父亲姐妹的子女 + 母亲所有兄弟姐妹的子女 → 异姓
    final isTang = paternal && auntUncle.token == 'B';

    final older = _isOlder(cousin.person.id, centerId);

    if (isTang) {
      if (older == true) return cousinMale ? '堂哥' : '堂姐';
      if (older == false) return cousinMale ? '堂弟' : '堂妹';
      return cousinMale ? '堂兄弟' : '堂姐妹';
    } else {
      if (older == true) return cousinMale ? '表哥' : '表姐';
      if (older == false) return cousinMale ? '表弟' : '表妹';
      return cousinMale ? '表兄弟' : '表姐妹';
    }
  }

  /// 侄子/侄女/外甥/外甥女
  String? _nephewNieceTerm(List<_Step> path, String centerId) {
    final s2 = path[1]; // 父母 → 兄弟/姐妹
    final s3 = path[2]; // 兄弟/姐妹 → 子女

    // s2 是 center 的兄弟还是姐妹？
    final siblingIsBrother = s2.token == 'B' || s2.token == 'S';

    if (siblingIsBrother) {
      return s3.token == 'S' ? '侄子' : '侄女';
    } else {
      return s3.token == 'S' ? '外甥' : '外甥女';
    }
  }

  // ── 4+ 步长路径：尝试通用描述 ──
  String? _longPathTerm(
    List<_Step> path,
    String centerId,
    String tokens,
  ) {
    // 全上：N 代祖先
    final upSteps = path.where((s) => s.dir == _Dir.up).toList();
    final downSteps = path.where((s) => s.dir == _Dir.down).toList();
    final acrossSteps = path.where((s) => s.dir == _Dir.across).toList();

    if (downSteps.isEmpty && acrossSteps.isEmpty) {
      // 纯向上 > 3 代
      return _distantAncestor(tokens);
    }

    if (upSteps.isEmpty && acrossSteps.isEmpty) {
      // 纯向下 > 3 代
      if (downSteps.length >= 4) return '玄孙辈';
    }

    // 返回描述性路径文字
    final parts = <String>[];
    for (final step in path) {
      parts.add(_stepLabel(step));
    }
    // 倒过来拼接："爷爷的弟弟的儿子" → 但这个不够口语化
    // 交给 AI 处理
    return null;
  }

  String _stepLabel(_Step step) {
    return switch (step.token) {
      'F' => '爸爸',
      'M' => '妈妈',
      'S' => '儿子',
      'D' => '女儿',
      'H' => '老公',
      'W' => '老婆',
      'B' => '兄弟',
      'Z' => '姐妹',
      _ => step.person.name,
    };
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

    String pathDesc;
    if (path != null && path.isNotEmpty) {
      final parts = path.map((s) => '${s.dir}→${s.person.name}(${s.person.relationship})').join(' , ');
      final tokenPath = path.map((s) => s.token).join(' → ');
      pathDesc = '关系路径（$tokenPath）：$parts';
    } else {
      pathDesc = '未找到直接路径';
    }

    final prompt =
        '在家族图谱中，从"${center.name}"到"${target.name}"，$pathDesc。'
        '请给出对应的中文亲属口语称呼（如：表舅、堂叔公等）。'
        '只回答称呼本身，不要解释。如果实在无法确定，请回答"远亲"。';

    try {
      final result = await aiService!.askAgent(
        prompt,
        controller.aiContextSummary,
      );
      final term = result.trim();
      // 过滤过长的回复（可能是 AI 的解释）
      if (term.length > 20) return null;
      return term;
    } catch (_) {
      return null;
    }
  }
}

/// BFS 队列项
class _QueueItem {
  final String personId;
  final List<_Step> path;
  const _QueueItem(this.personId, this.path);
}

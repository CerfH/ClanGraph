# Implementation Plan

- [x] 1. 编写 Bug 条件探索测试（修复前运行）
  - **Property 1: Bug Condition** - 删除联动 / 颜色层级 / 导出范围 / 配偶字段四项 Bug 条件验证
  - **CRITICAL**: 这些测试 MUST FAIL on unfixed code — 失败即证明 Bug 存在
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: 测试编码了期望行为，修复后通过即验证 Bug 已修复
  - **GOAL**: 通过反例暴露四个 Bug 的根因
  - **Scoped PBT Approach**: 针对确定性 Bug，将属性范围收窄到具体失败用例以确保可复现
  - Bug 1 探索：创建 A（有配偶 B），删除 B，断言 A.spouseId 仍为 B 的 ID（在未修复代码上应通过，证明悬空引用存在）
  - Bug 2 探索：调用 `GalaxyLayoutEngine.generationColor(-2)` 与 `generationColor(-1)`，断言两者颜色相同（在未修复代码上应通过）
  - Bug 3 探索：构造含叔伯的家谱，以中心人导出，断言叔伯 ID 不在导出集合中（在未修复代码上应通过）
  - Bug 4 探索：调用 `addSpouse`，断言 `person.spouse == null` 且 `calculateGenerations` 中配偶节点不参与遍历（在未修复代码上应通过）
  - 运行测试于 UNFIXED 代码
  - **EXPECTED OUTCOME**: 测试 FAILS（正确 — 证明 Bug 存在）
  - 记录反例以理解根因
  - 任务完成标准：测试已编写、已运行、失败已记录
  - _Requirements: 1.1, 1.3, 1.4, 1.8_

- [x] 2. 编写保留性属性测试（修复前运行）
  - **Property 2: Preservation** - 删除 / 颜色 / 导出 / 配偶四项回归防护
  - **IMPORTANT**: 遵循 observation-first 方法论
  - 在 UNFIXED 代码上观察非 Bug 条件输入的实际输出
  - Bug 1 保留：删除无配偶的叶子节点，观察父母/子女列表清理结果，编写属性测试断言该行为
  - Bug 2 保留：调用 `generationColor(0)`，观察返回绿色 `0xFF4CAF50`，编写属性测试断言本辈颜色不变
  - Bug 3 保留：导出不含叔伯的简单家谱，观察 JSON 格式合法且不含超出范围节点，编写属性测试
  - Bug 4 保留：导入含旧 `spouse` 字段的 JSON，观察配偶关系正确解析，编写属性测试
  - 在 UNFIXED 代码上运行测试
  - **EXPECTED OUTCOME**: 测试 PASSES（确认基线行为，修复后不得回归）
  - 任务完成标准：测试已编写、已运行、在未修复代码上通过
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.12_

- [x] 3. 修复 Bug 1：deletePerson 补充 spouseId 清理

  - [x] 3.1 在 `lib/controllers/family_controller.dart` 的 `deletePerson` 方法中，在现有父母/子女列表清理逻辑之后，新增遍历全量 `_people` Map 的循环
    - 对每个 person，若 `person.spouseId == id`，重建该 person 并将 `spouseId` 置为 null
    - 同时检查旧 `spouse` 字段（向后兼容），若 `person.spouse == id`，也置为 null
    - 不修改父母/子女列表清理逻辑（保留现有行为）
    - _Bug_Condition: isBugCondition_1(deleteId, people) — EXISTS person WHERE person.spouseId == deleteId AND deleteId NOT IN people.keys_
    - _Expected_Behavior: 删除后 people Map 中不存在任何指向已删除 ID 的 spouseId 引用_
    - _Preservation: 删除叶子节点的父母/子女列表清理逻辑不变；root 节点保护逻辑不变_
    - _Requirements: 2.2, 2.3, 3.1, 3.2, 3.3_

  - [x] 3.2 验证 Bug 1 探索测试现在通过
    - **Property 1: Expected Behavior** - 删除后无悬空引用
    - **IMPORTANT**: 重新运行 task 1 中的 Bug 1 探索测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认 Bug 1 已修复）
    - _Requirements: 2.2, 2.3_

  - [x] 3.3 验证 Bug 1 保留性测试仍然通过
    - **Property 2: Preservation** - 删除操作回归防护
    - **IMPORTANT**: 重新运行 task 2 中的 Bug 1 保留性测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认无回归）

- [x] 4. 修复 Bug 2：generationColor 扩展为五档

  - [x] 4.1 在 `lib/views/family_tree_view.dart` 的 `GalaxyLayoutEngine.generationColor` 方法中，将四档映射扩展为五档
    - 新增 `generation <= -2` 分支，返回紫色 `Color(0xFF9C27B0)`（曾祖辈）
    - `generation == -1` 返回蓝色 `Color(0xFF2196F3)`（祖辈）
    - `generation == 0` 保持绿色 `Color(0xFF4CAF50)`（本辈，不变）
    - `generation == 1` 返回黄色 `Color(0xFFFFC107)`（子辈）
    - `generation >= 2` 返回橙色 `Color(0xFFFF5722)`（孙辈）
    - _Bug_Condition: isBugCondition_2(generation) — generation <= -2 AND colorOf(generation) == colorOf(-1)_
    - _Expected_Behavior: 五档颜色各不相同，任意两档颜色不得相同_
    - _Preservation: generation == 0 颜色保持 0xFF4CAF50；节点位置/大小/连线逻辑不受影响_
    - _Requirements: 2.4, 2.5, 3.4, 3.5_

  - [x] 4.2 在 `AppTheme`（`lib/theme/app_theme.dart`）中新增五代颜色常量
    - `static const Color genAncestor2 = Color(0xFF9C27B0);` // 曾祖辈 - 紫
    - `static const Color genAncestor1 = Color(0xFF2196F3);` // 祖辈 - 蓝
    - `static const Color genSelf = Color(0xFF4CAF50);`      // 本辈 - 绿
    - `static const Color genChild1 = Color(0xFFFFC107);`    // 子辈 - 黄
    - `static const Color genChild2 = Color(0xFFFF5722);`    // 孙辈 - 橙
    - 更新 `generationColor` 引用 `AppTheme` 常量
    - _Requirements: 2.5_

  - [x] 4.3 验证 Bug 2 探索测试现在通过
    - **Property 1: Expected Behavior** - 五代颜色显著区分
    - **IMPORTANT**: 重新运行 task 1 中的 Bug 2 探索测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认 Bug 2 已修复）
    - _Requirements: 2.4, 2.5_

  - [x] 4.4 验证 Bug 2 保留性测试仍然通过
    - **Property 2: Preservation** - 颜色映射回归防护
    - **IMPORTANT**: 重新运行 task 2 中的 Bug 2 保留性测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认无回归）

- [x] 5. 修复 Bug 3：DfsExtractor 扩展核心成员范围

  - [x] 5.1 在 `lib/services/dfs_extractor.dart` 的 `DfsExtractor.extract` 方法中，在配偶扩展阶段之后新增"父母的兄弟姐妹"扩展阶段
    - 收集中心人的所有父母 ID（`centerPerson.parents`）
    - 对每个父母，找到其父母（祖父母）
    - 对每个祖父母，遍历其 `children`，将不在 `result` 中的兄弟姐妹（叔伯舅姑）加入 `result`
    - 对新加入的叔伯舅姑，执行配偶扩展（`spouseId` 非空则加入）
    - 不修改现有 BFS 主循环和配偶扩展逻辑（保留现有行为）
    - _Bug_Condition: isBugCondition_3 — missingCoreMembers(centerId, people, exported) — 父母的兄弟姐妹未被包含_
    - _Expected_Behavior: 导出集合包含中心人父母的所有兄弟姐妹及其配偶_
    - _Preservation: 导出 JSON 格式与现有 exportToJSON 兼容；不包含超出范围的远亲节点_
    - _Requirements: 2.6, 2.8, 3.6, 3.7_

  - [x] 5.2 验证 Bug 3 探索测试现在通过
    - **Property 1: Expected Behavior** - 导出包含核心成员
    - **IMPORTANT**: 重新运行 task 1 中的 Bug 3 探索测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认 Bug 3 已修复）
    - _Requirements: 2.6, 2.8_

  - [x] 5.3 验证 Bug 3 保留性测试仍然通过
    - **Property 2: Preservation** - 导出格式兼容性
    - **IMPORTANT**: 重新运行 task 2 中的 Bug 3 保留性测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认无回归）

- [x] 6. 修复 Bug 4：统一配偶字段为 spouseId

  - [x] 6.1 修改 `lib/models/person.dart` 的 `Person.fromMap`，将 `spouseId` 读取逻辑改为 `spouseIdRaw ?? spouseRaw`（向后兼容旧 `spouse` 字段）
    - _Requirements: 2.12, 3.12_

  - [x] 6.2 修改 `lib/controllers/family_controller.dart` 的 `calculateGenerations`，将 `person.spouse` 替换为 `person.spouseId`
    - _Requirements: 2.13_

  - [x] 6.3 修改 `lib/controllers/family_controller.dart` 的 `aiContextSummary`，将 `p.spouse` 替换为 `p.spouseId`
    - _Requirements: 2.13_

  - [x] 6.4 修改 `lib/controllers/family_controller.dart` 的 `addParent`，将 `spouse: existingParentId` 改为 `spouseId: existingParentId`；将旧父母更新中的 `spouse: newId` 改为 `spouseId: newId`，移除 `spouse` 参数
    - _Requirements: 2.13_

  - [x] 6.5 修改 `lib/widgets/gift_record_dialog.dart` 的 `_submit`，将 `person.spouse` 替换为 `person.spouseId`
    - _Requirements: 2.13_

  - [x] 6.6 验证 Bug 4 探索测试现在通过
    - **Property 1: Expected Behavior** - 配偶字段统一
    - **IMPORTANT**: 重新运行 task 1 中的 Bug 4 探索测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认 Bug 4 已修复）
    - _Requirements: 2.11, 2.13_

  - [x] 6.7 验证 Bug 4 保留性测试仍然通过
    - **Property 2: Preservation** - 旧数据兼容性
    - **IMPORTANT**: 重新运行 task 2 中的 Bug 4 保留性测试 — 不要编写新测试
    - **EXPECTED OUTCOME**: 测试 PASSES（确认无回归）

- [x] 7. 实现附加功能：动态中心重构

  - [x] 7.1 修改 `lib/controllers/family_controller.dart`
    - 将 `final String _centerPersonId = 'root'` 改为 `String _mainPersonId = 'root'`
    - 新增 getter `String get mainPersonId => _mainPersonId`
    - 新增方法 `void setMainPerson(String id)` — 更新 `_mainPersonId`，调用 `notifyListeners()`
    - `calculateGenerations` 和 `GalaxyLayoutEngine.compute` 的 `rootId` 参数改为使用 `mainPersonId`
    - _Requirements: 2.9, 2.10, 3.8, 3.9_

  - [x] 7.2 修改 `lib/widgets/person_details_sidebar.dart`
    - 新增 `VoidCallback? onSetAsCenter` 回调参数
    - 在操作区新增"以此人为中心查看"按钮，调用 `onSetAsCenter`
    - 仅当 `person.id != controller.mainPersonId` 时显示该按钮
    - _Requirements: 2.9_

  - [x] 7.3 修改 `lib/views/family_tree_view.dart`
    - `GalaxyLayoutEngine.compute` 的 `rootId` 改为 `widget.controller.mainPersonId`
    - `PersonDetailsSidebar` 传入 `onSetAsCenter` 回调，调用 `widget.controller.setMainPerson(id)` 并关闭侧边栏
    - _Requirements: 2.10_

- [x] 8. Checkpoint — 确保所有测试通过
  - 运行全部测试（`flutter test`），确认所有测试通过
  - 如有疑问，询问用户

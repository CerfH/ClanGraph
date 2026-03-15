# 实现计划：智能导出过滤器 & 配偶关系重构

## 概述

按照设计文档，分五个阶段实现：数据模型扩展 → 业务逻辑层（DFS 提取 + 导出过滤 + 配偶操作）→ UI 层 → 集成接入 → 最终验收。

## 任务

- [x] 1. 更新 Person 模型，新增 spouseId 字段
  - 在 `lib/models/person.dart` 的 `Person` 类中新增 `final String? spouseId` 字段
  - 更新构造函数，将 `spouseId` 设为可选命名参数，默认值为 `null`
  - 在 `toMap()` 中新增键 `"spouseId"`，值为 `spouseId`
  - 在 `fromMap()` 中读取 `map['spouseId']`，缺失或空值时赋 `null`
  - 保留现有 `spouse` 字段不变，确保向后兼容
  - _需求：6.1, 6.2, 6.3, 6.5_

  - [x] 1.1 为 Person 序列化往返编写属性测试
    - **属性 8：Person 序列化往返**
    - **验证需求：6.4**
    - 生成含任意 `spouseId`（含 null）的随机 Person，验证 `Person.fromMap(p.toMap()).spouseId == p.spouseId`
    - 同时验证旧格式数据（无 `spouseId` 键）加载后 `spouseId` 为 `null`

- [x] 2. 新增导出配置数据模型
  - 创建 `lib/models/export_config.dart`
  - 定义 `enum ExportDimension { basicInfo, giftHistory, relations, bio }`
  - 定义 `ExportConfig` 类，包含 `enabledDimensions` 和 `centerId` 字段
  - 实现 `ExportConfig.defaultConfig(String centerId)` 静态工厂方法（默认勾选 basicInfo + relations）
  - _需求：2.1, 2.4_

- [x] 3. 实现 DfsExtractor 服务
  - 创建 `lib/services/dfs_extractor.dart`
  - 实现 `DfsExtractor.extract({required Map<String, Person> people, required String centerId, int maxGenerations = 2})` 静态方法
  - 算法：BFS/DFS 队列，携带代际深度，`depth > maxGenerations` 时剪枝
  - 配偶扩展：对结果集中每个血亲，若 `spouseId` 非空则加入结果集，但不以配偶为起点继续搜索
  - 中心人物 ID 不存在时返回空集合
  - _需求：4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [x] 3.1 为 DFS 代际距离不变量编写属性测试
    - **属性 1：DFS 代际距离不变量**
    - **验证需求：4.1, 4.8**
    - 生成随机家谱图 + 随机中心人物，验证所有结果节点到中心人物的最短血亲路径 ≤ 2

  - [x] 3.2 为血亲配偶纳入结果编写属性测试
    - **属性 2：血亲配偶纳入结果**
    - **验证需求：4.5**
    - 生成含 `spouseId` 的家谱，验证每个血亲范围内 Person 的配偶都出现在结果集中

  - [x] 3.3 为配偶扩展不传播 DFS 编写属性测试
    - **属性 3：配偶扩展不传播 DFS**
    - **验证需求：4.7**
    - 生成含姻亲分支的家谱，验证仅通过配偶关系纳入的 Person 的 parents/children 不被加入结果集

- [x] 4. 实现 ExportFilter 服务
  - 创建 `lib/services/export_filter.dart`
  - 实现 `ExportFilter.filter({required Iterable<Person> people, required ExportConfig config})` 静态方法
  - 按 `enabledDimensions` 对每个 Person 执行字段清洗：未勾选维度对应字段置为空值
  - 输出格式：`{"members": [...]}` — 与现有 `exportToJSON` 完全一致
  - 输入空集合时返回 `{"members":[]}`
  - _需求：5.1, 5.2, 5.3_

  - [x] 4.1 为 ExportFilter 字段清洗正确性编写属性测试
    - **属性 4：ExportFilter 字段清洗正确性**
    - **验证需求：2.2, 2.3, 5.2**
    - 生成随机 Person 集合 + 随机 ExportConfig，验证未勾选维度字段为空值，已勾选维度字段与原始数据一致

  - [x] 4.2 为 ExportFilter 输出合法 JSON 编写属性测试
    - **属性 5：ExportFilter 输出合法 JSON**
    - **验证需求：2.5, 5.3**
    - 生成随机 ExportConfig，验证输出可被 `json.decode` 解析且顶层含 `members` 数组

  - [x] 4.3 为 ExportFilter 幂等性编写属性测试
    - **属性 6：ExportFilter 幂等性**
    - **验证需求：5.4**
    - 生成随机 Person 集合 + 随机 ExportConfig，执行两次 filter，验证结果完全相同

  - [x] 4.4 为 ExportFilter 范围隔离编写属性测试
    - **属性 7：ExportFilter 范围隔离**
    - **验证需求：5.1**
    - 生成随机家谱图，DFS 提取后过滤，验证输出 members 中不含提取范围外的 Person

- [x] 5. 检查点 — 确保所有测试通过
  - 确保所有测试通过，如有问题请向用户反馈。

- [x] 6. 在 FamilyController 中实现 addSpouse 方法
  - 在 `lib/controllers/family_controller.dart` 中新增 `addSpouse` 方法
  - 方法签名：`void addSpouse(String personId, String name, String relationship, String bio, String gender)`
  - 原子操作：创建新 Person B，设置 A.spouseId = B.id，B.spouseId = A.id（互指）
  - 子女继承：遍历 A 的所有子女，将 B.id 加入每个子女的 parents，将所有子女 id 加入 B.children
  - 操作完成后调用 `saveToDisk()` 持久化
  - 注意：唯一性检查（已有配偶时的确认对话框）由 UI 层处理，controller 只执行替换
  - 同步更新 `addParent`、`addChild`、`updatePerson`、`deletePerson` 等方法，使其在构造 Person 时传递 `spouseId` 字段，避免字段丢失
  - _需求：8.1, 8.2, 8.3, 8.4, 8.6_

  - [x] 6.1 为配偶互指不变量编写属性测试
    - **属性 9：配偶互指不变量**
    - **验证需求：8.1, 8.3**
    - 生成随机 Person 对，调用 addSpouse 后验证 A.spouseId == B.id 且 B.spouseId == A.id

  - [x] 6.2 为子女继承属性编写属性测试
    - **属性 10：子女继承属性**
    - **验证需求：8.2, 8.4**
    - 生成随机含子女的 Person，调用 addSpouse 后验证每个子女的 parents 含 B.id，且 B.children 含子女 id

- [x] 7. 实现 ExportDialog 组件
  - 创建 `lib/widgets/export_dialog.dart`
  - 实现 `ExportDialog` StatelessWidget，接收 `FamilyController controller`
  - 展示"完整备份"和"亲友分享"两个选项
  - "完整备份"：调用 `controller.exportToJSON()` 并复制到剪贴板，关闭对话框
  - "亲友分享"：`Navigator.push` 至 `ShareConfigPage`
  - 点击对话框外部或取消按钮时关闭且不执行任何操作
  - _需求：1.1, 1.2, 1.3, 1.4_

- [x] 8. 实现 ShareConfigPage 组件
  - 创建 `lib/widgets/share_config_page.dart`
  - 实现 `ShareConfigPage` StatefulWidget，接收 `FamilyController controller`
  - 四个 Checkbox：基本信息（默认勾选）、亲缘关系（默认勾选）、礼金记录（默认不勾选）、备注（默认不勾选）
  - 搜索框：实时模糊匹配 `name` / `relationship`，展示匹配列表
  - 已选中心人物展示区：显示姓名和关系标签
  - "开始导出"按钮：无中心人物或无匹配结果时禁用
  - 点击"开始导出"：调用 `DfsExtractor.extract` 提取范围，再调用 `ExportFilter.filter` 清洗，将结果复制到剪贴板
  - _需求：2.1, 2.4, 3.1, 3.2, 3.3, 3.4_

- [x] 9. 在 PersonDetailsSidebar 中新增"添加配偶"入口
  - 修改 `lib/widgets/person_details_sidebar.dart`
  - 在操作区（"添加父母"和"添加子女"按钮之间或之后）新增"添加配偶"按钮
  - 新增 `onAddSpouse` 回调参数（`VoidCallback`）
  - 当 `person.spouseId` 非空时，点击"添加配偶"前弹出确认对话框（提示已有配偶，询问是否替换）
  - 用户确认后才触发 `onAddSpouse` 回调
  - _需求：7.1, 7.2, 8.5_

- [x] 10. 在 FamilyTreeView 中接入 ExportDialog 和 addSpouse 回调
  - 修改 `lib/views/family_tree_view.dart`
  - 将现有导出按钮的 `onTap` 替换为弹出 `ExportDialog`
  - 在 `PersonDetailsSidebar` 的调用处新增 `onAddSpouse` 回调，回调内弹出 PersonDialog 并调用 `controller.addSpouse`
  - _需求：1.1, 7.3_

- [ ] 11. 最终检查点 — 确保所有测试通过
  - 确保所有测试通过，如有问题请向用户反馈。

## 备注

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 进度
- 每个任务均引用具体需求条款，确保可追溯性
- 检查点确保增量验证
- 属性测试验证普遍性正确性，单元测试验证具体示例和边界条件
- GalaxyPainter 绘图逻辑不做任何修改（不实现配偶虚线）

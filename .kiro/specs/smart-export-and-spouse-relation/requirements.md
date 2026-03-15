# 需求文档

## 简介

本文档描述 Flutter 家谱应用（ClanGraph）的两项新功能：

**功能一：智能数据导出过滤器**——在现有导出功能基础上，新增"亲友分享"模式，支持以中心人物为基准的 DFS 亲属范围提取（向上/向下各 2 代），并提供字段维度过滤，在导出前对未选中字段执行数据清洗，保护隐私。

**功能二：配偶关系逻辑重构**——在 `Person` 模型中明确引入 `spouseId` 字段，新增"添加配偶"原子操作（含子女继承、唯一性检查），并在绘图层以虚线区分配偶连线与血亲连线。

---

## 词汇表

- **ExportFilter（导出过滤器）**：负责根据用户配置对导出数据进行字段裁剪和人员范围筛选的模块。
- **DfsExtractor（深度优先提取器）**：以中心人物为起点，沿血亲关系执行深度优先搜索，提取指定代际范围内人员的算法组件。
- **Person（人员）**：家谱中的一个成员节点，包含基本信息、亲缘关系、礼金记录等字段。
- **SpouseLinker（配偶关联器）**：负责执行"添加配偶"原子操作的控制器方法集合，包含互指、子女继承和唯一性检查。
- **GalaxyPainter（星系绘制器）**：负责在画布上绘制家谱节点和连线的自定义 `CustomPainter`。
- **FamilyController（家族控制器）**：管理家谱数据状态、持久化和业务逻辑的 `ChangeNotifier`。
- **ExportDialog（导出对话框）**：用户点击导出按钮后弹出的模式对话框，提供导出模式选择入口。
- **ShareConfigPage（分享配置页）**：在"亲友分享"模式下展示的配置界面，包含字段勾选和中心人物搜索。
- **血亲关系**：通过 `parents` / `children` 字段建立的父子代际关系。
- **姻亲关系**：通过 `spouseId` 字段建立的配偶关系，不属于血亲链路。
- **代际距离**：从中心人物出发，沿血亲关系（父母/子女方向）到达目标人员所需的跳数。

---

## 需求

### 需求 1：导出模式选择

**用户故事：** 作为家谱应用用户，我希望在点击导出按钮后能选择导出模式，以便根据场景决定是完整备份还是定向分享。

#### 验收标准

1. WHEN 用户点击导出按钮，THE ExportDialog SHALL 弹出包含"完整备份"和"亲友分享"两个选项的模式对话框。
2. WHEN 用户在 ExportDialog 中选择"完整备份"，THE FamilyController SHALL 执行原有 `exportToJSON` 逻辑并将结果复制到剪贴板。
3. WHEN 用户在 ExportDialog 中选择"亲友分享"，THE ExportDialog SHALL 跳转至 ShareConfigPage。
4. WHEN 用户在 ExportDialog 中点击取消或点击对话框外部区域，THE ExportDialog SHALL 关闭且不执行任何导出操作。

---

### 需求 2：字段维度过滤

**用户故事：** 作为家谱应用用户，我希望在"亲友分享"模式下能勾选要导出的字段，以便在分享时保护敏感信息。

#### 验收标准

1. THE ShareConfigPage SHALL 提供四个独立的 Checkbox，分别对应以下导出维度：基本信息（`name`、`relationship`、`gender`）、礼金记录（`giftHistory`）、亲缘关系（`parents`、`children`、`spouseId`）、备注（`bio`）。
2. WHEN 用户取消勾选某一维度，THE ExportFilter SHALL 在导出的 JSON 中将该维度对应的所有字段置为空值或从对象中移除。
3. WHEN 用户勾选某一维度，THE ExportFilter SHALL 在导出的 JSON 中保留该维度对应字段的完整数据。
4. THE ShareConfigPage SHALL 默认勾选"基本信息"和"亲缘关系"两个维度，默认不勾选"礼金记录"和"备注"。
5. FOR ALL 导出配置组合，THE ExportFilter SHALL 生成可被标准 JSON 解析器成功解析的合法 JSON 字符串（不变量）。

---

### 需求 3：中心人物搜索与选择

**用户故事：** 作为家谱应用用户，我希望在"亲友分享"模式下能搜索并指定一个中心人物，以便系统自动确定导出范围。

#### 验收标准

1. THE ShareConfigPage SHALL 提供一个搜索输入框，支持按 `name` 或 `relationship` 字段进行模糊匹配。
2. WHEN 用户在搜索框中输入查询词，THE ShareConfigPage SHALL 实时展示所有匹配的 Person 列表供用户选择。
3. WHEN 用户从列表中选定一个 Person 作为中心人物，THE ShareConfigPage SHALL 显示该人物的姓名和关系标签作为已选状态的视觉反馈。
4. IF 搜索框为空或无匹配结果，THEN THE ShareConfigPage SHALL 禁用"开始导出"按钮并展示相应提示文字。

---

### 需求 4：DFS 亲属范围提取与姻亲剪枝

**用户故事：** 作为家谱应用用户，我希望系统能自动提取中心人物的近亲范围，以便导出结果只包含相关人员而不泄露无关家庭的信息。

#### 验收标准

1. WHEN 用户选定中心人物并触发导出，THE DfsExtractor SHALL 沿血亲关系（`parents` / `children`）执行深度优先搜索，提取代际距离不超过 2 的所有 Person。
2. THE DfsExtractor SHALL 将中心人物本人包含在提取结果中（代际距离为 0）。
3. THE DfsExtractor SHALL 将中心人物的父母（代际距离 1）和祖父母（代际距离 2）包含在提取结果中。
4. THE DfsExtractor SHALL 将中心人物的子女（代际距离 1）和孙辈（代际距离 2）包含在提取结果中。
5. THE DfsExtractor SHALL 将提取范围内每位血亲的直接配偶（`spouseId`）一并纳入结果，以保持家庭单元完整性。
6. THE DfsExtractor SHALL 排除所有代际距离超过 2 的 Person，包括曾祖辈、曾孙辈及其延伸分支。
7. THE DfsExtractor SHALL 排除通过姻亲关系延伸出的无关血亲分支（例如：配偶的兄弟姐妹的子女不在提取范围内）。
8. FOR ALL 中心人物选择，THE DfsExtractor 提取的结果集合 SHALL 满足：结果中任意 Person 到中心人物的最短血亲路径长度不超过 2（代际距离不变量）。

---

### 需求 5：导出数据清洗

**用户故事：** 作为家谱应用用户，我希望导出前系统能自动清洗未选中字段的数据，以便确保分享内容不包含敏感信息。

#### 验收标准

1. WHEN 用户触发"亲友分享"导出，THE ExportFilter SHALL 仅对 DfsExtractor 提取的 Person 集合执行序列化，不包含范围外的 Person。
2. FOR ALL 在提取范围内的 Person，THE ExportFilter SHALL 根据字段维度勾选状态，将未勾选维度对应的字段在序列化时置为空列表（`[]`）、空字符串（`""`）或 `null`。
3. THE ExportFilter SHALL 生成包含 `members` 数组的顶层 JSON 对象，格式与现有 `exportToJSON` 方法的输出结构保持一致，以确保导入兼容性。
4. FOR ALL 字段维度勾选配置，THE ExportFilter 对同一 Person 集合执行清洗后再解析，再次清洗的结果 SHALL 与首次清洗结果等价（幂等性）。

---

### 需求 6：Person 模型 spouseId 字段适配

**用户故事：** 作为开发者，我希望 Person 模型明确包含 `spouseId` 字段，以便配偶关系有清晰的数据来源而非依赖反向推导。

#### 验收标准

1. THE Person SHALL 包含类型为 `String?` 的 `spouseId` 字段，用于存储配偶的唯一标识符。
2. THE Person SHALL 在 `toMap` 方法中将 `spouseId` 序列化为键名 `"spouseId"` 的 JSON 字段。
3. THE Person SHALL 在 `fromMap` 工厂方法中从键名 `"spouseId"` 反序列化，若键不存在或值为空则赋值为 `null`。
4. FOR ALL 包含非空 `spouseId` 的 Person 对象 `p`，执行 `Person.fromMap(p.toMap())` 后，结果对象的 `spouseId` SHALL 等于 `p.spouseId`（序列化往返属性）。
5. THE Person SHALL 同时保留现有的 `spouse` 字段以维持向后兼容，直至迁移完成。

---

### 需求 7：添加配偶 UI 入口

**用户故事：** 作为家谱应用用户，我希望在节点编辑弹窗中能找到"添加配偶"按钮，以便快速为家族成员建立配偶关系。

#### 验收标准

1. THE PersonDetailsSidebar SHALL 在"添加父母"和"添加子女"按钮的同一操作区域内展示"添加配偶"按钮。
2. WHEN 用户点击"添加配偶"按钮，THE PersonDetailsSidebar SHALL 弹出与"添加父母/子女"风格一致的 PersonDialog，供用户填写配偶的姓名、关系、性别和备注。
3. WHEN 用户在 PersonDialog 中提交配偶信息，THE FamilyController SHALL 调用 SpouseLinker 执行添加配偶的原子操作。

---

### 需求 8：添加配偶原子操作

**用户故事：** 作为家谱应用用户，我希望添加配偶时系统自动处理所有关联数据更新，以便家谱数据保持一致性。

#### 验收标准

1. WHEN SpouseLinker 为 Person A 添加配偶 Person B，THE SpouseLinker SHALL 同时将 A 的 `spouseId` 设置为 B 的 `id`，并将 B 的 `spouseId` 设置为 A 的 `id`（互指不变量）。
2. WHEN SpouseLinker 为 Person A 添加配偶 Person B，且 A 的 `childrenIds` 非空，THE SpouseLinker SHALL 遍历 A 的所有子女，将 B 的 `id` 加入每个子女的 `parents` 列表，并将所有子女的 `id` 加入 B 的 `children` 列表。
3. FOR ALL 执行添加配偶操作后的状态，THE FamilyController 中 A 的 `spouseId` 与 B 的 `spouseId` SHALL 互相指向对方（配偶互指属性）。
4. FOR ALL 执行添加配偶操作后的状态，A 的每个子女 `c` 的 `parents` 列表 SHALL 包含 B 的 `id`，且 B 的 `children` 列表 SHALL 包含 `c` 的 `id`（子女继承属性）。
5. IF Person A 已存在非空的 `spouseId`，THEN THE SpouseLinker SHALL 向用户展示确认对话框，提示当前已有配偶关系，询问是否替换，并在用户确认后才执行替换操作。
6. WHEN SpouseLinker 完成添加配偶操作，THE FamilyController SHALL 调用 `saveToDisk` 将更新后的数据持久化。



# Bugfix 需求文档

## 简介

本文档描述三个相互关联的 Bug 修复，以及一项与导出功能相关的附加功能：

- **Bug 1（删除联动）**：`FamilyController.deletePerson` 在删除某人时，未清除其他人对该人的引用（`parentsIds`、`childrenIds`、`spouseId`），导致引用断裂，进而使 `GalaxyPainter` 高亮逻辑失效（"无法发亮"）。
- **Bug 2（颜色层级映射）**：`GalaxyPainter` 绘制节点时，颜色未基于相对于当前主人公的绝对代际差（Generation Offset）计算，导致不同代际颜色区分不明显或重叠。
- **Bug 3（智能导出距离变远）**：`DfsExtractor` 导出数据时未将中心人的 `depth` 强制设为 0，且导出范围不完整（缺少父母的兄弟姐妹等核心成员），导致重新导入后布局算法失去参考点，节点间距离变远。
- **Bug 4（配偶字段冗余导致连线缺失）**：`Person` 模型同时存在 `spouse` 和 `spouseId` 两个语义相同的字段，不同模块分别依赖不同字段，导致 `addSpouse` 写入 `spouseId` 后 `calculateGenerations` 等依赖 `spouse` 的逻辑找不到配偶节点，配偶成为孤立节点无连线。修复方案：统一保留 `spouseId`，废弃 `spouse`，`fromMap` 兼容读取旧数据。
- **附加功能（动态中心重构）**：在详情侧边栏新增"以此人为中心查看"按钮，点击后更新 `FamilyController.mainPersonId`，触发 `GalaxyPainter` 以新中心人为 `(0,0)` 重绘。

---

## Bug 分析

### Bug 1：删除联动问题

#### Current Behavior（缺陷）

1.1 WHEN 用户删除某人 A，且 A 的父母或子女存在于 `people` Map 中，THEN 系统仅从 `people` Map 中移除 A 本身，但未遍历全量人员清除其他人对 A 的 `parentsIds`、`childrenIds`、`spouseId` 引用，导致悬空引用残留

1.2 WHEN `GalaxyPainter` 尝试根据 `people` Map 渲染高亮节点，且 Map 中存在指向已删除 ID 的悬空引用，THEN 系统无法正确解析节点关系，导致高亮（发亮）逻辑失效

#### Expected Behavior（正确）

2.1 WHEN 用户删除某人 A，THEN 系统 SHALL 仅从 `people` Map 中移除 A 本身，禁止递归删除 A 的父母或子女

2.2 WHEN 用户删除某人 A，THEN 系统 SHALL 遍历 `people` Map 中的全量人员，将所有人的 `parents` 列表、`children` 列表、`spouseId` 字段中包含 A 的 ID 的引用全部清除

2.3 WHEN 删除操作完成后，THEN 系统 SHALL 确保 `people` Map 中不存在任何指向已删除 ID 的悬空引用

#### Unchanged Behavior（回归防护）

3.1 WHEN 用户删除某人 A，且 A 不是 `root`，THEN 系统 SHALL CONTINUE TO 正常完成删除操作并持久化

3.2 WHEN 用户删除某人 A 后，其父母和子女仍存在于 `people` Map 中，THEN 系统 SHALL CONTINUE TO 正确渲染这些人员的节点和高亮效果

3.3 WHEN 用户尝试删除 `root` 节点，THEN 系统 SHALL CONTINUE TO 拒绝删除操作（保持现有保护逻辑）

---

### Bug 2：颜色层级映射错误

#### Current Behavior（缺陷）

1.3 WHEN `GalaxyPainter` 绘制家谱节点，THEN 系统使用固定颜色或未基于相对于当前主人公的代际差（Generation Offset）分配颜色，导致曾祖辈、祖辈、本辈、子辈、孙辈的颜色区分不明显或重叠

#### Expected Behavior（正确）

2.4 WHEN `GalaxyPainter` 绘制某节点，THEN 系统 SHALL 计算该节点相对于当前主人公的代际差（Generation Offset），并从 `AppTheme` 中为五代人（曾祖辈 offset≤-2、祖辈 offset=-1、本辈 offset=0、子辈 offset=1、孙辈 offset≥2）分别映射显著区分的颜色

2.5 WHEN `AppTheme` 定义代际颜色，THEN 系统 SHALL 为五代人提供视觉上显著区分的颜色常量（不得使用相近色或相同色）

#### Unchanged Behavior（回归防护）

3.4 WHEN `GalaxyPainter` 绘制节点，THEN 系统 SHALL CONTINUE TO 正确渲染节点的位置、大小和连线逻辑，不受颜色映射变更影响

3.5 WHEN 主人公（offset=0）节点被绘制，THEN 系统 SHALL CONTINUE TO 以本辈颜色高亮显示

---

### Bug 3：智能导出后"距离变远"问题

#### Current Behavior（缺陷）

1.4 WHEN `DfsExtractor` 导出以某人为中心的家谱数据，THEN 系统未将中心人的 `depth` 强制设为 0，导致导入后布局算法无法以中心人为参考原点

1.5 WHEN 导出数据被重新导入并解析，THEN 系统未将新中心人的坐标重置为屏幕中心 `(0, 0)`，导致节点间距离变远、布局失去参考

1.6 WHEN `DfsExtractor` 确定导出范围，THEN 系统仅提取上下各 2 代血亲，未包含"核心成员全家桶"（中心人父母的所有子女及配偶、中心人所有子女及配偶、中心人配偶），导致导出数据不完整

#### Expected Behavior（正确）

2.6 WHEN `DfsExtractor` 导出以 `centerId` 为中心的数据，THEN 系统 SHALL 强制将 `centerId` 对应节点的 `depth` 设为 0

2.7 WHEN 导入数据解析时识别到新中心人，THEN 系统 SHALL 将新中心人的坐标重置为屏幕中心 `(0, 0)`

2.8 WHEN `DfsExtractor` 确定导出范围，THEN 系统 SHALL 按"核心成员全家桶"规则提取：向上找 1 代（父母）及其所有子女和配偶，向下包含中心人所有子女及配偶，横向包含中心人配偶

#### Unchanged Behavior（回归防护）

3.6 WHEN `DfsExtractor` 执行提取，THEN 系统 SHALL CONTINUE TO 排除超出范围的远亲节点，不因范围扩展而无限膨胀

3.7 WHEN 导出数据被重新导入，THEN 系统 SHALL CONTINUE TO 生成可被标准 JSON 解析器成功解析的合法 JSON，且格式与现有 `exportToJSON` 兼容

---

### Bug 4：配偶字段冗余导致连线缺失

#### Current Behavior（缺陷）

1.8 WHEN 用户为"我"（root）或其兄弟姐妹添加配偶，THEN 系统在 `addSpouse` 中仅设置了 `spouseId` 字段，未同步更新 `spouse` 字段，导致 `calculateGenerations`、`gift_record_dialog` 等依赖 `person.spouse` 的逻辑无法找到配偶节点，配偶节点成为孤立节点、无连线、亲缘关系处不显示

1.9 WHEN 用户再次尝试为同一人添加配偶，THEN 系统因 `spouseId` 已存在而提示"已有配偶"，但界面上配偶节点仍无连线，形成数据与视图不一致的状态

1.10 WHEN `Person` 模型同时存在 `spouse` 和 `spouseId` 两个语义相同的字段，THEN 不同模块分别依赖不同字段，导致数据不一致且难以维护

#### Expected Behavior（正确）

2.11 WHEN `Person` 模型定义配偶关系，THEN 系统 SHALL 统一使用单一字段 `spouseId`，废弃 `spouse` 字段

2.12 WHEN `Person.fromMap` 解析历史数据，THEN 系统 SHALL 将旧 `spouse` 字段的值合并读入 `spouseId`（向后兼容），确保历史数据不丢失

2.13 WHEN `addSpouse`、`addParent`、`calculateGenerations`、`gift_record_dialog` 等所有模块访问配偶关系，THEN 系统 SHALL 统一读写 `spouseId` 字段

#### Unchanged Behavior（回归防护）

3.10 WHEN 用户为任意人员添加配偶，THEN 系统 SHALL CONTINUE TO 正确渲染配偶节点与连线，不受被操作人的 ID 或层级影响

3.11 WHEN 用户为已有子女的人添加配偶，THEN 系统 SHALL CONTINUE TO 将配偶 ID 加入所有子女的 `parents` 列表

3.12 WHEN 导入包含旧 `spouse` 字段的历史 JSON 数据，THEN 系统 SHALL CONTINUE TO 正确解析配偶关系，不丢失任何已有数据

---

### 附加功能：动态中心重构

#### Current Behavior（缺陷）

1.7 WHEN 用户在详情侧边栏查看某人信息，THEN 系统未提供"以此人为中心查看"的入口，用户无法动态切换家谱视图的中心人

#### Expected Behavior（正确）

2.9 WHEN 用户在 `PersonDetailsSidebar` 中点击"以此人为中心查看"按钮，THEN 系统 SHALL 更新 `FamilyController` 中的 `mainPersonId` 为该人的 ID

2.10 WHEN `mainPersonId` 更新后，THEN 系统 SHALL 触发 `GalaxyPainter` 重绘，以新中心人为 `(0, 0)` 重新计算所有节点的代际差、距离和大小

#### Unchanged Behavior（回归防护）

3.8 WHEN 用户切换中心人后，THEN 系统 SHALL CONTINUE TO 保持 `people` Map 中所有人员数据不变，仅视图参考点发生变化

3.9 WHEN 用户切换中心人后，THEN 系统 SHALL CONTINUE TO 支持再次切换中心人，不限制切换次数

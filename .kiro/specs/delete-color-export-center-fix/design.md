# delete-color-export-center-fix Bugfix Design

## Overview

本文档描述四个 Bug 的修复设计，以及一项附加功能的实现方案。

- **Bug 1（删除联动）**：`deletePerson` 未清除其他人对已删除 ID 的 `spouseId` 引用，导致悬空引用使 `GalaxyPainter` 高亮失效。
- **Bug 2（颜色层级映射）**：`GalaxyLayoutEngine.generationColor` 仅区分四档（< -1 / -1 / 0 / >0），五代人颜色区分不明显。
- **Bug 3（导出距离变远）**：`DfsExtractor` 未将中心人 depth 强制设为 0，且导出范围不包含父母的兄弟姐妹等核心成员。
- **Bug 4（配偶字段冗余）**：`Person` 同时存在 `spouse` 和 `spouseId`，`addSpouse` 只写 `spouseId`，`calculateGenerations` 等依赖 `spouse`，导致配偶节点孤立无连线。
- **附加功能（动态中心重构）**：侧边栏新增"以此人为中心查看"按钮，更新 `FamilyController` 中心人并触发重绘。

修复策略：最小化改动，逐 Bug 精准修复，不引入架构重构。

---

## Glossary

- **Bug_Condition (C)**：触发 Bug 的输入条件集合
- **Property (P)**：Bug 条件成立时期望的正确行为
- **Preservation**：Bug 条件不成立时，行为必须与修复前完全一致
- **deletePerson**：`FamilyController` 中删除成员的方法，位于 `lib/controllers/family_controller.dart`
- **generationColor**：`GalaxyLayoutEngine` 中根据代际差返回颜色的静态方法，位于 `lib/views/family_tree_view.dart`
- **DfsExtractor**：`lib/services/dfs_extractor.dart` 中的 BFS 导出算法，以中心人为起点提取亲属子集
- **spouseId / spouse**：`Person` 模型中两个语义相同的配偶字段，`spouse` 为旧字段，`spouseId` 为新字段
- **mainPersonId**：`FamilyController` 中标识当前视图中心人的字段（待新增）
- **generation**：`_NodePosition.generation`，相对于当前中心人的代际差（负数=祖辈，0=本辈，正数=子辈）

---

## Bug Details

### Bug 1：删除联动

#### Bug Condition

删除某人 A 时，其他人的 `spouseId` 字段可能仍指向 A 的 ID，形成悬空引用。

```
FUNCTION isBugCondition_1(deleteId, people)
  INPUT: deleteId: String, people: Map<String, Person>
  OUTPUT: boolean

  RETURN EXISTS person IN people.values
         WHERE person.spouseId == deleteId
         AND deleteId NOT IN people.keys  // 已被删除
END FUNCTION
```

#### Examples

- 删除"父亲"后，"母亲"的 `spouseId` 仍为父亲 ID → `GalaxyPainter._getSpouseIds` 通过子女反查，但 `calculateGenerations` 中 `person.spouse` 路径仍可能残留
- 删除"配偶"后，"我"的 `spouseId` 仍指向已删除 ID → `_onAddSpouseTap` 误判"已有配偶"
- 删除无子女的叶子节点 → 当前逻辑已正确处理父母/子女列表，但 `spouseId` 未清除

---

### Bug 2：颜色层级映射

#### Bug Condition

节点代际差 `generation <= -2`（曾祖辈）与 `generation == -1`（祖辈）使用同一颜色蓝色；`generation >= 1`（子辈）与 `generation >= 2`（孙辈）使用同一颜色橙色。

```
FUNCTION isBugCondition_2(generation)
  INPUT: generation: int
  OUTPUT: boolean

  RETURN (generation <= -2 AND colorOf(generation) == colorOf(-1))
      OR (generation >= 2 AND colorOf(generation) == colorOf(1))
END FUNCTION
```

#### Examples

- 曾祖辈（generation = -3）与祖辈（generation = -1）颜色相同（蓝色）→ 无法区分
- 孙辈（generation = 2）与子辈（generation = 1）颜色相同（橙色）→ 无法区分
- 本辈（generation = 0）颜色正确（绿色）→ 不受影响

---

### Bug 3：导出距离变远

#### Bug Condition

`DfsExtractor.extract` 以 `centerId` 为起点 BFS，但 `centerId` 的初始 depth 为 0，`maxGenerations = 2` 时仅提取上下各 2 代血亲，未包含父母的兄弟姐妹（父母的 depth=1，其兄弟姐妹 depth=2，但其子女 depth=3 被剪枝）。

```
FUNCTION isBugCondition_3(centerId, people, exported)
  INPUT: centerId: String, people: Map, exported: Set<String>
  OUTPUT: boolean

  centerDepth := depthOf(centerId, exported)  // 导出后中心人的 depth 字段
  RETURN centerDepth != 0
      OR missingCoreMembers(centerId, people, exported)
END FUNCTION

FUNCTION missingCoreMembers(centerId, people, exported)
  // 父母的兄弟姐妹（叔伯舅姑）未被包含
  RETURN EXISTS uncle IN siblingsOfParents(centerId, people)
         WHERE uncle.id NOT IN exported
END FUNCTION
```

#### Examples

- 以"我"为中心导出，"叔叔"（父亲的兄弟）未被包含 → 导入后家谱不完整
- 导出后重新导入，布局算法以某个非中心人为参考点 → 节点间距离变远

---

### Bug 4：配偶字段冗余

#### Bug Condition

`addSpouse` 只写 `spouseId`，但 `calculateGenerations` 中遍历配偶使用 `person.spouse`，`gift_record_dialog` 中同步配偶礼金也使用 `person.spouse`。

```
FUNCTION isBugCondition_4(person)
  INPUT: person: Person
  OUTPUT: boolean

  RETURN person.spouseId != null
     AND person.spouse == null
     AND spouseNodeIsIsolated(person)
END FUNCTION
```

#### Examples

- 为"我"添加配偶"妻子"后，`calculateGenerations` 中 `person.spouse == null` → 妻子节点不参与代际计算 → 孤立节点无连线
- `gift_record_dialog` 中"同步记录至配偶"复选框：`person.spouse == null` → 同步失效
- 导入旧数据（只有 `spouse` 字段）→ `spouseId == null` → 新逻辑找不到配偶

---

## Expected Behavior

### Preservation Requirements

**Bug 1 修复后不变的行为：**
- 删除叶子节点（无子女）的逻辑保持不变
- 删除 `root` 节点的保护逻辑保持不变
- 删除后父母/子女列表的清理逻辑保持不变

**Bug 2 修复后不变的行为：**
- 节点位置、大小、连线逻辑不受颜色变更影响
- 本辈（generation = 0）颜色保持绿色（`0xFF4CAF50`）

**Bug 3 修复后不变的行为：**
- 导出 JSON 格式与现有 `exportToJSON` 完全兼容
- 超出范围的远亲节点不被包含（无限膨胀防护）

**Bug 4 修复后不变的行为：**
- 为已有子女的人添加配偶时，配偶 ID 加入所有子女的 `parents` 列表
- 导入包含旧 `spouse` 字段的历史数据时，配偶关系不丢失

**附加功能不变的行为：**
- 切换中心人后，`people` Map 中所有人员数据不变
- 支持多次切换中心人

---

## Hypothesized Root Cause

### Bug 1

`deletePerson` 只遍历了被删除人的 `parents` 和 `children` 列表，清理了父母的 `children` 和子女的 `parents`，但**未遍历全量 `_people` Map** 清除其他人的 `spouseId` 引用。

### Bug 2

`GalaxyLayoutEngine.generationColor` 使用 `if (generation < -1)` 将所有祖辈（-2, -3, ...）归为同一颜色，使用 `return` 兜底将所有子辈（1, 2, ...）归为同一颜色，缺少对 `generation <= -2` 和 `generation >= 2` 的独立分支。

### Bug 3

`DfsExtractor.extract` 的 BFS 以 `(centerId, 0)` 为起点，`maxGenerations = 2` 时父母 depth=1，父母的兄弟姐妹 depth=2（在范围内），但父母的兄弟姐妹的子女 depth=3（被剪枝）。实际上父母的兄弟姐妹（叔伯舅姑）应被包含，但当前逻辑中 depth=2 的节点不再向下扩展（`depth + 1 <= maxGenerations` 为 false），所以叔伯舅姑的子女（堂兄弟）被剪枝，但叔伯舅姑本身应该在 depth=2 时被加入。

重新分析：父母 depth=1，父母的兄弟姐妹需要从父母出发再走一步 depth=2，在 `maxGenerations=2` 范围内，**应该被包含**。问题可能在于父母的兄弟姐妹通过 `parents` 关系连接（共同祖父母），而祖父母 depth=2，其子女（叔伯）depth=3，超出范围。

根本原因：叔伯舅姑不是通过直接血亲链接到中心人的，需要经过祖父母中转，路径长度为 3，超出 `maxGenerations=2`。修复方案：在配偶扩展阶段之前，额外添加"父母的兄弟姐妹"扩展逻辑。

### Bug 4

`addSpouse` 方法（`family_controller.dart`）创建新配偶时只设置 `spouseId`，更新 personA 时也只设置 `spouseId`，但 `calculateGenerations` 中使用 `person.spouse`（旧字段）遍历配偶，`gift_record_dialog` 中 `person.spouse` 判断配偶是否存在。两个字段语义相同但读写路径不一致。

---

## Correctness Properties

Property 1: Bug Condition 1 - 删除后无悬空引用

_For any_ 删除操作 `deletePerson(id)`，修复后的函数 SHALL 确保 `people` Map 中所有人员的 `spouseId`、`parents`、`children` 字段均不包含已删除的 `id`。

**Validates: Requirements 2.2, 2.3**

Property 2: Preservation 1 - 删除操作回归防护

_For any_ 不涉及 `spouseId` 引用的删除操作（被删除人无配偶），修复后的 `deletePerson` SHALL 产生与修复前完全相同的结果，父母/子女列表清理逻辑不变。

**Validates: Requirements 3.1, 3.2, 3.3**

Property 3: Bug Condition 2 - 五代颜色显著区分

_For any_ 代际差 `generation` 属于 {≤-2, -1, 0, 1, ≥2} 五档，修复后的 `generationColor` SHALL 为每档返回视觉上显著不同的颜色，任意两档颜色不得相同。

**Validates: Requirements 2.4, 2.5**

Property 4: Preservation 2 - 颜色映射回归防护

_For any_ `generation == 0`（本辈），修复后的 `generationColor` SHALL 返回与修复前相同的颜色（绿色 `0xFF4CAF50`），节点渲染逻辑不受影响。

**Validates: Requirements 3.4, 3.5**

Property 5: Bug Condition 3 - 导出包含核心成员

_For any_ 以 `centerId` 为中心的导出操作，修复后的 `DfsExtractor.extract` SHALL 包含中心人的父母的所有兄弟姐妹（叔伯舅姑）及其配偶。

**Validates: Requirements 2.6, 2.8**

Property 6: Preservation 3 - 导出格式兼容性

_For any_ 导出操作，修复后的导出结果 SHALL 生成合法 JSON，格式与现有 `exportToJSON` 完全兼容，且不包含超出范围的远亲节点。

**Validates: Requirements 3.6, 3.7**

Property 7: Bug Condition 4 - 配偶字段统一

_For any_ `addSpouse` 操作后，修复后的 `Person` SHALL 使 `spouseId` 字段有效，且 `calculateGenerations`、`gift_record_dialog` 等所有模块均能通过 `spouseId` 正确找到配偶节点。

**Validates: Requirements 2.11, 2.13**

Property 8: Preservation 4 - 旧数据兼容性

_For any_ 包含旧 `spouse` 字段的历史 JSON 数据，修复后的 `Person.fromMap` SHALL 将 `spouse` 值合并读入 `spouseId`，不丢失任何已有配偶关系。

**Validates: Requirements 2.12, 3.12**

---

## Fix Implementation

### Bug 1：deletePerson 补充 spouseId 清理

**File**: `lib/controllers/family_controller.dart`

**Function**: `deletePerson`

**Specific Changes**:

1. 在现有"Remove from parents' children lists"和"Remove from children's parents lists"逻辑之后，新增遍历全量 `_people` Map 的循环：
   - 对每个 `person`，若 `person.spouseId == id`，则重建该 `person` 并将 `spouseId` 置为 `null`
   - 同时检查旧 `spouse` 字段（向后兼容），若 `person.spouse == id`，也置为 `null`

```
// 伪代码
for each (pid, person) in _people:
  if person.spouseId == id OR person.spouse == id:
    _people[pid] = person.copyWith(
      spouseId: person.spouseId == id ? null : person.spouseId,
      spouse:   person.spouse   == id ? null : person.spouse,
    )
```

---

### Bug 2：generationColor 扩展为五档

**File**: `lib/views/family_tree_view.dart`

**Function**: `GalaxyLayoutEngine.generationColor`

**Specific Changes**:

将现有四档映射扩展为五档，新增曾祖辈（≤-2）和孙辈（≥2）的独立颜色：

```
// 修复前（四档）
if (generation < -1) return Color(0xFF2196F3); // 蓝（祖辈+曾祖辈混用）
if (generation == -1) return Color(0xFFFFC107); // 黄
if (generation == 0) return Color(0xFF4CAF50);  // 绿
return Color(0xFFFF5722);                        // 橙（子辈+孙辈混用）

// 修复后（五档）
if (generation <= -2) return Color(0xFF9C27B0); // 紫（曾祖辈）
if (generation == -1) return Color(0xFF2196F3); // 蓝（祖辈）
if (generation == 0)  return Color(0xFF4CAF50); // 绿（本辈，不变）
if (generation == 1)  return Color(0xFFFFC107); // 黄（子辈）
return Color(0xFFFF5722);                        // 橙（孙辈）
```

同时在 `AppTheme` 中新增五代颜色常量，供 `GalaxyLayoutEngine` 引用：

```dart
static const Color genAncestor2  = Color(0xFF9C27B0); // 曾祖辈 - 紫
static const Color genAncestor1  = Color(0xFF2196F3); // 祖辈   - 蓝
static const Color genSelf       = Color(0xFF4CAF50); // 本辈   - 绿
static const Color genChild1     = Color(0xFFFFC107); // 子辈   - 黄
static const Color genChild2     = Color(0xFFFF5722); // 孙辈   - 橙
```

---

### Bug 3：DfsExtractor 扩展核心成员范围

**File**: `lib/services/dfs_extractor.dart`

**Function**: `DfsExtractor.extract`

**Specific Changes**:

在配偶扩展阶段之后，新增"父母的兄弟姐妹"扩展阶段：

1. 收集中心人的所有父母 ID（`centerPerson.parents`）
2. 对每个父母，找到其父母（祖父母）
3. 对每个祖父母，遍历其 `children`，将不在 `result` 中的兄弟姐妹（叔伯舅姑）加入 `result`
4. 对新加入的叔伯舅姑，同样执行配偶扩展（`spouseId` 非空则加入）

```
// 伪代码：父母的兄弟姐妹扩展
centerPerson := people[centerId]
for parentId in centerPerson.parents:
  parent := people[parentId]
  for grandparentId in parent.parents:
    grandparent := people[grandparentId]
    for uncleId in grandparent.children:
      if uncleId != parentId AND people.containsKey(uncleId):
        result.add(uncleId)
        // 配偶扩展
        uncle := people[uncleId]
        if uncle.spouseId != null AND people.containsKey(uncle.spouseId):
          result.add(uncle.spouseId)
```

---

### Bug 4：统一配偶字段为 spouseId

**Files**:
- `lib/models/person.dart`
- `lib/controllers/family_controller.dart`
- `lib/widgets/gift_record_dialog.dart`

**Specific Changes**:

1. **`Person.fromMap`**：`spouseId` 读取逻辑改为 `spouseIdRaw ?? spouseRaw`（向后兼容旧 `spouse` 字段）

2. **`FamilyController.calculateGenerations`**：将 `person.spouse` 替换为 `person.spouseId`

3. **`FamilyController.aiContextSummary`**：将 `p.spouse` 替换为 `p.spouseId`

4. **`FamilyController.addParent`**：创建新父母时 `spouse: existingParentId` 改为 `spouseId: existingParentId`；更新旧父母时 `spouse: newId` 改为 `spouseId: newId`，同时移除 `spouse` 参数

5. **`GiftRecordDialog._submit`**：将 `person.spouse` 替换为 `person.spouseId`

---

### 附加功能：动态中心重构

**Files**:
- `lib/controllers/family_controller.dart`
- `lib/widgets/person_details_sidebar.dart`
- `lib/views/family_tree_view.dart`

**Specific Changes**:

1. **`FamilyController`**：
   - 将 `_centerPersonId` 从 `final String` 改为 `String _mainPersonId = 'root'`
   - 新增 getter `String get mainPersonId => _mainPersonId`
   - 新增方法 `void setMainPerson(String id)` → 更新 `_mainPersonId`，调用 `notifyListeners()`
   - `calculateGenerations`、`GalaxyLayoutEngine.compute` 的 `rootId` 参数改为使用 `mainPersonId`

2. **`PersonDetailsSidebar`**：
   - 新增 `VoidCallback? onSetAsCenter` 回调参数
   - 在操作区新增"以此人为中心查看"按钮，调用 `onSetAsCenter`
   - 仅当 `person.id != controller.mainPersonId` 时显示该按钮

3. **`FamilyTreeView`**：
   - `GalaxyLayoutEngine.compute` 的 `rootId` 改为 `widget.controller.mainPersonId`
   - `PersonDetailsSidebar` 传入 `onSetAsCenter` 回调，调用 `widget.controller.setMainPerson(id)` 并关闭侧边栏

---

## Testing Strategy

### Validation Approach

两阶段验证：先在未修复代码上运行探索性测试，确认 Bug 可复现；再在修复后运行修复验证测试和保留性测试。

---

### Exploratory Bug Condition Checking

**Goal**: 在未修复代码上复现 Bug，确认根因分析正确。

**Test Cases**:

1. **Bug 1 探索**：创建 A（有配偶 B），删除 B，断言 A 的 `spouseId` 仍为 B 的 ID（在未修复代码上应通过，证明悬空引用存在）
2. **Bug 2 探索**：调用 `GalaxyLayoutEngine.generationColor(-2)` 和 `generationColor(-1)`，断言两者颜色相同（在未修复代码上应通过）
3. **Bug 3 探索**：构造包含叔伯的家谱，以中心人导出，断言叔伯 ID 不在导出集合中（在未修复代码上应通过）
4. **Bug 4 探索**：调用 `addSpouse`，断言 `person.spouse == null` 且 `calculateGenerations` 中配偶节点不参与遍历（在未修复代码上应通过）

**Expected Counterexamples**:
- Bug 1：删除后 `spouseId` 未被清除
- Bug 2：`generationColor(-2) == generationColor(-1)`
- Bug 3：叔伯 ID 不在导出集合中
- Bug 4：`person.spouse == null` 导致配偶节点孤立

---

### Fix Checking

**Goal**: 验证修复后 Bug 条件成立时行为正确。

**Pseudocode:**
```
// Bug 1
FOR ALL (deleteId, people) WHERE isBugCondition_1(deleteId, people) DO
  deletePerson_fixed(deleteId)
  ASSERT NOT EXISTS p IN people.values WHERE p.spouseId == deleteId
END FOR

// Bug 2
FOR ALL generation IN {-3, -2, -1, 0, 1, 2, 3} DO
  colors := {generationColor_fixed(g) | g IN {-3,-2,-1,0,1,2,3}}
  ASSERT allDistinct(colors[{≤-2}], colors[-1], colors[0], colors[1], colors[{≥2}])
END FOR

// Bug 3
FOR ALL centerId WHERE isBugCondition_3 DO
  exported := DfsExtractor_fixed.extract(centerId)
  ASSERT siblingsOfParents(centerId) ⊆ exported
END FOR

// Bug 4
FOR ALL person WHERE isBugCondition_4 DO
  addSpouse_fixed(person.id, ...)
  ASSERT person_fixed.spouseId != null
  ASSERT calculateGenerations_fixed() includes spouseNode
END FOR
```

---

### Preservation Checking

**Goal**: 验证修复后 Bug 条件不成立时行为与修复前完全一致。

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT fixedFunction(input) == originalFunction(input)
END FOR
```

**Test Cases**:

1. **Bug 1 保留**：删除无配偶的叶子节点，父母/子女列表清理结果与修复前一致
2. **Bug 2 保留**：`generationColor(0)` 返回绿色 `0xFF4CAF50`，与修复前一致
3. **Bug 3 保留**：导出 JSON 格式合法，不包含超出范围的远亲
4. **Bug 4 保留**：导入含旧 `spouse` 字段的 JSON，配偶关系正确解析

---

### Unit Tests

- `deletePerson` 删除有配偶的人后，配偶的 `spouseId` 为 null
- `deletePerson` 删除无配偶的叶子节点，父母/子女列表正确更新
- `generationColor` 五档颜色各不相同
- `DfsExtractor.extract` 包含叔伯舅姑
- `DfsExtractor.extract` 不包含超出范围的远亲
- `Person.fromMap` 兼容旧 `spouse` 字段
- `addSpouse` 后 `spouseId` 正确设置，`calculateGenerations` 包含配偶节点

### Property-Based Tests

- 随机生成家谱，删除任意非 root 节点后，`people` Map 中不存在指向已删除 ID 的 `spouseId` 引用（对应 Property 1）
- 随机生成 generation 值，`generationColor` 对五档始终返回不同颜色（对应 Property 3）
- 随机生成包含叔伯的家谱，`DfsExtractor.extract` 始终包含叔伯（对应 Property 5）
- 随机生成含旧 `spouse` 字段的 JSON，`Person.fromMap` 始终正确解析 `spouseId`（对应 Property 8）

### Integration Tests

- 完整流程：添加配偶 → 删除配偶 → 验证原人员 `spouseId` 为 null，`GalaxyPainter` 高亮正常
- 完整流程：构造五代家谱 → 验证各代节点颜色显著不同
- 完整流程：导出 → 导入 → 验证叔伯节点存在，布局参考点正确
- 完整流程：添加配偶 → 验证配偶节点有连线，礼金同步功能正常
- 完整流程：点击"以此人为中心查看" → 验证 `mainPersonId` 更新，画布重绘以新中心人为原点

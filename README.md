<div align="center">

# ⛩️ ClanGraph · 家族智慧图谱

*重建有温度的家族连接，让每一份人情都有迹可循*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-%2302569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-%230175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Zhipu AI](https://img.shields.io/badge/ZhipuAI-GLM--4.5_air_%7C_GLM--4.6V-6B3EFF?style=for-the-badge)](https://open.bigmodel.cn)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-lightgrey?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 📖 项目简介

**ClanGraph** 是一款专为中国乡土社交语境深度设计的 **智能家族关系管理 × 人情洞察 Agent**。

在中国的人情社会中，每个人都面临三大难题：

> **「亲戚叫不出」「随礼记不住」「关系理不清」**

ClanGraph 以家族图谱为骨架、以社交 CRM 为血肉、以端侧 AI 为大脑，用结构化数据与 AI 推理来解码这张复杂的人情网络。它不是一个普通的家谱 App——它是一个能听懂自然语言、能操作真实数据、能给出建议的 **AI Agent**。

---

## ✨ 核心功能

### 🕸️ 家族图谱拓扑引擎

基于图论构建多叉家族树，采用 BFS 代数层级算法动态计算每位成员的辈分序列。支持一键切换中心节点（"以爸爸为中心看"），关系脉络实时重算。节点大小表示亲疏远近，颜色区分辈分差异。

### 💰 人情记事本（社交 CRM）

深度集成随礼管理模块。追踪每一笔人情往来的时间、事件、金额。支持按时间线查看、按事件类型筛选，将口耳相传的人情债务转化为可量化的数据。

### 🤖 AI Agent 工具调用系统

AI 不只是聊天——它可以**操作真实数据**。系统定义了 7 个本地工具供模型调用：

| 工具 | 功能 |
|------|------|
| `search_family_members` | 按姓名/称呼搜索成员 |
| `get_member_details` | 查看成员完整关系网（父母、配偶、子女、兄弟姐妹、礼金记录） |
| `get_family_branch` | 展开某人的后代分支树 |
| `get_gift_summary` | 统计全家族或某人的礼金汇总 |
| `set_graph_center` | 切换图谱中心节点 |
| `recommend_gift_amount` | 基于历史数据 + 亲疏距离推荐礼金金额 |
| `add_family_member` | 对话式创建成员并自动建立关系 |

支持多轮工具调用循环，模型可以连续调用多个工具完成复杂查询。

### 👁️ 视觉礼单识别

拍照或上传手写礼单，`GLM-4.6V` 多模态模型自动提取姓名、金额、事件、日期。支持多图并发识别 + 自动去重，一键导入随礼记录。图片上传前自动压缩（1024px, 70% 质量），节省 token。

### 📊 统计看板

年度礼金趋势柱状图 + 事件类型分布饼图，一目了然。支持年份切换，自动从历史数据中提取可用年份。

### 🖼️ 图谱图片导出

一键将当前家族图谱导出为高清图片，保存到系统相册。

### 🔒 隐私优先

所有成员信息、礼金数额、备注内容均通过 `SharedPreferences` 本地持久化。AI 推理仅传输必要数据，无后端服务器、无数据收集、无埋点上报。

---

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────────────┐
│                 Presentation Layer                  │
│   FamilyTreeView  ·  AIAssistantView                │
│   StatsDashboard  ·  PersonDetailsSidebar           │
├─────────────────────────────────────────────────────┤
│                   Business Layer                    │
│        FamilyController (ChangeNotifier)            │
│   图论拓扑推导  ·  代数层级算法  ·  关系链计算        │
├─────────────────────────────────────────────────────┤
│                   Service Layer                     │
│   AIService (Zhipu SDK)  ·  FamilyAgentTools        │
│   GLM-4.5-air (Text + Tool Calling)                 │
│   GLM-4.6V (Vision OCR)                             │
├─────────────────────────────────────────────────────┤
│                    Data Layer                       │
│         Person Model  ·  GiftRecord Model           │
│         SharedPreferences (Local Persistence)       │
└─────────────────────────────────────────────────────┘
```

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| UI 框架 | Flutter 3.x (Dart 3.11) | 跨平台声明式 UI，深空灰科技感主题 |
| 状态管理 | `ChangeNotifier` | 轻量响应式 |
| 持久化 | `shared_preferences` | 纯端侧 JSON 存储 |
| AI 通信 | `dio` + 智谱 OpenAI 兼容接口 | 长超时策略，支持 tool_calling |
| 图像处理 | `image_picker` + `flutter_image_compress` | 压缩后传入视觉模型 |
| 图表 | `fl_chart` | 柱状图 + 饼图 |
| 配置管理 | `flutter_dotenv` | API Key 外置 `.env` |

---

## 📁 项目结构

```
lib/
├── main.dart                       # 应用入口
├── controllers/
│   └── family_controller.dart      # 核心状态管理 & 图谱拓扑
├── models/
│   ├── person.dart                 # 成员 & 礼金数据模型
│   └── export_config.dart          # 导出配置模型
├── services/
│   ├── ai_service.dart             # 智谱双引擎调度（文本 + 视觉）
│   ├── family_agent_tools.dart     # AI Agent 工具定义 & 执行器
│   ├── demo_data.dart              # 预置三代家族 Demo 数据
│   ├── dfs_extractor.dart          # BFS 亲属提取算法
│   ├── export_filter.dart          # 导出维度过滤器
│   └── z_algorithm.dart            # 分层涟漪布局算法
├── theme/
│   └── app_theme.dart              # 深空灰主题 & 辈分配色
├── views/
│   ├── family_tree_view.dart       # 家族图谱主视图
│   └── ai_assistant_view.dart      # AI 助手对话界面
└── widgets/
    ├── person_node_widget.dart      # 图谱节点渲染
    ├── person_dialog.dart           # 成员编辑弹窗
    ├── person_details_sidebar.dart  # 成员详情侧边栏
    ├── gift_record_dialog.dart      # 礼金记录管理
    ├── stats_dashboard.dart         # 统计看板（图表）
    ├── floating_ai_assistant.dart   # 悬浮 AI 按钮
    ├── glassmorphic_container.dart  # 毛玻璃 UI 组件
    ├── spring_button.dart           # 弹性动画按钮
    ├── export_dialog.dart           # 导出弹窗
    └── share_config_page.dart       # 导出配置页
```

---

## 🚀 快速开始

### 环境要求

- Flutter SDK `>= 3.11.0`
- Dart SDK `>= 3.0.0`
- 智谱 AI API Key（[免费申请](https://open.bigmodel.cn)）

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/CerfH/ClanGraph.git
cd ClanGraph

# 2. 安装依赖
flutter pub get

# 3. 创建 .env 文件并配置 API Key（参考下方配置项）

# 4. 运行
flutter run
```

### .env 配置项

```env
ZHIPU_API_KEY=你的API Key
ZHIPU_BASE_URL=https://open.bigmodel.cn/api/paas/v4/
ZHIPU_MODEL_TEXT=glm-4.5-air
ZHIPU_MODEL_VISION=glm-4.6v
```

---

## 🧪 测试

```bash
flutter test
```

包含 9 个测试文件，覆盖数据模型、控制器、Agent 工具、布局算法、导出过滤器、DFS 提取器等核心模块。

---

## 🛡️ 隐私声明

- **本地存储优先**：所有成员信息、礼金数额、备注内容仅存储于设备本地
- **AI 最小权限**：调用视觉模型时仅传输必要的图像数据，不构建用户画像
- **无后端服务器**：无数据收集、无埋点上报

---

## 📄 License

MIT License. 详见 [LICENSE](LICENSE) 文件。

---

<div align="center">

*Built with ❤️ for Chinese family culture · 为中华家族文化而生*

</div>

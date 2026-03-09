<div align="center">

# ⛩️ ClanGraph · 家族智慧图谱

*重建有温度的家族连接，让每一份人情都有迹可循*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-%2302569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-%230175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Zhipu AI](https://img.shields.io/badge/ZhipuAI-GLM--4.5_air_%7C_GLM--4.6V-6B3EFF?style=for-the-badge)](https://open.bigmodel.cn)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS-lightgrey?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-Private-red?style=for-the-badge)]()

</div>

---

## 📖 项目简介

**ClanGraph** 是一款专为中国乡土社交语境深度设计的 **智能家族关系管理 × 人情洞察 Agent**。

它不是一个普通的家谱 App——它是一个以家族图谱为骨架、以社交 CRM 为血肉、以端侧 AI 为大脑的复合型智能体。在"互联网改变社交"的浪潮下，ClanGraph 致力于用结构化数据与 AI 推理，解码中国乡土人情网络中最复杂的三大痛点：

> **「亲戚叫不出」「随礼记不住」「关系理不清」**

---

## ✨ 核心功能

### 🕸️ 智能拓扑推导引擎
基于图论（Graph Theory）构建多叉家族树，采用 **代数层级（ClanCompass）** 算法动态计算每位成员的辈分序列。支持一键切换图谱中心节点，关系脉络实时重算——无论家族规模多大，辈分关系一目了然。

### 💰 人情记事本（社交 CRM）
深度集成随礼管理模块，以 **回礼天平** 模型追踪每一笔人情往来的收支平衡。支持按时间线查看随礼趋势、标注场合类型，将口耳相传的人情债务转化为可量化的社交资产。

### 🤖 AI 双引擎驱动

| 能力 | 模型 | 使用场景 |
|------|------|----------|
| 🧠 关系推理对话 | `GLM-4.5-air` | 多轮上下文问答，支持长记忆会话 |
| 👁️ 礼单视觉识别 | `GLM-4.6V` | 拍照/上传手写礼单，自动结构化提取 |

AI 助手以家族成员数据为上下文，支持自然语言提问：*「我跟王大伯家小明是什么关系？」*、*「近三年给张叔叔家随礼总额是多少？」*

### 🔒 隐私优先，数据不出设备
所有成员信息、礼金数额、备注内容均通过 `SharedPreferences` **本地持久化**，AI 推理遵循最小化权限原则，拒绝任何形式的云端用户画像。

---

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────────────┐
│                   Presentation Layer                │
│   FamilyTreeView  ·  AIAssistantView                │
│   PersonNode  ·  PersonDetailSidebar  ·  GiftDialog │
├─────────────────────────────────────────────────────┤
│                    Business Layer                   │
│        FamilyController (ChangeNotifier)            │
│   图论拓扑推导  ·  代数层级算法  ·  关系链计算        │
├─────────────────────────────────────────────────────┤
│                    Service Layer                    │
│              AIService (Zhipu SDK)                  │
│   GLM-4.5-air (Text)  ·  GLM-4.6V (Vision)         │
│   Dio HTTP Client  ·  Image Compress Pipeline       │
├─────────────────────────────────────────────────────┤
│                     Data Layer                      │
│         Person Model  ·  GiftRecord Model           │
│         SharedPreferences (Local Persistence)       │
└─────────────────────────────────────────────────────┘
```

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| UI 框架 | Flutter 3.x (Dart 3.11) | 跨平台声明式 UI，深空灰科技感主题 |
| 状态管理 | `ChangeNotifier` + `Provider` | 轻量响应式，零冗余 |
| 持久化 | `SharedPreferences ^2.2.2` | 纯端侧存储，隐私优先 |
| AI 通信 | `Dio ^5.9.2` + 智谱 OpenAI 兼容接口 | 长超时策略，支持流式扩展 |
| 图像处理 | `image_picker ^1.2.1` + `flutter_image_compress ^2.3.0` | 压缩后传入视觉模型，减少 token 消耗 |
| 配置管理 | `flutter_dotenv ^6.0.0` | API Key 与模型端点外置 `.env` |

---

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口 & 路由
├── controllers/
│   └── family_controller.dart   # 核心大脑：图谱拓扑 & 状态管理
├── models/
│   └── person.dart              # 成员数据模型 & 礼金记录
├── services/
│   └── ai_service.dart          # 智谱双引擎统一调度（文字/视觉）
├── views/
│   ├── family_tree_view.dart    # 家族图谱主视图
│   └── ai_assistant_view.dart   # AI 智能助手对话界面
├── widgets/
│   ├── person_node_widget.dart  # 图谱节点渲染组件
│   ├── person_dialog.dart       # 成员信息编辑弹窗
│   ├── person_details_sidebar.dart # 成员详情侧边栏
│   └── gift_record_dialog.dart  # 礼金记录管理弹窗
└── theme/                       # 深空灰主题配置
```

---

## 🚀 快速开始

### 环境要求

- Flutter SDK `>= 3.11.0`
- Dart SDK `>= 3.0.0`
- 智谱 AI API Key（[申请地址](https://open.bigmodel.cn)）

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/CerfH/ClanGraph.git
cd ClanGraph

# 2. 安装依赖
flutter pub get

# 3. 配置环境变量
cp .env.example .env
# 编辑 .env，填入你的 ZHIPU_API_KEY

# 4. 运行
flutter run
```

### .env 配置项

```env
ZHIPU_API_KEY=your_api_key_here
ZHIPU_BASE_URL=https://open.bigmodel.cn/api/paas/v4/
ZHIPU_MODEL_TEXT=glm-4.5-air
ZHIPU_MODEL_VISION=glm-4.6v
```

---

## 📅 Roadmap

- [x] 核心家族图谱拓扑推导算法
- [x] 深空灰科技感 UI 主题系统
- [x] 人情往来数据模型与本地持久化
- [x] 智谱 GLM 双引擎 AI 服务层
- [x] 视觉礼单识别（GLM-4.6V 多模态）
- [x] AI 多轮上下文对话（长记忆 Session）
- [ ] 导出高清家族图谱海报
- [ ] 智能称呼换算器（根据关系链自动生成标准中文称谓）
- [ ] 家族事件日历（生日、节日、红白喜事提醒）
- [ ] 多家族数据隔离与切换

---

## 🛡️ 隐私声明

ClanGraph 将用户隐私置于首位。核心原则如下：

- **本地存储优先**：所有成员信息、礼金数额、备注内容均仅存储于用户设备本地
- **AI 最小权限**：调用视觉模型时仅传输必要的图像数据，不构建任何用户画像
- **无后端服务器**：应用不运行任何自有服务端，无数据收集、无埋点上报

---

<div align="center">

*Built with ❤️ for Chinese family culture · 为中华家族文化而生*

</div>

# ClanGraph (家族智慧图谱)

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Gemini](https://img.shields.io/badge/Gemini-AI-orange?style=for-the-badge)](https://deepmind.google/technologies/gemini/)

**ClanGraph** 是一款专为中国乡土社交语境设计的智能家族关系管理与人情洞察工具。它不仅是一个家谱绘图板，更是一个基于端侧 AI 的社交关系 Agent。

---

## 🌟 核心愿景
在数字化时代，重建有温度的家族连接。通过 AI 视觉识别和结构化数据分析，解决“亲戚叫不出”、“随礼记不住”、“关系理不清”的社交痛点。

## 🚀 核心功能
* **智能拓扑推导**：基于图论算法自动计算家族辈分与亲疏关系，支持动态中心切换。
* **人情记事本**：深度集成社交 CRM，记录每一份人情往来，支持历史随礼趋势分析。
* **AI 礼单识别 (Coming Soon)**：集成 Google Gemini Vision 引擎，一键拍照识别手写礼单。
* **硬核性能**：针对端侧进行优化，确保在处理庞大家族树时依然保持流畅的交互体验。

## 🛠 技术架构
* **Frontend**: Flutter (Dart) - 响应式 UI 与声明式状态管理。
* **Logic**: `FamilyController` (ChangeNotifier) - 核心业务逻辑与拓扑算法中心。
* **Storage**: `Shared Preferences` - 本地数据持久化，确保隐私数据不出终端。
* **Theme**: 自定义深空灰 (Deep Space Grey) 科技感皮肤。



## 📦 快速开始

### 环境要求
* Flutter SDK >= 3.11.0
* Dart SDK >= 3.0.0

### 安装步骤
1. **克隆仓库**:
   ```bash
   git clone [https://github.com/CerfH/ClanGraph.git](https://github.com/CerfH/ClanGraph.git)
   cd ClanGraph
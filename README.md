<div align="center">

# ⛩️ ClanGraph · 家族智慧图谱

*重建有温度的家族连接，让每一份人情都有迹可循*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-%2302569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Zhipu AI](https://img.shields.io/badge/AI-智谱_GLM--4.5_air_|_GLM--4.6V-6B3EFF?style=for-the-badge)](https://open.bigmodel.cn)
[![Platform](https://img.shields.io/badge/Platform-iOS_|_Android_|_macOS_|_Windows_|_Linux_|_Web-lightgrey?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 这是什么

过年回家面对一屋子亲戚叫不出名字？上次随了多少礼死活想不起来？别人托你打听"你表哥家孩子叫什么"你翻半天微信？

ClanGraph 就是解决这些事的——一个帮你**理清家族关系、记住人情往来**的小工具。画一张家族图谱，记下谁家随了多少礼，想问什么直接跟 AI 对话，AI 能帮你查数据、加成员、推荐该随多少钱。

数据全存你手机上，不联网不上传。

---

## 能干什么

### 1. 画家族关系图
添加你的家人，App 自动算出每个人的辈分、帮你排好位置。亲疏远近看圆圈大小，辈分高低看颜色深浅。点一下爸爸就能切换到"以爸爸为中心"的视角，爷爷奶奶叔叔姑姑怎么排列一目了然。

首次打开有 Demo 数据可以直接体验。

### 2. 记人情账
谁家结婚随了 2000、过年给了多少压岁钱，记下来就不怕忘。每笔记录包含时间、事件、金额，在统计看板里能看到年度礼金走势和各类事件的占比。

### 3. AI 对话助手
接入了智谱 AI 大模型，不是简单的聊天——它能**直接操作你的家族数据**。你可以：

- "我跟我表弟是什么关系？" → AI 查图谱告诉你
- "该给表哥结婚随多少钱？" → AI 翻历史礼金记录，结合你跟他家的亲疏程度给出建议
- "帮我把我二姨加进来" → AI 直接帮你创建成员
- "近三年给张家随了多少礼？" → AI 统计汇总
- 拍一张婚礼礼单的照片 → AI 识别姓名金额，一键导入

AI 有两个模型搭配工作：`GLM-4.5-air` 负责对话和查数据，`GLM-4.6V` 负责看图识字。

### 4. 图谱导出
随时把当前图谱保存为图片，方便发给家人确认关系对不对。

---

## 怎么跑起来

### 你需要准备

- 装好 Flutter 的电脑（[Flutter 安装教程](https://flutter.dev/docs/get-started/install)）
- 一个智谱 AI 的 API Key（[点这里免费申请](https://open.bigmodel.cn)，新用户有额度）

### 步骤

```bash
# 1. 下载代码
git clone https://github.com/CerfH/ClanGraph.git
cd ClanGraph

# 2. 安装依赖
flutter pub get

# 3. 在项目根目录新建 .env 文件，写入下面内容（把 Key 换成你自己的）
```

```
ZHIPU_API_KEY=你的API_Key
ZHIPU_BASE_URL=https://open.bigmodel.cn/api/paas/v4/
ZHIPU_MODEL_TEXT=glm-4.5-air
ZHIPU_MODEL_VISION=glm-4.6v
```

```bash
# 4. 跑起来
flutter run
```

> 注意：不配 API Key 也能打开 App、看 Demo 数据，但 AI 对话和图片识别功能用不了。

---

## 关于隐私

- **数据全在本地**：你输入的家族成员、礼金数额、备注，全部存在手机本地（SharedPreferences），删 App 就没了
- **AI 按需传数据**：只有你跟 AI 对话时，相关的家族成员信息才会作为上下文发给智谱服务器；拍照识别时只传压缩后的图片。不构建用户画像，不存服务端日志
- **没有后台上传**：App 不接任何统计 SDK，不收集使用数据，不联网上报

---

## License

MIT — 随便用，署名就行。

---

<div align="center">

*为中华家族文化而生 ⛩️*

</div>

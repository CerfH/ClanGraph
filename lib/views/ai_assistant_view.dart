import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../controllers/family_controller.dart';
import '../services/ai_service.dart';
import '../models/person.dart';


class AIAssistantView extends StatefulWidget {
  final FamilyController controller;

  const AIAssistantView({super.key, required this.controller});

  @override
  State<AIAssistantView> createState() => _AIAssistantViewState();
}

class _AIAssistantViewState extends State<AIAssistantView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  /// 消息列表 - 使用 dynamic 以支持 isJsonData 字段
  /// 每条消息包含: role, content, isJsonData
  final List<Map<String, dynamic>> _messages = [];

  final AIService _aiService = AIService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  final List<File> _selectedImages = []; // 多图选择列表
  String _loadingText = '正在思考中...';

  static const String _chatStorageKey = 'ai_chat_history_v2';

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载聊天历史
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString(_chatStorageKey);
      if (encoded != null) {
        final List<dynamic> decoded = json.decode(encoded);
        setState(() {
          _messages.clear();
          _messages.addAll(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      print('加载聊天历史失败: $e');
    }
  }

  /// 保存聊天历史
  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_messages);
      await prefs.setString(_chatStorageKey, encoded);
    } catch (e) {
      print('保存聊天历史失败: $e');
    }
  }

  /// 清空聊天历史
  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        title: const Text('清空聊天记录', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要清空所有聊天记录吗？此操作无法撤销。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _messages.clear();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatStorageKey);
    }
  }

  /// 从相册多选图片
  Future<void> _pickMultipleImagesFromGallery() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles.map((f) => File(f.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择图片失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 拍照选择
  Future<void> _takePicture() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 移除已选图片
  void _removeSelectedImage(int index) {
    setState(() {
      if (index >= 0 && index < _selectedImages.length) {
        _selectedImages.removeAt(index);
      }
    });
  }

  /// 清空所有已选图片
  void _clearSelectedImages() {
    setState(() {
      _selectedImages.clear();
    });
  }

  void _showImageSourceActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('上传礼金单据', style: TextStyle(color: Colors.white70)),
        message: _selectedImages.isNotEmpty
            ? Text('已选择 ${_selectedImages.length} 张图片', style: const TextStyle(color: Colors.white54, fontSize: 12))
            : null,
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('拍照', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _takePicture();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从相册多选', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _pickMultipleImagesFromGallery();
            },
          ),
          if (_selectedImages.isNotEmpty)
            CupertinoActionSheetAction(
              child: const Text('清空已选图片', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.pop(context);
                _clearSelectedImages();
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消', style: TextStyle(color: Colors.white70)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty) return;

    // 添加用户消息
    final imagesToSend = List<File>.from(_selectedImages);
    setState(() {
      if (imagesToSend.isNotEmpty) {
        // 多图消息：存储所有图片路径
        _messages.add({
          'role': 'user',
          'content': text.isNotEmpty ? text : '识别${imagesToSend.length}张礼金单据',
          'isJsonData': false,
          'imagePaths': imagesToSend.map((f) => f.path).toList(),
        });
        _loadingText = imagesToSend.length > 1
            ? '正在识别${imagesToSend.length}张图片...'
            : '正在识别图片...';
      } else {
        _messages.add({
          'role': 'user',
          'content': text,
          'isJsonData': false,
        });
        _loadingText = '正在思考中...';
      }
      _isLoading = true;
      _inputController.clear();
      _selectedImages.clear(); // 清空已选图片
    });

    _scrollToBottom();
    await _saveChatHistory();

    try {
      final contextData = widget.controller.aiContextSummary;
      String response;

      if (imagesToSend.isNotEmpty) {
        if (imagesToSend.length == 1) {
          // 单图识别
          response = await _aiService.analyzeImage(imagesToSend.first, contextData);
        } else {
          // 多图并发识别
          response = await _aiService.analyzeImages(imagesToSend, contextData);
        }

        // 尝试解析 JSON 列表，判断是否为有效礼金数据
        final items = AIService.parseJsonResponseList(response);
        final isValidGiftData = items.isNotEmpty;

        // 添加 AI 响应消息，标记是否为 JSON 数据
        setState(() {
          _messages.add({
            'role': 'ai',
            'content': response,
            'isJsonData': isValidGiftData,
          });
        });
      } else {
        // 传递完整消息历史，实现长上下文记忆
        response = await _aiService.askAgent(
          text,
          contextData,
          history: _messages,
        );
        setState(() {
          _messages.add({
            'role': 'ai',
            'content': response,
            'isJsonData': false,
          });
        });
      }

      await _saveChatHistory();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI 请求失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// 处理一键导入（后台静默处理，无UI跳转）
  void _handleImport(String jsonContent) {
    // 解析 JSON 数据列表
    final items = _parseGiftDataList(jsonContent);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法解析礼金数据'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 后台自动同步：遍历记录并直接写入数据
    int successCount = 0;
    
    for (final item in items) {
      final isNew = item['is_new'] == true;
      
      // 忽略新成员：若 is_new 为 true 或找不到匹配成员，直接跳过
      if (isNew) continue;
      
      // 通过 _findMatchingPersonId 找到家谱中对应的成员 ID
      final personId = _findMatchingPersonId(item);
      
      // 如果找不到匹配成员（返回 root 表示未匹配），跳过
      if (personId == 'root') continue;
      
      // 提取金额、事件和日期字段
      final amount = _parseAmount(item['amount']);
      final event = item['event']?.toString() ?? '';
      final date = DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now();
      
      // 直接写入数据
      widget.controller.addGiftRecord(personId, amount, event, date);
      successCount++;
    }

    // 使用 Overlay 在屏幕顶部显示成功提示
    _showTopOverlayNotification('导入成功：已同步 $successCount 条礼金记录');
  }

  /// 在屏幕顶部显示 Overlay 提示（避开刘海屏）
  void _showTopOverlayNotification(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 插入 Overlay
    overlay.insert(overlayEntry);

    // 2秒后自动移除
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  /// 智能匹配成员 ID
  String _findMatchingPersonId(Map<String, dynamic> data) {
    // 优先使用 AI 返回的 matched_id
    if (data['matched_id'] != null && data['matched_id'].toString().isNotEmpty) {
      final person = widget.controller.getPerson(data['matched_id'].toString());
      if (person != null) return person.id;
    }
    
    // 尝试通过姓名匹配
    final name = data['name']?.toString();
    if (name != null && name.isNotEmpty) {
      // 精确匹配
      for (final p in widget.controller.allPeople) {
        if (p.name == name) return p.id;
      }
      // 模糊匹配（包含）
      for (final p in widget.controller.allPeople) {
        if (p.name.contains(name) || name.contains(p.name)) return p.id;
      }
    }
    
    // 默认返回 root
    return 'root';
  }

  /// 解析金额
  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[￥¥,\s]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  /// 滚动到底部（新消息时一律自动滑到底）
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceGrey,
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Input Area (包含顶部的进度条)
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.electricBlue, size: 20),
              SizedBox(width: 8),
              Text(
                '家族智能管家',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: _messages.isEmpty ? null : _clearChatHistory,
                tooltip: '清空聊天',
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 加载进度条
            if (_isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.electricBlue,
                backgroundColor: Colors.white10,
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 多图预览区域
                  if (_selectedImages.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 90,
                      child: Row(
                        children: [
                          // 图片缩略图列表
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _selectedImages[index],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      // 删除按钮
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => _removeSelectedImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      // 序号标签
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 输入行
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
                        onPressed: _showImageSourceActionSheet,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: _isLoading ? _loadingText : '输入问题或上传单据...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          enabled: !_isLoading,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.electricBlue),
                        onPressed: _isLoading ? null : _sendMessage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 探测消息是否包含有效 JSON 数据（支持数组和多行格式）
  bool _detectJsonInContent(String content) {
    final items = _parseGiftDataList(content);
    return items.isNotEmpty;
  }

  /// 解析礼金数据列表（支持数组格式、单个对象、多行独立 JSON）
  /// 使用正则表达式提取所有 JSON 块，避免散乱 JSON 解析失败
  List<Map<String, dynamic>> _parseGiftDataList(String content) {
    final List<Map<String, dynamic>> result = [];
    
    // 先尝试整体解析（数组或单个对象）
    try {
      final cleaned = AIService.cleanJsonString(content);
      final decoded = json.decode(cleaned);
      
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map && _isValidGiftItem(Map<String, dynamic>.from(item))) {
            result.add(Map<String, dynamic>.from(item));
          }
        }
        return result;
      } else if (decoded is Map) {
        if (_isValidGiftItem(Map<String, dynamic>.from(decoded))) {
          result.add(Map<String, dynamic>.from(decoded));
        }
        return result;
      }
    } catch (_) {
      // 整体解析失败，继续使用正则提取
    }
    
    // 使用正则表达式提取所有 JSON 对象块
    // 使用 \{[\s\S]*?\} 匹配 {...} 格式，支持多行散乱数据
    final jsonRegex = RegExp(r'\{[\s\S]*?\}', multiLine: true);
    final matches = jsonRegex.allMatches(content);
    
    for (final match in matches) {
      final jsonStr = match.group(0);
      if (jsonStr == null) continue;
      
      try {
        final cleaned = AIService.cleanJsonString(jsonStr);
        final item = json.decode(cleaned);
        if (item is Map && _isValidGiftItem(Map<String, dynamic>.from(item))) {
          result.add(Map<String, dynamic>.from(item));
        }
      } catch (_) {
        // 忽略解析失败的块
      }
    }
    
    return result;
  }

  /// 检查是否为有效的礼金数据项
  bool _isValidGiftItem(Map<String, dynamic> item) {
    return item.containsKey('name') || item.containsKey('amount');
  }

  /// 统计已知成员数量
  int _countKnownMembers(List<Map<String, dynamic>> items) {
    int count = 0;
    for (final item in items) {
      final isNew = item['is_new'] == true;
      if (!isNew) count++;
    }
    return count;
  }

  /// 复制文本到剪贴板
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        backgroundColor: AppTheme.electricBlue,
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 检查图片文件是否存在且有效
  bool _isImageFileValid(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      final file = File(path);
      return file.existsSync();
    } catch (e) {
      return false;
    }
  }

  /// 过滤有效的图片路径列表
  List<String> _getValidImagePaths(List<dynamic>? paths) {
    if (paths == null || paths.isEmpty) return [];
    return paths
        .where((p) => p is String && _isImageFileValid(p))
        .cast<String>()
        .toList();
  }

  /// 构建消息气泡 - 支持长按复制、图片显示和 JSON 数据卡片
  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final content = msg['content']?.toString() ?? '';
    // 优先使用已缓存的 isJsonData 字段，避免每次 build 重复解析 JSON
    // 若尚未缓存（首次渲染），则调用检测函数，并将结果回写以供后续复用
    bool isJsonData = msg['isJsonData'] == true;
    if (!isJsonData && content.isNotEmpty) {
      isJsonData = _detectJsonInContent(content);
      if (isJsonData) msg['isJsonData'] = true; // 回写缓存，下次直接走短路
    }
    // 支持单图和多图（过滤掉无效的图片路径）
    final imagePath = msg['imagePath']?.toString();
    final rawImagePaths = msg['imagePaths'] as List<dynamic>?;
    final validImagePaths = _getValidImagePaths(rawImagePaths);
    final bool hasValidSingleImage = _isImageFileValid(imagePath);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 多图消息
            if (validImagePaths.isNotEmpty)
              _buildMultiImagePreview(validImagePaths, isUser: isUser),
            // 单图消息（兼容旧数据）
            if (hasValidSingleImage && rawImagePaths == null && imagePath != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(imagePath),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  constraints: const BoxConstraints(
                    maxWidth: 200,
                    maxHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // 文本消息气泡 - 长按复制
            if (content.isNotEmpty)
              GestureDetector(
                onLongPress: () => _copyToClipboard(content),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppTheme.electricBlue.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppTheme.electricBlue.withValues(alpha: 0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: isJsonData
                      ? _buildJsonPreview(content)
                      : SelectableText(
                          content,
                          style: const TextStyle(color: Colors.white, height: 1.5),
                          contextMenuBuilder: (context, editableTextState) {
                            return AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            );
                          },
                        ),
                ),
              ),

            // JSON 数据同步卡片
            if (isJsonData && !isUser)
              _buildSyncCard(content),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 显示全屏图片查看
  void _showFullScreenImage(String imagePath) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: true,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Container(
          color: Colors.black,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(File(imagePath)),
          ),
        ),
      ),
    );
  }

  /// 构建多图预览组件
  Widget _buildMultiImagePreview(List<String> paths, {bool isUser = false}) {
    final int imageCount = paths.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: 120,
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图片数量标签
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$imageCount 张图片',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
          // 图片网格
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: isUser,
              itemCount: paths.length,
              itemBuilder: (context, index) {
                final int displayIndex = isUser ? (paths.length - 1 - index) : index;
                return GestureDetector(
                  onTap: () => _showFullScreenImage(paths[displayIndex]),
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.file(
                            File(paths[displayIndex]),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                          // 序号标签
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${displayIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建数据同步卡片
  Widget _buildSyncCard(String jsonContent) {
    // 解析数据并统计
    final items = _parseGiftDataList(jsonContent);
    final knownCount = _countKnownMembers(items);
    final unknownCount = items.length - knownCount;
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      // 明确约束宽度
      constraints: BoxConstraints(
        minWidth: 200,
        maxWidth: 300,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部提示 - 显示统计信息
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppTheme.electricBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    children: [
                      TextSpan(text: '检测到 '),
                      TextSpan(
                        text: '$knownCount',
                        style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' 条已知成员记录'),
                      if (unknownCount > 0) ...[
                        const TextSpan(text: '，'),
                        TextSpan(
                          text: '$unknownCount',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' 条新成员已跳过'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 操作按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: knownCount > 0 ? () => _handleImport(jsonContent) : null,
              icon: const Icon(Icons.download, size: 16),
              label: Text(knownCount > 0 ? '一键导入' : '无已知成员'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricBlue,
                disabledBackgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 JSON 预览显示（支持多条记录）
  Widget _buildJsonPreview(String jsonContent) {
    final items = _parseGiftDataList(jsonContent);
    
    if (items.isEmpty) {
      return const Text(
        '识别结果为空',
        style: TextStyle(color: Colors.white54),
      );
    }

    // 多条记录时显示列表（限制最大高度）
    if (items.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: AppTheme.electricBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '识别结果（${items.length}条）',
                style: TextStyle(
                  color: AppTheme.electricBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 使用 ListView 约束高度，支持滚动查看多条记录
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 200,
            ),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => _buildGiftItemSummary(items[index]),
            ),
          ),
        ],
      );
    }

    // 单条记录时显示详细信息
    return _buildSingleGiftItemDetail(items.first);
  }

  /// 构建单条礼金记录详情
  Widget _buildSingleGiftItemDetail(Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? '未知';
    final amount = _parseAmount(data['amount']);
    final event = data['event']?.toString() ?? '未知事件';
    final date = data['date']?.toString() ?? '';
    final isNew = data['is_new'] == true;
    
    // 查找匹配成员
    String? matchedId = data['matched_id']?.toString();
    Person? matchedPerson;
    if (matchedId != null && matchedId.isNotEmpty) {
      matchedPerson = widget.controller.getPerson(matchedId);
    }
    // 如果没有 matched_id，尝试通过姓名匹配
    if (matchedPerson == null && !isNew) {
      final id = _findMatchingPersonId(data);
      if (id != 'root') {
        matchedPerson = widget.controller.getPerson(id);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.receipt_long,
              color: AppTheme.electricBlue,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '识别结果',
              style: TextStyle(
                color: AppTheme.electricBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoRow('姓名', name),
        _buildInfoRow('金额', '¥${amount.toStringAsFixed(0)}'),
        _buildInfoRow('事件', event),
        if (date.isNotEmpty) _buildInfoRow('日期', date),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              isNew ? Icons.person_add : Icons.person,
              size: 14,
              color: isNew ? Colors.orange : AppTheme.electricBlue,
            ),
            const SizedBox(width: 4),
            Text(
              isNew 
                  ? '新成员（需手动添加）'
                  : '匹配: ${matchedPerson?.name ?? "未匹配"}',
              style: TextStyle(
                color: isNew ? Colors.orange : AppTheme.electricBlue,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建礼金记录简要信息（用于多条记录列表）
  Widget _buildGiftItemSummary(Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? '未知';
    final amount = _parseAmount(data['amount']);
    final event = data['event']?.toString() ?? '';
    final isNew = data['is_new'] == true;
    final matchedId = data['matched_id']?.toString();
    
    // 查找匹配成员名称
    String matchedName = '';
    if (matchedId != null && matchedId.isNotEmpty) {
      final person = widget.controller.getPerson(matchedId);
      if (person != null) matchedName = person.name;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // 状态图标
          Icon(
            isNew ? Icons.person_add_outlined : Icons.check_circle_outline,
            size: 16,
            color: isNew ? Colors.orange : AppTheme.electricBlue,
          ),
          const SizedBox(width: 8),
          // 主要信息：姓名给了金额
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' 给了 '),
                  TextSpan(
                    text: '¥${amount.toStringAsFixed(0)}',
                    style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold),
                  ),
                  if (event.isNotEmpty) ...[
                    const TextSpan(text: '（'),
                    TextSpan(text: event),
                    const TextSpan(text: '）'),
                  ],
                ],
              ),
            ),
          ),
          // 匹配状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isNew 
                  ? Colors.orange.withValues(alpha: 0.2)
                  : AppTheme.electricBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isNew ? '新成员' : (matchedName.isNotEmpty ? matchedName : '已匹配'),
              style: TextStyle(
                color: isNew ? Colors.orange : AppTheme.electricBlue,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

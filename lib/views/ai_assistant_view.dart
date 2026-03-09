import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../controllers/family_controller.dart';
import '../services/ai_service.dart';
import '../models/person.dart';
import '../widgets/gift_record_dialog.dart';

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
  File? _selectedImage;
  String _loadingText = '智谱 AI 正在思考中...';
  
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
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

  void _showImageSourceActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('上传礼金单据', style: TextStyle(color: Colors.white70)),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('拍照', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从相册选择', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
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
    if (text.isEmpty && _selectedImage == null) return;

    // 添加用户消息
    setState(() {
      if (_selectedImage != null) {
        _messages.add({
          'role': 'user', 
          'content': '[图片] ${text.isNotEmpty ? text : "识别这张礼金单据"}',
          'isJsonData': false,
        });
        _loadingText = '智谱 4.6V 正在识别图片...';
      } else {
        _messages.add({
          'role': 'user', 
          'content': text,
          'isJsonData': false,
        });
        _loadingText = '智谱 AI 正在思考中...';
      }
      _isLoading = true;
      _inputController.clear();
    });

    _scrollToBottom();
    await _saveChatHistory();

    try {
      final contextData = widget.controller.aiContextSummary;
      String response;

      if (_selectedImage != null) {
        final imageFile = _selectedImage!;
        setState(() {
          _selectedImage = null;
        });
        
        response = await _aiService.analyzeImage(imageFile, contextData);
        
        // 尝试解析 JSON，判断是否为有效礼金数据
        final data = AIService.parseJsonResponse(response);
        final isValidGiftData = data != null && data.isNotEmpty && _hasValidGiftFields(data);
        
        // 添加 AI 响应消息，标记是否为 JSON 数据
        setState(() {
          _messages.add({
            'role': 'ai',
            'content': response,
            'isJsonData': isValidGiftData,
          });
        });
      } else {
        response = await _aiService.askAgent(text, contextData);
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

  /// 检查 JSON 是否包含有效的礼金字段
  bool _hasValidGiftFields(Map<String, dynamic> data) {
    // 必须有姓名
    if (data['name'] == null || data['name'].toString().isEmpty) {
      return false;
    }
    // 至少要有金额或事件
    return data['amount'] != null || data['event'] != null;
  }

  /// 处理一键导入
  void _handleImport(String jsonContent) {
    // 解析 JSON
    final data = AIService.parseJsonResponse(jsonContent);
    if (data == null || data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法解析礼金数据'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 检查是否为陌生人
    final name = data['name']?.toString() ?? '';
    final isNew = data['is_new'] == true;
    
    // 智能匹配成员
    String? matchedPersonId = _findMatchingPersonId(data);
    
    // 如果是陌生人且没有匹配到成员，跳过
    if (isNew && matchedPersonId == 'root') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「$name」不在家谱中，已跳过'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 关闭聊天抽屉
    Navigator.of(context).pop();
    
    // 延迟后弹出填表对话框
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      final person = widget.controller.getPerson(matchedPersonId);
      final record = GiftRecord(
        id: '',
        amount: _parseAmount(data['amount']),
        event: data['event']?.toString() ?? '',
        date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
      );

      showDialog(
        context: context,
        builder: (ctx) => GiftRecordDialog(
          controller: widget.controller,
          personId: matchedPersonId,
          initialRecord: record,
          allowMemberSelection: true,
        ),
      );
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildLoadingBubble();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Input Area
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 图片预览
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 80,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImage!),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
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
                      hintText: '输入问题或上传单据...',
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
    );
  }

  /// 构建消息气泡 - 支持 JSON 数据时显示导入按钮
  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final isJsonData = msg['isJsonData'] == true;
    final content = msg['content']?.toString() ?? '';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 消息气泡
            Container(
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
                  : Text(
                      content,
                      style: const TextStyle(color: Colors.white, height: 1.5),
                    ),
            ),
            
            // 一键导入按钮（仅 JSON 数据显示）
            if (isJsonData)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _handleImport(content),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('点击一键同步至礼金簿'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.electricBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 构建 JSON 预览显示
  Widget _buildJsonPreview(String jsonContent) {
    try {
      final data = AIService.parseJsonResponse(jsonContent);
      if (data == null || data.isEmpty) {
        return const Text(
          '识别结果为空',
          style: TextStyle(color: Colors.white54),
        );
      }

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
    } catch (e) {
      return Text(
        jsonContent,
        style: const TextStyle(color: Colors.white, height: 1.5),
      );
    }
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

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.electricBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _loadingText,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

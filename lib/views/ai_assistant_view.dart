import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
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
  final List<Map<String, String>> _messages = []; // 'role': 'user' | 'ai'
  final AIService _aiService = AIService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  File? _selectedImage;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    setState(() {
      if (_selectedImage != null) {
        _messages.add({'role': 'user', 'content': '[图片] ${text.isNotEmpty ? text : "识别这张礼金单据"}'});
      } else {
        _messages.add({'role': 'user', 'content': text});
      }
      _isLoading = true;
      _inputController.clear();
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      final contextData = widget.controller.aiContextSummary;
      String response;

      if (_selectedImage != null) {
        response = await _aiService.analyzeImage(_selectedImage!, contextData);
        // Clear image after sending
        setState(() {
          _selectedImage = null;
        });
        
        // Try to parse JSON response for auto-filling
        try {
          // Remove potential markdown code blocks ```json ... ``` and ``` ... ```
          final jsonString = response
              .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
              .replaceAll(RegExp(r'^```\s*'), '')
              .replaceAll(RegExp(r'\s*```$'), '')
              .trim();
          
          // Attempt to parse JSON
          final Map<String, dynamic> data = json.decode(jsonString);
          
          if (data.isNotEmpty) {
            // Auto-fill logic
             _handleAutoFill(data);
             // Don't add AI response to chat if handled by dialog
             setState(() {
               _isLoading = false;
             });
             return;
          }
        } catch (e) {
          // Not a JSON response, treat as normal text
          print('Failed to parse JSON: $e');
        }

      } else {
        response = await _aiService.askAgent(text, contextData);
      }

      setState(() {
        _messages.add({'role': 'ai', 'content': response});
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI请求失败: $e'),
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

  void _handleAutoFill(Map<String, dynamic> data) {
    if (!mounted) return;
    
    // Close AI Assistant View
    Navigator.of(context).pop();

    // Determine target person
    String personId = 'root'; // Default to root
    if (data['matched_id'] != null && data['matched_id'].toString().isNotEmpty) {
       final person = widget.controller.getPerson(data['matched_id']);
       if (person != null) {
         personId = person.id;
       }
    } else if (data['is_new'] == true) {
      // Logic for new person could be added here, currently default to root
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到匹配成员，默认添加到“我”')),
      );
    }

    // Construct GiftRecord for pre-filling
    final record = GiftRecord(
      id: '', // Will be generated in add
      amount: (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0,
      event: data['event']?.toString() ?? '',
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
    );

    showDialog(
      context: context,
      builder: (ctx) => GiftRecordDialog(
        controller: widget.controller,
        personId: personId,
        initialRecord: record, // Reusing edit mode for pre-filling
      ),
    );
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '家族智能管家',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

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
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: Column(
                children: [
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
        child: Text(
          msg['content']!,
          style: const TextStyle(color: Colors.white, height: 1.5),
        ),
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
             SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.electricBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
               _selectedImage != null ? '正在通过智谱 4.6V 辨认...' : '思考中...',
               style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

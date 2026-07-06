import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

typedef AgentToolExecutor =
    Map<String, dynamic> Function(
      String toolName,
      Map<String, dynamic> arguments,
    );

class AgentResult {
  final String content;
  final List<String> toolsUsed;

  const AgentResult({required this.content, this.toolsUsed = const []});
}

/// AIService - 智谱全家桶统一调度
/// 纯文字对话: glm-4.5-air
/// 图片识别: glm-4.6v
class AIService {
  Dio? _zhipuDio;

  // 智谱 API 配置 - 动态从 .env 获取
  String get _zhipuApiKey => dotenv.env['ZHIPU_API_KEY'] ?? '';
  String get _zhipuBaseUrl =>
      dotenv.env['ZHIPU_BASE_URL'] ?? 'https://open.bigmodel.cn/api/paas/v4/';
  String get _textModel => dotenv.env['ZHIPU_MODEL_TEXT'] ?? 'glm-4.5-air';
  String get _visionModel => dotenv.env['ZHIPU_MODEL_VISION'] ?? 'glm-4.6v';

  // Lazy getter for Zhipu Dio
  Dio get _dio {
    _zhipuDio ??= Dio(
      BaseOptions(
        baseUrl: _zhipuBaseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return _zhipuDio!;
  }

  /// 纯文字对话 - 使用智谱 glm-4.5-air
  /// 支持传入完整消息历史实现长上下文记忆
  /// [question] 当前用户问题
  /// [contextData] 家族成员数据
  /// [history] 历史消息列表，格式: [{'role': 'user'|'ai', 'content': '...'}]
  Future<String> askAgent(
    String question,
    String contextData, {
    List<Map<String, dynamic>> history = const [],
  }) async {
    if (_zhipuApiKey.isEmpty) {
      throw Exception('智谱 API Key 未配置，请在 .env 中设置 ZHIPU_API_KEY');
    }

    // 更新请求配置
    _dio.options.baseUrl = _zhipuBaseUrl;
    _dio.options.headers['Authorization'] = 'Bearer $_zhipuApiKey';

    // 构建消息数组：system + 历史 + 当前问题
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            '你是一个精通中国家族人情往来的智能管家。以下是用户的家族成员数据：$contextData。请基于此数据回答问题，若涉及送礼请给出符合辈分和习俗的体面建议。回答要有人情味，不要一股AI味。',
      },
    ];

    // 添加历史消息（跳过 JSON 数据消息，只保留对话内容）
    for (final msg in history) {
      final role = msg['role']?.toString();
      final content = msg['content']?.toString();
      final isJsonData = msg['isJsonData'] == true;

      // 跳过空消息和 JSON 数据消息
      if (content == null || content.isEmpty) continue;
      if (isJsonData) continue;

      // 转换角色：'ai' -> 'assistant'
      final apiRole = role == 'ai' ? 'assistant' : role;
      if (apiRole == 'user' || apiRole == 'assistant') {
        messages.add({'role': apiRole, 'content': content});
      }
    }

    // 添加当前问题
    messages.add({'role': 'user', 'content': question});

    try {
      final response = await _dio.post(
        'chat/completions',
        data: {'model': _textModel, 'messages': messages, 'temperature': 0.7},
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception('未知错误: $e');
    }
  }

  /// 带本地工具调用的家族 Agent。若当前模型不支持 tools，会自动回退到普通问答。
  Future<AgentResult> askAgentWithTools(
    String question,
    String contextData, {
    List<Map<String, dynamic>> history = const [],
    required List<Map<String, dynamic>> tools,
    required AgentToolExecutor executeTool,
  }) async {
    if (_zhipuApiKey.isEmpty) {
      throw Exception('智谱 API Key 未配置，请在 .env 中设置 ZHIPU_API_KEY');
    }

    _dio.options.baseUrl = _zhipuBaseUrl;
    _dio.options.headers['Authorization'] = 'Bearer $_zhipuApiKey';

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': '''你是 ClanGraph 家族智能管家，可以调用本地工具操作真实家谱数据。

工具清单：
- search_family_members：按姓名或称呼搜索成员
- get_member_details：查看某人完整信息（父母、配偶、子女、兄弟姐妹、礼金记录）
- get_family_branch：展开某人的后代树（3层）
- get_gift_summary：统计全家族或某人的礼金
- set_graph_center：切换家谱中心人物
- recommend_gift_amount：根据历史记录和亲疏关系，推荐礼金金额范围
- add_family_member：通过对话创建新成员并建立关系

行为规则：
1. 涉及具体成员、关系、金额时，必须优先调用工具，不要编造
2. 用户问”该给多少钱/随多少礼”时，调用 recommend_gift_amount
3. 用户说”帮我加个人/录入/添加 XXX”时，先 search_family_members 确认不重复，再调用 add_family_member
4. 关系词映射：爸爸/妈妈=parent，儿子/女儿=child，老公/老婆=spouse
5. 工具结果可信。用自然中文答复，简洁温暖，像长辈在帮你参谋。
6. 添加成员时，如果用户没说明是父/子/配偶关系，根据称呼推断（”XX的爸爸”→parent）
当前家谱上下文：$contextData''',
      },
    ];
    for (final msg in history) {
      final content = msg['content']?.toString() ?? '';
      if (content.isEmpty || msg['isJsonData'] == true) continue;
      final role = msg['role'] == 'ai' ? 'assistant' : msg['role'];
      if (role == 'user' || role == 'assistant') {
        messages.add({'role': role, 'content': content});
      }
    }
    messages.add({'role': 'user', 'content': question});

    try {
      var response = await _dio.post(
        'chat/completions',
        data: {
          'model': _textModel,
          'messages': messages,
          'tools': tools,
          'tool_choice': 'auto',
          'temperature': 0.3,
        },
      );
      final toolsUsed = <String>[];
      for (var round = 0; round < 4; round++) {
        final assistantMessage = _responseMessage(response);
        final rawToolCalls = assistantMessage['tool_calls'];
        if (rawToolCalls is! List || rawToolCalls.isEmpty) {
          final content = assistantMessage['content']?.toString().trim() ?? '';
          return AgentResult(
            content: content.isEmpty ? '工具已执行，但暂时无法生成总结。' : content,
            toolsUsed: toolsUsed,
          );
        }

        messages.add({
          'role': 'assistant',
          'content': assistantMessage['content'],
          'tool_calls': rawToolCalls,
        });
        for (final rawCall in rawToolCalls.whereType<Map>()) {
          final call = Map<String, dynamic>.from(rawCall);
          final function = call['function'];
          if (function is! Map) continue;
          final functionMap = Map<String, dynamic>.from(function);
          final name = functionMap['name']?.toString() ?? '';
          if (name.isEmpty) continue;

          Map<String, dynamic> arguments = {};
          final rawArguments = functionMap['arguments'];
          try {
            if (rawArguments is Map) {
              arguments = Map<String, dynamic>.from(rawArguments);
            } else if (rawArguments is String && rawArguments.isNotEmpty) {
              final decoded = json.decode(rawArguments);
              if (decoded is Map) {
                arguments = Map<String, dynamic>.from(decoded);
              }
            }
          } catch (_) {
            arguments = {};
          }

          Map<String, dynamic> result;
          try {
            result = executeTool(name, arguments);
          } catch (error) {
            result = {'ok': false, 'error': error.toString()};
          }
          if (!toolsUsed.contains(name)) toolsUsed.add(name);
          messages.add({
            'role': 'tool',
            'tool_call_id': call['id']?.toString() ?? name,
            'content': json.encode(result),
          });
        }

        response = await _dio.post(
          'chat/completions',
          data: {
            'model': _textModel,
            'messages': messages,
            'tools': tools,
            'tool_choice': 'auto',
            'temperature': 0.3,
          },
        );
      }
      final summaryResponse = await _dio.post(
        'chat/completions',
        data: {
          'model': _textModel,
          'messages': [
            ...messages,
            {'role': 'system', 'content': '不要再调用工具。请仅根据上面的工具结果，直接完整回答用户最初的问题。'},
          ],
          'temperature': 0.3,
        },
      );
      final summary =
          _responseMessage(summaryResponse)['content']?.toString().trim() ?? '';
      return AgentResult(
        content: summary.isEmpty ? '工具查询完成，但未能生成文字总结。' : summary,
        toolsUsed: toolsUsed,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 404 || status == 422) {
        return AgentResult(
          content: await askAgent(question, contextData, history: history),
        );
      }
      _handleDioError(error);
      rethrow;
    }
  }

  Map<String, dynamic> _responseMessage(Response response) {
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
    final data = response.data;
    if (data is Map && data['choices'] is List && data['choices'].isNotEmpty) {
      final choice = data['choices'].first;
      if (choice is Map && choice['message'] is Map) {
        return Map<String, dynamic>.from(choice['message'] as Map);
      }
    }
    throw Exception('AI 响应缺少 message');
  }

  /// 压缩图片 - 限制分辨率 1024px，质量 70%
  /// 返回压缩后的 Uint8List
  Future<Uint8List> _compressImage(File imageFile) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      return result ?? await imageFile.readAsBytes();
    } catch (e) {
      print('图片压缩失败: $e，使用原图');
      return await imageFile.readAsBytes();
    }
  }

  /// 多模态图片识别 - 使用智谱 glm-4.6v
  /// 返回纯 JSON 字符串
  Future<String> analyzeImage(File imageFile, String contextData) async {
    if (_zhipuApiKey.isEmpty) {
      throw Exception('智谱 API Key 未配置，请在 .env 中设置 ZHIPU_API_KEY');
    }

    // 更新请求配置
    _dio.options.baseUrl = _zhipuBaseUrl;
    _dio.options.headers['Authorization'] = 'Bearer $_zhipuApiKey';

    // 压缩图片并转换为 Base64 Data URI
    final compressedBytes = await _compressImage(imageFile);
    final base64Image = base64Encode(compressedBytes);
    final mimeType = 'image/jpeg'; // 压缩后统一为 JPEG
    final dataUri = 'data:$mimeType;base64,$base64Image';

    try {
      final response = await _dio.post(
        'chat/completions',
        data: {
          'model': _visionModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  '''你是一个精通中国家族礼尚往来的智能管家。
任务：从图片中提取【姓名、金额、事件、日期】。
家族成员数据：$contextData

匹配规则：
1. 对比家族成员数据中的姓名，若完全匹配则返回 matched_id
2. 若姓名不完全匹配但相似，返回 matched_id 和 similarity 字段
3. 若完全不匹配，标记 is_new: true

重要：必须严格返回纯 JSON 格式，不要包含任何 markdown 标记、代码块或额外文字。

JSON 格式：
{"name":"张三","amount":1000,"event":"结婚","date":"2023-10-01","matched_id":"12345","is_new":false}

如果无法识别或图片无关，返回：{}''',
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUri},
                },
                {'type': 'text', 'text': '请识别这张礼金单据，返回纯JSON格式'},
              ],
            },
          ],
          'temperature': 0.1,
        },
      );

      final rawResponse = _parseResponse(response);
      // 清理并返回纯 JSON
      return cleanJsonString(rawResponse);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception('未知错误: $e');
    }
  }

  /// 解析 API 响应
  String _parseResponse(Response response) {
    if (response.statusCode == 200) {
      final data = response.data;
      if (data != null &&
          data['choices'] != null &&
          data['choices'].isNotEmpty) {
        return data['choices'][0]['message']['content'].toString();
      }
    } else {
      print('AI Error Status: ${response.statusCode}');
      print('AI Error Body: ${response.data}');
      throw Exception('API 错误: ${response.statusCode} - ${response.data}');
    }
    throw Exception('获取响应失败: ${response.statusCode}');
  }

  /// 处理网络错误
  void _handleDioError(DioException e) {
    print('DioException: ${e.message}');
    if (e.response != null) {
      print('Response Data: ${e.response?.data}');
    }
    throw Exception('网络错误: ${e.message}');
  }

  /// 清理 JSON 字符串，移除 Markdown 代码块
  /// 处理: ```json ... ```, ``` ... ```, 以及额外空白
  static String cleanJsonString(String raw) {
    var cleaned = raw.trim();

    // 移除 markdown 代码块
    final codeBlockPattern = RegExp(
      r'^```(?:json)?\s*\n?([\s\S]*?)\n?```\\s*$',
      multiLine: true,
    );
    final match = codeBlockPattern.firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1) ?? cleaned;
    }

    // 备用清理：移除残留的 ``` 标记
    cleaned = cleaned
        .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();

    return cleaned;
  }

  /// 解析 AI 返回的 JSON，处理 Markdown 包装
  /// 支持单个对象、数组格式、多行独立 JSON
  static Map<String, dynamic>? parseJsonResponse(String raw) {
    try {
      final cleaned = cleanJsonString(raw);
      if (cleaned.isEmpty || cleaned == '{}') {
        return {};
      }
      final decoded = json.decode(cleaned);

      // 如果是数组，返回第一个元素（兼容旧逻辑）
      if (decoded is List) {
        if (decoded.isEmpty) return {};
        return Map<String, dynamic>.from(decoded.first as Map);
      }

      return decoded as Map<String, dynamic>;
    } catch (e) {
      print('JSON 解析失败: $e');
      print('原始响应: $raw');
      return null;
    }
  }

  /// 批量并发图片识别 - 使用 Future.wait 同时处理多张图片
  /// [imageFiles] 图片文件列表
  /// [contextData] 家族成员上下文数据
  /// 返回合并后的 JSON 字符串（数组格式）
  Future<String> analyzeImages(
    List<File> imageFiles,
    String contextData,
  ) async {
    if (imageFiles.isEmpty) {
      return '[]';
    }

    // 并发执行所有图片识别请求
    final futures = imageFiles.map((file) => analyzeImage(file, contextData));
    final responses = await Future.wait(
      futures,
      eagerError: false, // 即使部分失败也等待所有请求完成
    );

    // 合并所有响应结果
    final allItems = <Map<String, dynamic>>[];
    for (int i = 0; i < responses.length; i++) {
      try {
        final items = parseJsonResponseList(responses[i]);
        allItems.addAll(items);
      } catch (e) {
        print('解析第 ${i + 1} 张图片结果失败: $e');
      }
    }

    // 去重处理：根据 name 和 amount 进行简单内存级去重
    final uniqueItems = _deduplicateItems(allItems);

    return json.encode(uniqueItems);
  }

  /// 去重处理：根据 name 和 amount 进行简单内存级去重
  List<Map<String, dynamic>> _deduplicateItems(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <String>{};
    final uniqueItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final name = item['name']?.toString() ?? '';
      final amount = item['amount']?.toString() ?? '';
      final key = '$name|$amount';

      if (name.isNotEmpty && amount.isNotEmpty) {
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueItems.add(item);
        } else {
          print('去重过滤: $name - $amount');
        }
      } else {
        // 保留不完整数据（可能用于调试）
        uniqueItems.add(item);
      }
    }

    return uniqueItems;
  }

  /// 解析 AI 返回的 JSON 列表
  /// 支持数组格式和多行独立 JSON 格式
  static List<Map<String, dynamic>> parseJsonResponseList(String raw) {
    final List<Map<String, dynamic>> result = [];

    try {
      final cleaned = cleanJsonString(raw);
      if (cleaned.isEmpty || cleaned == '{}') {
        return result;
      }

      final decoded = json.decode(cleaned);

      if (decoded is List) {
        // 数组格式: [{}, {}, ...]
        for (final item in decoded) {
          if (item is Map) {
            result.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (decoded is Map) {
        // 单个对象格式: {}
        result.add(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      // 尝试解析多行独立 JSON 格式
      // 格式: {"name":"..."}\n{"name":"..."}\n...
      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty);
      for (final line in lines) {
        try {
          final cleanedLine = cleanJsonString(line);
          final item = json.decode(cleanedLine);
          if (item is Map) {
            result.add(Map<String, dynamic>.from(item));
          }
        } catch (_) {
          // 忽略解析失败的行
        }
      }
    }

    return result;
  }
}

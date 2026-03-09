import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AIService - 智谱全家桶统一调度
/// 纯文字对话: glm-4.5-air
/// 图片识别: glm-4.6v
class AIService {
  Dio? _zhipuDio;

  // 智谱 API 配置 - 动态从 .env 获取
  String get _zhipuApiKey => dotenv.env['ZHIPU_API_KEY'] ?? '';
  String get _zhipuBaseUrl => dotenv.env['ZHIPU_BASE_URL'] ?? 'https://open.bigmodel.cn/api/paas/v4/';
  String get _textModel => dotenv.env['ZHIPU_MODEL_TEXT'] ?? 'glm-4.5-air';
  String get _visionModel => dotenv.env['ZHIPU_MODEL_VISION'] ?? 'glm-4.6v';

  // Lazy getter for Zhipu Dio
  Dio get _dio {
    _zhipuDio ??= Dio(BaseOptions(
      baseUrl: _zhipuBaseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      validateStatus: (status) => status != null && status < 500,
    ));
    return _zhipuDio!;
  }

  /// 纯文字对话 - 使用智谱 glm-4.5-air
  Future<String> askAgent(String question, String contextData) async {
    if (_zhipuApiKey.isEmpty) {
      throw Exception('智谱 API Key 未配置，请在 .env 中设置 ZHIPU_API_KEY');
    }

    // 更新请求配置
    _dio.options.baseUrl = _zhipuBaseUrl;
    _dio.options.headers['Authorization'] = 'Bearer $_zhipuApiKey';

    try {
      final response = await _dio.post(
        'chat/completions',
        data: {
          'model': _textModel,
          'messages': [
            {
              'role': 'system',
              'content': '你是一个精通中国家族人情往来的智能管家。以下是用户的家族成员数据：$contextData。请基于此数据回答问题，若涉及送礼请给出符合辈分和习俗的体面建议。回答要有人情味且使用，不要一股ai味。'
            },
            {
              'role': 'user',
              'content': question,
            }
          ],
          'temperature': 0.7,
        },
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception('未知错误: $e');
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

    // 转换图片为 Base64 Data URI
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final extension = imageFile.path.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mimeType;base64,$base64Image';

    try {
      final response = await _dio.post(
        'chat/completions',
        data: {
          'model': _visionModel,
          'messages': [
            {
              'role': 'system',
              'content': '''你是一个精通中国家族礼尚往来的智能管家。
任务：从图片中提取【姓名、金额、事件、日期】。
家族成员数据：$contextData

匹配规则：
1. 对比家族成员数据中的姓名，若完全匹配则返回 matched_id
2. 若姓名不完全匹配但相似，返回 matched_id 和 similarity 字段
3. 若完全不匹配，标记 is_new: true

重要：必须严格返回纯 JSON 格式，不要包含任何 markdown 标记、代码块或额外文字。

JSON 格式：
{"name":"张三","amount":1000,"event":"结婚","date":"2023-10-01","matched_id":"12345","is_new":false}

如果无法识别或图片无关，返回：{}'''
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUri}
                },
                {
                  'type': 'text',
                  'text': '请识别这张礼金单据，返回纯JSON格式'
                }
              ]
            }
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
    final codeBlockPattern = RegExp(r'^```(?:json)?\s*\n?([\s\S]*?)\n?```\\s*$', multiLine: true);
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
  static Map<String, dynamic>? parseJsonResponse(String raw) {
    try {
      final cleaned = cleanJsonString(raw);
      if (cleaned.isEmpty || cleaned == '{}') {
        return {};
      }
      return json.decode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      print('JSON 解析失败: $e');
      print('原始响应: $raw');
      return null;
    }
  }
}

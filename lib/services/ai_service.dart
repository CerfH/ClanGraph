import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  late final Dio _dio;
  late final Dio _zhipuDio;

  // Use getters to access environment variables directly
  String get _apiKey => dotenv.env['AI_API_KEY'] ?? '';
  String get _baseUrl => dotenv.env['AI_BASE_URL'] ?? 'https://api.deepseek.com';
  String get _zhipuApiKey => dotenv.env['ZHIPU_API_KEY'] ?? '';
  String get _zhipuBaseUrl => dotenv.env['ZHIPU_BASE_URL'] ?? 'https://open.bigmodel.cn/api/paas/v4/';

  AIService() {
    // DeepSeek Configuration
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (status) => status != null && status < 500,
    ));

    // Zhipu Configuration
    _zhipuDio = Dio(BaseOptions(
      baseUrl: _zhipuBaseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      validateStatus: (status) => status != null && status < 500,
    ));
  }

  // Regular Text Chat (DeepSeek)
  Future<String> askAgent(String question, String contextData) async {
    if (_apiKey.isEmpty) {
      throw Exception('DeepSeek API Key not found in .env');
    }

    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers['Authorization'] = 'Bearer $_apiKey';

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个精通中国家族人情往来的智能管家。以下是用户的家族成员数据：$contextData。请基于此数据回答问题，若涉及送礼请给出符合辈分和习俗的体面建议。'
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
      throw Exception('Unknown error: $e');
    }
  }

  // Multimodal Vision Chat (Zhipu GLM-4V)
  Future<String> analyzeImage(File imageFile, String contextData) async {
    if (_zhipuApiKey.isEmpty) {
      throw Exception('Zhipu API Key not found in .env');
    }

    _zhipuDio.options.baseUrl = _zhipuBaseUrl;
    _zhipuDio.options.headers['Authorization'] = 'Bearer $_zhipuApiKey';

    // Convert image to Base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final response = await _zhipuDio.post(
        'chat/completions',
        data: {
          'model': dotenv.env['ZHIPU_MODEL_VISION'] ?? 'glm-4.6v',
          'messages': [
            {
              'role': 'system',
              'content': '''
你是一个精通中国家族礼尚往来的智能管家。
任务：从图片中提取【姓名、金额、事件、日期】。
家族成员数据：$contextData。
匹配规则：对比家族成员数据，若姓名匹配则返回 matched_id；若不匹配，根据姓氏猜测关系并标记为 is_new: true。
输出要求：严格返回 JSON 格式，不要包含 markdown 标记。
JSON 格式示例：
{
  "name": "张三",
  "amount": 1000,
  "event": "结婚",
  "date": "2023-10-01",
  "matched_id": "12345", 
  "is_new": false
}
如果无法识别或图片无关，返回空 JSON {}。
'''
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': base64Image
                  }
                },
                {
                  'type': 'text',
                  'text': '请帮我识别这张图片里的礼金信息'
                }
              ]
            }
          ],
          'temperature': 0.1, // Lower temperature for extraction tasks
        },
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception('Unknown error: $e');
    }
  }

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
      throw Exception('API Error: ${response.statusCode} - ${response.data}');
    }
    throw Exception('Failed to get response: ${response.statusCode}');
  }

  void _handleDioError(DioException e) {
    print('DioException: ${e.message}');
    if (e.response != null) {
      print('Response Data: ${e.response?.data}');
    }
    throw Exception('Network error: ${e.message}');
  }
}

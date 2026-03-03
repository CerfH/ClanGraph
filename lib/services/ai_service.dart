import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  late final Dio _dio;
  late final String _apiKey;
  late final String _baseUrl;

  AIService() {
    _apiKey = dotenv.env['AI_API_KEY'] ?? '';
    _baseUrl = dotenv.env['AI_BASE_URL'] ?? 'https://api.deepseek.com';

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (status) => status != null && status < 500, // 允许接收 4xx 错误以便调试
    ));
  }

  Future<String> askAgent(String question, String contextData) async {
    if (_apiKey.isEmpty) {
      // 尝试重新读取，因为 main 里的 load 可能是异步还没完成，或者 hot restart 后内存状态
      _apiKey = dotenv.env['AI_API_KEY'] ?? '';
      _dio.options.headers['Authorization'] = 'Bearer $_apiKey';
    }

    if (_apiKey.isEmpty) {
      throw Exception('API Key not found in .env');
    }

    // 确保每次请求都使用最新的 Key（防止初始化时 Key 为空）
    _dio.options.headers['Authorization'] = 'Bearer $_apiKey';

    try {
      print('Request Headers: ${_dio.options.headers}'); 
      // DeepSeek 官方文档通常是 https://api.deepseek.com/chat/completions
      // 如果 BaseURL 是 https://api.deepseek.com，那么 path 是 /chat/completions
      // 如果 BaseURL 已经带了 v1，那么 path 就不带 v1
      // 这里假设用户 .env 里配的是 https://api.deepseek.com
      final response = await _dio.post(
        '/chat/completions', 
        data: {
          'model': 'deepseek-chat', // 默认模型，可根据需要调整
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

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null &&
            data['choices'] != null &&
            data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].toString();
        }
      } else {
        // 增加更详细的错误日志
        print('AI Error Status: ${response.statusCode}');
        print('AI Error Body: ${response.data}');
        throw Exception('API Error: ${response.statusCode} - ${response.data}');
      }
      
      throw Exception('Failed to get response: ${response.statusCode}');
    } on DioException catch (e) {
      print('DioException: ${e.message}');
      if (e.response != null) {
        print('Response Data: ${e.response?.data}');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Unknown error: $e');
    }
  }
}

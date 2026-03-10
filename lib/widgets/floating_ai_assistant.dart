import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// 可爱的语音助手浮动按钮
/// 带有丝滑的悬浮动画，避免与底部毛玻璃按钮重叠
class FloatingAIAssistant extends StatefulWidget {
  final VoidCallback onTap;
  final bool isRightSide;

  const FloatingAIAssistant({
    super.key,
    required this.onTap,
    this.isRightSide = true,
  });

  @override
  State<FloatingAIAssistant> createState() => _FloatingAIAssistantState();
}

class _FloatingAIAssistantState extends State<FloatingAIAssistant>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _breathController;
  late final AnimationController _pulseController;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _breathAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 悬浮动画 - 上下轻柔飘动
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _floatAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );
    
    // 呼吸动画 - 轻微缩放
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOutSine,
      ),
    );
    
    // 脉冲光晕动画
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // 启动所有动画
    _floatController.repeat(reverse: true);
    _breathController.repeat(reverse: true);
    _pulseController.repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _breathController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _floatController,
        _breathController,
        _pulseController,
      ]),
      builder: (context, child) {
        // 悬浮偏移量 (上下飘动)
        final floatOffset = math.sin(_floatAnimation.value * 2 * math.pi) * 8;
        
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: GestureDetector(
            onTap: _handleTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 外圈脉冲光晕
                Transform.scale(
                  scale: 1.0 + _pulseAnimation.value * 0.3,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.electricBlue.withValues(
                        alpha: 0.15 * (1 - _pulseAnimation.value),
                      ),
                    ),
                  ),
                ),
                
                // 中圈光晕
                Transform.scale(
                  scale: _breathAnimation.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.electricBlue.withValues(alpha: 0.4),
                          AppTheme.electricBlue.withValues(alpha: 0.1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricBlue.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 主按钮
                Transform.scale(
                  scale: _breathAnimation.value,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.electricBlue,
                          AppTheme.electricBlue.withBlue(200),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricBlue.withValues(alpha: 0.5),
                          blurRadius: 15,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                
                // 小装饰点 - 增加可爱感
                Positioned(
                  right: 8,
                  top: 8 + floatOffset * 0.3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// 苹果级毛玻璃容器
/// 实现分层玻璃效果：BackdropFilter + 渐变 + 微光边框 + 阴影
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final Color backgroundColor;
  final Gradient? gradient;
  final BorderRadius borderRadius;
  final double borderWidth;
  final Color borderColor;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blurSigma = 25.0,
    this.backgroundColor = const Color(0x0DFFFFFF), // Colors.white.withOpacity(0.05)
    this.gradient,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.borderWidth = 0.5,
    this.borderColor = const Color(0x33FFFFFF), // Colors.white.withOpacity(0.2)
    this.boxShadow,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            // 1. 毛玻璃模糊层
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // 2. 背景色层
            Container(
              color: backgroundColor,
            ),
            // 3. 渐变层 (背光感)
            if (gradient != null)
              Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                ),
              ),
            // 4. 微光边框层
            Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
              ),
            ),
            // 5. 内容层
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索框专用毛玻璃容器
/// 带有顶部亮、底部暗的背光渐变
class SearchGlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;

  const SearchGlassmorphicContainer({
    super.key,
    required this.child,
    this.blurSigma = 20.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      blurSigma: blurSigma,
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      borderRadius: borderRadius,
      borderWidth: 0.5,
      borderColor: Colors.white.withValues(alpha: 0.15),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
      child: child,
    );
  }
}

/// 底部按钮专用毛玻璃容器
/// 带有更强的悬浮感和微光效果
class ButtonGlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double blurSigma;
  final BorderRadius borderRadius;

  const ButtonGlassmorphicContainer({
    super.key,
    required this.child,
    required this.onTap,
    this.blurSigma = 25.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      blurSigma: blurSigma,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      borderRadius: borderRadius,
      borderWidth: 0.5,
      borderColor: Colors.white.withValues(alpha: 0.25),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.02),
        ],
        stops: const [0.0, 0.6, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 30,
          spreadRadius: -5,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.05),
          blurRadius: 10,
          spreadRadius: -2,
          offset: const Offset(0, -2),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: child,
        ),
      ),
    );
  }
}

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
    this.backgroundColor = const Color(0x0DFFFFFF),
    this.gradient,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.borderWidth = 0.5,
    this.borderColor = const Color(0x33FFFFFF),
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
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(color: Colors.transparent),
            ),
            // 2. 背景色层
            Container(color: backgroundColor),
            // 3. 渐变层 (背光感)
            if (gradient != null)
              Container(decoration: BoxDecoration(gradient: gradient)),
            // 4. 微光边框层
            Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
            ),
            // 5. 内容层
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// 搜索框专用毛玻璃容器
/// 与底部按钮保持一致的高级毛玻璃效果
class SearchGlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;

  const SearchGlassmorphicContainer({
    super.key,
    required this.child,
    this.blurSigma = 25.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      blurSigma: blurSigma,
      // 与底部按钮一致：降低底色透明度
      backgroundColor: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.03),
      borderRadius: borderRadius,
      //搜索框边框稍细一些，更精致
      borderWidth: 0.0,
      // 与底部按钮一致：高亮度边框
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          // 与底部按钮一致：增强左上角亮度
          Colors.white.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0.10),
          Colors.black.withValues(alpha: 0.05),
        ],
        // 与底部按钮一致：光照集中在边缘
        stops: const [0.0, 0.15, 1.0],
      ),
      boxShadow: [
        // 与底部按钮一致：主阴影
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 40,
          spreadRadius: -8,
          offset: const Offset(0, 15),
        ),
        // 与底部按钮一致：顶部微光
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.15),
          blurRadius: 15,
          spreadRadius: -2,
          offset: const Offset(0, -1),
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
      // 稍微降低底色透明度，让背景的星系星点能透过来
      backgroundColor: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.03),
      borderRadius: borderRadius,
      // 边框宽度 1.8，在手机端最精致
      borderWidth: 1.8,
      // 高亮度边框，金属冷光感
      borderColor: Colors.white.withValues(alpha: 0.9),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          // 增强左上角亮度，白一圈的关键
          Colors.white.withValues(alpha: 0.60),
          Colors.white.withValues(alpha: 0.10),
          Colors.black.withValues(alpha: 0.05),
        ],
        // 光照效果集中在边缘 15% 区域
        stops: const [0.0, 0.15, 1.0],
      ),
      boxShadow: [
        // 主阴影：深色下沉感
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 40,
          spreadRadius: -8,
          offset: const Offset(0, 15),
        ),
        // 副阴影：顶部微光，增强边缘厚度
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.15),
          blurRadius: 15,
          spreadRadius: -2,
          offset: const Offset(0, -1),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: child,
        ),
      ),
    );
  }
}

enum ExportDimension { basicInfo, giftHistory, relations, bio }

class ExportConfig {
  final Set<ExportDimension> enabledDimensions;
  final String centerId;

  const ExportConfig({required this.enabledDimensions, required this.centerId});

  // 默认配置：基本信息 + 亲缘关系
  static ExportConfig defaultConfig(String centerId) => ExportConfig(
    enabledDimensions: {ExportDimension.basicInfo, ExportDimension.relations},
    centerId: centerId,
  );
}

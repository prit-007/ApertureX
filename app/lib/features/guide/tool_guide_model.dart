import 'package:flutter/material.dart';

/// Categories of photo editing tools and workflows in ApertureX.
enum ToolCategory {
  light('Light', Icons.wb_sunny_outlined),
  color('Color', Icons.palette_outlined),
  effects('Effects', Icons.auto_awesome),
  detail('Detail', Icons.details_outlined),
  optics('Optics', Icons.camera_outlined),
  geometry('Geometry', Icons.crop_rotate),
  masking('Masking', Icons.brush_outlined),
  workflow('Workflow', Icons.tune);

  final String label;
  final IconData icon;

  const ToolCategory(this.label, this.icon);
}

/// Comprehensive documentation model for a single tool or workflow in ApertureX.
class ToolGuideModel {
  final String id;
  final String title;
  final ToolCategory category;
  final String summary;
  final String description;
  final IconData icon;
  final List<String> proTips;
  final String bestUsedFor;
  final String? shortcut;

  const ToolGuideModel({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.description,
    required this.icon,
    required this.proTips,
    required this.bestUsedFor,
    this.shortcut,
  });
}

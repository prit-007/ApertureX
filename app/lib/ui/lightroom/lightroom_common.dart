import '../../l10n/app_strings.dart';

/// Master editing tabs in the Lightroom shell.
enum MasterTab {
  lightColor,
  effectsDetail,
  cropGeometry,
  proTools,
  looksPresets,
  masks,
  plugins,
}

/// Tracks which tabs and sub-tabs have uncommitted changes.
class LightroomDirtyState {
  const LightroomDirtyState({
    required this.hasTabChanges,
    required this.modifiedMasterMask,
    required this.modifiedSubTabMask,
  });

  final bool hasTabChanges;
  final int modifiedMasterMask;
  final int modifiedSubTabMask;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LightroomDirtyState &&
          runtimeType == other.runtimeType &&
          hasTabChanges == other.hasTabChanges &&
          modifiedMasterMask == other.modifiedMasterMask &&
          modifiedSubTabMask == other.modifiedSubTabMask;

  @override
  int get hashCode =>
      Object.hash(hasTabChanges, modifiedMasterMask, modifiedSubTabMask);
}

String masterTabLabel(MasterTab tab, [AppStrings? strings]) => switch (tab) {
      MasterTab.lightColor => strings?.lightAndColor ?? 'Light & Color',
      MasterTab.effectsDetail => strings?.effectsAndDetail ?? 'Effects & Detail',
      MasterTab.cropGeometry => strings?.cropAndGeometry ?? 'Crop & Geometry',
      MasterTab.proTools => strings?.proTools ?? 'Pro Tools',
      MasterTab.looksPresets => strings?.looksAndPresets ?? 'Looks & Presets',
      MasterTab.masks => strings?.masks ?? 'Masks',
      MasterTab.plugins => strings?.plugins ?? 'Plugins',
    };

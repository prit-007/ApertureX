import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized internationalized strings and localization delegate for ApertureX (#10).
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('de'),
    Locale('fr'),
    Locale('ja'),
    Locale('zh'),
  ];

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        const AppStrings(Locale('en'));
  }

  String _t(Map<String, String> translations, String enDefault) {
    return translations[locale.languageCode] ?? enDefault;
  }

  // --- General Navigation & Headers ---
  String get appName => 'ApertureX';
  String get gallery => _t({
        'es': 'Galería',
        'de': 'Galerie',
        'fr': 'Galerie',
        'ja': 'ギャラリー',
        'zh': '图库',
      }, 'Gallery');

  String get editor => _t({
        'es': 'Editor',
        'de': 'Editor',
        'fr': 'Éditeur',
        'ja': 'エディター',
        'zh': '编辑器',
      }, 'Editor');

  String get settings => _t({
        'es': 'Ajustes',
        'de': 'Einstellungen',
        'fr': 'Paramètres',
        'ja': '設定',
        'zh': '设置',
      }, 'Settings');

  String get recent => _t({
        'es': 'Recientes',
        'de': 'Zuletzt',
        'fr': 'Récents',
        'ja': '最近の項目',
        'zh': '最近',
      }, 'Recent');

  String get tryAgain => _t({
        'es': 'Reintentar',
        'de': 'Erneut versuchen',
        'fr': 'Réessayer',
        'ja': '再試行',
        'zh': '重试',
      }, 'Try again');

  String get couldNotOpenPhoto => _t({
        'es': 'No se pudo abrir esta foto',
        'de': 'Foto konnte nicht geöffnet werden',
        'fr': 'Impossible d\'ouvrir cette photo',
        'ja': 'この写真を開けませんでした',
        'zh': '无法打开此照片',
      }, 'Could not open this photo');

  String get preparingShare => _t({
        'es': 'Preparando para compartir…',
        'de': 'Freigabe wird vorbereitet…',
        'fr': 'Préparation du partage…',
        'ja': '共有を準備中…',
        'zh': '正在准备分享…',
      }, 'Preparing share…');

  String selectedCount(int count) {
    switch (locale.languageCode) {
      case 'es':
        return '$count seleccionado(s)';
      case 'de':
        return '$count ausgewählt';
      case 'fr':
        return '$count sélectionné(s)';
      case 'ja':
        return '$count 項目を選択';
      case 'zh':
        return '已选择 $count 项';
      default:
        return '$count selected';
    }
  }

  String syncedSettings(int count) {
    switch (locale.languageCode) {
      case 'es':
        return 'Ajustes sincronizados con $count foto(s)';
      case 'de':
        return 'Einstellungen mit $count Foto(s) synchronisiert';
      case 'fr':
        return 'Paramètres synchronisés avec $count photo(s)';
      case 'ja':
        return '$count 枚の写真に設定を同期しました';
      case 'zh':
        return '已将设置同步到 $count 张照片';
      default:
        return 'Synced settings to $count photo(s)';
    }
  }

  String appliedSettings(int count) {
    switch (locale.languageCode) {
      case 'es':
        return 'Ajustes aplicados a $count foto(s)';
      case 'de':
        return 'Einstellungen auf $count Foto(s) angewendet';
      case 'fr':
        return 'Paramètres appliqués à $count photo(s)';
      case 'ja':
        return '$count 枚の写真に設定を適用しました';
      case 'zh':
        return '已将设置应用到 $count 张照片';
      default:
        return 'Applied settings to $count photo(s)';
    }
  }

  // --- Lightroom Master Tabs ---
  String get lightAndColor => _t({
        'es': 'Luz y color',
        'de': 'Licht & Farbe',
        'fr': 'Lumière et couleur',
        'ja': 'ライト & カラー',
        'zh': '光效与色彩',
      }, 'Light & Color');

  String get effectsAndDetail => _t({
        'es': 'Efectos y detalle',
        'de': 'Effekte & Details',
        'fr': 'Effets et détails',
        'ja': '効果 & ディテール',
        'zh': '效果与细节',
      }, 'Effects & Detail');

  String get cropAndGeometry => _t({
        'es': 'Recorte y geometría',
        'de': 'Zuschneiden & Geometrie',
        'fr': 'Recadrage et géométrie',
        'ja': '切り抜き & ジオメトリ',
        'zh': '裁切与几何',
      }, 'Crop & Geometry');

  String get proTools => _t({
        'es': 'Herramientas Pro',
        'de': 'Profi-Werkzeuge',
        'fr': 'Outils Pro',
        'ja': 'プロツール',
        'zh': '专业工具',
      }, 'Pro Tools');

  String get looksAndPresets => _t({
        'es': 'Estilos y ajustes preestablecidos',
        'de': 'Looks & Vorgaben',
        'fr': 'Styles et paramètres prédéfinis',
        'ja': 'スタイル & プリセット',
        'zh': '外观与预设',
      }, 'Looks & Presets');

  String get masks => _t({
        'es': 'Máscaras',
        'de': 'Masken',
        'fr': 'Masques',
        'ja': 'マスク',
        'zh': '蒙版',
      }, 'Masks');

  String get plugins => _t({
        'es': 'Plugins',
        'de': 'Plugins',
        'fr': 'Extensions',
        'ja': 'プラグイン',
        'zh': '插件',
      }, 'Plugins');

  // --- Editor Actions & Tooltips ---
  String get discardChanges => _t({
        'es': 'Descartar cambios',
        'de': 'Änderungen verwerfen',
        'fr': 'Ignorer les modifications',
        'ja': '変更を破棄',
        'zh': '放弃更改',
      }, 'Discard changes');

  String get applyChanges => _t({
        'es': 'Aplicar cambios',
        'de': 'Änderungen anwenden',
        'fr': 'Appliquer les modifications',
        'ja': '変更を適用',
        'zh': '应用更改',
      }, 'Apply changes');

  String get undo => _t({
        'es': 'Deshacer',
        'de': 'Rückgängig',
        'fr': 'Annuler',
        'ja': '元に戻す',
        'zh': '撤消',
      }, 'Undo');

  String get redo => _t({
        'es': 'Rehacer',
        'de': 'Wiederholen',
        'fr': 'Rétablir',
        'ja': 'やり直す',
        'zh': '重做',
      }, 'Redo');

  String get autoTone => _t({
        'es': 'Tono automático',
        'de': 'Automatischer Farbton',
        'fr': 'Tonalité automatique',
        'ja': '自動補正',
        'zh': '自动色调',
      }, 'Auto Tone');

  String get holdToCompare => _t({
        'es': 'Mantener para comparar',
        'de': 'Zum Vergleichen gedrückt halten',
        'fr': 'Maintenir pour comparer',
        'ja': '長押しで比較',
        'zh': '长按对比',
      }, 'Hold to compare');

  String get wiperCompare => _t({
        'es': 'Comparación dividida',
        'de': 'Wischvergleich teilen',
        'fr': 'Comparaison par balayage',
        'ja': 'ワイパー分割比較',
        'zh': '滑动分屏对比',
      }, 'Split curtain wiper compare');

  String get exposureAssist => _t({
        'es': 'Asistente de exposición',
        'de': 'Belichtungsassistent',
        'fr': 'Assistant d\'exposition',
        'ja': '露出アシスト',
        'zh': '曝光辅助',
      }, 'Exposure assist zebras & false color');

  String get softProofing => _t({
        'es': 'Prueba en pantalla',
        'de': 'Softproof',
        'fr': 'Épreuvage écran',
        'ja': 'ソフトプルーフ',
        'zh': '软打样',
      }, 'Soft proofing & print simulation');

  String get historyAndBranches => _t({
        'es': 'Historial y ramas',
        'de': 'Verlauf & Verzweigungen',
        'fr': 'Historique et branches',
        'ja': '編集履歴 & 分岐',
        'zh': '历史记录与分支',
      }, 'Edit history & branches');

  // --- Selection & Batch Actions ---
  String get export => _t({
        'es': 'Exportar',
        'de': 'Exportieren',
        'fr': 'Exporter',
        'ja': '書き出し',
        'zh': '导出',
      }, 'Export');

  String get exporting => _t({
        'es': 'Exportando…',
        'de': 'Exportieren…',
        'fr': 'Exportation…',
        'ja': '書き出し中…',
        'zh': '正在导出…',
      }, 'Exporting…');

  String get copyEdits => _t({
        'es': 'Copiar ediciones',
        'de': 'Bearbeitungen kopieren',
        'fr': 'Copier les modifications',
        'ja': '編集内容をコピー',
        'zh': '复制编辑',
      }, 'Copy edits');

  String get paste => _t({
        'es': 'Pegar',
        'de': 'Einfügen',
        'fr': 'Coller',
        'ja': '貼り付け',
        'zh': '粘贴',
      }, 'Paste');

  String get syncEdits => _t({
        'es': 'Sincronizar ediciones',
        'de': 'Bearbeitungen synchronisieren',
        'fr': 'Synchroniser les modifications',
        'ja': '編集内容を同期',
        'zh': '同步编辑',
      }, 'Sync edits');

  String get virtualCopy => _t({
        'es': 'Copia virtual',
        'de': 'Virtuelle Kopie',
        'fr': 'Copie virtuelle',
        'ja': '仮想コピー',
        'zh': '虚拟副本',
      }, 'Virtual copy');

  String get hdrMerge => _t({
        'es': 'Fusión HDR',
        'de': 'HDR-Zusammenführung',
        'fr': 'Fusion HDR',
        'ja': 'HDR結合',
        'zh': 'HDR合并',
      }, 'HDR Merge');

  // --- Asset Management ---
  String get colorLabels => _t({
        'es': 'Etiquetas de color',
        'de': 'Farbetiketten',
        'fr': 'Libellés de couleur',
        'ja': 'カラーラベル',
        'zh': '颜色标签',
      }, 'Color Labels');

  String get keywords => _t({
        'es': 'Palabras clave',
        'de': 'Stichwörter',
        'fr': 'Mots-clés',
        'ja': 'キーワード',
        'zh': '关键字',
      }, 'Keywords');

  String get addKeyword => _t({
        'es': 'Añadir palabra clave',
        'de': 'Stichwort hinzufügen',
        'fr': 'Ajouter un mot-clé',
        'ja': 'キーワードを追加',
        'zh': '添加关键字',
      }, 'Add keyword');

  String get clearLabel => _t({
        'es': 'Borrar etiqueta',
        'de': 'Etikett löschen',
        'fr': 'Effacer le libellé',
        'ja': 'ラベルを消去',
        'zh': '清除标签',
      }, 'Clear label');

  // --- Soft Proofing & Print ---
  String get proofProfile => _t({
        'es': 'Perfil de prueba',
        'de': 'Proof-Profil',
        'fr': 'Profil d\'épreuve',
        'ja': 'プルーフプロファイル',
        'zh': '打样配置文件',
      }, 'Proof Profile');

  String get renderingIntent => _t({
        'es': 'Propósito de reproducción',
        'de': 'Renderpriorität',
        'fr': 'Mode de rendu',
        'ja': 'レンダリングインテント',
        'zh': '渲染意图',
      }, 'Rendering Intent');

  String get simulatePaperAndInk => _t({
        'es': 'Simular papel y tinta',
        'de': 'Papier & Tinte simulieren',
        'fr': 'Simuler le papier et l\'encre',
        'ja': '紙とインクのシミュレーション',
        'zh': '模拟纸张和墨水',
      }, 'Simulate Paper & Ink');

  String get gamutWarning => _t({
        'es': 'Aviso de gama',
        'de': 'Farbumfang-Warnung',
        'fr': 'Avertissement de gamme',
        'ja': '色域警告',
        'zh': '色域警告',
      }, 'Gamut Warning (Clip Overlay)');

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

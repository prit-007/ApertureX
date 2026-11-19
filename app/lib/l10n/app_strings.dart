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

  String get settingsHub => _t({
        'es': 'Panel de Ajustes',
        'de': 'Einstellungs-Hub',
        'fr': 'Centre de Paramètres',
        'ja': '設定ハブ',
        'zh': '设置中心',
      }, 'Settings Hub');

  String get workspaceAndShell => _t({
        'es': 'Espacio de trabajo y estructura',
        'de': 'Arbeitsbereich & Shell',
        'fr': 'Espace de travail et interface',
        'ja': 'ワークスペースとシェル',
        'zh': '工作区与界面',
      }, 'Workspace & Shell');

  String get workspaceAndShellDesc => _t({
        'es': 'Estructuras duales (Lightroom / Snapseed), tema, interfaz translúcida',
        'de': 'Duale Shells (Lightroom / Snapseed), Theme, Glasmorphismus',
        'fr': 'Double interface (Lightroom / Snapseed), thème, interface translucide',
        'ja': 'デュアルシェル（Lightroom / Snapseed）、テーマ、透過UI',
        'zh': '双重界面（Lightroom / Snapseed）、主题、拟玻质感UI',
      }, 'Dual shells (Lightroom / Snapseed), theme, glassmorphic UI');

  String get stylusAndInput => _t({
        'es': 'Lápiz y entrada táctil',
        'de': 'Stylus & Eingabe',
        'fr': 'Stylet et saisie',
        'ja': 'スタイラスと入力',
        'zh': '手写笔与输入',
      }, 'Stylus & Input');

  String get stylusAndInputDesc => _t({
        'es': 'Rechazo de palma, sensibilidad a la presión, borrador invertido',
        'de': 'Handflächenerkennung, Druckempfindlichkeit, Stiftradiermodus',
        'fr': 'Rejet de la paume, sensibilité à la pression, gomme inversée',
        'ja': 'パームリジェクション、筆圧感知、反転消しゴム',
        'zh': '防手掌误触、压感灵敏度、笔尾橡皮擦',
      }, 'Palm rejection, pressure sensitivity, inverted stylus eraser');

  String get exportDefaults => _t({
        'es': 'Predeterminados de exportación',
        'de': 'Export-Standardwerte',
        'fr': 'Valeurs d\'exportation par défaut',
        'ja': '書き出しのデフォルト',
        'zh': '默认导出设置',
      }, 'Export Defaults');

  String get exportDefaultsDesc => _t({
        'es': 'Calidad JPEG, dimensiones máximas, firma C2PA fuera de línea',
        'de': 'Standard-JPEG-Qualität, maximale Abmessungen, C2PA-Offline-Signatur',
        'fr': 'Qualité JPEG par défaut, dimensions maximales, signature C2PA hors ligne',
        'ja': '標準JPEG品質、最大解像度、C2PAオフライン署名',
        'zh': '默认JPEG画质、最大尺寸、C2PA离线签名',
      }, 'Default JPEG quality, max dimensions, C2PA offline signing');

  String get privacyAndLocalAi => _t({
        'es': 'Privacidad e IA local',
        'de': 'Datenschutz & Lokale KI',
        'fr': 'Confidentialité et IA locale',
        'ja': 'プライバシーとローカルAI',
        'zh': '隐私与本地AI',
      }, 'Privacy & Local AI');

  String get privacyAndLocalAiDesc => _t({
        'es': 'Inferencia neuronal en el dispositivo, descarga de modelos, cero telemetría',
        'de': 'On-Device neuronale Inferenz, Modell-Downloads, null Telemetrie',
        'fr': 'Inférence neuronale sur l\'appareil, téléchargement de modèles, zéro télémétrie',
        'ja': 'デバイス内ニューラル推論、モデルダウンロード、テレメトリゼロ',
        'zh': '设备端神经网络推理、模型下载、零遥测',
      }, 'On-device neural inference consent, model downloads, zero telemetry');

  String get aboutApertureX => _t({
        'es': 'Acerca de ApertureX',
        'de': 'Über ApertureX',
        'fr': 'À propos d\'ApertureX',
        'ja': 'ApertureX について',
        'zh': '关于 ApertureX',
      }, 'About ApertureX');

  String get aboutApertureXDesc => _t({
        'es': 'Versión, desarrolladores, licencias de código abierto, garantía en dispositivo',
        'de': 'App-Version, Entwickler, Open-Source-Lizenzen, On-Device-Garantie',
        'fr': 'Version de l\'application, développeurs, licences libres, garantie sur l\'appareil',
        'ja': 'アプリバージョン、開発者、オープンソースライセンス、デバイス内保証',
        'zh': '应用版本、开发者、开源许可证、设备端保证',
      }, 'App version, developers, open-source licenses, on-device guarantee');

  // --- Workspace & Shell Sheet Strings ---
  String get editorShellLayout => _t({
        'es': 'Estructura del editor',
        'de': 'Editor-Shell-Layout',
        'fr': 'Disposition de l\'éditeur',
        'ja': 'エディターシェル配置',
        'zh': '编辑器界面布局',
      }, 'Editor Shell Layout');

  String get panelsLightroom => _t({
        'es': 'Paneles (Lightroom)',
        'de': 'Panels (Lightroom)',
        'fr': 'Panneaux (Lightroom)',
        'ja': 'パネル（Lightroom）',
        'zh': '面板（Lightroom）',
      }, 'Panels (Lightroom)');

  String get gesturesSnapseed => _t({
        'es': 'Gestos (Snapseed)',
        'de': 'Gesten (Snapseed)',
        'fr': 'Gestes (Snapseed)',
        'ja': 'ジェスチャー（Snapseed）',
        'zh': '手势（Snapseed）',
      }, 'Gestures (Snapseed)');

  String get themeMode => _t({
        'es': 'Modo de tema',
        'de': 'Theme-Modus',
        'fr': 'Mode de thème',
        'ja': 'テーマモード',
        'zh': '主题模式',
      }, 'Theme Mode');

  String get systemTheme => _t({
        'es': 'Sistema',
        'de': 'System',
        'fr': 'Système',
        'ja': 'システム',
        'zh': '跟随系统',
      }, 'System');

  String get lightTheme => _t({
        'es': 'Claro',
        'de': 'Hell',
        'fr': 'Clair',
        'ja': 'ライト',
        'zh': '浅色',
      }, 'Light');

  String get darkTheme => _t({
        'es': 'Oscuro',
        'de': 'Dunkel',
        'fr': 'Sombre',
        'ja': 'ダーク',
        'zh': '深色',
      }, 'Dark');

  String get glassmorphicUi => _t({
        'es': 'Interfaz translúcida',
        'de': 'Glasmorphismus-UI',
        'fr': 'Interface translucide',
        'ja': 'グラスモフィズムUI',
        'zh': '拟玻质感UI',
      }, 'Glassmorphic UI');

  String get glassmorphicUiDesc => _t({
        'es': 'Paneles y HUD de cristal esmerilado translúcido para ver la foto detrás',
        'de': 'Durchscheinende Milchglas-Panels und HUD, damit das Foto sichtbar bleibt',
        'fr': 'Panneaux et affichage translucides en verre dépoli pour voir la photo',
        'ja': '写真が見通せる半透明すりガラス調パネルとHUD',
        'zh': '半透明磨砂玻璃面板与HUD，使照片在控件下方隐现',
      }, 'Translucent frosted-glass panels and HUD so photo stays visible');

  // --- Stylus & Input Sheet Strings ---
  String get palmRejection => _t({
        'es': 'Rechazo de palma',
        'de': 'Handflächenerkennung',
        'fr': 'Rejet de la paume',
        'ja': 'パームリジェクション',
        'zh': '防手掌误触',
      }, 'Palm Rejection');

  String get palmRejectionDesc => _t({
        'es': 'Rechaza toques táctiles mientras se utiliza el lápiz activo',
        'de': 'Touch-Eingaben ignorieren, wenn ein aktiver Stift verwendet wird',
        'fr': 'Rejette les événements tactiles lors de l\'utilisation d\'un stylet actif',
        'ja': 'アクティブペン使用中のタッチ入力を無視',
        'zh': '使用主动式电磁笔时忽略手掌触摸输入',
      }, 'Reject touch pointer events when using active pen');

  String get pressureSensitivity => _t({
        'es': 'Sensibilidad a la presión',
        'de': 'Druckempfindlichkeit',
        'fr': 'Sensibilité à la pression',
        'ja': '筆圧感知',
        'zh': '压感灵敏度',
      }, 'Pressure Sensitivity');

  String get pressureSensitivityDesc => _t({
        'es': 'Varía el flujo del pincel con la presión dinámica del lápiz (event.pressure)',
        'de': 'Pinselstärke dynamisch mit Stiftdruck variieren (event.pressure)',
        'fr': 'Varie le flux du pinceau avec la pression dynamique du stylet (event.pressure)',
        'ja': 'ペンの筆圧に応じてブラシ流量を動的に変化（event.pressure）',
        'zh': '根据笔尖下压实时改变画笔流量与不透明度（event.pressure）',
      }, 'Vary brush flow with dynamic pen pressure (event.pressure)');

  String get invertedStylusSupport => _t({
        'es': 'Compatibilidad con lápiz invertido',
        'de': 'Stiftradiermodus-Unterstützung',
        'fr': 'Prise en charge du stylet inversé',
        'ja': '反転スタイラス対応',
        'zh': '支持笔尾橡皮擦',
      }, 'Inverted Stylus Support');

  String get invertedStylusSupportDesc => _t({
        'es': 'Gira el lápiz para cambiar al instante al modo borrador de precisión',
        'de': 'Stift umdrehen, um sofort in den Präzisions-Radiergummi-Modus zu wechseln',
        'fr': 'Retournez le stylet pour passer instantanément en mode gomme de précision',
        'ja': 'ペンを反転させて高精度消しゴムモードへ瞬時に切り替え',
        'zh': '将电磁笔反转即可秒切至精准橡皮擦模式',
      }, 'Flip active pen to instantly switch to precision eraser mode');

  // --- Export Defaults Sheet Strings ---
  String get quality => _t({
        'es': 'Calidad',
        'de': 'Qualität',
        'fr': 'Qualité',
        'ja': '品質',
        'zh': '画质',
      }, 'Quality');

  String get maxSizeLongSide => _t({
        'es': 'Tamaño máximo (lado largo)',
        'de': 'Max. Größe (lange Kante)',
        'fr': 'Taille max (bord long)',
        'ja': '最大サイズ（長辺）',
        'zh': '最大边长（长边）',
      }, 'Max size (long side)');

  String get sizeOriginal => _t({
        'es': 'Original',
        'de': 'Original',
        'fr': 'Original',
        'ja': 'オリジナル',
        'zh': '原始尺寸',
      }, 'Original');

  String get c2paContentCredentials => _t({
        'es': 'Credenciales de contenido C2PA',
        'de': 'C2PA-Inhaltsnachweise',
        'fr': 'Identifiants de contenu C2PA',
        'ja': 'C2PA コンテンツクレデンシャル',
        'zh': 'C2PA 内容凭据',
      }, 'C2PA Content Credentials');

  String get c2paDesc => _t({
        'es': 'Firma la procedencia de la imagen criptográficamente con Ed25519 en local',
        'de': 'Signiert die Bildprovenienz offline kryptografisch mit Ed25519',
        'fr': 'Signe cryptographiquement la provenance de l\'image hors ligne avec Ed25519',
        'ja': 'Ed25519で画像の出所をオフラインで暗号署名',
        'zh': '通过Ed25519离线对图像来源进行密码学签名',
      }, 'Cryptographically signs image provenance offline with Ed25519');

  // --- Privacy & AI Sheet Strings ---
  String get onDeviceAiProcessing => _t({
        'es': 'Procesamiento de IA en el dispositivo',
        'de': 'On-Device KI-Verarbeitung',
        'fr': 'Traitement de l\'IA sur l\'appareil',
        'ja': 'デバイス内AI処理',
        'zh': '设备端本地AI处理',
      }, 'On-device AI processing');

  String get onDeviceAiProcessingDesc => _t({
        'es': 'Habilita máscaras inteligentes locales (Sujeto/Cielo) con Depth Anything y U2Net. 100% en dispositivo, cero telemetría.',
        'de': 'Ermöglicht lokale intelligente Maskierung (Motiv/Himmel) über Depth Anything & U2Net. 100% auf dem Gerät, null Telemetrie.',
        'fr': 'Active le masquage intelligent local (Sujet/Ciel) via Depth Anything et U2Net. 100% sur l\'appareil, zéro télémétrie.',
        'ja': 'Depth AnythingとU2Netによるローカル高度マスキング（被写体/空を選択）を有効化。100%端末内処理、テレメトリゼロ。',
        'zh': '启用基于Depth Anything与U2Net的本地智能蒙版（主体/天空选区）。100%设备端运行，零遥测。',
      }, 'Enables local intelligent masking (Select Subject/Sky) via Depth Anything & U2Net. 100% offline, zero telemetry.');

  String get aiModelsAndNeuralRuntimes => _t({
        'es': 'Modelos de IA y entornos neuronales',
        'de': 'KI-Modelle & Neuronale Runtimes',
        'fr': 'Modèles d\'IA et moteurs neuronaux',
        'ja': 'AIモデル & ニューラルランタイム',
        'zh': 'AI模型与神经计算运行时',
      }, 'AI Models & Neural Runtimes');

  String get aiModelsAndNeuralRuntimesDesc => _t({
        'es': 'Administra el entorno ONNX, pesos de modelos y aceleración por hardware',
        'de': 'ONNX-Runtime, Modellgewichte und Inferenz-Hardware verwalten',
        'fr': 'Gérez le runtime ONNX, les poids des modèles et l\'accélération matérielle',
        'ja': 'ONNXランタイム、モデル重み、推論ハードウェアを管理',
        'zh': '管理ONNX运行时、模型权重与硬件加速',
      }, 'Manage ONNX runtime, model weights, and inference hardware');

  // --- About Sheet Strings ---
  String get appOverviewAndPhilosophy => _t({
        'es': 'Visión general y filosofía',
        'de': 'App-Übersicht & Philosophie',
        'fr': 'Présentation et philosophie',
        'ja': 'アプリ概要と哲学',
        'zh': '应用概览与理念',
      }, 'App Overview & Philosophy');

  String get developersAndMaintainers => _t({
        'es': 'Desarrolladores y mantenedores',
        'de': 'Entwickler & Maintainer',
        'fr': 'Développeurs et mainteneurs',
        'ja': '開発者とメンテナー',
        'zh': '开发者与维护者',
      }, 'Developers & Maintainers');

  String get openSourceLicenses => _t({
        'es': 'Licencias de código abierto',
        'de': 'Open-Source-Lizenzen',
        'fr': 'Licences open source',
        'ja': 'オープンソースライセンス',
        'zh': '开源许可证',
      }, 'Open-Source Licenses');

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

  // --- Lightroom Master Tabs & Categories ---
  String get light => _t({
        'es': 'Luz',
        'de': 'Licht',
        'fr': 'Lumière',
        'ja': 'ライト',
        'zh': '光效',
      }, 'Light');

  String get color => _t({
        'es': 'Color',
        'de': 'Farbe',
        'fr': 'Couleur',
        'ja': 'カラー',
        'zh': '色彩',
      }, 'Color');

  String get effects => _t({
        'es': 'Efectos',
        'de': 'Effekte',
        'fr': 'Effets',
        'ja': '効果',
        'zh': '效果',
      }, 'Effects');

  String get detail => _t({
        'es': 'Detalle',
        'de': 'Details',
        'fr': 'Détails',
        'ja': 'ディテール',
        'zh': '细节',
      }, 'Detail');

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

  String get wiper => _t({
        'es': 'Cortinilla',
        'de': 'Wischer',
        'fr': 'Volet',
        'ja': 'ワイパー',
        'zh': '擦除',
      }, 'Wiper');

  String get splitCompare => _t({
        'es': 'División A/D',
        'de': 'V/N-Teilung',
        'fr': 'Scinder A/A',
        'ja': '前/後 分割',
        'zh': '前/后分屏',
      }, 'B/A Split');

  String get previousPhoto => _t({
        'es': 'Foto anterior',
        'de': 'Vorheriges Foto',
        'fr': 'Photo précédente',
        'ja': '前の写真',
        'zh': '上一张照片',
      }, 'Previous photo');

  String get nextPhoto => _t({
        'es': 'Foto siguiente',
        'de': 'Nächstes Foto',
        'fr': 'Photo suivante',
        'ja': '次の写真',
        'zh': '下一张照片',
      }, 'Next photo');

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

  String get histogram => _t({
        'es': 'Histograma',
        'de': 'Histogramm',
        'fr': 'Histogramme',
        'ja': 'ヒストグラム',
        'zh': '直方图',
      }, 'Histogram');

  // --- Mask Controls ---
  String get maskBrush => _t({
        'es': 'Pincel',
        'de': 'Pinsel',
        'fr': 'Pinceau',
        'ja': 'ブラシ',
        'zh': '画笔',
      }, 'Brush');

  String get maskLinearGradient => _t({
        'es': 'Gradiente lineal',
        'de': 'Linearer Verlauf',
        'fr': 'Dégradé linéaire',
        'ja': '線形グラデーション',
        'zh': '线性渐变',
      }, 'Linear Gradient');

  String get maskRadialGradient => _t({
        'es': 'Gradiente radial',
        'de': 'Radialer Verlauf',
        'fr': 'Dégradé radial',
        'ja': '円グラデーション',
        'zh': '径向渐变',
      }, 'Radial Gradient');

  String get maskSubject => _t({
        'es': 'Sujeto',
        'de': 'Motiv',
        'fr': 'Sujet',
        'ja': '被写体',
        'zh': '主体',
      }, 'Subject');

  String get maskSky => _t({
        'es': 'Cielo',
        'de': 'Himmel',
        'fr': 'Ciel',
        'ja': '空',
        'zh': '天空',
      }, 'Sky');

  String get maskLuminance => _t({
        'es': 'Luminancia',
        'de': 'Helligkeit',
        'fr': 'Luminance',
        'ja': '輝度',
        'zh': '亮度',
      }, 'Luminance');

  String get maskColorRange => _t({
        'es': 'Rango de color',
        'de': 'Farbebereich',
        'fr': 'Plage de couleurs',
        'ja': '色域',
        'zh': '颜色范围',
      }, 'Color Range');

  String get maskAutoBrush => _t({
        'es': 'Pincel automático',
        'de': 'Automatischer Pinsel',
        'fr': 'Pinceau automatique',
        'ja': '自動ブラシ',
        'zh': '自动画笔',
      }, 'Auto Brush');

  String get maskDepthRange => _t({
        'es': 'Rango de profundidad',
        'de': 'Tiefenbereich',
        'fr': 'Plage de profondeur',
        'ja': '深度範囲',
        'zh': '深度范围',
      }, 'Depth Range');

  String get maskNoPhotoRefine => _t({
        'es': 'No hay foto cargada para refinar máscara',
        'de': 'Kein Foto zum Verfeinern der Maske geladen',
        'fr': 'Aucune photo chargée pour affiner le masque',
        'ja': 'マスクを洗練する写真が読み込まれていません',
        'zh': '没有加载照片来细化蒙版',
      }, 'No photo loaded to refine mask');

  String get maskSampleLuminance => _t({
        'es': 'Toca la foto para muestrear banda de luminancia',
        'de': 'Foto antippen, um Helligkeitsband zu probieren',
        'fr': 'Touchez la photo pour échantillonner la bande de luminance',
        'ja': '写真をタップして輝度帯をサンプリング',
        'zh': '点按照片采样亮度带',
      }, 'Tap photo to sample luminance band');

  String get maskSampleColor => _t({
        'es': 'Toca la foto para muestrear color objetivo',
        'de': 'Foto antippen, um Ziel-Farbe zu probieren',
        'fr': 'Touchez la photo pour échantillonner la couleur cible',
        'ja': '写真をタップして対象色をサンプリング',
        'zh': '点按照片采样目标颜色',
      }, 'Tap photo to sample target color');

  String get maskAISegmentationFailed => _t({
        'es': 'Segmentación IA falló; usando máscara de sujeto de respaldo',
        'de': 'KI-Segmentierung fehlgeschlagen; Fallback-Motivmaske',
        'fr': 'Segmentation IA échouée ; masque de sujet de secours',
        'ja': 'AIセグメンテーションに失敗; フォールバック被写体マスク',
        'zh': 'AI 分割失败; 使用回退主体蒙版',
      }, 'AI segmentation failed; using fallback subject mask');

  String get maskFaceDetectionFailed => _t({
        'es': 'Detección de rostro falló; usando máscara de rostro de respaldo',
        'de': 'Gesichtserkennung fehlgeschlagen; Fallback-Gesichtsmaske',
        'fr': 'Détection de visage échouée ; masque de visage de secours',
        'ja': '顔検出に失敗; フォールバック顔マスク',
        'zh': '人脸检测失败; 使用回退人脸蒙版',
      }, 'Face detection failed; using fallback face mask');

  String get maskNoPhotoDepth => _t({
        'es': 'No hay foto cargada para extraer profundidad',
        'de': 'Kein Foto zur Tiefenextraktion geladen',
        'fr': 'Aucune photo chargée pour extraire la profondeur',
        'ja': '深度を抽出する写真が読み込まれていません',
        'zh': '没有加载照片来提取深度',
      }, 'No photo loaded for depth extraction');

  String get maskDepthLoaded => _t({
        'es': 'Máscara de profundidad retrato cargada',
        'de': 'Eingebettete Porträt-Tiefemaske geladen',
        'fr': 'Masque de profondeur portrait chargé',
        'ja': 'ポートレート深度マスクを読み込みました',
        'zh': '已加载嵌入人像深度蒙版',
      }, 'Loaded embedded portrait depth mask');

  String maskDepthGenerated(String modelName) {
    switch (locale.languageCode) {
      case 'es':
        return 'Máscara de profundidad IA neural generada vía $modelName';
      case 'de':
        return 'KI-Neural-Tiefemaske via $modelName generiert';
      case 'fr':
        return 'Masque de profondeur neural IA généré via $modelName';
      case 'ja':
        return 'AI ニューラル深度マスクを $modelName で生成';
      case 'zh':
        return '通过 $modelName 生成的 AI 神经深度蒙版';
      default:
        return 'Generated AI neural depth mask via $modelName';
    }
  }

  String get maskDepthFailed => _t({
        'es': 'No se pudo generar máscara de profundidad',
        'de': 'Tiefemaske konnte nicht generiert werden',
        'fr': 'Impossible de générer le masque de profondeur',
        'ja': '深度マスクを生成できませんでした',
        'zh': '无法生成深度蒙版',
      }, 'Could not generate depth mask');

  String get maskShadows => _t({
        'es': 'Sombras',
        'de': 'Schatten',
        'fr': 'Ombres',
        'ja': 'シャドウ',
        'zh': '阴影',
      }, 'Shadows');

  String get maskMidtones => _t({
        'es': 'Medios tonos',
        'de': 'Mitteltöne',
        'fr': 'Mi-teintes',
        'ja': 'ミッドトーン',
        'zh': '中间调',
      }, 'Midtones');

  String get maskHighlights => _t({
        'es': 'Altas luces',
        'de': 'Lichter',
        'fr': 'Lumières',
        'ja': 'ハイライト',
        'zh': '高光',
      }, 'Highlights');

  // --- Geometry Controls ---
  String get geometryNoPhotoStraighten => _t({
        'es': 'No hay foto cargada para auto-alineación',
        'de': 'Kein Foto zum Auto-Geradeziehen geladen',
        'fr': 'Aucune photo chargée pour l\'auto-redressage',
        'ja': '自動傾き補正する写真が読み込まれていません',
        'zh': '没有加载照片来自动矫正',
      }, 'No photo loaded for auto-straighten');

  String get geometryHorizonStraight => _t({
        'es': 'El horizonte ya está recto',
        'de': 'Horizont ist bereits gerade',
        'fr': 'L\'horizon est déjà droit',
        'ja': '地平線はすでに水平です',
        'zh': '地平线已经是水平的',
      }, 'Horizon is already straight');

  String geometryStraightenFailed(String e) {
    switch (locale.languageCode) {
      case 'es':
        return 'Auto-alineación falló: $e';
      case 'de':
        return 'Auto-Geradeziehen fehlgeschlagen: $e';
      case 'fr':
        return 'Auto-redressage échoué : $e';
      case 'ja':
        return '自動傾き補正に失敗: $e';
      case 'zh':
        return '自动矫正失败: $e';
      default:
        return 'Auto-straighten failed: $e';
    }
  }

  String get geometryNoPhotoUpright => _t({
        'es': 'No hay foto cargada para auto-enderezado',
        'de': 'Kein Foto zum Auto-Ausrichten geladen',
        'fr': 'Aucune photo chargée pour l\'auto-alignement',
        'ja': '自動整列する写真が読み込まれていません',
        'zh': '没有加载照片来自动对齐',
      }, 'No photo loaded for auto-upright');

  String get geometryAlreadyAligned => _t({
        'es': 'La geometría ya está alineada',
        'de': 'Geometrie ist bereits ausgerichtet',
        'fr': 'La géométrie est déjà alignée',
        'ja': '幾何はすでに配置されています',
        'zh': '几何已经是对齐的',
      }, 'Geometry is already aligned');

  String geometryUprightFailed(String e) {
    switch (locale.languageCode) {
      case 'es':
        return 'Auto-enderezado falló: $e';
      case 'de':
        return 'Auto-Ausrichten fehlgeschlagen: $e';
      case 'fr':
        return 'Auto-alignement échoué : $e';
      case 'ja':
        return '自動整列に失敗: $e';
      case 'zh':
        return '自动对齐失败: $e';
      default:
        return 'Auto-upright failed: $e';
    }
  }

  String get geometryNoPhotoFrame => _t({
        'es': 'No hay foto cargada para auto-encuadre',
        'de': 'Kein Foto zum Auto-Framen geladen',
        'fr': 'Aucune photo chargée pour l\'auto-cadrage',
        'ja': '自動フレーミングする写真が読み込まれていません',
        'zh': '没有加载照片来自动构图',
      }, 'No photo loaded for auto-frame');

  String get geometryNoSubject => _t({
        'es': 'No se detectó sujeto distinto para encuadrar',
        'de': 'Kein eindeutiges Motiv für Framing erkannt',
        'fr': 'Aucun sujet distinct détecté pour le cadrage',
        'ja': 'フレーミングする明確な被写体が検出されません',
        'zh': '未检测到用于构图的明确主体',
      }, 'No distinct subject detected to frame');

  String geometryFrameFailed(String e) {
    switch (locale.languageCode) {
      case 'es':
        return 'Auto-encuadre falló: $e';
      case 'de':
        return 'Auto-Framen fehlgeschlagen: $e';
      case 'fr':
        return 'Auto-cadrage échoué : $e';
      case 'ja':
        return '自動フレーミングに失敗: $e';
      case 'zh':
        return '自动构图失败: $e';
      default:
        return 'Auto-frame failed: $e';
    }
  }

  String get geometryFlipLeft => _t({
        'es': 'Izquierda',
        'de': 'Links',
        'fr': 'Gauche',
        'ja': '左',
        'zh': '左',
      }, 'Left');

  String get geometryFlipRight => _t({
        'es': 'Derecha',
        'de': 'Rechts',
        'fr': 'Droite',
        'ja': '右',
        'zh': '右',
      }, 'Right');

  String get geometryFlipH => _t({
        'es': 'Voltear H',
        'de': 'Spiegeln H',
        'fr': 'Retourner H',
        'ja': '水平反転',
        'zh': '水平翻转',
      }, 'Flip H');

  String get geometryFlipV => _t({
        'es': 'Voltear V',
        'de': 'Spiegeln V',
        'fr': 'Retourner V',
        'ja': '垂直反転',
        'zh': '垂直翻转',
      }, 'Flip V');

  // --- Retouch Controls ---
  String get retouchResetSource => _t({
        'es': 'Restablecer origen',
        'de': 'Quelle zurücksetzen',
        'fr': 'Réinitialiser la source',
        'ja': 'ソースをリセット',
        'zh': '重置源',
      }, 'Reset Source');

  String get retouchHeal => _t({
        'es': 'Sanar',
        'de': 'Heilen',
        'fr': 'Corriger',
        'ja': '修復',
        'zh': '修复',
      }, 'Heal');

  String get retouchClone => _t({
        'es': 'Clonar',
        'de': 'Klonen',
        'fr': 'Cloner',
        'ja': 'クローン',
        'zh': '克隆',
      }, 'Clone');

  String get retouchSpotSettings => _t({
        'es': 'Ajustes del punto',
        'de': 'Punkteinstellungen',
        'fr': 'Paramètres du point',
        'ja': 'スポット設定',
        'zh': '点位设置',
      }, 'Spot Settings');

  String get retouchDeletePatch => _t({
        'es': 'Eliminar parche',
        'de': 'Patch löschen',
        'fr': 'Supprimer le correctif',
        'ja': 'パッチを削除',
        'zh': '删除补丁',
      }, 'Delete Patch');

  String get retouchClearAll => _t({
        'es': 'Borrar todo',
        'de': 'Alles löschen',
        'fr': 'Tout effacer',
        'ja': 'すべてクリア',
        'zh': '全部清除',
      }, 'Clear All');

  String get retouchCancel => _t({
        'es': 'Cancelar',
        'de': 'Abbrechen',
        'fr': 'Annuler',
        'ja': 'キャンセル',
        'zh': '取消',
      }, 'Cancel');

  String get retouchSet => _t({
        'es': 'Establecer',
        'de': 'Setzen',
        'fr': 'Définir',
        'ja': '設定',
        'zh': '设置',
      }, 'Set');

  // --- Blur Controls ---
  String get blurDepthAware => _t({
        'es': 'Desenfoque de lente consciente de profundidad',
        'de': 'Tiefenbewusster Objektivunschärfe',
        'fr': 'Flou de lentille conscient de la profondeur',
        'ja': '深度対応レンズぼかし',
        'zh': '深度感知镜头模糊',
      }, 'Depth-Aware Lens Blur');

  String get blurDepthAwareSubtitle => _t({
        'es': 'Campo de profundidad óptico + bokeh consciente del sujeto',
        'de': 'Optische Schärfentiefe + motivbewusstes Bokeh',
        'fr': 'Champ de profondeur optique + bokeh conscient du sujet',
        'ja': '光学被写界深度 + 被写体対応ボケ',
        'zh': '光学景深 + 主体感知博ケ',
      }, 'Optical depth-of-field + subject-aware bokeh');

  String get blurNoPhotoFocus => _t({
        'es': 'No hay foto cargada para colocar enfoque',
        'de': 'Kein Foto zum Fokussieren geladen',
        'fr': 'Aucune photo chargée pour placer la mise au point',
        'ja': '焦点を置く写真が読み込まれていません',
        'zh': '没有加载照片来放置焦点',
      }, 'No photo loaded to place focus');

  String get blurSubjectNotDetected => _t({
        'es': 'Sujeto no detectado — enfoque central aplicado',
        'de': 'Motiv nicht erkannt — Zentraler Fokus angewendet',
        'fr': 'Sujet non détecté — mise au point centrale appliquée',
        'ja': '被写体が検出されません — 中央フォーカスを適用',
        'zh': '未检测到主体 — 已应用中央焦点',
      }, 'Subject not detected — center focus applied');

  String get blurReRunSubjectFocus => _t({
        'es': 'Volver a ejecutar enfoque del sujeto',
        'de': 'Motiv-Fokus erneut ausführen',
        'fr': 'Ré-exécuter la mise au point du sujet',
        'ja': '被写体フォーカスを再実行',
        'zh': '重新运行主体对焦',
      }, 'Re-run Subject Focus');

  String get blurSectionLensBlur => _t({
        'es': 'Desenfoque de lente',
        'de': 'Objektivunschärfe',
        'fr': 'Flou de lentille',
        'ja': 'レンズぼかし',
        'zh': '镜头模糊',
      }, 'Lens Blur');

  String get blurSectionBokehShape => _t({
        'es': 'Forma de bokeh y especular',
        'de': 'Bokeh-Form & Spekular',
        'fr': 'Forme de bokeh & spéculaire',
        'ja': 'ボケの形状 & スペキュラー',
        'zh': '博ケ形状 & 高光',
      }, 'Bokeh Shape & Specular');

  String get blurDepthVisualizer => _t({
        'es': 'Visualizador de mapa de profundidad',
        'de': 'Tiefenkarten-Visualisierer',
        'fr': 'Visualiseur de carte de profondeur',
        'ja': '深度マップビジュアライザー',
        'zh': '深度图可视化器',
      }, 'Depth Map Visualizer');

  String get blurDepthVisualizerSubtitle => _t({
        'es': 'Superponer plano focal de color falso y gradiente de profundidad',
        'de': 'Falschfarben-Fokusebene und Tiefengradient überlagern',
        'fr': 'Superposer plan focal en fausses couleurs et gradient de profondeur',
        'ja': '疑似カラーのフォーカス面と深度グラデーションをオーバーレイ',
        'zh': '叠加伪彩色焦平面和深度渐变',
      }, 'Overlay false-color focal plane & depth gradient');

  String get blurFindingSubject => _t({
        'es': 'Buscando sujeto… Por favor espere',
        'de': 'Motiv wird gesucht… Bitte warten',
        'fr': 'Recherche du sujet… Veuillez patienter',
        'ja': '被写体を検出中… しばらくお待ちください',
        'zh': '正在寻找主体… 请稍候',
      }, 'Finding subject… Please wait a moment');

  String blurConfidenceReliable(int pct) => _t({
        'es': '$pct% confiable',
        'de': '$pct% zuverlässig',
        'fr': '$pct% fiable',
        'ja': '$pct% 信頼性',
        'zh': '$pct% 可靠',
      }, '$pct% reliable');

  String get blurConfidenceLow => _t({
        'es': 'Baja confianza de profundidad en esta escena',
        'de': 'Geringes Tiefenvertrauen in dieser Szene',
        'fr': 'Faible confiance de profondeur sur cette scène',
        'ja': 'このシーンの深度信頼度が低いです',
        'zh': '此场景的深度置信度较低',
      }, 'Low depth confidence in this scene');

  String get blurLowConfidence => blurConfidenceLow;

  String get blurSwitchToGradient => _t({
        'es': 'Cambiar a gradiente',
        'de': 'Zu Gradient wechseln',
        'fr': 'Passer au dégradé',
        'ja': 'グラデーションに切り替え',
        'zh': '切换到渐变',
      }, 'Switch to Gradient');

  String get blurRefineBrush => _t({
        'es': 'Pincel de refinamiento de enfoque',
        'de': 'Fokus-Verfeinerungspinsel',
        'fr': 'Pinceau d’affinage de mise au point',
        'ja': 'フォーカス調整ブラシ',
        'zh': '焦点微调画笔',
      }, 'Refine Focus Brush');

  String get blurPortrait85 => _t({
        'es': 'Retrato 85mm f/1.8',
        'de': 'Porträt 85mm f/1.8',
        'fr': 'Portrait 85mm f/1.8',
        'ja': 'ポートレート 85mm f/1.8',
        'zh': '人像 85mm f/1.8',
      }, 'Portrait 85mm f/1.8');

  String get blurStreet35 => _t({
        'es': 'Calle 35mm f/1.4',
        'de': 'Street 35mm f/1.4',
        'fr': 'Rue 35mm f/1.4',
        'ja': 'ストリート 35mm f/1.4',
        'zh': '街头 35mm f/1.4',
      }, 'Street 35mm f/1.4');

  String get blurAnamorphic => _t({
        'es': 'Anamórfico 50mm',
        'de': 'Anamorph 50mm',
        'fr': 'Anamorphique 50mm',
        'ja': 'アナモルフィック 50mm',
        'zh': '变形 50mm',
      }, 'Anamorphic 50mm');

  String get blurVintageSwirl => _t({
        'es': 'Remolino Vintage (Petzval)',
        'de': 'Vintage Swirl (Petzval)',
        'fr': 'Tourbillon Vintage (Petzval)',
        'ja': 'ビンテージスワール (ペッツバール)',
        'zh': '复古旋涡 (匹兹瓦)',
      }, 'Vintage Swirl (Petzval)');

  String get blurCreamyMacro => _t({
        'es': 'Macro Cremoso',
        'de': 'Cremiges Makro',
        'fr': 'Macro crémeux',
        'ja': 'クリーミーマクロ',
        'zh': '柔顺微距',
      }, 'Creamy Macro');

  String get blurUseOpticalGradient => _t({
        'es': 'Usar gradiente óptico',
        'de': 'Optischen Gradienten verwenden',
        'fr': 'Utiliser le gradient optique',
        'ja': '光学グラデーションを使用',
        'zh': '使用光学渐变',
      }, 'Use Optical Gradient');

  String blurSubjectFocusPlaced(int focalPoint, int focalRange) => _t({
        'es': 'Enfoque de sujeto fijado: punto focal $focalPoint%, rango $focalRange%',
        'de': 'Motivfokus gesetzt: Fokuspunkt $focalPoint%, Bereich $focalRange%',
        'fr': 'Mise au point sur le sujet : point focal $focalPoint%, plage $focalRange%',
        'ja': '被写体フォーカス設定完了: フォーカス位置 $focalPoint%、範囲 $focalRange%',
        'zh': '主体对焦完成：焦点 $focalPoint%，范围 $focalRange%',
      }, 'Subject focus placed: focal point $focalPoint%, range $focalRange%');

  // --- Optics Controls ---
  String get opticsRemoveCA => _t({
        'es': 'Eliminar aberración cromática',
        'de': 'Chromatische Aberration entfernen',
        'fr': 'Supprimer l\'aberration chromatique',
        'ja': '色収差を除去',
        'zh': '消除色差',
      }, 'Remove Chromatic Aberration');

  String get opticsRemoveCASubtitle => _t({
        'es': 'Auto-corrección de franjas de color laterales',
        'de': 'Seitliche Farbsäume automatisch korrigieren',
        'fr': 'Correction automatique des franges de couleur latérales',
        'ja': '横方向色フリンジを自動補正',
        'zh': '自动纠正横向色边',
      }, 'Auto-correct lateral color fringing');

  String get opticsEnableProfile => _t({
        'es': 'Habilitar correcciones de perfil',
        'de': 'Profil-Korrekturen aktivieren',
        'fr': 'Activer les corrections de profil',
        'ja': 'プロファイル補正を有効化',
        'zh': '启用配置文件修正',
      }, 'Enable Profile Corrections');

  String get opticsProfileSubtitle => _t({
        'es': 'Perfiles de distorsión geométrica y viñeteado',
        'de': 'Geometrische Verzerrungs- und Vignettierungsprofile',
        'fr': 'Profils de distorsion géométrique et de vignetage',
        'ja': '幾何歪みとヴィネットプロファイル',
        'zh': '几何畸变和晕影配置文件',
      }, 'Geometric distortion and vignetting profiles');

  // --- Mask Controls: button labels ---
  String get maskNewGroupPlus => _t({
        'es': 'Nuevo grupo +',
        'de': 'Neue Gruppe +',
        'fr': 'Nouveau groupe +',
        'ja': '新しいグループ +',
        'zh': '新建组 +',
      }, 'New Group +');

  String get maskAdd => _t({
        'es': 'Añadir',
        'de': 'Hinzufügen',
        'fr': 'Ajouter',
        'ja': '追加',
        'zh': '添加',
      }, 'Add');

  String get maskSubtract => _t({
        'es': 'Restar',
        'de': 'Subtrahieren',
        'fr': 'Soustraire',
        'ja': '減算',
        'zh': '减去',
      }, 'Subtract');

  String get maskIntersect => _t({
        'es': 'Intersección',
        'de': 'Schneiden',
        'fr': 'Intersection',
        'ja': '交差',
        'zh': '交集',
      }, 'Intersect');

  String get maskPlus => _t({'+': '+'}, '+');

  String get maskMinus => _t({'-': '-'}, '-');

  String get maskIntersectSymbol => _t({'⋂': '⋂'}, '⋂');

  String get maskInvert => _t({
        'es': 'Invertir',
        'de': 'Umkehren',
        'fr': 'Inverser',
        'ja': '反転',
        'zh': '反转',
      }, 'Invert');

  String get maskPaint => _t({
        'es': 'Pintar',
        'de': 'Malen',
        'fr': 'Peindre',
        'ja': 'ペイント',
        'zh': '涂抹',
      }, 'Paint');

  String get maskErase => _t({
        'es': 'Borrar',
        'de': 'Löschen',
        'fr': 'Effacer',
        'ja': '消去',
        'zh': '擦除',
      }, 'Erase');

  String get maskAutoMask => _t({
        'es': 'Máscara automática',
        'de': 'Automatische Maske',
        'fr': 'Masque automatique',
        'ja': '自動マスク',
        'zh': '自动蒙版',
      }, 'Auto Mask');

  String get maskRefineBrush => _t({
        'es': 'Refinar pincel',
        'de': 'Pinsel verfeinern',
        'fr': 'Affiner le pinceau',
        'ja': 'ブラシを洗練',
        'zh': '细化画笔',
      }, 'Refine Brush');

  String get maskRefineEdge => _t({
        'es': 'Refinar borde',
        'de': 'Kante verfeinern',
        'fr': 'Affiner le bord',
        'ja': 'エッジを洗練',
        'zh': '细化边缘',
      }, 'Refine Edge');

  String get maskDuplicate => _t({
        'es': 'Duplicar',
        'de': 'Duplizieren',
        'fr': 'Dupliquer',
        'ja': '複製',
        'zh': '复制',
      }, 'Duplicate');

  String get maskSampleLuma => _t({
        'es': 'Muestreo de luminancia',
        'de': 'Luminanz-Probe',
        'fr': 'Échantillon de luminance',
        'ja': '輝度サンプル',
        'zh': '采样亮度',
      }, 'Sample Luma');

  String get maskClear => _t({
        'es': 'Limpiar',
        'de': 'Löschen',
        'fr': 'Effacer',
        'ja': 'クリア',
        'zh': '清除',
      }, 'Clear');

  String get maskSampleColorBtn => _t({
        'es': 'Muestreo de color',
        'de': 'Farbe probieren',
        'fr': 'Échantillon de couleur',
        'ja': '色サンプル',
        'zh': '采样颜色',
      }, 'Sample Color');

  // --- Geometry Controls: button labels ---
  String get geometryAuto => _t({
        'es': 'Auto',
        'de': 'Auto',
        'fr': 'Auto',
        'ja': '自動',
        'zh': '自动',
      }, 'Auto');

  String get geometryUpright => _t({
        'es': 'Upright',
        'de': 'Upright',
        'fr': 'Upright',
        'ja': 'Upright',
        'zh': 'Upright',
      }, 'Upright');

  String get geometryAutoFrame => _t({
        'es': 'Auto Frame',
        'de': 'Auto Frame',
        'fr': 'Auto Frame',
        'ja': 'Auto Frame',
        'zh': 'Auto Frame',
      }, 'Auto Frame');

  // --- Retouch Controls: button labels ---
  String get retouchHealSpotPlus => _t({
        'es': 'Sanar punto +',
        'de': 'Heilen Punkt +',
        'fr': 'Corriger point +',
        'ja': '修復ポイント +',
        'zh': '修复点 +',
      }, 'Heal Spot +');

  String get retouchCloneSpotPlus => _t({
        'es': 'Clonar punto +',
        'de': 'Klonen Punkt +',
        'fr': 'Cloner point +',
        'ja': 'クローンポイント +',
        'zh': '克隆点 +',
      }, 'Clone Spot +');

  // Desktop Menu Strings
  String get fileMenu => _t({
        'es': 'Archivo',
        'de': 'Datei',
        'fr': 'Fichier',
        'ja': 'ファイル',
        'zh': '文件',
      }, 'File');

  String get openPhoto => _t({
        'es': 'Abrir foto…',
        'de': 'Foto öffnen…',
        'fr': 'Ouvrir une photo…',
        'ja': '写真を開く…',
        'zh': '打开照片…',
      }, 'Open Photo…');

  String get exportImage => _t({
        'es': 'Exportar imagen…',
        'de': 'Bild exportieren…',
        'fr': 'Exporter l\'image…',
        'ja': '画像を書き出し…',
        'zh': '导出图像…',
      }, 'Export Image…');

  String get printContactSheet => _t({
        'es': 'Imprimir / Hoja de contactos…',
        'de': 'Drucken / Kontaktabzug…',
        'fr': 'Imprimer / Planche contact…',
        'ja': '印刷 / コンタクトシート…',
        'zh': '打印 / 缩略图索引…',
      }, 'Print / Contact Sheet…');

  String get studioTetheredCapture => _t({
        'es': 'Captura vinculada de estudio…',
        'de': 'Studio-Tethering-Aufnahme…',
        'fr': 'Capture connectée en studio…',
        'ja': 'スタジオ テザー撮影…',
        'zh': '工作室联机拍摄…',
      }, 'Studio Tethered Capture…');

  String get videoColorStudio => _t({
        'es': 'Estudio de color de video…',
        'de': 'Video-Farbkorrektur-Studio…',
        'fr': 'Studio d\'étalonnage vidéo…',
        'ja': 'ビデオ カラースタジオ…',
        'zh': '视频调色工作室…',
      }, 'Video Color Studio…');

  String get closeWindow => _t({
        'es': 'Cerrar ventana',
        'de': 'Fenster schließen',
        'fr': 'Fermer la fenêtre',
        'ja': 'ウィンドウを閉じる',
        'zh': '关闭窗口',
      }, 'Close Window');

  String get editMenu => _t({
        'es': 'Edición',
        'de': 'Bearbeiten',
        'fr': 'Édition',
        'ja': '編集',
        'zh': '编辑',
      }, 'Edit');

  String get copySettings => _t({
        'es': 'Copiar ajustes',
        'de': 'Einstellungen kopieren',
        'fr': 'Copier les paramètres',
        'ja': '設定をコピー',
        'zh': '复制设置',
      }, 'Copy Settings');

  String get pasteSettings => _t({
        'es': 'Pegar ajustes',
        'de': 'Einstellungen einfügen',
        'fr': 'Coller les paramètres',
        'ja': '設定を貼り付け',
        'zh': '粘贴设置',
      }, 'Paste Settings');

  String get viewMenu => _t({
        'es': 'Ver',
        'de': 'Ansicht',
        'fr': 'Affichage',
        'ja': '表示',
        'zh': '视图',
      }, 'View');

  String get exitWiperCompare => _t({
        'es': 'Salir de comparación de cortinilla A/B',
        'de': 'A/B-Wischer-Vergleich beenden',
        'fr': 'Quitter la comparaison avant/après par volet',
        'ja': 'ワイパー比較を終了',
        'zh': '退出卷帘对比',
      }, 'Exit A/B Wiper Compare');

  String get splitCurtainWiperCompare => _t({
        'es': 'Comparación de cortinilla dividida',
        'de': 'Geteilter Wischer-Vergleich',
        'fr': 'Comparaison par volet divisé',
        'ja': '分割ワイパー比較',
        'zh': '卷帘对比',
      }, 'Split Curtain Wiper Compare');

  String get toggleWiperOrientation => _t({
        'es': 'Alternar orientación de cortinilla',
        'de': 'Wischer-Ausrichtung umschalten',
        'fr': 'Changer l\'orientation du volet',
        'ja': 'ワイパー方向を切り替え',
        'zh': '切换卷帘方向',
      }, 'Toggle Wiper Orientation');

  String get resetWiperToCenter => _t({
        'es': 'Restablecer cortinilla al centro',
        'de': 'Wischer auf Mitte zurücksetzen',
        'fr': 'Recentrer le volet',
        'ja': 'ワイパーを中央にリセット',
        'zh': '重置卷帘至中心',
      }, 'Reset Wiper to Center');

  String get exitBeforeAfterSplit => _t({
        'es': 'Salir de vista dividida antes/después',
        'de': 'Vorher/Nachher-Teilung beenden',
        'fr': 'Quitter la vue fractionnée avant/après',
        'ja': '前後分割表示を終了',
        'zh': '退出前后分割视图',
      }, 'Exit Before/After Split View');

  String get toggleBeforeAfterSplit => _t({
        'es': 'Alternar vista dividida antes/después',
        'de': 'Vorher/Nachher-Teilung umschalten',
        'fr': 'Activer/désactiver la vue fractionnée',
        'ja': '前後分割表示を切り替え',
        'zh': '切换前后分割视图',
      }, 'Toggle Before/After Split View');

  String get toggleSplitOrientation => _t({
        'es': 'Alternar orientación de vista dividida',
        'de': 'Teilungsausrichtung umschalten',
        'fr': 'Changer l\'orientation du fractionnement',
        'ja': '分割方向を切り替え',
        'zh': '切换分割方向',
      }, 'Toggle Split View Orientation');

  // History & Stacks Sheet Strings
  String get editHistoryAndBranches => _t({
        'es': 'Historial de edición y ramas',
        'de': 'Bearbeitungsverlauf & Zweige',
        'fr': 'Historique des modifications et branches',
        'ja': '編集履歴とブランチ',
        'zh': '编辑历史与分支',
      }, 'Edit History & Branches');

  String get editStacksSnapseed => _t({
        'es': 'Pilas de edición (paridad Snapseed)',
        'de': 'Bearbeitungsstapel (Snapseed-Parität)',
        'fr': 'Piles de retouches (parité Snapseed)',
        'ja': '編集スタック (Snapseed パリティ)',
        'zh': '编辑图层堆栈 (Snapseed 对齐)',
      }, 'Edit Stacks (Snapseed Parity)');

  String get snapshotsAndVirtualCopies => _t({
        'es': 'Instantáneas y copias virtuales',
        'de': 'Schnappschüsse & virtuelle Kopien',
        'fr': 'Instantanés et copies virtuelles',
        'ja': 'スナップショットと仮想コピー',
        'zh': '快照与虚拟副本',
      }, 'Snapshots & Virtual Copies');

  String get close => _t({
        'es': 'Cerrar',
        'de': 'Schließen',
        'fr': 'Fermer',
        'ja': '閉じる',
        'zh': '关闭',
      }, 'Close');

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

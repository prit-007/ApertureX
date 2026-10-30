import 'package:aperturex/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppStrings i18n localization', () {
    test('English default strings', () {
      const strings = AppStrings(Locale('en'));
      expect(strings.gallery, 'Gallery');
      expect(strings.editor, 'Editor');
      expect(strings.settings, 'Settings');
      expect(strings.lightAndColor, 'Light & Color');
      expect(strings.autoTone, 'Auto Tone');
      expect(strings.export, 'Export');
      expect(strings.colorLabels, 'Color Labels');
      expect(strings.selectedCount(3), '3 selected');
      expect(strings.syncedSettings(2), 'Synced settings to 2 photo(s)');
    });

    test('Spanish strings', () {
      const strings = AppStrings(Locale('es'));
      expect(strings.gallery, 'Galería');
      expect(strings.editor, 'Editor');
      expect(strings.settings, 'Ajustes');
      expect(strings.lightAndColor, 'Luz y color');
      expect(strings.autoTone, 'Tono automático');
      expect(strings.export, 'Exportar');
      expect(strings.colorLabels, 'Etiquetas de color');
      expect(strings.selectedCount(4), '4 seleccionado(s)');
    });

    test('German strings', () {
      const strings = AppStrings(Locale('de'));
      expect(strings.gallery, 'Galerie');
      expect(strings.settings, 'Einstellungen');
      expect(strings.lightAndColor, 'Licht & Farbe');
      expect(strings.autoTone, 'Automatischer Farbton');
      expect(strings.export, 'Exportieren');
      expect(strings.colorLabels, 'Farbetiketten');
      expect(strings.selectedCount(5), '5 ausgewählt');
    });

    test('French strings', () {
      const strings = AppStrings(Locale('fr'));
      expect(strings.gallery, 'Galerie');
      expect(strings.editor, 'Éditeur');
      expect(strings.settings, 'Paramètres');
      expect(strings.lightAndColor, 'Lumière et couleur');
      expect(strings.export, 'Exporter');
      expect(strings.selectedCount(2), '2 sélectionné(s)');
    });

    test('Japanese strings', () {
      const strings = AppStrings(Locale('ja'));
      expect(strings.gallery, 'ギャラリー');
      expect(strings.editor, 'エディター');
      expect(strings.settings, '設定');
      expect(strings.lightAndColor, 'ライト & カラー');
      expect(strings.autoTone, '自動補正');
      expect(strings.export, '書き出し');
      expect(strings.selectedCount(1), '1 項目を選択');
    });

    test('Chinese strings', () {
      const strings = AppStrings(Locale('zh'));
      expect(strings.gallery, '图库');
      expect(strings.editor, '编辑器');
      expect(strings.settings, '设置');
      expect(strings.lightAndColor, '光效与色彩');
      expect(strings.autoTone, '自动色调');
      expect(strings.export, '导出');
      expect(strings.selectedCount(8), '已选择 8 项');
    });

    test('Delegate supports listed locales and falls back smoothly', () {
      const delegate = AppStrings.delegate;
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('es')), isTrue);
      expect(delegate.isSupported(const Locale('de')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isTrue);
      expect(delegate.isSupported(const Locale('ja')), isTrue);
      expect(delegate.isSupported(const Locale('zh')), isTrue);
      expect(delegate.isSupported(const Locale('xx')), isFalse);
    });
  });
}

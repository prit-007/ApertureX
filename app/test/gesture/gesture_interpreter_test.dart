import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/gesture/gesture_interpreter.dart';

void main() {
  late List<String> log;
  late GestureInterpreter fsm;

  setUp(() {
    log = <String>[];
    fsm = GestureInterpreter(
      onToolChanged: (t) => log.add('tool:${t.name}'),
      onValueChanged: (t, d) =>
          log.add('value:${t.name}:${d.toStringAsFixed(3)}'),
      onReset: (t) => log.add('reset:${t.name}'),
      onPhaseChanged: (p) => log.add('phase:${p.name}'),
    );
  });

  test('starts idle on the first tool', () {
    expect(fsm.phase, GesturePhase.idle);
    expect(fsm.axis, GestureAxis.undecided);
    expect(fsm.tool, GradeTool.exposure);
  });

  test('setTool makes later swipes edit the newly-selected tool', () {
    fsm.setTool(GradeTool.saturation);
    expect(fsm.tool, GradeTool.saturation);
    expect(log, contains('tool:saturation'));

    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(200, 0));
    expect(
      log.any((e) => e.startsWith('value:saturation:')),
      isTrue,
      reason: 'swiping must scrub the selected tool, not exposure',
    );
  });

  test('gestureCategories partition every tool', () {
    final all = [
      for (final c in ToolCategory.values) ...gestureCategories[c]!,
    ];
    expect(all.toSet(), GradeTool.values.toSet());
    expect(all.length, GradeTool.values.length); // no duplicates
  });

  test('setTools switches the carousel and selects the first tool', () {
    fsm.setTools(gestureCategories[ToolCategory.detail]!);
    expect(fsm.tool, GradeTool.sharpen);
  });

  test('cancel aborts the gesture WITHOUT firing the tap-reset', () {
    fsm.onPanStart(Offset.zero);
    fsm.cancel();
    expect(log.any((e) => e.startsWith('reset:')), isFalse);
    expect(fsm.phase, GesturePhase.idle);
  });

  test('a tap below slop resets the active tool and never changes a value', () {
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(3, 4)); // distance 5 < touchSlop(18)
    fsm.onPanEnd();

    expect(log, contains('phase:scanning'));
    expect(log, contains('reset:exposure'));
    expect(log.any((e) => e.startsWith('value:')), isFalse);
    expect(fsm.phase, GesturePhase.idle);
  });

  test('horizontal drag past slop scrubs the value and locks horizontal', () {
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(200, 0));

    expect(fsm.phase, GesturePhase.scrubbing);
    expect(fsm.axis, GestureAxis.horizontal);
    expect(log.any((e) => e.startsWith('value:exposure')), isTrue);
    expect(log.any((e) => e.startsWith('tool:')), isFalse);
  });

  test('vertical drag past slop cycles tools and locks vertical', () {
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(0, -60)); // up -> next

    expect(fsm.phase, GesturePhase.cycling);
    expect(fsm.axis, GestureAxis.vertical);
    expect(fsm.tool, GradeTool.contrast);
    expect(log.any((e) => e.startsWith('value:')), isFalse);
  });

  test('axis lock: vertical motion after horizontal lock does not cycle', () {
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(200, 0)); // lock horizontal
    fsm.onPanUpdate(const Offset(0, -200)); // must still scrub

    expect(fsm.tool, GradeTool.exposure);
    expect(fsm.phase, GesturePhase.scrubbing);
  });

  test('cycling wraps forward around the carousel', () {
    fsm.setTool(GradeTool.values.last);
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(0, -48)); // one step up -> wrap to first

    expect(fsm.tool, GradeTool.exposure);
  });

  test('downward vertical steps to the previous tool', () {
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(0, 48)); // one step down -> wrap to last

    expect(fsm.tool, GradeTool.values.last);
  });

  test('scrubbing accumulates signed, normalized deltas', () {
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(300, 0)); // +0.5 of full range
    fsm.onPanUpdate(const Offset(-150, 0)); // -0.25

    expect(log, contains('value:exposure:0.500'));
    expect(log, contains('value:exposure:-0.250'));
  });

  test('a new gesture starts fresh even after an axis lock', () {
    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(200, 0)); // lock horizontal
    fsm.onPanEnd();

    fsm.onPanStart(Offset.zero);
    fsm.onPanUpdate(const Offset(0, -60)); // new gesture can lock vertical

    expect(fsm.axis, GestureAxis.vertical);
    expect(fsm.tool, GradeTool.contrast);
  });
}

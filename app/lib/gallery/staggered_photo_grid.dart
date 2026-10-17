import 'package:material_ui/material_ui.dart';

/// A Google Photos-style staggered masonry grid that supports varied aspect ratios
/// across multiple columns with fluid responsiveness.
class StaggeredPhotoGrid extends StatelessWidget {
  const StaggeredPhotoGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisCount,
    this.spacing = 2.0,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int? crossAxisCount;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = crossAxisCount ??
            (constraints.maxWidth >= 900
                ? 5
                : constraints.maxWidth >= 600
                    ? 4
                    : 3);

        // Distribute items across columns in round-robin fashion for balanced masonry
        final columns = List.generate(cols, (_) => <Widget>[]);
        for (var i = 0; i < itemCount; i++) {
          final colIndex = i % cols;
          columns[colIndex].add(
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: itemBuilder(context, i),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < cols; col++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: col < cols - 1 ? spacing : 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: columns[col],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

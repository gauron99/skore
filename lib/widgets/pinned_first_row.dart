import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps the first row of [table] (the player names) in view while the rows
/// below it scroll under it.
///
/// [table] must build a [Table] directly. It stays one table with one
/// layout: once its top has scrolled above the nearest vertical
/// [Scrollable], the first row is painted a second time at the top of that
/// viewport, over [background]. So the pinned row always lines up with the
/// columns below, also while scrolling sideways, and nothing changes while
/// the table's top is in view. The pinned copy is paint only: hit tests and
/// semantics see the first row where it really is. The table is painted
/// twice, so it must not hold repaint boundaries.
class PinnedFirstRow extends SingleChildRenderObjectWidget {
  const PinnedFirstRow({super.key, required Widget table, this.background})
    : super(child: table);

  /// Fills the pinned row behind its cells. Defaults to the scaffold
  /// background, which is what the tables sit on.
  final Color? background;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderPinnedFirstRow(
    scrollable: Scrollable.maybeOf(context, axis: Axis.vertical),
    background: background ?? Theme.of(context).scaffoldBackgroundColor,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPinnedFirstRow renderObject,
  ) {
    renderObject
      ..scrollable = Scrollable.maybeOf(context, axis: Axis.vertical)
      ..background = background ?? Theme.of(context).scaffoldBackgroundColor;
  }
}

/// Render object of [PinnedFirstRow].
class RenderPinnedFirstRow extends RenderProxyBox {
  RenderPinnedFirstRow({
    required ScrollableState? scrollable,
    required this._background,
  }) : _scrollable = scrollable,
       _position = scrollable?.position;

  ScrollableState? _scrollable;
  ScrollPosition? _position;

  set scrollable(ScrollableState? value) {
    _scrollable = value;
    if (value?.position == _position) return;
    if (attached) _position?.removeListener(markNeedsPaint);
    _position = value?.position;
    if (attached) _position?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _background;

  set background(Color value) {
    if (value == _background) return;
    _background = value;
    markNeedsPaint();
  }

  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // A list item may sit behind a repaint boundary, so scrolling alone
    // would not repaint it.
    _position?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _position?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final pin = _pin();
    if (pin == null) {
      _clip.layer = null;
      return;
    }
    final (dy, area) = pin;
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset.translate(0, dy),
      area,
      (context, offset) {
        context.canvas.drawRect(
          area.shift(offset),
          Paint()..color = _background,
        );
        context.paintChild(child!, offset);
      },
      oldLayer: _clip.layer,
    );
  }

  /// How far down to paint the first row again, and the area it covers; or
  /// null while the table's top is in view.
  (double, Rect)? _pin() {
    final table = child;
    final scrollable = _scrollable?.context.findRenderObject();
    if (table is! RenderTable || table.rows == 0 || scrollable == null) {
      return null;
    }
    // Measure against the viewport itself, not the Scrollable's outer box:
    // an overscroll stretch sits between the two and springs back without
    // scrolling. A sideways viewport may sit below it, so take the outermost.
    RenderObject? viewport;
    for (
      var node = parent;
      node != null && node != scrollable;
      node = node.parent
    ) {
      if (node is RenderAbstractViewport) viewport = node;
    }
    if (viewport == null) return null;
    final top = getTransformTo(viewport).getTranslation().y;
    if (top >= 0) return null;
    // One point wider on each side: at a fractional x the edge pixels are
    // only partly covered, and rows passing underneath would show through.
    final area = Rect.fromLTRB(
      -1,
      0,
      size.width + 1,
      table.getRowBox(0).bottom + _lineBelow(table),
    );
    // Stop at the table's end, like the rows do.
    final dy = math.min(-top, size.height - area.height);
    return dy > 0 ? (dy, area) : null;
  }

  /// How far the line under the first row reaches into the next one, so
  /// the pinned row keeps that line.
  static double _lineBelow(RenderTable table) {
    final inside = table.border?.horizontalInside ?? BorderSide.none;
    var below = inside.style == BorderStyle.none ? 0.0 : inside.width / 2;
    final decorations = table.rowDecorations;
    final next = decorations.length > 1 ? decorations[1] : null;
    if (next is BoxDecoration && next.border is Border) {
      final top = (next.border! as Border).top;
      if (top.style != BorderStyle.none) below = math.max(below, top.width);
    }
    return below;
  }
}

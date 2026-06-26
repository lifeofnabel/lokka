import 'package:flutter/widgets.dart';

/// Caps page content width and centres it on wide viewports (tablet/desktop) so
/// the mobile-first, single-column layouts don't stretch edge-to-edge — which
/// makes buttons look oversized and content feel sparse/"dead" on desktop.
///
/// On phones (viewport width <= [maxWidth]) this is a transparent no-op: the
/// child gets the full width. It works for both box scroll views
/// (SingleChildScrollView/ListView) and sliver scroll views (CustomScrollView),
/// because the scrollable still fills the available height — only the cross-axis
/// width is constrained.
///
/// Usage: wrap a page's scroll body, e.g.
///   body: ResponsiveContentWidth(child: CustomScrollView(...))
class ResponsiveContentWidth extends StatelessWidget {
  const ResponsiveContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;

  /// Maximum content width on wide screens. Defaults to a comfortable reading
  /// column for feed/profile content; pass a larger value for grid/menu pages.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

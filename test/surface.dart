import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sizes the test window the way the page under test sees it.
///
/// `binding.setSurfaceSize` sets the layout constraints and nothing else: the
/// view metrics stay at the 800pt default, so `MediaQuery.sizeOf` keeps
/// reporting a window the page is not being drawn in, and every branch on width
/// — `isDesktop`, a two-pane layout, a column count — reads the wrong size.
/// Setting the view sizes the constraints and the MediaQuery together.
///
/// The raster scale is left where the test binding puts it, so a golden captured
/// through this helper has the same pixel dimensions as one captured through
/// `setSurfaceSize`.
void setTestSurface(WidgetTester tester, Size size) {
  final ratio = tester.view.devicePixelRatio;
  tester.view.physicalSize = Size(size.width * ratio, size.height * ratio);
  addTearDown(tester.view.reset);
}

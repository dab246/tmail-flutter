import 'package:core/presentation/constants/constants_ui.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/views/html_viewer/html_content_viewer_configuration.dart';
import 'package:core/presentation/views/html_viewer/html_viewer_document_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:tmail_ui_user/features/email/presentation/styles/email_view_styles.dart';

/// The width the app gives the email body, as `EmailView` measures it
/// (`bodyConstraints.maxWidth`, padding included).
class EmailViewViewport {
  const EmailViewViewport(this.bodyWidth);

  final int bodyWidth;

  /// `EmailView` switches to its mobile text size below the tablet breakpoint.
  bool get isMobile => bodyWidth < ResponsiveUtils.minTabletWidth;

  double get fontSize => isMobile ? 16 : 14;
}

/// One email viewer of the app, the engine that approximates its webview, and
/// the viewports it is checked at. Geometry comes from the app's constants,
/// so a layout change in the app moves the goldens.
enum EmailViewTarget {
  /// `HtmlContentViewer` on Android (Chromium-based WebView).
  nativeAndroid('native-android', 'chromium', _phones, isAndroid: true),

  /// `HtmlContentViewer` on iOS (WKWebView).
  nativeIos('native-ios', 'webkit', _phones),

  /// `HtmlContentViewerOnWeb` in the browser email pane.
  web('web', 'chromium', _desktops),

  /// `IosHtmlContentViewerWidget` (EML previewer), no surrounding padding.
  iosPreviewer('ios-previewer', 'webkit', _phones, hasQuoteToggle: false);

  const EmailViewTarget(
    this.label,
    this.engine,
    this._viewports, {
    this.isAndroid = false,
    this.hasQuoteToggle = true,
  });

  static const _phones = (
    standard: EmailViewViewport(414),
    responsive: [EmailViewViewport(320), EmailViewViewport(768)],
  );

  static const _desktops = (
    standard: EmailViewViewport(1032),
    responsive: [EmailViewViewport(632), EmailViewViewport(1432)],
  );

  final String label;
  final String engine;
  final ({EmailViewViewport standard, List<EmailViewViewport> responsive}) _viewports;
  final bool isAndroid;
  final bool hasQuoteToggle;

  EmailViewViewport get standardViewport => _viewports.standard;

  List<EmailViewViewport> get responsiveViewports => _viewports.responsive;

  bool get isWeb => this == web;

  /// Horizontal padding `EmailView` puts around the viewer.
  int get horizontalPadding => switch (this) {
        nativeAndroid || nativeIos => EmailViewStyles.mobileEmailContentPadding.horizontal.round(),
        web => EmailViewStyles.emailContentPadding.horizontal.round(),
        iosPreviewer => 0,
      };

  /// Width of the webview or iframe itself.
  int paneWidth(EmailViewViewport viewport) => viewport.bodyWidth - horizontalPadding;

  /// The document this viewer loads for already transformed [content].
  String buildDocument(String content, EmailViewViewport viewport, TextDirection direction) => switch (this) {
        nativeAndroid || nativeIos => HtmlViewerDocumentBuilder.buildNative(
            configuration: _nativeConfiguration(content, viewport, direction),
            applyMobileResponsiveLayout: true,
            isAndroid: isAndroid,
          ),
        web => HtmlViewerDocumentBuilder.buildWeb(_webInput(content, viewport, direction)),
        iosPreviewer => HtmlViewerDocumentBuilder.buildIos(
            content: content,
            direction: direction,
            useDefaultFontStyle: true,
          ),
      };

  static HtmlContentViewerTypography _typography(EmailViewViewport viewport) => HtmlContentViewerTypography(
        fontStyle: HtmlContentViewerFontStyle.defaultStyle,
        textSize: HtmlContentViewerLength(viewport.fontSize),
      );

  /// As `EmailView` configures `HtmlContentViewer`.
  static HtmlContentViewerConfiguration _nativeConfiguration(
    String content,
    EmailViewViewport viewport,
    TextDirection direction,
  ) =>
      HtmlContentViewerConfiguration(
        content: HtmlContentViewerContent(html: content, direction: direction),
        layout: HtmlContentViewerLayout(
          viewport: HtmlContentViewerViewport(
            constraints: BoxConstraints.tightFor(width: viewport.bodyWidth.toDouble()),
          ),
          contentPadding: const HtmlContentViewerLength(0),
        ),
        typography: _typography(viewport),
        behavior: HtmlContentViewerBehavior(features: {
          HtmlContentViewerFeature.quoteToggle,
          HtmlContentViewerFeature.mobileResponsiveLayout,
        }),
      );

  /// As `EmailView` configures `HtmlContentViewerOnWeb`.
  static HtmlWebViewerDocumentInput _webInput(
    String content,
    EmailViewViewport viewport,
    TextDirection direction,
  ) =>
      HtmlWebViewerDocumentInput(
        content: HtmlContentViewerContent(html: content, direction: direction),
        typography: _typography(viewport),
        behavior: HtmlContentViewerBehavior(features: {HtmlContentViewerFeature.quoteToggle}),
        dimensions: HtmlWebViewerDimensions(
          widthContent: viewport.bodyWidth.toDouble(),
          minHeight: ConstantsUI.htmlContentMinHeight,
          minWidth: ConstantsUI.htmlContentMinWidth,
          contentPadding: 0,
        ),
      );
}

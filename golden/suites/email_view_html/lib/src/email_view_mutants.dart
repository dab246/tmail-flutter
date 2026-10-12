import 'package:core/utils/html/html_interaction.dart';
import 'package:core/utils/html/html_template.dart';
import 'package:core/utils/html/html_utils.dart';
import 'package:core/utils/html/mobile_email_responsive_layout_script.dart';
import 'package:golden_email_view_html/src/email_view_target.dart';

typedef MutantPart = String Function(EmailViewTarget target, EmailViewViewport viewport);

/// One block the viewer document builder injects, removed to prove the pixel
/// goldens or the page invariants notice it. The part is the production
/// constant itself, so a renamed or dropped block fails the export loudly.
class EmailViewMutant {
  const EmailViewMutant({
    required this.id,
    required this.part,
    required this.targets,
    required this.fixtureTag,
    this.state = 'collapsed',
  });

  final String id;
  final MutantPart part;
  final Set<EmailViewTarget> targets;

  /// Fixtures likely to show the block's effect.
  final String fixtureTag;
  final String state;

  /// How many cases per mutant are rendered; one is enough when it is killed.
  static const maxCases = 3;
}

String _quoteToggleStyle(EmailViewTarget target, EmailViewViewport viewport) => HtmlUtils.quoteToggleStyle;

String _quoteToggleScript(EmailViewTarget target, EmailViewViewport viewport) => HtmlUtils.quoteToggleScript;

String _normalizeImageScript(EmailViewTarget target, EmailViewViewport viewport) =>
    HtmlInteraction.generateNormalizeImageScript(viewport.bodyWidth.toDouble());

String _responsiveLayoutScript(EmailViewTarget target, EmailViewViewport viewport) =>
    MobileEmailResponsiveLayoutScript.generate(
      contentSizeChangedEventJSChannelName: HtmlInteraction.contentSizeChangedEventJSChannelName,
    );

String _lazyBackgroundScript(EmailViewTarget target, EmailViewViewport viewport) =>
    HtmlInteraction.scriptsHandleLazyLoadingBackgroundImage;

String _contentSizeScript(EmailViewTarget target, EmailViewViewport viewport) =>
    HtmlInteraction.scriptsHandleContentSizeChanged;

String _fontFaces(EmailViewTarget target, EmailViewViewport viewport) => HtmlTemplate.fontFaceStyle;

String _defaultFontStyle(EmailViewTarget target, EmailViewViewport viewport) =>
    HtmlTemplate.defaultFontStyle(fontSize: viewport.fontSize);

const emailViewMutants = [
  EmailViewMutant(
    id: 'without quote toggle style',
    part: _quoteToggleStyle,
    targets: {EmailViewTarget.web, EmailViewTarget.nativeAndroid},
    fixtureTag: 'quotes',
  ),
  EmailViewMutant(
    id: 'without quote toggle script',
    part: _quoteToggleScript,
    targets: {EmailViewTarget.web, EmailViewTarget.nativeAndroid},
    fixtureTag: 'quotes',
  ),
  EmailViewMutant(
    id: 'without image normalize script',
    part: _normalizeImageScript,
    targets: {EmailViewTarget.nativeAndroid, EmailViewTarget.web},
    fixtureTag: 'images',
  ),
  EmailViewMutant(
    id: 'without mobile responsive layout script',
    part: _responsiveLayoutScript,
    targets: {EmailViewTarget.nativeAndroid, EmailViewTarget.nativeIos},
    fixtureTag: 'wide-content',
  ),
  EmailViewMutant(
    id: 'without lazy background image script',
    part: _lazyBackgroundScript,
    targets: {EmailViewTarget.nativeAndroid, EmailViewTarget.web},
    fixtureTag: 'background-images',
  ),
  EmailViewMutant(
    id: 'without content size script',
    part: _contentSizeScript,
    targets: {EmailViewTarget.nativeAndroid},
    fixtureTag: 'links',
  ),
  EmailViewMutant(
    id: 'without font faces',
    part: _fontFaces,
    targets: {EmailViewTarget.web},
    fixtureTag: 'links',
  ),
  EmailViewMutant(
    id: 'without default font style',
    part: _defaultFontStyle,
    targets: {EmailViewTarget.nativeIos, EmailViewTarget.web},
    fixtureTag: 'signature',
  ),
];

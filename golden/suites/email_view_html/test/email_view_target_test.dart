import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/utils/html/html_interaction.dart';
import 'package:core/utils/html/html_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_email_view_html/golden_email_view_html.dart';
import 'package:tmail_ui_user/features/email/presentation/styles/email_view_styles.dart';

const _quoted = '<p>reply</p><blockquote><p>original</p></blockquote>';

void main() {
  group('EmailViewViewport', () {
    test('SHOULD use the mobile text size below the tablet breakpoint only', () {
      expect(const EmailViewViewport(ResponsiveUtils.minTabletWidth - 1).fontSize, 16);
      expect(const EmailViewViewport(ResponsiveUtils.minTabletWidth).fontSize, 14);
    });
  });

  group('EmailViewTarget geometry', () {
    test('SHOULD take the padding around each viewer from the app styles', () {
      expect(EmailViewTarget.nativeAndroid.horizontalPadding, EmailViewStyles.mobileEmailContentPadding.horizontal);
      expect(EmailViewTarget.nativeIos.horizontalPadding, EmailViewStyles.mobileEmailContentPadding.horizontal);
      expect(EmailViewTarget.web.horizontalPadding, EmailViewStyles.emailContentPadding.horizontal);
      expect(EmailViewTarget.iosPreviewer.horizontalPadding, 0);
    });

    test('SHOULD size the webview as the body width minus that padding', () {
      const target = EmailViewTarget.nativeAndroid;

      expect(target.paneWidth(target.standardViewport), target.standardViewport.bodyWidth - target.horizontalPadding);
    });
  });

  group('EmailViewTarget.buildDocument', () {
    for (final target in EmailViewTarget.values) {
      test('${target.label} SHOULD ${target.hasQuoteToggle ? '' : 'NOT '}add the quote toggle', () {
        final document = target.buildDocument(_quoted, target.standardViewport, TextDirection.ltr);

        expect(document.contains(EmailViewRenderSuite.quoteToggleMarker), target.hasQuoteToggle);
        expect(document, contains('original'));
      });

      test('${target.label} SHOULD lay out right to left WHEN the direction is rtl', () {
        final document = target.buildDocument('<p>x</p>', target.standardViewport, TextDirection.rtl);

        expect(document, contains('dir="rtl"'));
      });
    }

    test('native-android SHOULD be the only target with the Android content size script', () {
      for (final target in EmailViewTarget.values) {
        final document = target.buildDocument('<p>x</p>', target.standardViewport, TextDirection.ltr);
        expect(document.contains(HtmlInteraction.scriptsHandleContentSizeChanged), target == EmailViewTarget.nativeAndroid, reason: target.label);
      }
    });

    test('web SHOULD add the quote toggle style the viewer ships', () {
      const target = EmailViewTarget.web;

      expect(target.buildDocument('<p>x</p>', target.standardViewport, TextDirection.ltr), contains(HtmlUtils.quoteToggleStyle));
    });
  });
}

import 'package:core/presentation/utils/html_transformer/transform_configuration.dart';
import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/src/offline_html_transform.dart';
import 'package:golden_tmail_html/src/transform_pipeline.dart';

/// Every production HTML pipeline of the app, built once and shared by the
/// suites, so no suite rebuilds one or picks its own invariants.
///
/// Which pipelines sanitize follows `html_pipelines_sanitizer_wiring_test`;
/// `tmail_pipelines_test` checks each claim against a hostile probe.
class TmailPipelines {
  TmailPipelines({OfflineHtmlTransform? transform}) : _transform = transform ?? OfflineHtmlTransform();

  final OfflineHtmlTransform _transform;

  TransformPipeline _html(
    String id,
    TransformConfigurationFactory configuration,
    List<Invariant<HtmlTransformSubject>> invariants, {
    PipelinePlatform platform = PipelinePlatform.native,
  }) =>
      TransformPipeline(
        id: id,
        format: FixtureFormat.html,
        configuration: configuration,
        invariants: invariants,
        platform: platform,
        transform: _transform,
      );

  /// `EmailDataSourceImpl` / `SingleEmailController` on Android and iOS.
  late final previewNative = _html('preview-native', TransformConfiguration.forPreviewEmail, sanitizingInvariants);

  /// Same, on web.
  late final previewWeb = _html(
    'preview-web',
    TransformConfiguration.forPreviewEmailOnWeb,
    sanitizingInvariants,
    platform: PipelinePlatform.web,
  );

  /// `HtmlAnalyzer` for text/plain bodies.
  late final plainText = TransformPipeline(
    id: 'plain-text',
    format: FixtureFormat.text,
    configuration: TransformConfiguration.forPlainTextEmail,
    invariants: sanitizingInvariants,
    transform: _transform,
  );

  /// Composer content (`setup_email_content_extension.dart`,
  /// `GetListDetailedEmailByIdInteractor`). Reply and forward do not sanitize.
  late final replyForward = _html('reply-forward', TransformConfiguration.forReplyForwardEmail, preservingInvariants);
  late final replyForwardEmpty =
      _html('reply-forward-empty', TransformConfiguration.forReplyForwardEmptyEmail, preservingInvariants);
  late final drafts = _html('drafts', TransformConfiguration.forDraftsEmail, sanitizingInvariants);
  late final editDraftsNative =
      _html('edit-drafts-native', TransformConfiguration.forEditDraftsEmail, sanitizingInvariants);
  late final editDraftsWeb = _html(
    'edit-drafts-web',
    TransformConfiguration.forEditDraftsEmail,
    sanitizingInvariants,
    platform: PipelinePlatform.web,
  );
  late final restore = _html('restore', TransformConfiguration.forRestoreEmail, sanitizingInvariants);

  /// `PrintFileDataSourceImpl` prints what the email view loaded
  /// (`EmailActionReactor.printEmail` passes `emailLoaded.htmlContent`).
  late final printFromPreviewNative = _print('print-native', previewNative);
  late final printFromPreviewWeb = _print('print-web', previewWeb);

  /// `IdentityDataSourceImpl` and `ComposerController` signatures.
  late final signatureIdentity =
      _html('signature-identity', TransformConfiguration.forSignatureIdentity, sanitizingInvariants);
  late final composerSignature =
      _html('composer-signature', TransformConfiguration.forComposerSignature, preservingInvariants);

  ChainedPipeline _print(String id, TransformPipeline preview) => ChainedPipeline(
        id: id,
        first: preview,
        last: _html(id, TransformConfiguration.forPrintEmail, preservingInvariants),
        invariants: sanitizingInvariants,
      );

  List<TextPipeline> get all => [
        previewNative,
        previewWeb,
        plainText,
        replyForward,
        replyForwardEmpty,
        drafts,
        editDraftsNative,
        editDraftsWeb,
        restore,
        printFromPreviewNative,
        printFromPreviewWeb,
        signatureIdentity,
        composerSignature,
      ];
}

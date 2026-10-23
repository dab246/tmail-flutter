import 'dart:convert';

import 'package:core/data/network/dio_client.dart';
import 'package:core/presentation/utils/html_transformer/html_transform.dart';
import 'package:core/presentation/utils/html_transformer/transform_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures carry no CID map, so the pipeline never downloads; any network
/// call would throw from this fake instead of hiding behind a mock.
class _OfflineDioClient extends Fake implements DioClient {}

/// The production [HtmlTransform], built the way the app builds it, offline.
class OfflineHtmlTransform {
  OfflineHtmlTransform() : _transform = HtmlTransform(_OfflineDioClient(), const HtmlEscape());

  final HtmlTransform _transform;

  Future<String> html(String content, TransformConfiguration configuration) =>
      _transform.transformToHtml(htmlContent: content, transformConfiguration: configuration);

  String text(String content, TransformConfiguration configuration) =>
      _transform.transformToTextPlain(content: content, transformConfiguration: configuration);
}

import 'dart:convert';
import 'dart:io';

/// Root folder of [package] as resolved by the workspace.
///
/// `flutter test` cannot resolve `package:` URIs to files at runtime, so this
/// reads the `.dart_tool/package_config.json` found above [from].
Directory packageRoot(String package, {Directory? from}) {
  final start = (from ?? Directory.current).absolute;
  for (var dir = start; dir.parent.path != dir.path; dir = dir.parent) {
    final config = File('${dir.path}/.dart_tool/package_config.json');
    if (config.existsSync()) return _resolve(config, package);
  }
  throw StateError('No .dart_tool/package_config.json above ${start.path}');
}

Directory _resolve(File config, String package) {
  final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().where((p) => p['name'] == package).firstOrNull;
  if (entry == null) throw StateError('$package is not in ${config.path}');
  return Directory.fromUri(config.uri.resolve(entry['rootUri'] as String));
}

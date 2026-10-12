/// The document of a render case with one injected block (a viewer script or
/// style) removed. The runner proves the goldens notice: rendering it must
/// change the case's pixels or break one of its invariants.
class MutantCase {
  const MutantCase({required this.caseId, required this.document});

  final String caseId;
  final String document;

  Map<String, Object?> toJson() => {'caseId': caseId, 'document': document};
}

/// Removes [part] from [document] for mutant [mutantId]. Throws when the part
/// is missing, which means the builder changed and the mutant is stale.
String withoutPart(String document, String part, {required String mutantId}) {
  if (part.isEmpty || !document.contains(part)) {
    throw StateError('mutant "$mutantId": the part to remove is not in the document; update the mutant');
  }
  return document.replaceFirst(part, '');
}

/// Where the mutant [mutantId] of [document] is written in the export.
String mutantDocumentPath(String mutantId, String document) => 'mutants/${_slug(mutantId)}/$document';

/// Lowercase letters and digits kept, anything else becomes `-`.
String _slug(String id) => String.fromCharCodes(
      id.toLowerCase().codeUnits.map((unit) => _isSlugUnit(unit) ? unit : 0x2D),
    );

bool _isSlugUnit(int unit) => _isLowercaseLetter(unit) || _isDigit(unit);

bool _isLowercaseLetter(int unit) => unit >= 0x61 && unit <= 0x7A;

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

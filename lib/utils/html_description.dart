/// Converts Jellyfin HTML descriptions to readable plain text.
///
/// Descriptions are displayed in regular Flutter Text widgets, so preserve
/// common block boundaries while removing markup and decoding entities.
String cleanHtmlDescription(String? html) {
  if (html == null || html.trim().isEmpty) return '';

  var text = html
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(
        RegExp(
          r'<(script|style)\b[^>]*>.*?</\1\s*>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|h[1-6]|blockquote)\s*>', caseSensitive: false),
        '\n\n',
      )
      .replaceAll(
        RegExp(r'<(p|div|h[1-6]|blockquote)\b[^>]*>', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(ul|ol)\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '');

  text = _decodeHtmlEntities(text)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[\t\u00a0 ]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  return text;
}

String _decodeHtmlEntities(String text) {
  const namedEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'ndash': '–',
    'mdash': '—',
    'hellip': '…',
    'lsquo': '‘',
    'rsquo': '’',
    'ldquo': '“',
    'rdquo': '”',
    'bull': '•',
    'copy': '©',
    'reg': '®',
    'trade': '™',
    'euro': '€',
    'aacute': 'á',
    'agrave': 'à',
    'acirc': 'â',
    'atilde': 'ã',
    'auml': 'ä',
    'aring': 'å',
    'aelig': 'æ',
    'ccedil': 'ç',
    'eacute': 'é',
    'egrave': 'è',
    'ecirc': 'ê',
    'euml': 'ë',
    'iacute': 'í',
    'igrave': 'ì',
    'icirc': 'î',
    'iuml': 'ï',
    'ntilde': 'ñ',
    'oacute': 'ó',
    'ograve': 'ò',
    'ocirc': 'ô',
    'otilde': 'õ',
    'ouml': 'ö',
    'oslash': 'ø',
    'uacute': 'ú',
    'ugrave': 'ù',
    'ucirc': 'û',
    'uuml': 'ü',
    'yacute': 'ý',
    'yuml': 'ÿ',
    'szlig': 'ß',
    'Aacute': 'Á',
    'Agrave': 'À',
    'Acirc': 'Â',
    'Atilde': 'Ã',
    'Auml': 'Ä',
    'Aring': 'Å',
    'AElig': 'Æ',
    'Ccedil': 'Ç',
    'Eacute': 'É',
    'Egrave': 'È',
    'Ecirc': 'Ê',
    'Euml': 'Ë',
    'Iacute': 'Í',
    'Igrave': 'Ì',
    'Icirc': 'Î',
    'Iuml': 'Ï',
    'Ntilde': 'Ñ',
    'Oacute': 'Ó',
    'Ograve': 'Ò',
    'Ocirc': 'Ô',
    'Otilde': 'Õ',
    'Ouml': 'Ö',
    'Oslash': 'Ø',
    'Uacute': 'Ú',
    'Ugrave': 'Ù',
    'Ucirc': 'Û',
    'Uuml': 'Ü',
    'Yacute': 'Ý',
    'Yuml': 'Ÿ',
  };

  return text.replaceAllMapped(
    RegExp(r'&(#(?:x[0-9a-f]+|[0-9]+)|[a-z]+);', caseSensitive: false),
    (match) {
      final entity = match[1]!;
      if (entity.startsWith('#')) {
        final isHex = entity.length > 1 && entity[1].toLowerCase() == 'x';
        final digits = entity.substring(isHex ? 2 : 1);
        final codePoint = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (codePoint != null &&
            codePoint > 0 &&
            codePoint <= 0x10ffff &&
            (codePoint < 0xd800 || codePoint > 0xdfff)) {
          return String.fromCharCode(codePoint);
        }
        return match[0]!;
      }
      return namedEntities[entity] ??
          namedEntities[entity.toLowerCase()] ??
          match[0]!;
    },
  );
}

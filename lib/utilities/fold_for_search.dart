/// Lower-cases [value] and strips common Latin diacritics so "reykjavik"
/// matches "Reykjavík".
String foldForSearch(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldedChars[char] ?? char);
  }
  return buffer.toString();
}

const _foldedChars = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', //
  'æ': 'ae', 'ç': 'c', 'ð': 'd', 'ß': 'ss', 'þ': 'th', 'œ': 'oe', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', //
  'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ý': 'y', 'ÿ': 'y',
};

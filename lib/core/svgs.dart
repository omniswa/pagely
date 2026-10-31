/// Line-art illustrations. They use `currentColor`, tinted at render time.
abstract final class AppSvgs {
  static const String _open =
      '<svg viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg" '
      'stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">';

  static const String emptyLibrary = '$_open'
      '<rect x="20" y="30" width="22" height="68" rx="4"/>'
      '<rect x="48" y="20" width="22" height="78" rx="4"/>'
      '<path d="M78 38l18-6 14 62-18 5z"/>'
      '<path d="M26 44h10M54 34h10"/>'
      '<path d="M10 104h100"/></svg>';

  static const String offline = '$_open'
      '<path d="M36 84h48a17 17 0 0 0 3-33.7A27 27 0 0 0 35 46a19 19 0 0 0 1 38z"/>'
      '<path d="M20 20l80 80"/></svg>';

  static const String noResults = '$_open'
      '<circle cx="52" cy="52" r="26"/>'
      '<path d="M72 72l26 26"/>'
      '<path d="M43 43l18 18M61 43L43 61"/></svg>';
}

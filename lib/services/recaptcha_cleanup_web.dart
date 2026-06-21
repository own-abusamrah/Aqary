import 'dart:html' as html;

void cleanupRecaptchaArtifacts() {
  final selectors = <String>[
    '.grecaptcha-badge',
    'iframe[src*="recaptcha"]',
    'div[id^="g-recaptcha"]',
  ];

  for (final selector in selectors) {
    final nodes = html.document.querySelectorAll(selector);
    for (final node in nodes) {
      node.remove();
    }
  }
}

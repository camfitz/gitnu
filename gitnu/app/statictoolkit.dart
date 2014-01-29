library StaticToolkit;

import 'dart:html';

import 'constants.dart';

class StaticToolkit {
  StaticToolkit();

  /**
   * Escapes HTML-special characters of [text] so that the result can be
   * included verbatim in HTML source code, either in an element body or in an
   * attribute value.
   */
  static String htmlEscape(String text) {
    // TODO(efortuna): A more efficient implementation.
    return text.replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
              .replaceAll("'", "&apos;");
  }

  /**
   * Returns true if the key code matches a key used for navigating the page.
   */
  static bool isNavigateKey(KeyboardEvent event) {
    return (event.keyCode == PG_DOWN_KEY ||
        event.keyCode == PG_UP_KEY ||
        event.keyCode == END_KEY ||
        event.keyCode == HOME_KEY);
  }
}
import 'dart:html';

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
   * Writes to output element and then scrolls into view of the scrollTo
   * element.
   */
  static void writeOutput(String h, OutputElement output, DivElement scrollTo) {
    output.insertAdjacentHtml('beforeEnd', h);
    scrollTo.scrollIntoView(ScrollAlignment.TOP);
  }
}
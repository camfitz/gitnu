library GitnuOutput;

import 'dart:html';

import "statictoolkit.dart";

/**
 * An interface for outputting in various formats.
 * Expected to utilise this class to output from GitnuFileSystem.
 *
 * Provides basic terminal implementation of the class.
 */
class GitnuOutput {
  /**
   * Baseline function for printing to an output stream.
   */
  Function _stringPrinter;

  /**
   * Constructor for the class.
   * Expected to receive the stringPrinter from the low level display class.
   */
  GitnuOutput(this._stringPrinter);

  /**
   * Prints a newline terminated string.
   * Escapes any HTML characters.
   */
  void printLine(String line) {
    _stringPrinter("${StaticToolkit.htmlEscape(line)}<br>");
  }

  /**
   * Prints a HTML pre-formatted string.
   */
  void printHtml(String line) {
    _stringPrinter(line);
  }

  /**
   * Print a list of entries into columns.
   */
  void printEntryColumns(List<Entry> entries) {
    _printColumns(entries,
                  (Entry entry) => entry.name,
                  (Entry entry) => entry.isDirectory ? 'folder' : 'file');
  }

  /**
   * Print a list of strings into columns.
   */
  void printStringColumns(List<String> items) {
    _printColumns(items, (String item) => item, null);
  }

  /**
   * Generic column printer.
   */
  void _printColumns(List items, Function stringify, Function displayClass) {
    if (items.length != 0) {
      StringBuffer html = new StringBuffer();
      int maxLength = 0;
      items.forEach((item) {
        if (displayClass != null)
          html.write('<span class="${displayClass(item)}">');
        else
          html.write('<span>');
        String itemString = stringify(item);
        if (itemString.length > maxLength)
          maxLength = itemString.length;
        html.write('${StaticToolkit.htmlEscape(itemString)}</span><br>');
      });
      html.write('</div>');
      StringBuffer formatBuffer = _formatColumns(maxLength);
      formatBuffer.write(html);
      printHtml(formatBuffer.toString());
    }
  }

  /**
   * Takes an int and establishes the number of columns to best output a list of
   * items where that int is the maximum length required to display.
   * Returns an HTML string representing then opening div for a table of
   * entries.
   */
  StringBuffer _formatColumns(int maxLength) {
    if (maxLength == 0)
      return new StringBuffer('<div>');
    StringBuffer sb = new StringBuffer();

    // Experimented width required for a column.
    var pxWidth = maxLength * 9;
    if (maxLength < 12)
      pxWidth = maxLength * 12;
    if (maxLength < 2)
      pxWidth = maxLength * 30;

    int colCount = window.innerWidth ~/ pxWidth;
    sb.write('<div class="ls-files" style="-webkit-column-count: $colCount;">');
    return sb;
  }
}
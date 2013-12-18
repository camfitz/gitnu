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
   * Print a list of items in nice columns.
   */
  void printColumns(List<Entry> entries) {
    if (entries.length != 0) {
      StringBuffer html = _formatColumns(entries);
      entries.forEach((file) {
        var fileType = file.isDirectory ? 'folder' : 'file';
        var span = '<span class="$fileType">'
                   '${StaticToolkit.htmlEscape(file.name)}</span><br>';
        html.write(span);
      });

      html.write('</div>');
      printHtml(html.toString());
    }
  }

  /**
   * Prints a HTML pre-formatted string.
   */
  void printHtml(String line) {
    _stringPrinter(line);
  }

  /**
   * Takes a list and establishes the number of columns to best output the list.
   * Returns an HTML string representing then opening div for a table of
   * entries.
   */
  StringBuffer _formatColumns(List<Entry> entries) {
    var maxName = entries[0].name;
    entries.forEach((entry) {
      if (entry.name.length > maxName.length) {
        maxName = entry.name;
      }
    });

    StringBuffer sb = new StringBuffer();

    /**
     * Max column width required
     * pxWidth = emWidth * parent font size
     * Parent font size = 14px
     * emWidth set to max out at the maximum string length.
     */
    var pxWidth = maxName.length * 14;

    int colCount = 3;
    if (pxWidth > window.innerWidth ~/ 2) {
      colCount = 1;
    } else if (pxWidth > window.innerWidth ~/ 3) {
      colCount = 2;
    }

    sb.write('<div class="ls-files" style="-webkit-column-count: $colCount;">');
    return sb;
  }
}
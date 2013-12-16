import 'dart:html';import 'gitnuterminal.dart';import 'filehandler.dart';import 'statictoolkit.dart';import 'package:chrome_gen/chrome_app.dart' as chrome;void main() {  var gitnu = new Gitnu();  gitnu.run();}class Gitnu {   GitnuTerminal term;  FileHandler file;    Gitnu() {  }    void run() {    term = new GitnuTerminal('#input-line', '#output', '#cmdline', '#container');        Map<String, Function> commandList;    /**     * Spec for user added functions-     * cmd: the command sent to the terminal to generate this function call     * printer: use this function to print to the terminal, one arg (html formatted string)     * args: list of arguments passed after the command sent to the terminal     *      * These functions should handle terminal output.     */    commandList = {      'ls': lsWrapper,      'cd': cdWrapper,      'mkdir': mkdirWrapper,      'mv': mvWrapper,      'cp': cpWrapper,      'open': openWrapper,      'pwd': pwdWrapper      /*      'rm': rmCommand,      'rmdir': rmdirCommand,      'cat': catCommand*/    };        term.initialiseCommands(commandList);        file = new FileHandler("#file_path");    // Listen for button click to open directory    InputElement chooseDirButton = document.querySelector('#choose_dir');      chooseDirButton.onClick.listen((_) {       file.openHandler("rootFolder");    });  }    void lsWrapper(String cmd, Function printer, List<String> args) {    void display(List<Entry> entries) {      if(entries.length != 0) {        StringBuffer html = formatColumns(entries);        entries.forEach((file) {          var fileType = file.isDirectory ? 'folder' : 'file';          var span = '<span class="$fileType">${StaticToolkit.htmlEscape(file.name)}</span><br>';          html.write(span);        });                html.write('</div>');        printer(html.toString());      }    }        file.listDirectory(args, display);  }    void cdWrapper(String cmd, Function printer, List<String> args) {    void display(String fullPath) {      printer('<div>${StaticToolkit.htmlEscape(fullPath)}</div>');    }        file.changeDirectory(args, display);  }    void mkdirWrapper(String cmd, Function printer, List<String> args) {    file.mkdirCommand(args, printer);  }    void mvWrapper(String cmd, Function printer, List<String> args) {    file.mvCommand(cmd, args, printer);  }    void cpWrapper(String cmd, Function printer, List<String> args) {    file.cpCommand(cmd, args, printer);  }    void openWrapper(String cmd, Function printer, List<String> args) {    file.openCommand(cmd, args, printer);  }    void pwdWrapper(String cmd, Function printer, List<String> args) {    file.printDirectory(printer);  }    void rmWrapper(String cmd, Function printer, List<String> args) {    file.rmCommand(cmd, args, printer);  }    void rmdirWrapper(String cmd, Function printer, List<String> args) {    file.rmdirCommand(cmd, args, printer);  }    void catWrapper(String cmd, Function printer, List<String> args) {    file.catCommand(cmd, args, printer);  }    /**   * Helper functions for the above function wrappers.   */  StringBuffer formatColumns(List<Entry> entries) {    var maxName = entries[0].name;    entries.forEach((entry) {      if (entry.name.length > maxName.length) {        maxName = entry.name;      }    });    StringBuffer sb = new StringBuffer();    // Max column width required    var emWidth = maxName.length * 14;        int colCount = 3;    if(emWidth > window.innerWidth ~/ 2) {      colCount = 1;    } else if(emWidth > window.innerWidth ~/ 3) {      colCount = 2;    }        sb.write('<div class="ls-files" style="-webkit-column-count: $colCount;">');    return sb;  }}
library GitnuTerminal;

import 'dart:html';
import 'dart:async';
import 'dart:math';

import 'constants.dart';
import 'gitnuoutput.dart';
import 'gitnutabcompleter.dart';
import 'keyboardhandler.dart';
import 'statictoolkit.dart';
import 'stringutils.dart';

/**
 * Views container for GitnuTerminal.
 */
class GitnuTerminalView {
  OutputElement output;
  InputElement input;
  DivElement cmdLine;
  DivElement prompt;
  DivElement containerDiv;

  /**
   * Constructs the view object from the document elements.
   */
  GitnuTerminalView() {
    cmdLine = document.querySelector(kInputLine);
    output = document.querySelector(kOutputRegion);
    input = document.querySelector(kCmdLine);
    containerDiv = document.querySelector(kContainer);
    prompt = document.querySelector(kPrompt);
  }

  /**
   * Creates a mock view object for testing.
   */
  GitnuTerminalView.mock() {
    output = new OutputElement();
    input = new InputElement();
    cmdLine = new DivElement();
    prompt = new DivElement();
    containerDiv = new DivElement();
  }
}

class GitnuTerminal {
  GitnuTerminalView view;
  String version = '0.9';
  List<String> _history = [];
  int _historyPosition = 0;
  Map<String, Function> _cmds;
  Map<String, Function> _tabCompletion;
  GitnuOutput _gitnuOutput;
  KeyboardHandler keyboardHandler;

  String kill = "";
  // If set to true, the kill command will empty the kill string before
  // adding more words.
  bool killNew = true;

  GitnuTerminal(this.view) {
    _gitnuOutput = new GitnuOutput(view.output, view.cmdLine);

    // Prompt will need to be enabled by client.
    disablePrompt();

    // Capture focus if click is near input line.
    view.cmdLine.onClick.listen((event) => view.input.focus());

    // Trick: Always force text cursor to end of input line.
    view.cmdLine.onClick.listen((event) => view.input.value = view.input.value);

    // Capture focus to input line on any key press that doesn't affect
    // screen position.
    window.onKeyDown.listen(focusCommandLine);

    // If the input field changes, reset the kill word buffer.
    view.input.onChange.listen(_resetKillBuffer);
    view.input.onKeyDown.listen(_resetKillBufferOnMove);
    view.input.onSelect.listen(_resetKillBuffer);

    // Handle up/down key presses for history, tab completion and enter for
    // new command.
    view.cmdLine.onKeyDown.listen(historyHandler);
    view.cmdLine.onKeyDown.listen(processNewCommand);
    view.cmdLine.onKeyDown.listen(tabCompleterEvent);

    // Handles pgUp, pgDown, end and home scrolling
    view.containerDiv.onKeyDown.listen(positionHandler);

    // Register other shortcut keys
    keyboardHandler = new KeyboardHandler();
    keyboardHandler.registerShortcut(_emacsStartOfLine, A_KEY, true);
    keyboardHandler.registerShortcut(_emacsEndOfLine, E_KEY, true);
    keyboardHandler.registerShortcut(_emacsRemoveSubset, K_KEY, true);
    keyboardHandler.registerShortcut((_) => clearCommand(null), L_KEY, true);
    keyboardHandler.registerShortcut(_emacsClear, U_KEY, true);
    keyboardHandler.registerShortcut(_emacsKillWord, W_KEY, true);
    keyboardHandler.registerShortcut(_emacsYank, Y_KEY, true);

    // Ensures the terminal covers the correct height
    int bodyHeight = window.innerHeight;
    view.containerDiv.style.maxHeight = "${bodyHeight - kTopMargin}px";
    view.containerDiv.style.height = "${bodyHeight - kTopMargin}px";
  }

  /**
   * Reset the kill word buffer. Set this switch to clear the buffer next time
   * we kill.
   */
  void _resetKillBuffer([Event e]) {
    killNew = true;
  }

  /**
   * If a cursor movement is detected in the buffer, reset the kill word buffer.
   */
  void _resetKillBufferOnMove(KeyboardEvent e) {
    if(e.keyCode == LEFT_ARROW_KEY && e.keyCode == RIGHT_ARROW_KEY)
      _resetKillBuffer();
  }

  /**
   * Emacs kill word shortcut, Ctrl+W
   */
  void _emacsKillWord(int keyCode) {
    if (killNew)
      kill = "";
    killNew = false;

    String inputNoTrailingWhiteSpace = view.input.value.trim();
    String lastWord = view.input.value;
    int separator = 0;
    if (inputNoTrailingWhiteSpace.contains(' ')) {
      separator = inputNoTrailingWhiteSpace.lastIndexOf(' ') + 1;
      lastWord = view.input.value.substring(separator, view.input.value.length);
    }
    kill = lastWord + kill;
    view.input.value = view.input.value.substring(0, separator);
  }

  /**
   * Emacs yank shortcut, Ctrl+Y
   */
  void _emacsYank(int keyCode) {
    _resetKillBuffer();
    view.input.value += kill;
  }

  /**
   * Emacs clear line shortcut, Ctrl+U
   */
  void _emacsClear(int keyCode) {
    view.input.value = "";
  }

  /**
   * Emacs start of line shortcut, Ctrl+A
   */
  void _emacsStartOfLine(int keyCode) {
    view.input.setSelectionRange(0, 0);
  }

  /**
   * Emacs end of line shortcut, Ctrl+E
   */
  void _emacsEndOfLine(int keyCode) {
    view.input.setSelectionRange(
        view.input.value.length, view.input.value.length);
  }

  /**
   * Emacs removes from cursor to end of line, Ctrl+K
   */
  void _emacsRemoveSubset(int keyCode) {
    view.input.value = view.input.value.substring(0, view.input.selectionStart);
  }

  /**
   * Window pull focus to command line, unless inputting a position command.
   */
  void focusCommandLine(KeyboardEvent event) {
    if (!StaticToolkit.isNavigateKey(event))
      view.input.focus();
  }

  /**
   * Handles scrolling using pgUp, pgDown, end and home keys.
   */
  void positionHandler(KeyboardEvent event) {
    bool handled = true;
    switch (event.keyCode) {
      case PG_UP_KEY:
        view.containerDiv.scrollByLines(-5);
        break;
      case PG_DOWN_KEY:
        view.containerDiv.scrollByLines(5);
        break;
      case END_KEY:
        view.cmdLine.scrollIntoView(ScrollAlignment.TOP);
        break;
      case HOME_KEY:
        view.output.scrollIntoView(ScrollAlignment.TOP);
        break;
      default:
        handled = false;
        break;
    }
    if (handled)
      event.preventDefault();
  }

  /**
   * Enables the input prompt and focuses on it.
   * Displays the prompt indicator "$>"
   */
  void enablePrompt() {
    view.input.disabled = false;
    view.prompt.innerHtml = "\$&gt;";
    view.input.focus();
  }

  /**
   * Hides the prompt indicator and disables the input prompt.
   */
  void disablePrompt() {
    view.input.disabled = true;
    view.prompt.innerHtml = "";
  }

  /**
   * Adds the current input element to the history list, moves it into a div
   * in the output pane, and creates a new input element.
   */
  void commitBufferToLog() {
    if (!view.input.value.isEmpty) {
      _history.add(view.input.value);
      _historyPosition = _history.length;
    }

    // Move the line to output and remove id's.
    DivElement line = view.input.parent.parent.clone(true);
    line.attributes.remove('id');
    line.classes.add('line');
    InputElement cmdInput = line.querySelector(kCmdLine);
    cmdInput.attributes.remove('id');
    cmdInput.autofocus = false;
    cmdInput.readOnly = true;
    view.output.children.add(line);

    _resetKillBuffer();
  }

  /**
   * Handles command input
   * Dispatches a function call either to commandFromList(cmd, args)
   * or commandFromExternalList(cmd, ouputWriter, args) where appropriate.
   */
  void processNewCommand(KeyboardEvent event) {
    if (event.keyCode == ENTER_KEY) {
      commitBufferToLog();

      String cmdline = view.input.value;
      view.input.value = ""; // clear input
      disablePrompt();

      runCommand(cmdline).whenComplete(() {
        enablePrompt();
        view.cmdLine.scrollIntoView(ScrollAlignment.TOP);
      });
    }
  }

  Future runCommand(String cmdline) {
    return new Future.value().then((_) {
      List<String> args = StringUtils.parseCommandLine(cmdline);

      if (args == null)
        throw '"unfinished quotation set.';

      if (args.isEmpty)
        return new Future.value();

      String cmd = args.removeAt(0);
      if (_cmds[cmd] is Function) {
        return new Future.sync(() => _cmds[cmd](args)).then((_) {},
            onError: (e) => _gitnuOutput.printHtml('$cmd error: $e'));
      }

      if (!cmd.isEmpty)
        _gitnuOutput.printHtml(
            '${StaticToolkit.htmlEscape(cmd)}: command not found');
    }).catchError((e) => _gitnuOutput.printHtml('error: $e'));
  }

  /**
   * Handles commands entered previously and redisplaying them in the input
   * field when the up and down arrows are used.
   */
  void historyHandler(KeyboardEvent event) {
    if (event.keyCode == UP_ARROW_KEY || event.keyCode == DOWN_ARROW_KEY) {
      event.preventDefault();
      _resetKillBuffer();
      if (_historyPosition < _history.length)
        _history[_historyPosition] = view.input.value;
    }

    if (event.keyCode == UP_ARROW_KEY) {
      _historyPosition--;
      if (_historyPosition < 0)
        _historyPosition = 0;
    } else if (event.keyCode == DOWN_ARROW_KEY) {
      _historyPosition++;
      if (_historyPosition > _history.length)
        _historyPosition = max(0, _history.length);
    }

    if (event.keyCode == UP_ARROW_KEY || event.keyCode == DOWN_ARROW_KEY) {
      if (_historyPosition == _history.length)
        view.input.value = "";
      else if (_history.length != 0 && _history[_historyPosition] != null)
        view.input.value = _history[_historyPosition];
    }
  }

  /**
   * Prints the tab completion output.
   * If there is only one option, the input field will be updated.
   * If there is more than one option, a full list will be displayed.
   */
  void writeTabCompleter(String cmdLine,
                         String currentWord,
                         List<String> options) {
    // If the input field has changed since the tab complete was called.
    // (i.e. due to an async complete taking too long, double hit of tab key).
    if (cmdLine != view.input.value)
      return;

    if (options.isEmpty)
      return;

    if (options.length == 1) {
      view.input.value += options[0].replaceFirst(currentWord, '') + ' ';
      return;
    }

    commitBufferToLog();
    _gitnuOutput.printStringColumns(options);
    _resetKillBuffer();
  }

  /**
   * Event handler for a tab completion event.
   * Prevents default tab behaviour and then fires the tab completion function.
   */
  void tabCompleterEvent(KeyboardEvent event) {
    if (event.keyCode != TAB_KEY)
      return;
    event.preventDefault();
    GitnuTabCompleter.tabCompleter(
        view.input.value, _cmds, _tabCompletion).then((Completion completion) {
      if (completion != null)
        writeTabCompleter(
            completion.cmdLine, completion.last, completion.options);
    });
  }

  /**
   * Establishes commands that can be called from the terminal and prints a
   * welcome note. Accepts a map of user commands to be called.
   */
  void initialiseCommands(Map<String, Function> commandList,
                          Map<String, Function> tabCompletion) {
    _cmds = {
      'clear': clearCommand,
      'help': helpCommand,
      'version': versionCommand,
      'date': dateCommand,
      'who': whoCommand
    };
    // User added commands
    _cmds.addAll(commandList);

    // User added tab completions
    _tabCompletion = new Map<String, Function>();
    _tabCompletion.addAll(tabCompletion);

    // Somewhat importantly, print out a welcome header.
    // Headers are slightly mangled below due to escaped characters.
    var rng = new Random();
    int choice = rng.nextInt(4);

    if (choice == 0) {
      _gitnuOutput.printHtml('<pre class="logo">'
        '           ######   #### ######## ##    ## ##     ## <br>'
        '          ##    ##   ##     ##    ###   ## ##     ## <br>'
        '          ##         ##     ##    ####  ## ##     ## <br>'
        '          ##   ####  ##     ##    ## ## ## ##     ## <br>'
        '          ##    ##   ##     ##    ##  #### ##     ## <br>'
        '          ##    ##   ##     ##    ##   ### ##     ## <br>'
        '           ######   ####    ##    ##    ##  #######  </pre>');
    } else if (choice == 1) {
      _gitnuOutput.printHtml('<pre class="logo">'
      '      ___                           ___         ___      <br>'
      '     /  /\\      ___         ___    /__/\\       /__/\\     <br>'
      '    /  /:/_    /  /\\       /  /\\   \\  \\:\\      \\  \\:\\    <br>'
      '   /  /:/ /\\  /  /:/      /  /:/    \\  \\:\\      \\  \\:\\   <br>'
      '  /  /:/_/::\\/__/::\\     /  /:/ _____\\__\\:\\ ___  \\  \\:\\  <br>'
      ' /__/:/__\\/\\:\\__\\/\\:\\__ /  /::\\/__/::::::::/__/\\  \\__\\:\\ <br>'
      ' \\  \\:\\ /~~/:/  \\  \\:\\//__/:/\\:\\  \\:\\~~\\~~\\\\  \\:\\ /  /:/ '
          '<br>'
      '  \\  \\:\\  /:/    \\__\\::\\__\\/  \\:\\  \\:\\  ~~~ \\  \\:\\  /:/  '
          '<br>'
      '   \\  \\:\\/:/     /__/:/     \\  \\:\\  \\:\\      \\  \\:\\/:/   <br>'
      '    \\  \\::/      \\__\\/       \\__\\/\\  \\:\\      \\  \\::/    <br>'
      '     \\__\\/                         \\__\\/       \\__\\/     '
      '</pre>');
    } else if (choice == 2) {
      _gitnuOutput.printHtml('<pre class="logo">'
      '      .-_\'\'\'-.  .-./`) ,---------. ,---.   .--.  ___    _  <br>'
      '     \'_( )_   \\ \\ .-.\')\\          \\|    \\  |  |.\'   |  | | <br>'
      '    |(_ o _)|  \'/ `-\' \\ `--.  ,---\'|  ,  \\ |  ||   .\'  | | <br>'
      '    . (_,_)/___| `-\'`"`    |   \\   |  |\\_ \\|  |.\'  \'_  | | <br>'
      '    |  |  .-----..---.     :_ _:   |  _( )_\\  |\'   ( \\.-.| <br>'
      '    \'  \\  \'-   .\'|   |     (_I_)   | (_ o _)  |\' (`. _` /| <br>'
      '     \\  `-\'`   | |   |    (_(=)_)  |  (_,_)\\  || (_ (_) _) <br>'
      '      \\        / |   |     (_I_)   |  |    |  | \\ /  . \\ / <br>'
      '       `\'-...-\'  \'---\'     \'---\'   \'--\'    \'--\'  ``-\'`-\'\'  '
      '</pre>');
    } else if (choice == 3) {
      _gitnuOutput.printHtml('<pre class="logo">'
      '         _/_/_/  _/    _/                        <br>'
      '      _/            _/_/_/_/  _/_/_/    _/    _/ <br>'
      '     _/  _/_/  _/    _/      _/    _/  _/    _/  <br>'
      '    _/    _/  _/    _/      _/    _/  _/    _/   <br>'
      '     _/_/_/  _/      _/_/  _/    _/    _/_/_/    '
      '</pre>');
    }

    _gitnuOutput.printHtml('<div>Welcome to Gitnu! (v$version)</div>');
    _gitnuOutput.printHtml(new DateTime.now().toLocal().toString());
    _gitnuOutput.printHtml('<p>Documentation: type "help"</p>');
  }

  /**
   * Basic inbuilt commands.
   * User function invariant (except help... builds off user functions).
   */
  void clearCommand(List<String> args) {
    view.output.innerHtml = '';
  }

  void helpCommand(List<String> args) {
    StringBuffer sb = new StringBuffer();
    sb.write('Keyboard shortcuts for default emacs behaviours: '
             'Ctrl + A, E, K, L, U, W or Y<br><br>');
    sb.write('<div class="ls-files">');
    _cmds.keys.forEach((key) => sb.write('$key<br>'));
    sb.write('</div>');
    _gitnuOutput.printHtml(sb.toString());
  }

  void versionCommand(List<String> args) {
    _gitnuOutput.printHtml("$version");
  }

  void dateCommand(List<String> args) {
    _gitnuOutput.printHtml(new DateTime.now().toLocal().toString());
  }

  void whoCommand(List<String> args) {
    _gitnuOutput.printHtml('${StaticToolkit.htmlEscape(document.title)}<br>'
        'Basic terminal implementation - By:  Eric Bidelman '
        '&lt;ericbidelman@chromium.org&gt;, Adam Singer '
        '&lt;financeCoding@gmail.com&gt;<br>Adapted by Cameron Fitzgerald '
        '&lt;camfitz@google.com|camandco@gmail.com&gt; for Git / advanced '
        'features.');
  }
}
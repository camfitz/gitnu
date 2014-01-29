library GitnuTerminal;

import 'dart:html';
import 'dart:async';
import 'dart:math';

import 'constants.dart';
import 'statictoolkit.dart';
import 'stringutils.dart';

class GitnuTerminal {
  OutputElement _output;
  InputElement _input;
  DivElement _cmdLine;
  DivElement _prompt;
  DivElement _containerDiv;
  String _version = '0.0.1';
  List<String> _history = [];
  int _historyPosition = 0;
  Map<String, Function> _cmds;
  Map<String, Function> _extCmds;

  GitnuTerminal() {
    _cmdLine = document.querySelector(kInputLine);
    _output = document.querySelector(kOutputRegion);
    _input = document.querySelector(kCmdLine);
    _containerDiv = document.querySelector(kContainer);
    _prompt = document.querySelector(kPrompt);

    // Prompt will need to be enabled by client.
    disablePrompt();

    // Capture focus if click is near input line.
    _cmdLine.onClick.listen((event) => _input.focus());

    // Trick: Always force text cursor to end of input line.
    _cmdLine.onClick.listen((event) => _input.value = _input.value);

    // Capture focus to input line on any key press that doesn't affect
    // screen position.
    window.onKeyDown.listen(focusCommandLine);

    // Handle up/down key presses for shell history and enter for new command.
    _cmdLine.onKeyDown.listen(historyHandler);
    _cmdLine.onKeyDown.listen(processNewCommand);

    // Handles pgUp, pgDown, end and home scrolling
    _containerDiv.onKeyDown.listen(positionHandler);

    // Ensures the terminal covers the correct height
    int bodyHeight = window.innerHeight;
    _containerDiv.style.maxHeight = "${bodyHeight - kTopMargin}px";
    _containerDiv.style.height = "${bodyHeight - kTopMargin}px";
  }

  /**
   * Window pull focus to command line, unless inputting a position command.
   */
  void focusCommandLine(KeyboardEvent event) {
    if (!StaticToolkit.isNavigateKey(event))
      _input.focus();
  }

  /**
   * Handles scrolling using pgUp, pgDown, end and home keys.
   */
  void positionHandler(KeyboardEvent event) {
    bool handled = true;
    switch (event.keyCode) {
      case PG_UP_KEY:
        _containerDiv.scrollByLines(-5);
        break;
      case PG_DOWN_KEY:
        _containerDiv.scrollByLines(5);
        break;
      case END_KEY:
        _cmdLine.scrollIntoView(ScrollAlignment.TOP);
        break;
      case HOME_KEY:
        _output.scrollIntoView(ScrollAlignment.TOP);
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
    _input.disabled = false;
    _prompt.innerHtml = "\$&gt;";
    _input.focus();
  }

  /**
   * Hides the prompt indicator and disables the input prompt.
   */
  void disablePrompt() {
    _input.disabled = true;
    _prompt.innerHtml = "";
  }

  /**
   * Handles command input
   * Dispatches a function call either to commandFromList(cmd, args)
   * or commandFromExternalList(cmd, ouputWriter, args) where appropriate.
   */
  void processNewCommand(KeyboardEvent event) {
    if (event.keyCode == TAB_KEY) {
      event.preventDefault();
    } else if (event.keyCode == ENTER_KEY) {
      if (!_input.value.isEmpty) {
        _history.add(_input.value);
        _historyPosition = _history.length;
      }

      // Move the line to output and remove id's.
      DivElement line = _input.parent.parent.clone(true);
      line.attributes.remove('id');
      line.classes.add('line');
      InputElement cmdInput = line.querySelector(kCmdLine);
      cmdInput.attributes.remove('id');
      cmdInput.autofocus = false;
      cmdInput.readOnly = true;
      _output.children.add(line);
      String cmdline = _input.value;
      _input.value = ""; // clear input
      disablePrompt();

      runCommand(cmdline).whenComplete(() {
        enablePrompt();
        _cmdLine.scrollIntoView(ScrollAlignment.TOP);
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
            onError: (e) => writeOutput('$cmd error: $e'));
      }

      if (!cmd.isEmpty)
        writeOutput('${StaticToolkit.htmlEscape(cmd)}: command not found');
    }).catchError((e) => writeOutput('error: $e'));
  }

  /**
   * Handles commands entered previously and redisplaying them in the input
   * field when the up and down arrows are used.
   */
  void historyHandler(KeyboardEvent event) {
    if (event.keyCode == UP_ARROW_KEY || event.keyCode == DOWN_ARROW_KEY) {
      event.preventDefault();
      if (_historyPosition < _history.length)
        _history[_historyPosition] = _input.value;
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
        _input.value = "";
      else if (_history.length != 0 && _history[_historyPosition] != null)
        _input.value = _history[_historyPosition];
    }
  }

  /**
   * Establishes commands that can be called from the terminal and prints a
   * welcome note. Accepts a map of user commands to be called.
   */
  void initialiseCommands(Map<String, Function> commandList) {
    _cmds = {
      'clear': clearCommand,
      'help': helpCommand,
      'version': versionCommand,
      'date': dateCommand,
      'who': whoCommand
    };
    // User added commands
    _cmds.addAll(commandList);

    // Somewhat importantly, print out a welcome header.
    // Headers are slightly mangled below due to escaped characters.
    var rng = new Random();
    int choice = rng.nextInt(3);

    if (choice == 0) {
      writeOutput('<pre class="logo">'
        '           ######   #### ######## ##    ## ##     ## <br>'
        '          ##    ##   ##     ##    ###   ## ##     ## <br>'
        '          ##         ##     ##    ####  ## ##     ## <br>'
        '          ##   ####  ##     ##    ## ## ## ##     ## <br>'
        '          ##    ##   ##     ##    ##  #### ##     ## <br>'
        '          ##    ##   ##     ##    ##   ### ##     ## <br>'
        '           ######   ####    ##    ##    ##  #######  </pre>');
    } else if (choice == 1) {
      writeOutput('<pre class="logo">'
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
      writeOutput('<pre class="logo">'
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
      writeOutput('<pre class="logo">'
      '         _/_/_/  _/    _/                        <br>'
      '      _/            _/_/_/_/  _/_/_/    _/    _/ <br>'
      '     _/  _/_/  _/    _/      _/    _/  _/    _/  <br>'
      '    _/    _/  _/    _/      _/    _/  _/    _/   <br>'
      '     _/_/_/  _/      _/_/  _/    _/    _/_/_/    '
      '</pre>');
    }

    writeOutput('<div>Welcome to Gitnu! (v$_version)</div>');
    writeOutput(new DateTime.now().toLocal().toString());
    writeOutput('<p>Documentation: type "help"</p>');
  }

  /**
   * Writes to output element and then scrolls into view of the scrollTo
   * element.
   */
  void writeOutput(String h) {
    _output.insertAdjacentHtml('beforeEnd', h);
    _cmdLine.scrollIntoView(ScrollAlignment.TOP);
  }

  /**
   * Basic inbuilt commands.
   * User function invariant (except help... builds off user functions).
   */
  void clearCommand(List<String> args) {
    _output.innerHtml = '';
  }

  void helpCommand(List<String> args) {
    StringBuffer sb = new StringBuffer();
    sb.write('<div class="ls-files">');
    _cmds.keys.forEach((key) => sb.write('$key<br>'));
    sb.write('</div>');
    writeOutput(sb.toString());
  }

  void versionCommand(List<String> args) {
    writeOutput("$_version");
  }

  void dateCommand(List<String> args) {
    writeOutput(new DateTime.now().toLocal().toString());
  }

  void whoCommand(List<String> args) {
    writeOutput('${StaticToolkit.htmlEscape(document.title)}<br>'
        'Basic terminal implementation - By:  Eric Bidelman '
        '&lt;ericbidelman@chromium.org&gt;, Adam Singer '
        '&lt;financeCoding@gmail.com&gt;<br>Adapted by Cameron Fitzgerald '
        '&lt;camfitz@google.com|camandco@gmail.com&gt; for Git / advanced '
        'features.');
  }
}
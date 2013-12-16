library GitnuTerminal;

import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'statictoolkit.dart';

class GitnuTerminal {
  String cmdLineContainer;
  String outputContainer;
  String cmdLineInput;
  String container;
  OutputElement output;
  InputElement input;
  DivElement cmdLine;
  DivElement containerDiv;
  String version = '0.0.1';
  List<String> history = [];
  int historyPosition = 0;
  Map<String, Function> cmds;
  Map<String, Function> extCmds;
  
  GitnuTerminal(this.cmdLineContainer, this.outputContainer, this.cmdLineInput, this.container) {
    cmdLine = document.querySelector(cmdLineContainer);
    output = document.querySelector(outputContainer);
    input = document.querySelector(cmdLineInput);
    containerDiv = document.querySelector(container);
    
    // Always force text cursor to end of input line.
    window.onClick.listen((event) => cmdLine.focus());

    // Trick: Always force text cursor to end of input line.
    cmdLine.onClick.listen((event) => input.value = input.value);

    // Handle up/down key presses for shell history and enter for new command.
    cmdLine.onKeyDown.listen(historyHandler);
    cmdLine.onKeyDown.listen(processNewCommand);
    
    // Handles pgUp, pgDown, end and home scrolling
    containerDiv.onKeyDown.listen(positionHandler);
    
    // Ensures the terminal covers the correct height
    int topMargin = 54;
    int bodyHeight = window.innerHeight; 
    containerDiv.style.maxHeight = "${bodyHeight - topMargin}px";
    containerDiv.style.height = "${bodyHeight - topMargin}px";
    
  }
  
  /**
   * Handles scrolling using pgUp, pgDown, end and home keys.
   */
  void positionHandler(KeyboardEvent event) { 
    const int pgDownKey = 34;
    const int pgUpKey = 33;
    const int endKey = 35;
    const int homeKey = 36;  
    
    if (event.keyCode == pgDownKey || event.keyCode == pgUpKey ||
        event.keyCode == endKey || event.keyCode == homeKey) {
      event.preventDefault();
      switch(event.keyCode) {
        case pgUpKey:
          containerDiv.scrollByLines(-5);
          break;
        case pgDownKey:
          containerDiv.scrollByLines(5);
          break;
        case endKey:
          cmdLine.scrollIntoView(ScrollAlignment.TOP);
          break;
        case homeKey:
          output.scrollIntoView(ScrollAlignment.TOP);
          break;
      }
    }
  }
  
  /**
   * Handles command input
   * Dispatches a function call either to commandFromList(cmd, args)
   * or commandFromExternalList(cmd, ouputWriter, args) where appropriate.
   */
  void processNewCommand(KeyboardEvent event) {
    int enterKey = 13;
    int tabKey = 9;

    if (event.keyCode == tabKey) {
      event.preventDefault();
    } else if (event.keyCode == enterKey) {
      if (!input.value.isEmpty) {
        history.add(input.value);
        historyPosition = history.length;
      }
      
      // Move the line to output and remove id's.
      DivElement line = input.parent.parent.clone(true);
      line.attributes.remove('id');
      line.classes.add('line');
      InputElement cmdInput = line.querySelector(cmdLineInput);
      cmdInput.attributes.remove('id');
      cmdInput.autofocus = false;
      cmdInput.readOnly = true;
      output.children.add(line);
      String cmdline = input.value;
      input.value = ""; // clear input

      // Parse out command, args, and trim off whitespace.
      List<String> args;
      String cmd = "";
      if (!cmdline.isEmpty) {
        cmdline.trim();
        args = StaticToolkit.htmlEscape(cmdline).split(' ');
        cmd = args[0];
        args.removeRange(0, 1);
      }
      
      // Function look up
      if (cmds[cmd] is Function) {
        cmds[cmd](cmd, args);
      } else if(extCmds[cmd] is Function) {
        // Pass our output writing function to the parent function.
        extCmds[cmd](cmd, this.writeOutput, args);
      } else {
        writeOutput('${StaticToolkit.htmlEscape(cmd)}: command not found');
      }

      window.scrollTo(0, window.innerHeight);
      
      // Ensures scrolls to prompt line even if no output recorded.
      cmdLine.scrollIntoView(ScrollAlignment.TOP);
    }
  }
  
  /**
   * Handles commands entered previously and redisplaying them in the input field
   * when the up and down arrows are used.
   */
  void historyHandler(KeyboardEvent event) {
    var histtemp = "";
    int upArrowKey = 38;
    int downArrowKey = 40;

    /* keyCode == up-arrow || keyCode == down-arrow */
    if (event.keyCode == upArrowKey || event.keyCode == downArrowKey) {
      event.preventDefault();

      // Up or down
      if (historyPosition < history.length) {
        history[historyPosition] = input.value;
      } else {
        histtemp = input.value;
      }
    }

    if (event.keyCode == upArrowKey) { // Up-arrow keyCode
      historyPosition--;
      if (historyPosition < 0) {
        historyPosition = 0;
      }
    } else if (event.keyCode == downArrowKey) { // Down-arrow keyCode
      historyPosition++;
      if (historyPosition >= history.length) {
        historyPosition = history.length - 1;
      }
    }

    /* keyCode == up-arrow || keyCode == down-arrow */
    if (event.keyCode == upArrowKey || event.keyCode == downArrowKey) {
      // Up or down
      input.value = history[historyPosition] != null ? history[historyPosition]  : histtemp;
    }
  }
  
  /**
   * Establishes commands that can be called from the terminal and prints a welcome note.
   * Accepts a map of user commands to be called.
   */
  void initialiseCommands(Map<String, Function> commandList) {    
    cmds = {
      'clear': clearCommand,
      'help': helpCommand,
      'version': versionCommand,
      'date': dateCommand,
      'who': whoCommand
    };
    
    // User added commands
    extCmds = commandList;
    
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
      ' \\  \\:\\ /~~/:/  \\  \\:\\//__/:/\\:\\  \\:\\~~\\~~\\\\  \\:\\ /  /:/ <br>'
      '  \\  \\:\\  /:/    \\__\\::\\__\\/  \\:\\  \\:\\  ~~~ \\  \\:\\  /:/  <br>'
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
    
    writeOutput('<div>Welcome to ${StaticToolkit.htmlEscape(document.title)}! (v$version)</div>');
    writeOutput(new DateTime.now().toLocal().toString());
    writeOutput('<p>Documentation: type "help"</p>');
    
    writeOutput('<p>Initialise a root directory to begin.</p>');
  }
  
  /**
   * Wraps around the StaticToolkit writer function as we have access to the output stream
   * and cmdLine element here.
   */
  void writeOutput(String h) {
    StaticToolkit.writeOutput(h, output, cmdLine);
  }
  
  /**
   * Basic inbuilt commands.
   * User function invariant (except help... builds off user functions).
   */
  void clearCommand(String cmd, List<String> args) {
    output.innerHtml = '';
  }
  
  void helpCommand(String cmd, List<String> args) {
    StringBuffer sb = new StringBuffer();
    sb.write('<div class="ls-files">');
    cmds.keys.forEach((key) => sb.write('$key<br>'));
    extCmds.keys.forEach((key) => sb.write('$key<br>'));
    sb.write('</div>');
    writeOutput(sb.toString());
  }

  void versionCommand(String cmd, List<String> args) {
    writeOutput("$version");
  }
  
  void dateCommand(String cmd, var args) {
    writeOutput(new DateTime.now().toLocal().toString());
  }
  
  void whoCommand(String cmd, List<String> args) {
    writeOutput('${StaticToolkit.htmlEscape(document.title)}<br>'
                'Basic terminal implementation - By:  Eric Bidelman '
                '${StaticToolkit.htmlEscape("<ericbidelman@chromium.org>")}, Adam Singer '
                '${StaticToolkit.htmlEscape("<financeCoding@gmail.com>")}<br>Adapted by Cameron Fitzgerald '
                '${StaticToolkit.htmlEscape("<camfitz@google.com|camandco@gmail.com>")} for Git / advanced '
                'features.');
  }
}
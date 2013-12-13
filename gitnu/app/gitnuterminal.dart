part of terminal_filesystem;

class GitnuTerminal extends Terminal {
  DirectoryEntry root;
  
  GitnuTerminal(String cmdLineContainer, String outputContainer, String cmdLineInput, String container) : 
    super(cmdLineContainer, outputContainer, cmdLineInput, container) {
    // Check if we set a rootFolder in a previous use of the app.
    chrome.storage.local.get('rootFolder').then((items) {
      chrome.fileSystem.isRestorable(items["rootFolder"]).then((value) {
        if(value == true) {
          window.console.debug("Restoring saved root folder."); 
          
          chrome.fileSystem.restoreEntry(items["rootFolder"]).then((theRoot) {
            this.root = theRoot;
            this.cwd = theRoot;
            
            // Display filePath 
            InputElement filePath = querySelector("#file_path");
            filePath.value = this.root.fullPath;   
          });
        } else {
          window.console.debug("No root folder to restore."); 
        }
      });
    });
    
    // Listen for button click to open directory
    InputElement chooseDirButton = document.querySelector('#choose_dir');  
    chooseDirButton.onClick.listen((_) { 
      openHandler("rootFolder");
    });
    
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
  
  /*
   * Opens a folder window allowing you to choose a folder.
   * Handler is returned, and the entry is retained in chrome.storage -> input storage name.
   */
  void openHandler(String storageName) {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_DIRECTORY);
    chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult res) {
      DirectoryEntry theEntry = res.entry;
      
      // use local storage to retain access to this file
      chrome.storage.local.set({storageName: chrome.fileSystem.retainEntry(theEntry)}).then((storageArea) {
        window.console.debug("Retained chosen folder- " + theEntry.fullPath + " as " + storageName);    
      });
      
      if(storageName == "rootFolder") {
        this.root = theEntry;
        
        // Change the current working directory as well.
        this.cwd = theEntry;
        
        // Display filePath 
        InputElement filePath = querySelector("#file_path");
        filePath.value = this.root.fullPath;    
      }
    });
  }
  
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
        args = htmlEscape(cmdline).split(' ');
        cmd = args[0];
        args.removeRange(0, 1);
      }

      // Function look up
      if (cmds[cmd] is Function) {
        cmds[cmd](cmd, args);
      } else  {
        writeOutput('${htmlEscape(cmd)}: command not found');
      }

      window.scrollTo(0, window.innerHeight);
      
      // Ensures scrolls to prompt line even if no output recorded.
      cmdLine.scrollIntoView(ScrollAlignment.TOP);
    }
  }
  
  void initializeFilesystem(bool persistent, int size) {
    cmds = {
      'clear': clearCommand,
      'help': helpCommand,
      'version': versionCommand,
      'cat': catCommand,
      'cd': cdCommand,
      'date': dateCommand,
      'ls': lsCommand,
      'mkdir': mkdirCommand,
      'mv': mvCommand,
      'cp': cpCommand,
      'open': openCommand,
      'pwd': pwdCommand,
      'rm': rmCommand,
      'rmdir': rmdirCommand,
      'theme': themeCommand,
      'who': whoCommand
    };

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
      '    |  |  .-----..---.     :_ _:   |  _( )_\\  |\'   ( \.-.| <br>'
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
    
    writeOutput('<div>Welcome to ${htmlEscape(document.title)}! (v$version)</div>');
    writeOutput(new DateTime.now().toLocal().toString());
    writeOutput('<p>Documentation: type "help"</p>');
    
    writeOutput('<p>Initialise a root directory to begin.</p>');
    
    // Not necessary as we now initalise the FileSystem access by having the user choose
    // a directory and treat that as the "root".
    //window.requestFileSystem(size, persistent: persistent)
    //.then(filesystemCallback, onError: errorHandler);
  }
  
  /**
   * Simplied to use columns and roughly calculate the number of columns possible
   */
  StringBuffer formatColumns(List<Entry> entries) {
    var maxName = entries[0].name;
    entries.forEach((entry) {
      if (entry.name.length > maxName.length) {
        maxName = entry.name;
      }
    });

    StringBuffer sb = new StringBuffer();

    // Max column width required
    var emWidth = maxName.length * 14;
    
    int colCount = 3;
    if(emWidth > window.innerWidth ~/ 2) {
      colCount = 1;
    } else if(emWidth > window.innerWidth ~/ 3) {
      colCount = 2;
    }
    
    sb.write('<div class="ls-files" style="-webkit-column-count: $colCount;">');
    return sb;
  }
  
  /**
   * Added sorting of entries.
   */
  void lsCommand(String cmd, List<String> args) {
    void displayFiles(List<Entry> entry) {
      if (entry.length != 0) {
        StringBuffer html = formatColumns(entry);
        entry.forEach((file) {
          var fileType = file.isDirectory ? 'folder' : 'file';
          var span = '<span class="$fileType">${htmlEscape(file.name)}</span><br>';
          html.write(span);
        });

        html.write('</div>');
        writeOutput(html.toString());
      }
    };

    // Read contents of current working directory. According to spec, need to
    // keep calling readEntries() until length of result array is 0. We're
    // guaranteed the same entry won't be returned again.
    List<Entry> entries = [];
    DirectoryReader reader = cwd.createReader();

    void readEntries() {
      reader.readEntries()
      .then((List<Entry> results) {
        if (results.length == 0) {
          entries.sort((a, b) => a.name.compareTo(b.name));
          displayFiles(entries);
        } else {
          entries.addAll(results);
          readEntries();
        }
      }, onError: errorHandler);
    };

    readEntries();
  }
  
  /**
   * Added my sign-off.
   */
  void whoCommand(String cmd, List<String> args) {
    writeOutput('${htmlEscape(document.title)}<br>'
                'Basic terminal implementation - By:  Eric Bidelman '
                '${htmlEscape("<ericbidelman@chromium.org>")}, Adam Singer '
                '${htmlEscape("<financeCoding@gmail.com>")}<br>Adapted by Cameron Fitzgerald '
                '${htmlEscape("<camfitz@google.com|camandco@gmail.com>")} for Git / advanced features.');
  }
  
  void writeOutput(String h) {
    output.insertAdjacentHtml('beforeEnd', h);  
    // Scrolls screen to ensure input is in view.
    cmdLine.scrollIntoView(ScrollAlignment.TOP);
  }
}
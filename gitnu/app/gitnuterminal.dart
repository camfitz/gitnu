part of terminal_filesystem;

class GitnuTerminal extends Terminal {
  //FileHandlers fileHandler;
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
    
    // Archived.
    //containerDiv.onKeyDown.listen(positionHandler);
    
    int topMargin = 54;
    int bodyHeight = window.innerHeight;
    
    window.console.debug("${bodyHeight} ${topMargin}");
    
    containerDiv.style.maxHeight = "${bodyHeight - topMargin}px";
    containerDiv.style.height = "${bodyHeight - topMargin}px";
    
    window.console.debug("constructor");
  }
  
  /*
   * Now fails with scrolling window setup
   void positionHandler(KeyboardEvent event) {
    int pgDownKey = 34;
    int pgUpKey = 33;
    int endKey = 35;
    int homeKey = 36;  
    
    if (event.keyCode == pgDownKey || event.keyCode == pgUpKey ||
        event.keyCode == endKey || event.keyCode == homeKey) {
      event.preventDefault();
      
      int offsetIncrement = 40;
      int topMargin = 54;
      
      // Calculates maximum offset.
      int height = querySelector("body").clientHeight - topMargin - containerDiv.clientHeight;
      
      // Only allows key based scrolling if there is more content than screen space.
      if(height < 0) {
        if (event.keyCode == pgUpKey) {
          offset = offset + offsetIncrement >= 0 ? 0 : offset + offsetIncrement;
          containerDiv.style.top = "${offset}px";
          containerDiv.style.bottom = "auto";
        } else if(event.keyCode == pgDownKey) {
          offset = offset - offsetIncrement <= height ? height : offset - offsetIncrement;
          containerDiv.style.top = "${offset}px";
          containerDiv.style.bottom = "auto";
        } else if(event.keyCode == endKey) {
          offsetBase = "top";
          containerDiv.style.top = "${height}px";
          offset = height;
        } else if(event.keyCode == homeKey) {
          offsetBase = "top";
          containerDiv.style.top = "0px";
          offset = 0;
        }
      }
      
      
    }
  }*/
  
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

    writeOutput('<div>Welcome to ${htmlEscape(document.title)}! (v$version)</div>');
    writeOutput(new DateTime.now().toLocal().toString());
    writeOutput('<p>Documentation: type "help"</p>');
    
    writeOutput('<p>Initialise a root directory to begin.</p>');
    
    // Not necessary as we now initalise the FileSystem access by having the user choose
    // a directory and treat that as the "root".
    //window.requestFileSystem(size, persistent: persistent)
    //.then(filesystemCallback, onError: errorHandler);
  }
  
  void whoCommand(String cmd, List<String> args) {
    writeOutput('${htmlEscape(document.title)}<br>'
                'Basic terminal implementation - By:  Eric Bidelman '
                '${htmlEscape("<ericbidelman@chromium.org>")}, Adam Singer '
                '${htmlEscape("<financeCoding@gmail.com>")}<br>Adapted by Cameron Fitzgerald '
                '${htmlEscape("<camfitz@google.com|camandco@gmail.com>")} for Git / advanced features.');
  }
}
library GitnuFileSystem;

import 'dart:html';
import 'dart:async';
import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'statictoolkit.dart';

class GitnuFileSystem {
  DirectoryEntry root;
  DirectoryEntry cwd;
  
  GitnuFileSystem(String displayFilePath) {
    // Check if we set a rootFolder in a previous use of the app.
    chrome.storage.local.get('rootFolder').then((items) {
      chrome.fileSystem.isRestorable(items["rootFolder"]).then((value) {
        if(value == true) {
          window.console.debug("Restoring saved root folder."); 
          
          chrome.fileSystem.restoreEntry(items["rootFolder"]).then((theRoot) {
            this.root = theRoot;
            this.cwd = theRoot;
            
            window.console.debug("${this.cwd.toString()} ${this.cwd.fullPath}");
            
            // Display filePath 
            InputElement filePath = querySelector(displayFilePath);
            filePath.value = this.root.fullPath;
          });
        } else {
          window.console.debug("No root folder to restore."); 
        }
      });
    });
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
  
  void invalidOpForEntryType(FileError error, String cmd, String dest, Function display) {
    switch (error.code) {
      case FileError.NOT_FOUND_ERR:
        display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(dest)}: No such file or directory<br>');
        break;
      case FileError.INVALID_STATE_ERR:
        display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(dest)}: Not a directory<br>');
        break;
      case FileError.INVALID_MODIFICATION_ERR:
        display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(dest)}: File already exists<br>');
        break;
      default:
        errorHandler(error);
        break;
    }
  }
  
  void read(String cmd, String path, Function display, var callback) {
    cwd.getFile(path).then((FileEntry fileEntry) {
      fileEntry.file().then((file) {
        var reader = new FileReader();
        reader.onLoadEnd.listen((ProgressEvent event) => callback(reader.result));
        reader.readAsText(file);
      }, onError: errorHandler);
    }, onError: (error) {
      if (error.code == FileError.INVALID_STATE_ERR) {
        display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(path)}): is a directory<br>');
      } else if (error.code == FileError.NOT_FOUND_ERR) {
        display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(path)}: No such file or directory<br>');
      } else {
        errorHandler(error);
      }
    });
  }
  
  void errorHandler(error) {
    var msg = '';
    switch (error.code) {
      case FileError.QUOTA_EXCEEDED_ERR:
        msg = 'QUOTA_EXCEEDED_ERR';
        break;
      case FileError.NOT_FOUND_ERR:
        msg = 'NOT_FOUND_ERR';
        break;
      case FileError.SECURITY_ERR:
        msg = 'SECURITY_ERR';
        break;
      case FileError.INVALID_MODIFICATION_ERR:
        msg = 'INVALID_MODIFICATION_ERR';
        break;
      case FileError.INVALID_STATE_ERR:
        msg = 'INVALID_STATE_ERR';
        break;
      case FileError.TYPE_MISMATCH_ERR:
        msg = 'TYPE_MISMATCH_ERR';
        break;
      default:
        msg = 'FileError = ${error.code}: Error not handled';
        break;
    };
    // Need to work out how best to output errors!
    window.console.debug('Error: ${StaticToolkit.htmlEscape(msg)}');
  }
  
  void catCommand(String cmd, List<String> args, Function display) {
    if (args.length >= 1) {
      var fileName = args[0];
      read(cmd, fileName, display, (result) => display('<pre>${StaticToolkit.htmlEscape(result)}</pre>'));
    } else {
      display('usage: ${StaticToolkit.htmlEscape(cmd)} filename');
    }
  }
  
  /**
   * cd calls this.
   */
  void changeDirectory(List<String> args, Function display) {
    var dest = args.join(' ').trim();
    if(dest.isEmpty) {
      dest = '/';
    }
    
    cwd.getDirectory(dest)
      .then((DirectoryEntry dirEntry) {
        cwd = dirEntry;
        display(dirEntry.fullPath);
      }, onError: (FileError error) {
        invalidOpForEntryType(error, "cd", dest, display);
      });
  }

  /**
   * ls calls this.
   * Why the looped call?
   * https://developer.mozilla.org/en-US/docs/Web/API/DirectoryReader
   */
  void listDirectory(List<String> args, Function display) {
    List<Entry> entries = [];
    DirectoryReader reader = cwd.createReader();
    
    void readEntries() {
      reader.readEntries().then((List<Entry> results) {
        if (results.length == 0) {
          entries.sort((a, b) => a.name.compareTo(b.name));
          display(entries);
        } else {
          entries.addAll(results);
          window.console.debug("readEntries call");
          readEntries();
        }
      }, onError: errorHandler);
    };
    
    readEntries();
  }
  
  void createDir(DirectoryEntry rootDirEntry, List<String> folders, Function display, [String createFromDir="", String cmd=""]) {
    if (folders.length == 0) {
      return;
    }

    if (createFromDir.isEmpty) {
      rootDirEntry.createDirectory(folders[0])
      .then((dirEntry) {
        // Recursively add the new subfolder if we still have a subfolder to create.
        if (folders.length != 0) {
          folders.removeAt(0);
          createDir(dirEntry, folders, display);
        }
      }, onError: errorHandler);
    } else {
      var fullPath = cwd.fullPath;
      cwd.getDirectory(createFromDir)
      .then((DirectoryEntry dirEntry) {
        cwd = dirEntry;
        // Create the folders
        createDir(cwd, folders, display);

        cwd.getDirectory(fullPath)
        .then((DirectoryEntry dirEntry) => cwd = dirEntry,
        onError: (FileError error) => invalidOpForEntryType(error, cmd, fullPath, display));
      }, onError: (FileError error) => invalidOpForEntryType(error, cmd, createFromDir, display));
    }
  }

  void mkdirCommand(List<String> args, Function display) {
    var dashP = false;
    var index = args.indexOf('-p');
    if (index != -1) {
      args.removeAt(index);
      dashP = true;
    }

    if (args.length == 0) {
      display('usage: mkdir [-p] directory<br>');
      return;
    }

    // Create each directory passed as an argument.
    for (int i = 0; i < args.length; i++) {
      String dirName = args[i];

      if (dashP) {
        var folders = dirName.split('/');
        // Throw out './' or '/' if present on the beginning of our path.
        if (folders[0] == '.' || folders[0] == '') {
          folders.removeAt(0);
        }

        // If '/' is present then we change directories in createDir.
        if (dirName[0] == "/") {
          createDir(cwd, folders, display, dirName[0], "mkdir");
        } else {
          createDir(cwd, folders, display);
        }
      } else {
        cwd.createDirectory(dirName, exclusive: true)
        .then((_) {}, onError: (FileError error) {
          invalidOpForEntryType(error, "mkdir", dirName, display);
        });
      }
    }
  }

  void updateFilename(String cmd, List<String> args, Function display, Function action) {
    if (args.length != 2) {
      display('usage: ${StaticToolkit.htmlEscape(cmd)} source target<br>'
                  '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;${StaticToolkit.htmlEscape(cmd)}'
                  ' source directory/');
      return;
    }

    String src = args[0];
    String dest = args[1];

    // Moving to a folder? (e.g. second arg ends in '/').
    if (dest[dest.length - 1].endsWith('/')) {
      cwd.getDirectory(src)
      .then((DirectoryEntry srcDirEntry) {
            // Create blacklist for dirs we can't re-create.
            var create = ['.', './', '..', '../', '/'].indexOf(dest) != -1 ? false : true;

            if (create) {
              cwd.createDirectory(dest)
              .then((DirectoryEntry destDirEntry) => action(srcDirEntry, destDirEntry),
              onError: errorHandler);
            } else {
              cwd.getDirectory(dest)
              .then((DirectoryEntry destDirEntry) => action(srcDirEntry, destDirEntry),
              onError: errorHandler);
            }
          }, onError: errorHandler);
    } else {
      // Treat src/destination as files.
      cwd.getFile(src).then((FileEntry srcFileEntry) {
            srcFileEntry.getParent()
            .then((DirectoryEntry parentDirEntry) => action(srcFileEntry, parentDirEntry, dest),
                onError: errorHandler);
          },
          onError: errorHandler);
    }
  }

  /**
   * [TODO]
   * mv and cp limitations:
   * Current directory only (not fully relative paths).
   * If dir copy, must include trailing slash.
   */
  void cpCommand(String cmd, List<String> args, Function display) {
    void copyTo(srcDirEntry, destDirEntry, [name = ""]) {
      if (name.isEmpty) {
        srcDirEntry.copyTo(destDirEntry);
      } else {
        srcDirEntry.copyTo(destDirEntry, name);
      }
    };
    
    updateFilename(cmd, args, display, copyTo);
  }

  void mvCommand(String cmd, List<String> args, Function display) {
    void moveTo(srcDirEntry, destDirEntry, [name = ""]) {
      if (name.isEmpty) {
        srcDirEntry.moveTo(destDirEntry);
      } else {
        srcDirEntry.moveTo(destDirEntry, name);
      }
    };
    
    window.console.debug("here2");
    updateFilename(cmd, args, display, moveTo);
  }

  void openCommand(String cmd, List<String> args, Function display) {
    //var fileName = Strings.join(args, ' ').trim();
    if (args.length == 0) {
      display('usage: ${StaticToolkit.htmlEscape(cmd)} [filenames]');
      return;
    } else {
      display('Implementation of open is not yet working.');
      return;  
    }

    void openWindow(String fileName, String url) {
      window.console.debug("lel $url $fileName");
      window.open(url, fileName);
    }
    
    args.forEach((fileName) {
      open(cmd, fileName, display, openWindow);
    });
  }

  void open(String cmd, String path, Function display, Function successCallback) {
    cwd.getFile(path).then((FileEntry fileEntry) {
      window.console.debug('lolol ${fileEntry.toString()} ${cwd.fullPath} ${fileEntry.toUrl()}');
      successCallback(path, fileEntry.toUrl());
    }, onError: (error) {
          if (error.code == FileError.NOT_FOUND_ERR) {
            display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(path)}: '
                    'No such file or directory<br>');
          } else {
            errorHandler(error);
          }
        });
  }

  void printDirectory(Function display) {
    display(StaticToolkit.htmlEscape(cwd.fullPath));
  }

  void rmCommand(String cmd, List<String> args, Function display) {
    // Remove recursively? If so, remove the flag(s) from the arg list.
    var recursive = false;
    var switches = ['-r', '-f', '-rf', '-fr'];
    switches.forEach((sw) {
      var index = args.indexOf(sw);
      if (index != -1) {
        while (index != -1) {
          args.removeAt(index);
          index = args.indexOf(sw);
        }
        recursive = true;
      }
    });

    args.forEach((fileName) {
      cwd.getFile(fileName).then((fileEntry) {
            fileEntry.remove().then((_) {}, onError: errorHandler);
          },
          onError: (error) {
            if (recursive && error.code == FileError.TYPE_MISMATCH_ERR) {
              cwd.getDirectory(fileName)
              .then((DirectoryEntry dirEntry) => dirEntry.removeRecursively().then((_) {}, onError: errorHandler),
                  onError: errorHandler);
            } else if (error.code == FileError.INVALID_STATE_ERR) {
              display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(fileName)}: is a directory<br>');
            } else {
              errorHandler(error);
            }
          });
    });
  }

  void rmdirCommand(String cmd, List<String> args, Function display) {
    args.forEach((dirName) {
      cwd.getDirectory(dirName)
      .then((dirEntry) {
            dirEntry.remove().then((_) {}, onError: (error) {
              if (error.code == FileError.INVALID_MODIFICATION_ERR) {
                display('${StaticToolkit.htmlEscape(cmd)}: ${StaticToolkit.htmlEscape(dirName)}: Directory not empty<br>');
              } else {
                errorHandler(error);
              }
            });
          },
          onError: (error) => invalidOpForEntryType(error, cmd, dirName, display));
    });
  }
}
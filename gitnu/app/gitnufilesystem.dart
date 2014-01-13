library GitnuFileSystem;

import 'dart:html';
import 'dart:async';
import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'statictoolkit.dart';
import 'gitnuoutput.dart';

/**
 * A state based class providing terminal-like file system operations.
 * Class variables: root directory and current working directory.
 */
class GitnuFileSystem {
  // Root directory accessible by the program.
  DirectoryEntry _root;

  // Current working directory about which operations are based.
  DirectoryEntry _cwd;

  // Instance or implementation of GitnuOutput class, permitting print
  // operations
  GitnuOutput _gitnuOutput;

  // Local storage key for the root folder.
  final String kRootFolder = "rootFolder";

  GitnuFileSystem(String displayFilePath, this._gitnuOutput) {
    // Check if we set a rootFolder in a previous use of the app.
    chrome.storage.local.get(kRootFolder).then((items) {
      chrome.fileSystem.isRestorable(items[kRootFolder]).then((value) {
        if (value) {
          window.console.debug("Restoring saved root folder.");

          chrome.fileSystem.restoreEntry(items[kRootFolder]).then((root) {
            setRoot(root);

            // Display filePath
            InputElement filePath = querySelector(displayFilePath);
            filePath.value = getRootString();
          });
        } else {
          window.console.debug("No root folder to restore.");
        }
      });
    });
  }

  /*
   * Shows a folder picker prompt, allowing the user to choose a new root /
   * other folder.
   * The entry is retained in chrome.storage.local, keyed by |storageName|,
   * and the callback is called, with the entry as a parameter.
   */
  void promptUserForFolderAccess(String storageName, Function callback) {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_DIRECTORY);
    chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult result) {
      DirectoryEntry entry = result.entry;

      // use local storage to retain access to this file
      chrome.storage.local.set(
          {storageName: chrome.fileSystem.retainEntry(entry)}).then(
        (_) => window.console.debug(
            "Retained chosen folder- ${entry.fullPath} as $storageName"));

      callback(entry);
    });
  }

  /**
   * Sets the input directory as the root directory entry.
   */
  void setRoot(DirectoryEntry root) {
    _root = root;
    _cwd = root;
  }

  String getCurrentDirectoryString() {
    return _cwd.fullPath;
  }

  DirectoryEntry getRoot() {
    return _root;
  }

  DirectoryEntry getCurrentDirectory() {
    return _cwd;
  }

  String getRootString() {
    return _root.fullPath;
  }

  void pwdCommand(List<String> args) {
    printDirectory();
  }
  
  void printDirectory() {
    _gitnuOutput.printLine(getCurrentDirectoryString());
  }

  GitnuOutput doOutput() {
    return _gitnuOutput;
  }

  void invalidOpForEntryType(FileError error, String cmd, String dest) {
    switch (error.code) {
      case FileError.NOT_FOUND_ERR:
        doOutput().printLine('${cmd}: ${dest}: No such file or directory');
        break;
      case FileError.INVALID_STATE_ERR:
        doOutput().printLine('${cmd}: ${dest}: Not a directory');
        break;
      case FileError.INVALID_MODIFICATION_ERR:
        doOutput().printLine('${cmd}: ${dest}: File already exists');
        break;
      default:
        errorHandler(error);
        break;
    }
  }

  /**
   * Reads a file - helper function for the cat command.
   * Passes read file to callback function.
   */
  void read(String cmd, String path, Function callback) {
    _cwd.getFile(path).then((FileEntry fileEntry) {
      fileEntry.file().then((file) {
        var reader = new FileReader();
        reader.onLoadEnd.listen((ProgressEvent event) =>
            callback(reader.result));
        reader.readAsText(file);
      }, onError: errorHandler);
    }, onError: (error) {
      if (error.code == FileError.INVALID_STATE_ERR) {
        doOutput().printLine('${cmd}: ${path}: is a directory');
      } else if (error.code == FileError.NOT_FOUND_ERR) {
        invalidOpForEntryType(error.code, cmd, path);
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
        msg = 'FileError = ${error.code}: Unknown error.';
        break;
    };
    doOutput().printLine('Error: ${msg}');
  }

  void catCommand(List<String> args) {
    if (args.length >= 1) {
      var fileName = args[0];
      read('cat', fileName, (result) {
        doOutput().printHtml('<pre>${StaticToolkit.htmlEscape(result)}</pre>');
      });
    } else {
      doOutput().printLine('usage: cat filename');
    }
  }

  void cdCommand(List<String> args) {
    var dest = args.join(' ').trim();
    if (dest.isEmpty) {
      dest = '/';
    }

    _cwd.getDirectory(dest).then((DirectoryEntry dirEntry) {
        _cwd = dirEntry;
        printDirectory();
      }, onError: (FileError error) {
        invalidOpForEntryType(error, "cd", dest);
      });
  }

  /**
   * Why the looped call?
   * https://developer.mozilla.org/en-US/docs/Web/API/DirectoryReader
   */
  void lsCommand(List<String> args) {
    List<Entry> entries = [];
    DirectoryReader reader = _cwd.createReader();

    void readEntries() {
      reader.readEntries().then((List<Entry> results) {
        if (results.length == 0) {
          entries.sort((a, b) => a.name.compareTo(b.name));
          doOutput().printColumns(entries);
        } else {
          entries.addAll(results);
          readEntries();
        }
      }, onError: errorHandler);
    };

    readEntries();
  }

  void createDirectory(DirectoryEntry rootDirEntry, List<String> folders) {
    if (folders.length == 0) {
      return;
    }
    rootDirEntry.createDirectory(folders[0]).then((dirEntry) {
      // Recursively add the new subfolder if we still have a subfolder to
      // create.
      if (folders.length != 0) {
        folders.removeAt(0);
        createDirectory(dirEntry, folders);
      }
    }, onError: errorHandler);
  }

  void mkdirCommand(List<String> args) {
    var dashP = false;
    var index = args.indexOf('-p');
    if (index != -1) {
      args.removeAt(index);
      dashP = true;
    }

    if (args.length == 0) {
      doOutput().printLine('usage: mkdir [-p] directory');
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
        createDirectory(_cwd, folders);
      } else {
        _cwd.createDirectory(dirName, exclusive: true).then(
            (_) {}, onError: (FileError error) {
            invalidOpForEntryType(error, "mkdir", dirName);
        });
      }
    }
  }

  void openCommand(List<String> args) {
    //var fileName = Strings.join(args, ' ').trim();
    if (args.length == 0) {
      doOutput().printLine('usage: open [filenames]');
      return;
    } else {
      doOutput().printLine('Implementation of open is not yet working.');
      return;
    }

    void openWindow(String fileName, String url) {
      window.open(url, fileName);
    }

    args.forEach((fileName) {
      open("open", fileName, openWindow);
    });
  }

  void open(String cmd, String path, Function successCallback) {
    _cwd.getFile(path).then((FileEntry fileEntry) {
      successCallback(path, fileEntry.toUrl());
    }, onError: (error) {
          if (error.code == FileError.NOT_FOUND_ERR) {
            doOutput().printLine('${cmd}: ${path}: No such file or directory');
          } else {
            errorHandler(error);
          }
        });
  }

  void rmCommand(List<String> args) {
    // Remove recursively? If so, remove the flag(s) from the arg list.
    List<String> switches = ['-r', '-rf', '-fr'];
    int originalLength = args.length;
    args.removeWhere((arg) => switches.contains(arg));
    bool recursive = args.length != originalLength;

    args.forEach((fileName) {
      _cwd.getFile(fileName).then((fileEntry) {
            fileEntry.remove().then((_) {}, onError: errorHandler);
          },
          onError: (error) {
            if (recursive && error.code == FileError.TYPE_MISMATCH_ERR) {
              _cwd.getDirectory(fileName)
              .then((DirectoryEntry dirEntry) =>
                  dirEntry.removeRecursively().then(
                    (_) {}, onError: errorHandler),
                    onError: errorHandler);
            } else if (error.code == FileError.INVALID_STATE_ERR) {
              doOutput().printLine('rm: ${fileName}: is a directory');
            } else {
              errorHandler(error);
            }
          });
    });
  }

  void rmdirCommand(List<String> args) {
    args.forEach((dirName) {
      _cwd.getDirectory(dirName).then((dirEntry) {
            dirEntry.remove().then((_) {}, onError: (error) {
              if (error.code == FileError.INVALID_MODIFICATION_ERR) {
                doOutput().printLine('rmdir: ${dirName}: Directory not empty');
              } else {
                errorHandler(error);
              }
            });
          },
          onError: (error) => invalidOpForEntryType(error, "rmdir", dirName));
    });
  }
}
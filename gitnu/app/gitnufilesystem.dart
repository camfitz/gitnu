library GitnuFileSystem;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'gitnuoutput.dart';
import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'statictoolkit.dart';

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
  GitnuOutput _output;

  GitnuFileSystem(this._output, this._root) {
    this._cwd = this._root;
  }

  String getCurrentDirectoryString() => _cwd.fullPath;

  DirectoryEntry getRoot() => _root;

  DirectoryEntry getCurrentDirectory() => _cwd;

  String getRootString() => _root.fullPath;

  Future pwdCommand(List<String> args) {
    printDirectory();
    return new Future.value();
  }

  void printDirectory() {
    _output.printLine(getCurrentDirectoryString());
  }

  Future listEntries([Function keepResults]) {
    List<Entry> entries = [];
    DirectoryReader reader = _cwd.createReader();
    Completer completer = new Completer();

    void readEntries() {
      reader.readEntries().then((List<Entry> results) {
        if (results.length == 0) {
          entries.sort((a, b) => a.name.compareTo(b.name));
          if (keepResults != null)
            entries.retainWhere(keepResults);
          completer.complete(entries);
        } else {
          entries.addAll(results);
          readEntries();
        }
      }, onError: (e) {
        completer.complete(null);
      });
    };

    readEntries();
    return completer.future;
  }

  Future<List<String>> tabCompleteDirectory(List<String> args) {
    return listEntries((Entry entry) => entry.isDirectory).then(
        (List<Entry> entries) => entries.map((Entry entry) => entry.name));
  }

  Future<List<String>> tabCompleteFile(List<String> args) {
    return listEntries((Entry entry) => entry.isFile).then(
        (List<Entry> entries) => entries.map((Entry entry) => entry.name));
  }

  /**
   * The file system API documentation (FileError deprecation doc:
   * https://developer.mozilla.org/en-US/docs/Web/API/FileError) says that
   * DomErrors will be thrown, but in fact JsObjects are. This function
   * retrieves the name of an error for either case.
   */
  String getErrorName(error) {
    if (error is JsObject)
      return error['name'];
    else
      return error.name;
  }

  void printFileError(error, String cmd, String path) {
    String name = getErrorName(error);
    switch (name) {
      case DomException.NOT_FOUND:
        _output.printLine('${cmd}: ${path}: No such file or directory');
        break;
      case DomException.INVALID_STATE:
        _output.printLine('${cmd}: ${path}: Not a directory');
        break;
      case DomException.INVALID_MODIFICATION:
        _output.printLine('${cmd}: ${path}: File already exists');
        break;
      default:
        printError(error);
        break;
    }
  }

  /**
   * Reads a file - helper function for the cat command.
   * Returns a future to be populated by a string representation of the file.
   * Throws FileError for an invalid file (doesn't not exist, is directory).
   */
  Future<String> read(String path) {
    return _cwd.getFile(path).then((chrome.ChromeFileEntry fileEntry) {
      return fileEntry.readText();
    });
  }

  void printError(error) {
    _output.printLine('Error: ${getErrorName(error)}');
  }

  Future catCommand(List<String> args) {
    if (args.length >= 1) {
      var fileName = args[0];
      return read(fileName).then((String result) {
        List<String> lines =
            "${StaticToolkit.htmlEscape(result)}".split("\n");
        StringBuffer numberedLines = new StringBuffer();
        for (int i = 0; i < lines.length; i++)
          numberedLines.write('${i+1}\r\n');

        _output.printHtml('''<table class="out"><tr>
                                <td class="line">
                                  <pre>${numberedLines.toString()}</pre></td>
                                <td class="file"><pre>$result</pre></td>
                              </tr></table>''');
      }, onError: (error) {
        String name = getErrorName(error);
        if (name == DomException.INVALID_STATE) {
          _output.printLine('cat: $fileName: is a directory');
        } else if (name == DomException.NOT_FOUND) {
          _output.printLine('cat: $fileName: no such file');
        } else {
          printError(error);
        }
        return new Future.value();
      });
    }
    _output.printLine('usage: cat filename');
    return new Future.value();
  }

  Future cdCommand(List<String> args) {
    var dest = args.join(' ').trim();
    if (dest.isEmpty) {
      _cwd = _root;
      printDirectory();
      return new Future.value();
    }

    return _cwd.getDirectory(dest).then((DirectoryEntry dirEntry) {
      _cwd = dirEntry;
      printDirectory();
    }, onError: (FileError error) => printFileError(error, "cd", dest));
  }

  /**
   * Why the looped call?
   * https://developer.mozilla.org/en-US/docs/Web/API/DirectoryReader
   */
  Future lsCommand(List<String> args) {
    return listEntries().then(_output.printEntryColumns);
  }

  Future createDirectory(DirectoryEntry rootDirEntry, List<String> folders) {
    if (folders.length == 0) {
      return new Future.value();
    }
    rootDirEntry.createDirectory(folders[0]).then((dirEntry) {
      // Recursively add the new subfolder if we still have a subfolder to
      // create.
      if (folders.length != 0) {
        folders.removeAt(0);
        createDirectory(dirEntry, folders);
      }
    }, onError: printError);
  }

  Future mkdirCommand(List<String> args) {
    var dashP = false;
    var index = args.indexOf('-p');
    if (index != -1) {
      args.removeAt(index);
      dashP = true;
    }

    if (args.length == 0) {
      _output.printLine('usage: mkdir [-p] directory');
      return new Future.value();
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
        return createDirectory(_cwd, folders);
      } else {
        return _cwd.createDirectory(dirName, exclusive: true).then(
            (_) => new Future.value(), onError: (FileError error) {
            printFileError(error, "mkdir", dirName);
            return new Future.value();
        });
      }
    }
  }

  Future openCommand(List<String> args) {
    //var fileName = Strings.join(args, ' ').trim();
    if (args.length == 0) {
      _output.printLine('usage: open [filenames]');
      return new Future.value();
    } else {
      _output.printLine('Implementation of open is not yet working.');
      return new Future.value();
    }

    void openWindow(String fileName, String url) {
      window.open(url, fileName);
    }

    args.forEach((fileName) {
      open("open", fileName, openWindow);
    });

    return new Future.value();
  }

  void open(String cmd, String path, Function successCallback) {
    _cwd.getFile(path).then((FileEntry fileEntry) {
      successCallback(path, fileEntry.toUrl());
    }, onError: (error) {
      String name = getErrorName(error);
      if (name == DomException.NOT_FOUND) {
        _output.printLine('${cmd}: ${path}: No such file or directory');
      } else {
        printError(error);
      }
    });
  }

  Future rmCommand(List<String> args) {
    // Remove recursively? If so, remove the flag(s) from the arg list.
    List<String> switches = ['-r', '-rf', '-fr'];
    int originalLength = args.length;
    args.removeWhere((arg) => switches.contains(arg));
    bool recursive = args.length != originalLength;

    args.forEach((fileName) {
      _cwd.getFile(fileName).then((fileEntry) {
            fileEntry.remove().then((_) {}, onError: printError);
          },
          onError: (error) {
            String name = getErrorName(error);
            if (recursive && name == DomException.TYPE_MISMATCH) {
              _cwd.getDirectory(fileName)
              .then((DirectoryEntry dirEntry) =>
                  dirEntry.removeRecursively().then(
                    (_) {}, onError: printError),
                    onError: printError);
            } else if (name == DomException.INVALID_STATE) {
              _output.printLine('rm: ${fileName}: is a directory');
            } else {
              printError(error);
            }
          });
    });

    return new Future.value();
  }

  Future rmdirCommand(List<String> args) {
    args.forEach((dirName) {
      _cwd.getDirectory(dirName).then((dirEntry) {
            dirEntry.remove().then((_) {}, onError: (error) {
              String name = getErrorName(error);
              if (name == DomException.INVALID_MODIFICATION) {
                _output.printLine('rmdir: ${dirName}: Directory not empty');
              } else {
                printError(error);
              }
            });
          },
          onError: (error) => printFileError(error, "rmdir", dirName));
    });

    return new Future.value();
  }
}
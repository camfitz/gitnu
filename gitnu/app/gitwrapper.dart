library gitnu;

import 'dart:async';
import 'dart:html';

import 'lib/spark/spark/ide/app/lib/git/options.dart';
import 'lib/spark/spark/ide/app/lib/git/git.dart';
import 'lib/spark/spark/ide/app/lib/git/objectstore.dart';

import 'lib/spark/spark/ide/app/lib/git/commands/clone.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/commit.dart';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'gitnuoutput.dart';
import 'gitnufilesystem.dart';

class GitWrapper {
  // Default options provided when running a Git command.
  GitOptions _defaultOptions;

  // Output class provided to print to the screen.
  GitnuOutput _gitnuOutput;

  // Store the FileSystem class so we now current folder location.
  GitnuFileSystem _fileSystem;

  // Map of Git specific command strings to functions.
  Map<String, Function> _cmds;

  // Holds the Git API object.
  Git git;

  // Local storage key names for reusable Git options.
  final String kNameStore = "gitName";
  final String kEmailStore = "gitEmail";

  GitWrapper(this._gitnuOutput, this._fileSystem) {
    window.console.debug("equals: ${_fileSystem.getRoot() == _fileSystem.getCurrentDirectory()}");

    _defaultOptions = new GitOptions();

    // Attempt to restore username and email options
    chrome.storage.local.get([kNameStore, kEmailStore]).then((items) {
      _defaultOptions.name = items[kNameStore];
      _defaultOptions.email = items[kEmailStore];
    });

    _cmds = {
        'clone': cloneWrapper,
        'commit': commitWrapper,
        'add': addWrapper,
        'push': pushWrapper,
        'pull': pullWrapper,
        'branch': branchWrapper,
        'help': helpWrapper,
        'repo': getRepo
    };

    git = new Git();
  }

  /**
   * Dispatches a received git command to its appropriate wrapper,
   * assuming the form
   * git args[0] args[1..n] = git command [args]
   */
  void gitDispatcher(List<String> args) {
    if(args.length > 0) {
      String gitOption = args.removeAt(0);
      if (_cmds[gitOption] is Function) {
        _cmds[gitOption](args);
      } else  {
        _gitnuOutput.printLine('git: \'$gitOption\' is not a git command.');
      }
    } else {
      helpWrapper(args);
    }
  }

  /**
   * Loads the ObjectStore associated with a Git repo for the current
   * directory. Returns null if the directory was not a Git directory.
   * Returns a future ObjectStore.
   */
  Future<ObjectStore> getRepo() {
    var completer = new Completer.sync();

    repoOp() {
      ObjectStore store = new ObjectStore(_fileSystem.getCurrentDirectory());
      _fileSystem.getCurrentDirectory().getDirectory(".git").then(
        (DirectoryEntry gitDir) {
          window.console.debug("Git directory!");
          store.load().then((value) {
            window.console.debug("Restored Git objectstore.");
            completer.complete(store);
          });
        }, onError: (e) {
          window.console.debug("Not a Git directory.");
          completer.complete(null);
        });
    }

    repoOp();
    return completer.future;
  }

  GitOptions buildOptions() {
    GitOptions custom = new GitOptions();

    // custom.root = _defaultOptions.root;
    // custom.username = _defaultOptions.username;
    // custom.password = _defaultOptions.password;
    // custom.repoUrl = _defaultOptions.repoUrl;
    // custom.branchName = _defaultOptions.branchName;
    // custom.store = _defaultOptions.store;
    custom.email = _defaultOptions.email;
    // custom.commitMessage = _defaultOptions.commitMessage;
    custom.name = _defaultOptions.name;
    // custom.depth = _defaultOptions.depth;
    custom.progressCallback = _defaultOptions.progressCallback;
  }

  /**
   * Allowable format:
   * git clone [options] [--] <repo>
   * Valid options:
   * --depth <int>
   * --branch <String>
   */
  void cloneWrapper(List<String> args) {
    GitOptions options = new GitOptions();

    if (args.length == 0) {
      _gitnuOutput.printLine("Error: no arguments passed to git clone.");
      return;
    }

    int depth = intSwitch(args, '--depth', -1);
    if (depth == null) {
      _gitnuOutput.printLine("Error: no option included with --depth.");
      return;
    } else if (depth > 0) {
      options.depth = depth;
    }

    String branch = stringSwitch(args, '--branch', "");
    if (branch == null) {
      _gitnuOutput.printLine("Error: no option included with --branch.");
      return;
    } else if (branch.length > 0) {
      options.branchName = branch;
    }

    if (args.length != 1) {
      // Throw an error for incorrect command line options
      _gitnuOutput.printLine("Error: no repo url passed to git clone.");
      return;
    }

    options.progressCallback = progressCallback;

    options.root = _fileSystem.getCurrentDirectory();
    options.repoUrl = args[0];
    options.store = new ObjectStore(_fileSystem.getCurrentDirectory());
    Clone clone = new Clone(options);
    options.store.init().then((_) {
      window.console.debug("Cloning...");
      _gitnuOutput.printLine("Cloning repo...");
      clone.clone().then((_) {
        window.console.debug("Cloned.");
        _gitnuOutput.printLine("Finished cloning repo.");
      });
    });
  }

  /**
   * Allowable format:
   * git commit [options] [--]
   * Valid options:
   * -m <string>
   * -a [assumed option as no staging area at this stage]
   * Additional options:
   * --email <string>
   * --name <string>
   */
  void commitWrapper(List<String> args) {
    getRepo().then((ObjectStore store) {
      if(store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return;
      } else {
        GitOptions options = new GitOptions();
        options.store = store;
        options.root = _fileSystem.getCurrentDirectory();

        options.commitMessage = stringSwitch(args, '-m', "");
        if (options.commitMessage == null) {
          _gitnuOutput.printLine("Error: no option included with -m.");
          return;
        }

        String email = stringSwitch(args, '--email', "");
        if (email == null) {
          _gitnuOutput.printLine("Error: no option included with --email.");
          return;
        } else if (email.length > 0) {
          options.email = email;
        } else if (options.email == null) {
          _gitnuOutput.printLine("Error: no email provided.");
          return;
        }

        String name = stringSwitch(args, '--name', "");
        if (name == null) {
          _gitnuOutput.printLine("Error: no option included with --name.");
          return;
        } else if (name.length > 0) {
          options.name = name;
        } else if (options.name == null) {
          _gitnuOutput.printLine("Error: no name provided.");
          return;
        }

        Commit.commit(options).then((value) {
          window.console.debug('$value ${value.toString()}');
        });
      }
    });
  }

  void addWrapper(List<String> args) {

  }

  void pushWrapper(List<String> args) {

  }

  void pullWrapper(List<String> args) {

  }

  void branchWrapper(List<String> args) {

  }

  void helpWrapper(List<String> args) {

  }

  // Progress of the Git call??? How to write this
  void progressCallback(int progress) {
    window.console.debug("${progress}");
  }

  /**
   * Searches the args list for a switch that includes a string parameter.
   * Returns defaultValue string if the switch is not present.
   * Returns null if the switch is present with no argument.
   * Returns the switch parameter string if switch is present.
   */
  String stringSwitch(List<String> args, String switchName,
                      String defaultValue) {
    String switchValue = switchFinder(args, switchName);
    if(switchValue == "") {
      return defaultValue;
    } else if (switchValue[0] != '-') {
      return switchValue;
    }
    return null;
  }

  /**
   * Searches the args list for a switch that includes an int parameter.
   * Returns defaultValue if the switch is not present.
   * Returns null if the switch is present with no argument.
   * Returns the switch parameter int if switch is present.
   */
  int intSwitch(List<String> args, String switchName, int defaultValue) {
    String switchValue = switchFinder(args, switchName);
    if (switchValue == "") {
      return defaultValue;
    } else if (int.parse(switchValue, onError: (value) { return -1;}) != -1) {
      return int.parse(switchValue);
    }
    return null;
  }

  /**
   * Searches the args list for a switch that includes a parameter.
   * Returns the empty string if the switch is missing a parameter. This is
   * an error case.
   * Returns null if the switch is not present. Continue execution.
   * Returns the parameter string if found.
   */
  String switchFinder(List<String> args, String switchName) {
    int index = args.indexOf(switchName);
    if (index != -1) {
      if (args.length > index + 1) {

        // Allows 2 word switch parameters, i.e. names
        if (args[index + 1].startsWith('"') && args.length > index + 2) {
          if (args[index + 2].endsWith('"')) {
            args.removeAt(index);
            List<String> first_word = args.removeAt(index).split('"');
            List<String> second_word = args.removeAt(index).split('"');
            return "${first_word[1]} ${second_word[0]}";
          }
        }

        args.removeAt(index);
        return args.removeAt(index);
      } else {
        return null;
      }
    } else {
      return "";
    }
  }
}
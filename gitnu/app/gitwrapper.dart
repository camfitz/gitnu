library gitnu;

import 'dart:async';
import 'dart:html';

import 'lib/spark/spark/ide/app/lib/git/options.dart';
import 'lib/spark/spark/ide/app/lib/git/git.dart';
import 'lib/spark/spark/ide/app/lib/git/objectstore.dart';

import 'lib/spark/spark/ide/app/lib/git/commands/clone.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/commit.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/push.dart';

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
        'help': helpWrapper
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
  Future<ObjectStore> _getRepo() {
    var completer = new Completer.sync();

    repoOperation() {
      ObjectStore store = new ObjectStore(_fileSystem.getCurrentDirectory());
      _fileSystem.getCurrentDirectory().getDirectory(".git").then(
        (DirectoryEntry gitDir) {
          store.load().then((value) {
            // Restored Git ObjectStore.
            completer.complete(store);
          });
        }, onError: (e) {
          // Not a Git directory.
          completer.complete(null);
        });
    }

    repoOperation();
    return completer.future;
  }

  /**
   * TODO(@camfitz): Finalise basic implementation of this method.
   */
  GitOptions buildOptions() {
    GitOptions custom = new GitOptions();

    custom.email = _defaultOptions.email;
    custom.name = _defaultOptions.name;
    custom.progressCallback = _defaultOptions.progressCallback;

    return custom;
  }

  /**
   * Allowable format:
   * git clone [options] [--] <repo>
   * Valid options:
   * --depth <int>
   * --branch <String>
   */
  void cloneWrapper(List<String> args) {
    if (args[0] == "clone") {
      String helpText = """
        usage: git clone [options] [--] &lt;repo&gt;
        <table class="help-list">
          <tr>
            <td>--depth <int>></td>
            <td>Depth to clone to</td>
          </tr>
          <tr>
            <td>--branch <string></td>
            <td>Branch to clone</td>
          </tr>
        </table>
      """;
      _gitnuOutput.printHtml(helpText);
      return;
    }
    
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
      _gitnuOutput.printLine("Error: no repo url passed to git clone.");
      return;
    }

    options.progressCallback = progressCallback;
    options.root = _fileSystem.getCurrentDirectory();
    options.repoUrl = args[0];
    options.store = new ObjectStore(_fileSystem.getCurrentDirectory());
    Clone clone = new Clone(options);
    options.store.init().then((_) {
      /**
       * TODO(@camfitz): Replace console debug with progress callback on screen,
       * awaiting callback implementation in Git library.
       */
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
    if (args[0] == "help") {
      String helpText = """
        usage: git commit [options] [--]
        <table class="help-list">
          <tr>
            <td>-m <string></td>
            <td>Message to accompany this commit</td>
          </tr>
          <tr>
            <td>--email <string></td>
            <td>Email to identify committer</td>
          </tr>
          <tr>
            <td>--name <string></td>
            <td>Name to identify committer</td>
          </tr>
        </table>
      """;
      _gitnuOutput.printHtml(helpText);
      return;
    }
    
    _getRepo().then((ObjectStore store) {
      if (store == null) {
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
          /**
           * TODO(@camfitz): Do something with the result.
           */
          window.console.debug('$value ${value.toString()}');
        });
      }
    });
  }

  void addWrapper(List<String> args) {

  }

  /**
   * Allowable format:
   * git push [options] [--]
   * Valid options:
   * -p <string> [password]
   * -l <string> [username]
   */
  void pushWrapper(List<String> args) {
    if (args[0] == "help") {
      String helpText = """
        usage: git push [options] [--]
        <table class="help-list">
          <tr>
            <td>-p <string></td>
            <td>Password to authenticate push</td>
          </tr>
          <tr>
            <td>-l <string></td>
            <td>Username to authenticate push</td>
          </tr>
        </table>
      """;
      _gitnuOutput.printHtml(helpText);
      return;
    }
    
    _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return;
      } else {
        GitOptions options = new GitOptions();
        options.store = store;
        options.root = _fileSystem.getCurrentDirectory();

        String password = stringSwitch(args, '-p', "");
        if (password == null) {
          _gitnuOutput.printLine("Error: no option included with -p.");
          return;
        } else if (password.length > 0) {
          options.password = password;
        }

        String username = stringSwitch(args, '-l', "");
        if (username == null) {
          _gitnuOutput.printLine("Error: no option included with -l.");
          return;
        } else if (username.length > 0) {
          options.username = username;
        }

        String repoUrl = stringSwitch(args, '--url', "");
        if (repoUrl == null) {
          _gitnuOutput.printLine("Error: no option included with -l.");
          return;
        } else if (repoUrl.length > 0) {
          options.repoUrl = repoUrl;
        }

        Push push = new Push();
        push.push(options).then((value) {
          /**
           * TODO(@camfitz): Do something with the result.
           */
          window.console.debug("$value");
        });
      }
    });
  }

  void pullWrapper(List<String> args) {

  }

  void branchWrapper(List<String> args) {

  }

  void helpWrapper(List<String> args) {
    String helpText = """
      usage: git &lt;command&gt; [&lt;args&gt;]
      <br><br>
      This app implements a subset of all git commands, as listed:
      <br>
      <table class="help-list">
        <tr>
          <td>clone</td>
          <td>Clone a repository into a new directory</td>
        </tr>
        <tr>
          <td>commit</td>
          <td>Record changes to the repository</td>
        </tr>
        <tr>
          <td>push</td>
          <td>Update remote refs along with associated objects</td>
        </tr>
        <tr>
          <td>pull</td>
          <td>Fetch from and merge with another repository</td>
        </tr>
        <tr>
          <td>branch</td>
          <td>List, create, or delete branches</td>
        </tr>
        <tr>
          <td>help</td>
          <td>Display help contents</td>
        </tr>
        <tr>
          <td>add</td>
          <td>[TBA] Add file contents to the index</td>
        </tr>
      </table>
    """;
    _gitnuOutput.printHtml(helpText);
  }

  /**
   * TODO(@camfitz): Implement progressCallback when it is completed in Git.
   */
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

        // Allows 2 word switch parameters, i.e. names (special case)
        /**
         * TODO(@camfitz): Improve this.
         */
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
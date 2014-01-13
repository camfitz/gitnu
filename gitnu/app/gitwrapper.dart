library gitnu;

import 'dart:async';
import 'dart:html';

import 'lib/spark/spark/ide/app/lib/git/options.dart';
import 'lib/spark/spark/ide/app/lib/git/git.dart';
import 'lib/spark/spark/ide/app/lib/git/objectstore.dart';

import 'lib/spark/spark/ide/app/lib/git/commands/branch.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/checkout.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/clone.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/commit.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/pull.dart';
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
    _defaultOptions = new GitOptions();

    // Attempt to restore username and email options
    chrome.storage.local.get([kNameStore, kEmailStore]).then((items) {
      if (items[kNameStore] != null || items[kEmailStore] != null) {
        _gitnuOutput.printHtml("""Restored options:<br>
                                  Name- ${items[kNameStore]}<br>
                                  Email- ${items[kEmailStore]}<br>""");
      }
      _defaultOptions.name = items[kNameStore];
      _defaultOptions.email = items[kEmailStore];
    });

    _defaultOptions.progressCallback = progressCallback;

    _cmds = {
        "clone": cloneCommand,
        "commit": commitCommand,
        "add": addCommand,
        "push": pushCommand,
        "pull": pullCommand,
        "branch": branchCommand,
        "merge": mergeCommand,
        "checkout": checkoutCommand,
        "help": helpCommand,
        "options": setCommand
    };

    git = new Git();
  }

  /**
   * Dispatches a received git command to its appropriate wrapper,
   * assuming the form
   * git args[0] args[1..n] = git command [args]
   */
  void gitDispatcher(List<String> args) {
    if (args.length > 0) {
      String gitOption = args.removeAt(0);
      if (_cmds[gitOption] is Function) {
        _cmds[gitOption](args);
      } else  {
        _gitnuOutput.printLine("git: '$gitOption' is not a git command.");
      }
    } else {
      helpCommand(args);
    }
  }

  /**
   * Loads the ObjectStore associated with a Git repo for the current
   * directory. Completes null if the directory was not a Git directory.
   * Returns a future ObjectStore.
   */
  Future<ObjectStore> _getRepo() {
    var completer = new Completer.sync();

    ObjectStore store = new ObjectStore(_fileSystem.getCurrentDirectory());
    _fileSystem.getCurrentDirectory().getDirectory(".git").then(
      (DirectoryEntry gitDir) {
        store.load().then((_) => completer.complete(store));
      }, onError: (e) => completer.complete(null));

    return completer.future;
  }

  /**
   * Provides a partially populated GitOptions object including
   * email, name and progressCallback from default options.
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
   * git options <name> <email>
   * Sets the name and email in local storage so the options are no
   * longer required to be included when committing.
   */
  void setCommand(List<String> args) {
    if (args[0] == "help") {
      String helpText = "usage: git clone &lt;name&gt; &lt;email&gt;";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    if (args.length != 2) {
      _gitnuOutput.printLine("Error: wrong number of arguments.");
      return;
    }

    _defaultOptions.name = args[0];
    _defaultOptions.email = args[1];

    chrome.storage.local.set({kNameStore: args[0], kEmailStore: args[1]}).then(
      (_) => _gitnuOutput.printHtml("""Retained options:<br>
                                        Name- ${args[0]}<br>
                                        Email- ${args[1]}<br>"""));
  }

  /**
   * Allowable format:
   * git clone [options] [--] <repo>
   * Valid options:
   * --depth <int>
   * --branch <String>
   */
  void cloneCommand(List<String> args) {
    if (args.length > 0 && args[0] == "help") {
      String helpText = """usage: git clone [options] [--] &lt;repo&gt;
        <table class="help-list">
          <tr><td>--depth &lt;int&gt;</td><td>Depth to clone to</td></tr>
          <tr><td>--branch &lt;string&gt;</td><td>Branch to clone</td></tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    GitOptions options = buildOptions();

    if (args.length == 0) {
      _gitnuOutput.printLine("Error: no arguments passed to git clone.");
      return;
    }

    try {
      options.depth = intSwitch(args, "--depth", options.depth);
      options.branchName = stringSwitch(args, "--branch", options.branchName);
    } catch (e) {
      _gitnuOutput.printLine("Error: ${e.message}");
      return;
    }

    if (args.length != 1) {
      _gitnuOutput.printLine("Error: no repo url passed to git clone.");
      return;
    }

    options.root = _fileSystem.getCurrentDirectory();
    options.repoUrl = args[0];
    options.store = new ObjectStore(_fileSystem.getCurrentDirectory());
    Clone clone = new Clone(options);
    options.store.init().then((_) {
      /**
       * TODO(camfitz): Replace console debug with progress callback on screen,
       * awaiting callback implementation in Git library.
       */
      _gitnuOutput.printLine("Cloning repo...");
      clone.clone().then((_) {
        _gitnuOutput.printLine("Finished cloning repo.");
      }, onError: (e) {
        _gitnuOutput.printLine("Clone error: $e");
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
  void commitCommand(List<String> args) {
    if (args.length > 0 && args[0] == "help") {
      String helpText = """usage: git commit [options] [--]
        <table class="help-list">
          <tr>
            <td>-m &lt;string&gt;</td>
            <td>Message to accompany this commit</td>
          </tr>
          <tr>
            <td>--email &lt;string&gt;</td>
            <td>Email to identify committer</td>
          </tr>
          <tr>
            <td>--name &lt;string&gt;</td>
            <td>Name to identify committer</td>
          </tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return;
      }

      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      try {
        options.commitMessage = stringSwitch(args, "-m", options.commitMessage);
        options.email = stringSwitch(args, "--email", options.email);
        if (options.email == null)
          throw new Exception("no email provided");
        options.name = stringSwitch(args, "--name", options.name);
        if (options.name == null)
          throw new Exception("no name provided");
      } catch (e) {
        _gitnuOutput.printLine("Error: ${e.message}");
        return;
      }

      _gitnuOutput.printLine("Committing.");
      Commit.commit(options).then((value) {
        // TODO(camfitz): Do something with the result.
        _gitnuOutput.printLine("Commit success: $value");
      }, onError: (e) {
        _gitnuOutput.printLine("Commit error: $e");
      });
    });
  }

  void addCommand(List<String> args) {
    // TODO(camfitz): Implement.
    _gitnuOutput.printLine("git: add not yet implemented.");
  }

  /**
   * Allowable format:
   * git push [options]
   * Valid options:
   * -p <string> [password]
   * -l <string> [username]
   * --url <string> [repo url]
   */
  void pushCommand(List<String> args) {
    if (args.length > 0 && args[0] == "help") {
      String helpText = """usage: git push [options] [--]
        <table class="help-list">
          <tr>
            <td>-p &lt;string&gt;</td>
            <td>Password to authenticate push</td>
          </tr>
          <tr>
            <td>-l &lt;string&gt;</td>
            <td>Username to authenticate push</td>
          </tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return;
      }

      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      try {
        options.password = stringSwitch(args, "-p", options.password);
        options.username = stringSwitch(args, "-l", options.username);
        options.repoUrl = stringSwitch(args, "--url", options.repoUrl);
      } catch (e) {
        _gitnuOutput.printLine("Error: ${e.message}");
        return;
      }

      Push push = new Push();
      push.push(options).then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
      }, onError: (e) {
        _gitnuOutput.printLine("Push error: $e");
      });
    });
  }

  /**
   * Allowable format:
   * git push [options]
   * Valid options:
   * -p <string> [password]
   * -l <string> [username]
   */
  void pullCommand(List<String> args) {
    if (args.length > 0 && args[0] == "help") {
      String helpText = """usage: git pull [options]
        <table class="help-list">
          <tr>
            <td>-p &lt;string&gt;</td>
            <td>Password to authenticate pull</td>
          </tr>
          <tr>
            <td>-l &lt;string&gt;</td>
            <td>Username to authenticate pull</td>
          </tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return;
      }

      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      try {
        options.password = stringSwitch(args, "-p", options.password);
        options.username = stringSwitch(args, "-l", options.username);
      } catch (e) {
        _gitnuOutput.printLine("Error: ${e.message}");
        return;
      }

      Pull pull = new Pull(options);
      pull.pull().then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
      }, onError: (e) {
        _gitnuOutput.printLine("Push error: $e");
      });
    });
  }

  /**
   * Allowable format:
   * git branch [<branch-name>]
   */
  void branchCommand(List<String> args) {
    // TODO(camfitz): Add option for no args (print branches)
    if (args.length > 0 && args[0] == "help") {
      String helpText = """usage: git branch &lt;branch-name&gt;""";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return;
      }

      GitOptions options = buildOptions();

      if (args.length == 0) {
        _gitnuOutput.printLine("Error: no branch name passed to git branch.");
        return;
      }

      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();
      options.branchName = args[0];

      Branch.branch(options).then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
      }, onError: (e) {
        _gitnuOutput.printLine("Branch error: $e");
      });
    });
  }

  /**
   * Allowable format:
   * git merge <branch-name>
   */
  void mergeCommand(List<String> args) {
    // TODO(camfitz): Implement.
    _gitnuOutput.printLine("git: merge not yet implemented.");
  }

  /**
   * Allowable format:
   * git checkout [options] <branch-name>
   * Valid options:
   * -b <branch-name> [create this branch]
   */
  void checkoutCommand(List<String> args) {
    if (args.length > 0 && args[0] == "help") {
      String helpText = """usage: git checkout [options] &lt;branch-name&gt;""";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return;
      }

      GitOptions options = buildOptions();

      if (args.length == 0) {
        _gitnuOutput.printLine("no branch name passed to git checkout.");
        return;
      }

      try {
        options.branchName = stringSwitch(args, "-b", options.branchName);
        if (options.branchName.length > 0) {
          // TODO(camfitz): Fix potential timing problem here.
          branchCommand([options.branchName]);
          checkoutCommand([options.branchName]);
          return;
        }
      } catch (e) {
        _gitnuOutput.printLine("Error: ${e.message}");
        return;
      }

      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();
      options.branchName = args[0];

      Checkout.checkout(options).then((value) {
        // TODO(camfitz): Do something with the result.
        _gitnuOutput.printLine("Checkout success: $value");
      }, onError: (e) {
        _gitnuOutput.printLine("Checkout error: $e");
      });
    });
  }

  void helpCommand(List<String> args) {
    String helpText = """usage: git &lt;command&gt; [&lt;args&gt;]<br><br>
      This app implements a subset of all git commands, as listed:
      <table class="help-list">
        <tr><td>clone</td><td>Clone a repository into a new directory</td></tr>
        <tr><td>commit</td><td>Record changes to the repository</td></tr>
        <tr>
          <td>push</td>
          <td>Update remote refs along with associated objects</td>
        </tr>
        <tr>
          <td>pull</td>
          <td>Fetch from and merge with another repository</td>
        </tr>
        <tr>
          <td>branch</td><td>List, create, or delete branches</td>
        </tr>
        <tr><td>help</td><td>Display help contents</td></tr>
        <tr>
          <td>options</td>
          <td>Retains name and email options in local storage</td>
        <tr><td>add</td><td>[TBA] Add file contents to the index</td></tr>
      </table>""";
    _gitnuOutput.printHtml(helpText);
  }

  // TODO(camfitz): Implement progressCallback when it is completed in Git.
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
    if(switchValue == "")
      return defaultValue;
    if (switchValue[0] != "-")
      return switchValue;
    throw new FormatException("no parameter included with $switchName");
  }

  /**
   * Searches the args list for a switch that includes an int parameter.
   * Returns defaultValue if the switch is not present.
   * Returns null if the switch is present with no argument.
   * Returns the switch parameter int if switch is present.
   */
  int intSwitch(List<String> args, String switchName, int defaultValue) {
    String switchValue = switchFinder(args, switchName);
    if (switchValue == "")
      return defaultValue;
    if (int.parse(switchValue, onError: (value) { return -1;}) != -1)
      return int.parse(switchValue);
    throw new FormatException("integer parameter required for $switchName");

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
        args.removeAt(index);
        return args.removeAt(index);
      }
      throw new FormatException("no parameter included with $switchName");
    }
    return "";
  }
}
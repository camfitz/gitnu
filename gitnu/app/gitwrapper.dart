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
import 'stringutils.dart';

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
        _gitnuOutput.printHtml("""restored options:<br>
                                  name- ${items[kNameStore]}<br>
                                  email- ${items[kEmailStore]}<br>""");
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
  Future gitDispatcher(List<String> args) {
    if (!args.isEmpty) {
      String gitOption = args.removeAt(0);
      if (_cmds[gitOption] is Function) {
        return _cmds[gitOption](args);
      } else  {
        _gitnuOutput.printLine("git: '$gitOption' is not a git command.");
        return new Future.value();
      }
    } else {
      return helpCommand(args);
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
    if (args.isEmpty || args[0] == "help") {
      String helpText = "usage: git clone &lt;name&gt; &lt;email&gt;";
      _gitnuOutput.printHtml(helpText);
      return;
    }

    if (args.length != 2) {
      _gitnuOutput.printLine("error: wrong number of arguments.");
      return;
    }

    _defaultOptions.name = args[0];
    _defaultOptions.email = args[1];

    chrome.storage.local.set({kNameStore: args[0], kEmailStore: args[1]}).then(
      (_) => _gitnuOutput.printHtml("""retained options:<br>
                                       name- ${args[0]}<br>
                                       email- ${args[1]}<br>"""));
  }

  /**
   * Allowable format:
   * git clone [options] [--] <repo>
   * Valid options:
   * --depth <int>
   * --branch <String>
   */
  Future cloneCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "help") {
      String helpText = """usage: git clone [options] [--] &lt;repo&gt;
        <table class="help-list">
          <tr><td>--depth &lt;int&gt;</td><td>depth to clone to</td></tr>
          <tr><td>--branch &lt;string&gt;</td><td>branch to clone</td></tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return new Future.value();
    }

    GitOptions options = buildOptions();

    if (args.isEmpty) {
      _gitnuOutput.printLine("error: no arguments passed to git clone.");
      return new Future.value();
    }

    try {
      options.depth = StringUtils.intSwitch(args, "depth", options.depth);
      options.branchName =
          StringUtils.stringSwitch(args, "branch", options.branchName);
    } catch (e) {
      _gitnuOutput.printLine("error: ${e.message}");
      return new Future.value();
    }

    if (args.length != 1) {
      _gitnuOutput.printLine("error: no repo url passed to git clone.");
      return new Future.value();
    }

    options.root = _fileSystem.getCurrentDirectory();
    options.repoUrl = args[0];
    options.store = new ObjectStore(_fileSystem.getCurrentDirectory());
    Clone clone = new Clone(options);
    return options.store.init().then((_) {
      /**
       * TODO(camfitz): Replace console debug with progress callback on screen,
       * awaiting callback implementation in Git library.
       */
      _gitnuOutput.printLine("cloning repo...");
      return clone.clone().then((_) {
        _gitnuOutput.printLine("finished cloning repo.");
        return new Future.value();
      }, onError: (e) {
        _gitnuOutput.printLine("clone error: $e");
        return new Future.value();
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
  Future commitCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "help") {
      String helpText = """usage: git commit [options] [--]
        <table class="help-list">
          <tr>
            <td>-m &lt;string&gt;</td>
            <td>message to accompany this commit</td>
          </tr>
          <tr>
            <td>--email &lt;string&gt;</td>
            <td>email to identify committer</td>
          </tr>
          <tr>
            <td>--name &lt;string&gt;</td>
            <td>name to identify committer</td>
          </tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: not a git repository.");
        return new Future.value();
      }

      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      try {
        options.commitMessage =
            StringUtils.stringSwitch(args, "m", options.commitMessage);
        options.email =
            StringUtils.stringSwitch(args, "email", options.email);
        if (options.email == null)
          throw new Exception("no email provided");
        options.name = StringUtils.stringSwitch(args, "--name", options.name);
        if (options.name == null)
          throw new Exception("no name provided");
      } catch (e) {
        _gitnuOutput.printLine("error: ${e.message}");
        return new Future.value();
      }

      _gitnuOutput.printLine("committing.");
      return Commit.commit(options).then((value) {
        // TODO(camfitz): Do something with the result.
        _gitnuOutput.printLine("commit success: $value");
        return new Future.value();
      }, onError: (e) {
        _gitnuOutput.printLine("commit error: $e");
        return new Future.value();
      });
    });
  }

  Future addCommand(List<String> args) {
    // TODO(camfitz): Implement.
    _gitnuOutput.printLine("git: add not yet implemented.");
    return new Future.value();
  }

  /**
   * Allowable format:
   * git push [options]
   * Valid options:
   * -p <string> [password]
   * -l <string> [username]
   * --url <string> [repo url]
   */
  Future pushCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "help") {
      String helpText = """usage: git push [options] [--]
        <table class="help-list">
          <tr>
            <td>-p &lt;string&gt;</td>
            <td>password to authenticate push</td>
          </tr>
          <tr>
            <td>-l &lt;string&gt;</td>
            <td>username to authenticate push</td>
          </tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: not a git repository.");
        return new Future.value();
      }

      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      try {
        options.password =
            StringUtils.stringSwitch(args, "p", options.password);
        options.username =
            StringUtils.stringSwitch(args, "l", options.username);
        options.repoUrl =
            StringUtils.stringSwitch(args, "url", options.repoUrl);
      } catch (e) {
        _gitnuOutput.printLine("Error: ${e.message}");
        return new Future.value();
      }

      Push push = new Push();
      return push.push(options).then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
        return new Future.value();
      }, onError: (e) {
        _gitnuOutput.printLine("push error: $e");
        return new Future.value();
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
  Future pullCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "help") {
      String helpText = """usage: git pull [options]
        <table class="help-list">
          <tr>
            <td>-p &lt;string&gt;</td>
            <td>password to authenticate pull</td>
          </tr>
          <tr>
            <td>-l &lt;string&gt;</td>
            <td>username to authenticate pull</td>
          </tr>
        </table>""";
      _gitnuOutput.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: not a git repository.");
        return new Future.value();
      }

      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      try {
        options.password =
            StringUtils.stringSwitch(args, "p", options.password);
        options.username =
            StringUtils.stringSwitch(args, "l", options.username);
      } catch (e) {
        _gitnuOutput.printLine("error: ${e.message}");
        return new Future.value();
      }

      Pull pull = new Pull(options);
      return pull.pull().then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
        return new Future.value();
      }, onError: (e) {
        _gitnuOutput.printLine("push error: $e");
        return new Future.value();
      });
    });
  }

  /**
   * Allowable format:
   * git branch [<branch-name>]
   */
  Future branchCommand(List<String> args) {
    // TODO(camfitz): Add option for no args (print branches)
    if (!args.isEmpty && args[0] == "help") {
      String helpText = "usage: git branch &lt;branch-name&gt;";
      _gitnuOutput.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: Not a git repository.");
        return new Future.value();
      }

      GitOptions options = buildOptions();

      if (args.isEmpty) {
        _gitnuOutput.printLine("error: no branch name passed to git branch.");
        return new Future.value();
      }

      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();
      options.branchName = args[0];

      return Branch.branch(options).then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
        return new Future.value();
      }, onError: (e) {
        _gitnuOutput.printLine("branch error: $e");
        return new Future.value();
      });
    });
  }

  /**
   * Allowable format:
   * git merge <branch-name>
   */
  Future mergeCommand(List<String> args) {
    // TODO(camfitz): Implement.
    _gitnuOutput.printLine("git: merge not yet implemented.");
    return new Future.value();
  }

  /**
   * Allowable format:
   * git checkout [options] <branch-name>
   * Valid options:
   * -b <branch-name> [create this branch]
   */
  Future checkoutCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "help") {
      String helpText = "usage: git checkout [options] &lt;branch-name&gt;";
      _gitnuOutput.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      if (store == null) {
        _gitnuOutput.printLine("git: not a git repository.");
        return new Future.value();
      }

      GitOptions options = buildOptions();

      if (args.isEmpty) {
        _gitnuOutput.printLine("no branch name passed to git checkout.");
        return new Future.value();
      }

      try {
        options.branchName =
            StringUtils.stringSwitch(args, "b", options.branchName);
        if (options.branchName.length > 0) {
          // TODO(camfitz): Fix potential timing problem here.
          return branchCommand([options.branchName]).then((_) {
            checkoutCommand([options.branchName]);
          });
        }
      } catch (e) {
        _gitnuOutput.printLine("error: ${e.message}");
        return new Future.value();
      }

      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();
      options.branchName = args[0];

      return Checkout.checkout(options).then((value) {
        // TODO(camfitz): Do something with the result.
        _gitnuOutput.printLine("checkout success: $value");
        return new Future.value();
      }, onError: (e) {
        _gitnuOutput.printLine("checkout error: $e");
        return new Future.value();
      });
    });
  }

  Future helpCommand(List<String> args) {
    String helpText = """usage: git &lt;command&gt; [&lt;args&gt;]<br><br>
      this app implements a subset of all git commands, as listed:
      <table class="help-list">
        <tr><td>clone</td><td>clone a repository into a new directory</td></tr>
        <tr><td>commit</td><td>record changes to the repository</td></tr>
        <tr>
          <td>push</td>
          <td>Update remote refs along with associated objects</td>
        </tr>
        <tr>
          <td>pull</td>
          <td>fetch from and merge with another repository</td>
        </tr>
        <tr>
          <td>branch</td><td>list, create, or delete branches</td>
        </tr>
        <tr><td>help</td><td>display help contents</td></tr>
        <tr>
          <td>options</td>
          <td>retains name and email options in local storage</td>
        <tr><td>add</td><td>[TBA] add file contents to the index</td></tr>
      </table>""";
    _gitnuOutput.printHtml(helpText);
    return new Future.value();
  }

  // TODO(camfitz): Implement progressCallback when it is completed in Git.
  void progressCallback(int progress) {
    window.console.debug("${progress}");
  }
}
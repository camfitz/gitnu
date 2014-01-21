library gitnu;

import 'dart:async';
import 'dart:html';

import 'lib/spark/spark/ide/app/lib/git/options.dart';
import 'lib/spark/spark/ide/app/lib/git/object.dart';
import 'lib/spark/spark/ide/app/lib/git/objectstore.dart';

import 'lib/spark/spark/ide/app/lib/git/commands/branch.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/checkout.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/commit.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/pull.dart';
import 'lib/spark/spark/ide/app/lib/git/commands/push.dart';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'gitcommands/gitcommand.dart';
import 'gitnuoutput.dart';
import 'gitnufilesystem.dart';
import 'statictoolkit.dart';
import 'stringutils.dart';

class GitWrapper {
  // Default options provided when running a Git command.
  GitOptions _defaultOptions;

  // Output class provided to print to the screen.
  GitnuOutput _output;

  // Store the FileSystem class so we know current folder location.
  GitnuFileSystem _fileSystem;

  // Map from names of git subcommands to factories.
  Map<String, Function> _commandFactories;

  // Map of Git specific command strings to functions.
  // TODO(camfitz): Remove when commands are swapped over to class format.
  Map<String, Function> _commands;

  // Local storage key names for reusable Git options.
  final String kNameStore = "gitName";
  final String kEmailStore = "gitEmail";

  GitWrapper(this._output, this._fileSystem) {
    _defaultOptions = new GitOptions();

    // Attempt to restore username and email options
    chrome.storage.local.get([kNameStore, kEmailStore]).then((items) {
      if (items[kNameStore] != null || items[kEmailStore] != null) {
        _output.printHtml("""restored options:<br>
                             name- ${items[kNameStore]}<br>
                             email- ${items[kEmailStore]}<br>""");
      }
      _defaultOptions.name = items[kNameStore];
      _defaultOptions.email = items[kEmailStore];
    });

    _defaultOptions.progressCallback = progressCallback;

    // TODO(camfitz): Remove when commands are swapped over to class format.
    _commands = {
        "add": addCommand,
        "branch": branchCommand,
        "checkout": checkoutCommand,
        "help": helpCommand,
        "log": logCommand,
        "merge": mergeCommand,
        "options": setCommand,
        "pull": pullCommand,
        "push": pushCommand,
        "status": statusCommand
    };

    _commandFactories = {
        "clone": () => new CloneCommand(_output, _fileSystem, buildOptions()),
        "commit": () => new CommitCommand(_output, _fileSystem, buildOptions())
    };
  }

  /**
   * Dispatches a received git command to its appropriate wrapper,
   * assuming the form
   * git args[0] args[1..n] = git command [args]
   */
  Future gitDispatcher(List<String> args) {
    if (!args.isEmpty) {
      String gitOption = args.removeAt(0);
      if (_commandFactories[gitOption] != null) {
        return _commandFactories[gitOption]().run(args);
      } else if (_commands[gitOption] != null) {
        return _commands[gitOption](args);
      } else  {
        _output.printLine("git: '$gitOption' is not a git command.");
        return new Future.value();
      }
    } else {
      return helpCommand(args);
    }
  }

  /**
   * Loads the ObjectStore associated with a Git repo for the current
   * directory. Throws Exception if the directory was not a Git directory.
   * Returns a future ObjectStore.
   */
  Future<ObjectStore> _getRepo() {
    ObjectStore store = new ObjectStore(_fileSystem.getCurrentDirectory());
    return _fileSystem.getCurrentDirectory().getDirectory(".git").then(
      (DirectoryEntry gitDir) {
        return store.load().then((_) => store);
      }, onError: (_) => throw new Exception("not a git repository."));
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
  Future setCommand(List<String> args) {
    if (args.isEmpty || args[0] == "--help") {
      String helpText = "usage: git clone &lt;name&gt; &lt;email&gt;";
      _output.printHtml(helpText);
      return new Future.value();
    }

    if (args.length != 2)
      throw new Exception("wrong number of arguments.");

    _defaultOptions.name = args[0];
    _defaultOptions.email = args[1];

    return chrome.storage.local.set(
        {kNameStore: args[0], kEmailStore: args[1]}).then(
      (_) => _output.printHtml("""retained options:<br>
                                  name- ${args[0]}<br>
                                  email- ${args[1]}<br>"""));
  }

  Future addCommand(List<String> args) {
    // TODO(camfitz): Implement.
    throw new Exception("add not yet implemented.");
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
    if (!args.isEmpty && args[0] == "--help") {
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
      _output.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      options.password = StringUtils.stringSwitch(args, "p", options.password);
      options.username = StringUtils.stringSwitch(args, "l", options.username);
      options.repoUrl = StringUtils.stringSwitch(args, "url", options.repoUrl);

      Push push = new Push();
      return push.push(options).then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
        return new Future.value();
      }, onError: (e) {
        _output.printLine("push error: $e");
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
    if (!args.isEmpty && args[0] == "--help") {
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
      _output.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      GitOptions options = buildOptions();
      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();

      options.password = StringUtils.stringSwitch(args, "p", options.password);
      options.username = StringUtils.stringSwitch(args, "l", options.username);

      Pull pull = new Pull(options);
      return pull.pull().then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
        return new Future.value();
      }, onError: (e) {
        _output.printLine("push error: $e");
        return new Future.value();
      });
    });
  }

  /**
   * Allowable format:
   * git branch [<branch-name>]
   */
  Future branchCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "--help") {
      String helpText = "usage: git branch &lt;branch-name&gt;";
      _output.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      GitOptions options = buildOptions();

      if (args.isEmpty) {
        return store.getCurrentBranch().then((String currentBranch) {
          return store.getAllHeads().then((List<String> branches) {
            branches.sort();
            for (String branch in branches) {
              if (currentBranch == branch)
                _output.printHtml(
                    '*&nbsp;<span class="green">$branch</span><br>');
              else
                _output.printHtml('&nbsp;&nbsp;$branch<br>');
            }
          });
        });
      }

      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();
      options.branchName = args[0];

      return Branch.branch(options).then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
        return new Future.value();
      }, onError: (e) {
        _output.printLine("branch error: $e");
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
    throw new Exception("merge not yet implemented.");
  }

  /**
   * Allowable format:
   * git checkout [options] <branch-name>
   * Valid options:
   * -b <branch-name> [create this branch]
   */
  Future checkoutCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "--help") {
      String helpText = "usage: git checkout [options] &lt;branch-name&gt;";
      _output.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      GitOptions options = buildOptions();

      if (args.isEmpty)
        throw new Exception("no branch name passed to git checkout.");

      options.branchName =
          StringUtils.stringSwitch(args, "b", options.branchName);
      if (options.branchName.length > 0) {
        // TODO(camfitz): Fix potential timing problem here.
        return branchCommand([options.branchName]).then((_) {
          checkoutCommand([options.branchName]);
        });
      }

      options.store = store;
      options.root = _fileSystem.getCurrentDirectory();
      options.branchName = args[0];

      return Checkout.checkout(options).then((value) {
        // TODO(camfitz): Do something with the result.
        _output.printLine("checkout success: $value");
        return new Future.value();
      }, onError: (e) {
        _output.printLine("checkout error: $e");
        return new Future.value();
      });
    });
  }

  /**
   * Allowable format:
   * git status
   */
  Future statusCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "--help") {
      String helpText = "usage: git status [--help]";
      _output.printHtml(helpText);
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      return store.getCurrentBranch().then((String currentBranch) {
        _output.printLine("On branch $currentBranch");
        return store.getHeadRef().then((String headRefName) {
          return store.getHeadForRef(headRefName).then((String parent) {
            return Commit.walkFiles(_fileSystem.getCurrentDirectory(),
                                    store).then((String sha) {
              return Commit.checkTreeChanged(store, parent, sha).then((_) {
                // TODO(camfitz): Expand this message to show changed files.
                _output.printLine("repo has changes to commit");
              }, onError: (e) {
                if (e == "commits_no_changes")
                  _output.printLine(
                      "nothing to commit, working directory clean");
              });
            });
          });
        });
      });
    });
  }

  /**
   * Allowable format:
   * git log [<branch-name>]
   */
  Future logCommand(List<String> args) {
    if (!args.isEmpty && args[0] == "--help") {
      String helpText = "usage: git log [&lt;branch-name&gt;]";
      _output.printHtml(helpText);
      return new Future.value();
    }

    Future printCommits(String headSha, ObjectStore store) {
      List<String> headShas = [headSha];
      // TODO(camfitz): Implement paging awaiting git library support.
      // Implement default "all", optional switch for num.
      return store.getCommitGraph(headShas, 10).then((CommitGraph graph) {
        for (CommitObject commit in graph.commits) {
          // TODO(camfitz): Replace split and toString, build output using
          // object getters. Blocking - implementation of CommitObject getters.
          List<String> commitLines = commit.toString().split("\n");
          bool firstEmptyLine = true;
          StringBuffer output = new StringBuffer();
          for (String commitLine in commitLines) {
            if (commitLine.length > "commit".length &&
                commitLine.substring(0, "commit".length) == "commit") {
              output.write('<span class="gold">$commitLine</span><br>');
            } else if (commitLine.isEmpty) {
              if (firstEmptyLine)
                output.write('<br /><div class="indent-14">');
              firstEmptyLine = false;
            } else {
              output.write('${StaticToolkit.htmlEscape(commitLine)}<br>');
            }
          }
          if (!firstEmptyLine)
            output.write('</div><br />');
          _output.printHtml(output.toString());
        }
      });
    }

    return _getRepo().then((ObjectStore store) {
      if (args.isEmpty) {
        return store.getHeadSha().then(
            (String headSha) => printCommits(headSha, store));
      }
      return store.getAllHeads().then((List<String> branches) {
        if (!branches.contains(args[0])) {
          _output.printLine("log error: ${args[0]} is not a branch.");
          return new Future.value();
        }
        return store.getHeadForRef('refs/heads/${args[0]}').then(
            (String headSha) => printCommits(headSha, store));
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
        <tr>
          <td>log</td><td>displays recent commits on the current branch</td>
        </tr>
        <tr>
          <td>status</td><td>displays current branch and working data</td>
        </tr>
        <tr><td>help</td><td>display help contents</td></tr>
        <tr>
          <td>options</td>
          <td>retains name and email options in local storage</td>
        <tr><td>add</td><td>[TBA] add file contents to the index</td></tr>
      </table>""";
    _output.printHtml(helpText);
    return new Future.value();
  }

  // TODO(camfitz): Implement progressCallback when it is completed in Git.
  void progressCallback(int progress) {
    window.console.debug("${progress}");
  }
}
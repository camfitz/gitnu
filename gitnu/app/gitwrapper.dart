library gitnu;

import 'dart:async';
import 'dart:html';

import 'lib/spark/spark/ide/app/lib/git/options.dart';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'gitcommands/gitcommand.dart';
import 'gitnu.dart';
import 'gitnufilesystem.dart';
import 'gitnuoutput.dart';
import 'gitnutabcompleter.dart';

class GitWrapper {
  // Default options provided when running a Git command.
  GitOptions _defaultOptions;

  // Output class provided to print to the screen.
  GitnuOutput _output;

  // Store the FileSystem class so we know current folder location.
  GitnuFileSystem _fileSystem;

  // Map from names of git subcommands to factories.
  Map<String, Function> _commandFactories;

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

    _commandFactories = {
        "add": () => new AddCommand(),
        "branch": () => new BranchCommand(_output, _fileSystem, buildOptions()),
        "checkout": () => new CheckoutCommand(
            _output, _fileSystem, buildOptions()),
        "clone": () => new CloneCommand(_output, _fileSystem, buildOptions()),
        "commit": () => new CommitCommand(_output, _fileSystem, buildOptions()),
        "help": () => new HelpCommand(_output),
        "log": () => new LogCommand(_output, _fileSystem),
        "merge": () => new MergeCommand(),
        "pull": () => new PullCommand(_output, _fileSystem, buildOptions()),
        "push": () => new PushCommand(_output, _fileSystem, buildOptions()),
        "options": () => new OptionsCommand(
            _output, _defaultOptions, kNameStore, kEmailStore),
        "status": () => new StatusCommand(_output, _fileSystem)
    };
  }

  ShellCommand _lookupCommand(String functionName) {
    if (_commandFactories[functionName] != null)
      return _commandFactories[functionName]();
    throw new Exception('$functionName is not a git command.');
  }

  /**
   * Dispatches a received git command to its appropriate wrapper,
   * assuming the form
   * git args[0] args[1..n] = git command [args]
   */
  Future gitDispatcher(List<String> args) {
    String subCommand = "help";
    if (!args.isEmpty)
      subCommand = args.removeAt(0);
    return _lookupCommand(subCommand).run(args);
  }

  /**
   * Dispatches a received tab completion request to the appropriate Git
   * command, if possible.
   *
   * Form expected for args:
   * git [partial-command] [partial-argument]
   *
   * If the command is not present or incomplete, the completer will return
   * Git command options appropriately.
   * If the command is complete, it's tab completer will be called.
   */
  Future<List<String>> tabCompleter(List<String> args) {
    return new Future.sync(() {
      // args = ["git", "x"] ==> x will be a portion of a command.
      if (args.length == 2) {
        return GitnuTabCompleter.filterList(
            _commandFactories.keys.toList()..sort(), args[1]);
      }

      // args = ["git", "x", "y"] ==> y may be an empty string (to denote a
      // trailing space, implying we should look to autocomplete y).
      if (_commandFactories.containsKey(args[1]) && args.length == 3) {
        return _lookupCommand(args[1]).getAllCompletions(args).then(
            (List<String> options) {
          return GitnuTabCompleter.filterList(options, args[2]);
        });
      }

      // Otherwise, return the empty list.
      // i.e. args = ["git"] => invalid input.
      return [];
    });
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

  // TODO(camfitz): Implement progressCallback when it is completed in Git.
  void progressCallback(int progress) {
    window.console.debug("${progress}");
  }
}
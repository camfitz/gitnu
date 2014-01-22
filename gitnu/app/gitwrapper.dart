library gitnu;

import 'dart:async';
import 'dart:html';

import 'lib/spark/spark/ide/app/lib/git/options.dart';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'gitcommands/gitcommand.dart';
import 'gitnuoutput.dart';
import 'gitnufilesystem.dart';

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
      } else  {
        _output.printLine("git: '$gitOption' is not a git command.");
        return new Future.value();
      }
    } else {
      return new HelpCommand(_output).run(args);
    }
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
library gitnu;

import 'dart:async';

import 'lib/spark/spark/ide/app/lib/git/options.dart';
import 'lib/spark/spark/ide/app/lib/git/git.dart';
import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'gitnuoutput.dart';

class GitWrapper {
  // Default options provided when running a Git command.
  GitOptions _defaultOptions;

  // Output class provided to print to the screen.
  GitnuOutput _gitnuOutput;

  // Map of Git specific command strings to functions.
  Map<String, Function> _cmds;

  // Holds the Git API object.
  Git git;

  // Local storage key names for reusable Git options.
  final String kNameStore = "gitName";
  final String kEmailStore = "gitEmail";

  GitWrapper(this._gitnuOutput) {
    _defaultOptions = new GitOptions();

    // Attempt to restore username and email options
    chrome.storage.local.get([kNameStore, kEmailStore]).then((items) {
      _defaultOptions.name = items[kNameStore];
      _defaultOptions.email = items[kEmailStore];
    });

    _cmds = {
        'clone': cloneWrapper,
        'add': addWrapper,
        'push': pushWrapper,
        'pull': pullWrapper,
        'branch': branchWrapper,
        'help': helpWrapper
    };

    git = new Git();
  }

  void gitDispatcher(List<String> args) {
    if(args.length > 0) {
      String gitOption = args.removeAt(0);

      // Function look up
      if (_cmds[gitOption] is Function) {
        _cmds[gitOption](args);
      } else  {
        _gitnuOutput.printLine('git: \'$gitOption\' is not a git command.');
      }

    } else {
      // git help
      helpWrapper(args);
    }
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

  void cloneWrapper(List<String> args) {

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

  }

}
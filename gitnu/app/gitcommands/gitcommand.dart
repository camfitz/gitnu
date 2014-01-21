library git_commands;

import 'dart:async';
import 'dart:html';

import 'package:args/args.dart';

import '../lib/spark/spark/ide/app/lib/git/objectstore.dart';
import '../lib/spark/spark/ide/app/lib/git/options.dart';

import '../lib/spark/spark/ide/app/lib/git/commands/clone.dart';

import '../gitnu.dart';
import '../gitnufilesystem.dart';
import '../gitnuoutput.dart';

part 'clonecommand.dart';

/**
 * Base class for all Git commands.
 */
class GitCommandBase {
  // Output class provided to print to the screen.
  GitnuOutput _output;

  // Store the FileSystem class so we know current folder location.
  GitnuFileSystem _fileSystem;

  GitCommandBase(this._output, this._fileSystem);

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
}

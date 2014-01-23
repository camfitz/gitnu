library git_commands;

import 'dart:async';
import 'dart:html';

import 'package:args/args.dart';
import 'package:chrome_gen/chrome_app.dart' as chrome;

import '../lib/spark/spark/ide/app/lib/git/object.dart';
import '../lib/spark/spark/ide/app/lib/git/objectstore.dart';
import '../lib/spark/spark/ide/app/lib/git/options.dart';

import '../lib/spark/spark/ide/app/lib/git/commands/branch.dart';
import '../lib/spark/spark/ide/app/lib/git/commands/checkout.dart';
import '../lib/spark/spark/ide/app/lib/git/commands/clone.dart';
import '../lib/spark/spark/ide/app/lib/git/commands/commit.dart';
import '../lib/spark/spark/ide/app/lib/git/commands/log.dart';
import '../lib/spark/spark/ide/app/lib/git/commands/pull.dart';
import '../lib/spark/spark/ide/app/lib/git/commands/push.dart';

import '../gitnu.dart';
import '../gitnufilesystem.dart';
import '../gitnuoutput.dart';
import '../statictoolkit.dart';

part 'addcommand.dart';
part 'branchcommand.dart';
part 'checkoutcommand.dart';
part 'clonecommand.dart';
part 'commitcommand.dart';
part 'helpcommand.dart';
part 'logcommand.dart';
part 'mergecommand.dart';
part 'optionscommand.dart';
part 'pullcommand.dart';
part 'pushcommand.dart';
part 'statuscommand.dart';

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

  String html(String input) {
    return StaticToolkit.htmlEscape(input);
  }
}

import 'dart:html';
import 'dart:async';

import 'constants.dart';
import 'gitnufilesystem.dart';
import 'gitnuoutput.dart';
import 'gitnuterminal.dart';
import 'gitwrapper.dart';
import 'rootpicker.dart';

void main() {
  new Gitnu().run();
}

class Gitnu {
  GitnuTerminal _term;
  GitnuFileSystem _fileSystem;
  GitnuOutput _output;
  GitWrapper _gitWrapper;

  Gitnu();

  void run() {
    _term = new GitnuTerminal(new GitnuTerminalView());
    _output = new GitnuOutput(_term.writeOutput);
    RootPicker rootPicker = new RootPicker(_output, startShell);
  }

  void startShell(DirectoryEntry root) {
    InputElement filePath = querySelector(kFilePath);
    filePath.value = root.fullPath;
    _term.clearCommand(null);
    _fileSystem = new GitnuFileSystem(_output, root);
    _gitWrapper = new GitWrapper(_output, _fileSystem);

    Map<String, Function> commandList;
    /**
     * Spec for user added functions-
     * args: list of arguments passed after the command sent to the terminal
     *
     * These functions should handle terminal output.
     */
    commandList = {
      'ls': _fileSystem.lsCommand,
      'cd': _fileSystem.cdCommand,
      'mkdir': _fileSystem.mkdirCommand,
      'open': _fileSystem.openCommand,
      'pwd': _fileSystem.pwdCommand,
      'rm': _fileSystem.rmCommand,
      'rmdir': _fileSystem.rmdirCommand,
      'cat': _fileSystem.catCommand,
      'git': _gitWrapper.gitDispatcher
    };

    Map<String, Function> tabCompletion;
    tabCompletion = {
      'ls': _fileSystem.tabCompleteDirectory,
      'cd': _fileSystem.tabCompleteDirectory,
      'open': _fileSystem.tabCompleteFile,
      'rm': _fileSystem.tabCompleteFile,
      'rmdir': _fileSystem.tabCompleteDirectory,
      'cat': _fileSystem.tabCompleteFile,
      'git': _gitWrapper.tabCompleter
    };

    _term.initialiseCommands(commandList, tabCompletion);
    _term.enablePrompt();
  }
}

/**
 * A command that is executable from the shell.
 * TODO: Make Filesystem commands conform to ShellCommand interface.
 */
abstract class ShellCommand {
  /**
   * |args| represents command line arguments and switches parsed from input.
   * args[0] will be the first argument after the identifier that lead to
   * this particular ShellCommand being instantiated.
   * i.e. for "git commit ..." args will be |...| in CommitCommand.
   * A command can throw an exception to be caught by the terminal and output
   * handled accordingly.
   */
  Future run(List<String> args);

  /**
   * A function that returns a list of options for the tab completer when
   * passed in arguments.
   */
  Future<List<String>> getAllCompletions(List<String> args);
}

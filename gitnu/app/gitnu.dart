import 'dart:html';
import 'gitnufilesystem.dart';
import 'gitnuoutput.dart';
import 'gitnuterminal.dart';
import 'gitwrapper.dart';

void main() {
  new Gitnu().run();
}

class Gitnu {
  GitnuTerminal _term;
  GitnuFileSystem _fileSystem;
  GitnuOutput _gitnuOutput;
  GitWrapper _gitWrapper;

  // Div ID- where to put the root file path.
  final String kFilePathDiv = "#file_path";

  // Button ID- click to choose root file path.
  final String kChooseDirButton = "#choose_dir";

  Gitnu();

  void run() {
    _term = new GitnuTerminal('#input-line', '#output', '#cmdline',
                              '#container', '#prompt');

    _gitnuOutput = new GitnuOutput(_term.writeOutput);

    _fileSystem = new GitnuFileSystem(kFilePathDiv, _gitnuOutput);
    InputElement chooseDirButton = document.querySelector(kChooseDirButton);
    chooseDirButton.onClick.listen((_) {
      _fileSystem.promptUserForFolderAccess(_fileSystem.kRootFolder, setRoot);
    });

    _gitWrapper = new GitWrapper(_gitnuOutput, _fileSystem);

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

    _term.initialiseCommands(commandList);
  }

  /**
   * Callback for the folder access prompt.
   * Displays the file path in the designated div, and sets it as root in
   * GitnuFileSystem.
   */
  void setRoot(DirectoryEntry root) {
    _fileSystem.setRoot(root);

    // Display filePath
    InputElement filePath = querySelector(kFilePathDiv);
    filePath.value = root.fullPath;
  }
}

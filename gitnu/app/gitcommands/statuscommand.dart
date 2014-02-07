part of git_commands;

class StatusCommand extends GitCommandBase implements ShellCommand {
  StatusCommand(GitnuOutput output, GitnuFileSystem fileSystem)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git status [--]
        <pre class="help">${getArgParser().getUsage()}</pre>""";
    _output.printHtml(helpText);
  }

  @override
  Future<List<String>> getAllCompletions(List<String> args) =>
      new Future.value([]);

  @override
  Future run(List<String> args) {
    ArgResults commandLineOptions = getArgParser().parse(args);

    if (commandLineOptions['help']) {
      help();
      return new Future.value();
    }

    return _getRepo().then((ObjectStore store) {
      return store.getCurrentBranch().then((String currentBranch) {
        _output.printHtml("On branch $currentBranch");

        return Status.getFileStatuses(store).then(
            (Map<String, FileStatus> statuses) {
          if (!statuses.isEmpty) {
            List<String> staged = [];
            List<String> modified = [];
            List<String> untracked = [];
            statuses.forEach((String path, FileStatus status) {
              switch (status.type) {
                case FileStatusType.STAGED:
                  staged.add(path);
                  break;
                case FileStatusType.MODIFIED:
                  modified.add(path);
                  break;
                case FileStatusType.UNTRACKED:
                  untracked.add(path);
                  break;
              }
            });

            int cwdPathLength = _fileSystem.getCurrentDirectoryString().length;

            if (!staged.isEmpty) {
              _output.printHtml("<br><br>Changes staged for commit:<br><br>");
              for (String item in staged) {
                String shortPath = item.substring(cwdPathLength);
                _output.printHtml('''<div class="indent-14">
                                     ${FileStatusType.STAGED.toLowerCase()}: 
                                     $shortPath<div>''');
              }
            }

            if (!modified.isEmpty) {
              _output.printHtml(
                  "<br><br>Changes not staged for commit:<br><br>");
              for (String item in modified) {
                String shortPath = item.substring(cwdPathLength);
                _output.printHtml('''<div class="indent-14">
                                     ${FileStatusType.MODIFIED.toLowerCase()}: 
                                     $shortPath<div>''');
              }
            }

            if (!untracked.isEmpty) {
              _output.printHtml("<br><br>Untracked changes:<br><br>");
              for (String item in untracked) {
                String shortPath = item.substring(cwdPathLength);
                _output.printHtml('''<div class="indent-14">
                                     ${FileStatusType.UNTRACKED.toLowerCase()}: 
                                     $shortPath<div>''');
              }
            }

            if (staged.isEmpty && modified.isEmpty && untracked.isEmpty) {
              _output.printHtml(
                  "<br><br>nothing to commit, working directory clean");
            }
          } else {
            _output.printHtml("<br><br>nothing in working directory");
          }
        });
      });
    });
  }
}
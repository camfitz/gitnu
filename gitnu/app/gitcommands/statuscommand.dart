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
  Future run(List<String> args) {
    ArgResults commandLineOptions = getArgParser().parse(args);

    if (commandLineOptions['help']) {
      help();
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
}
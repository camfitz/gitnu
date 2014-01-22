part of git_commands;

class BranchCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;

  BranchCommand(GitnuOutput output,
                GitnuFileSystem fileSystem,
                this._options)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git branch [--] ${html('[<branch-name>]')}
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
      if (commandLineOptions.rest.isEmpty) {
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

      _options.store = store;
      _options.root = _fileSystem.getCurrentDirectory();
      _options.branchName = commandLineOptions.rest[0];

      return Branch.branch(_options).then((value) {
        // TODO(camfitz): Do something with the result.
      }, onError: (e) {
        _output.printLine("branch error: $e");
      });
    });
  }
}

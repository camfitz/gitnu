part of git_commands;

class CloneCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;

  CloneCommand(GitnuOutput output,
               GitnuFileSystem fileSystem,
               this._options)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addOption('depth', help: html('<int> Depth to clone to'));
    parser.addOption('branch', help: html('<string> Branch to clone'));
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git clone [options] [--] ${html('<repo>')}
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

    _options.depth = commandLineOptions['depth'];
    _options.branchName = commandLineOptions['branch'];

    if (commandLineOptions.rest.isEmpty)
      throw new Exception("no repo url passed to git clone.");

    _options.root = _fileSystem.getCurrentDirectory();
    _options.repoUrl = commandLineOptions.rest[0];
    _options.store = new ObjectStore(_options.root);
    Clone clone = new Clone(_options);

    return _options.store.init().then((_) {
      /**
       * TODO(camfitz): Replace basic output with progress callback on screen,
       * awaiting callback implementation in Git library.
       */
      _output.printLine("cloning repo...");
      return clone.clone().then((_) {
        _output.printLine("finished cloning repo.");
      }, onError: (e) {
        _output.printLine("clone error: $e");
      });
    });
  }
}
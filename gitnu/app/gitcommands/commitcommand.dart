part of git_commands;

class CommitCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;

  CommitCommand(GitnuOutput output,
               GitnuFileSystem fileSystem,
               this._options)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addOption('message', abbr: 'm', help: html('<string> Message'));
    parser.addOption('email', defaultsTo: _options.email,
        help: html('<string> Email'));
    parser.addOption('name', defaultsTo: _options.name,
        help: html('<string> Name'));
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git commit [options] [--]
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
      _options.store = store;
      _options.root = _fileSystem.getCurrentDirectory();
      _options.commitMessage = commandLineOptions['message'];
      _options.email = commandLineOptions['email'];
      _options.name = commandLineOptions['name'];

      if (_options.email == null)
        throw new Exception("no email provided.");
      if (_options.name == null)
        throw new Exception("no name provided.");

      _output.printLine("committing.");
      return Commit.commit(_options).then((value) {
        // TODO(camfitz): Do something with the result.
        _output.printLine("commit success: $value");
      }, onError: (e) {
        _output.printLine("commit error: $e");
      });
    });
  }
}
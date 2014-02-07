part of git_commands;

class PullCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;

  PullCommand(GitnuOutput output,
              GitnuFileSystem fileSystem,
              this._options)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addOption('username', abbr: 'u', defaultsTo: _options.username,
        help: html('<string> Username to authenticate pull'));
    parser.addOption('password', abbr: 'p', defaultsTo: _options.password,
        help: html('<string> Password to authenticate pull'));
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git pull [options] [--]
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
      _options.store = store;
      _options.root = _fileSystem.getCurrentDirectory();

      _options.password = commandLineOptions['password'];
      _options.username = commandLineOptions['username'];

      Pull pull = new Pull(_options);
      return pull.pull().then((value) {
        // TODO(camfitz): Do something with the result.
        window.console.debug("$value");
      }, onError: (e) {
        _output.printLine("push error: $e");
      });
    });
  }
}
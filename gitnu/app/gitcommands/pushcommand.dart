part of git_commands;

class PushCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;

  PushCommand(GitnuOutput output,
              GitnuFileSystem fileSystem,
              this._options)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addOption('username', abbr: 'u', defaultsTo: _options.username,
        help: html('<string> Username to authenticate push'));
    parser.addOption('password', abbr: 'p', defaultsTo: _options.password,
        help: html('<string> Password to authenticate push'));
    parser.addOption('url', abbr: 'r', defaultsTo: _options.repoUrl,
        help: html('<string> Repository URL'));
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git push [options] [--]
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
      _options.repoUrl = commandLineOptions['url'];
      return pushWithPasswordPrompt();
    });
  }

  Future pushWithPasswordPrompt() {
    return Push.push(_options).then((value) {
      // TODO(camfitz): Do something with the result.
      _output.printLine("push was successful.");
    }, onError: (e) {
      final String invalidMessage = "Invalid username or password.";
      final String anonymousMessage = "Anonymous access to";
      if (e is StateError || e is NoSuchMethodError)
        throw e;
      if (e == invalidMessage || e.startsWith(anonymousMessage)) {
        _output.printLine("authentication failed.");
        AuthPrompt authPrompt =
            new AuthPrompt("Authentication required for push");
        return authPrompt.run().then((AuthDetails resultAuth) {
          if (resultAuth == null)
            throw new Exception("authentication required");
          _options.username = resultAuth.username;
          _options.password = resultAuth.password;
          return pushWithPasswordPrompt();
        });
      } else {
        _output.printLine("push error: $e");
      }
    });
  }
}
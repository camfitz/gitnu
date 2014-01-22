part of git_commands;

class CheckoutCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;

  CheckoutCommand(GitnuOutput output,
                  GitnuFileSystem fileSystem,
                  this._options)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addOption('branch', abbr: 'b', defaultsTo: _options.branchName,
        help: html('<string> Branch to checkout'));
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git checkout [options] ${html('<branch-name>')}
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
      if (args.isEmpty)
        throw new Exception("no branch name passed to git checkout.");

      _options.branchName = commandLineOptions['branch'];
      if (_options.branchName.length > 0) {
        // TODO(camfitz): Fix potential timing problem here.
        return new BranchCommand(_output, _fileSystem, _options).run(
            [_options.branchName]).then((_) {
          return new CheckoutCommand(_output, _fileSystem, _options).run(
              [_options.branchName]);
        });
      }

      _options.store = store;
      _options.root = _fileSystem.getCurrentDirectory();
      _options.branchName = args[0];

      return Checkout.checkout(_options).then((value) {
        // TODO(camfitz): Do something with the result.
        _output.printLine("checkout success: $value");
      }, onError: (e) {
        _output.printLine("checkout error: $e");
      });
    });
  }
}

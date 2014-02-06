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

      return store.getCurrentBranch().then((String currentBranch) {
        return store.getAllHeads().then((List<String> branches) {
          String branchName = commandLineOptions['branch'];
          if (branchName != null && !branchName.isEmpty) {
              if (branches.contains(branchName)) {
                throw new Exception("""A branch named '${branchName}' 
                                       already exists.""");
              }
              return new BranchCommand(_output, _fileSystem, _options).run(
                  [branchName]).then((_) {
                _options.branchName = null;
                return new CheckoutCommand(_output, _fileSystem, _options).run(
                    [branchName]);
              });
          }

          _options.store = store;
          _options.root = _fileSystem.getCurrentDirectory();
          _options.branchName = commandLineOptions.rest[0];

          if (currentBranch == _options.branchName)
            throw new Exception("Already on '$currentBranch'");

          return Checkout.checkout(_options).then((value) {
            _output.printLine("Switched to branch '${_options.branchName}'");
          }, onError: (e) => _output.printLine("checkout error: $e"));
        });
      });
    });
  }
}

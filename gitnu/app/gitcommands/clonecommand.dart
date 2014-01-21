part of git_commands;

/**
 * Allowable format:
 * git clone [options] [--] <repo>
 * Valid options:
 * --depth <int>
 * --branch <String>
 */
class CloneCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;

  CloneCommand(GitnuOutput output,
               GitnuFileSystem fileSystem,
               this._options)
      : super(output, fileSystem);

  ArgResults parse(List<String> args) {
    var parser = new ArgParser();
    parser.addOption('depth');
    parser.addOption('branch');
    parser.addFlag('help');
    return parser.parse(args);
  }

  void help() {
    String helpText = """usage: git clone [options] [--] &lt;repo&gt;
        <table class="help-list">
          <tr><td>--depth &lt;int&gt;</td><td>depth to clone to</td></tr>
          <tr><td>--branch &lt;string&gt;</td><td>branch to clone</td></tr>
        </table>""";
    _output.printHtml(helpText);
  }

  Future run(List<String> args) {
    ArgResults commandLineOptions = parse(args);

    if (commandLineOptions['help']) {
      help();
      return new Future.value();
    }

    _options.depth = commandLineOptions['depth'];
    _options.branchName = commandLineOptions['branch'];

    if (commandLineOptions.rest.isEmpty) {
      _output.printLine("error: no repo url passed to git clone.");
      return new Future.value();
    }

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
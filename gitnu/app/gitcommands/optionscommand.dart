part of git_commands;

class OptionsCommand extends GitCommandBase implements ShellCommand {
  // Stores default GitOptions to be used with this command.
  GitOptions _options;
  String _kNameStore;
  String _kEmailStore;

  OptionsCommand(GitnuOutput output,
                 this._options,
                 this._kNameStore,
                 this._kEmailStore)
      : super(output, null);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git options ${html('<name> <email>')}
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

    if (commandLineOptions.rest.length != 2)
      throw new Exception("options: wrong number of arguments.");

    _options.name = commandLineOptions.rest[0];
    _options.email = commandLineOptions.rest[1];

    return chrome.storage.local.set(
        {_kNameStore: _options.name, _kEmailStore: _options.email}).then(
            (_) => _output.printHtml("""retained options:<br>
                                        name- ${_options.name}<br>
                                        email- ${_options.email}<br>"""));
  }
}

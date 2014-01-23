part of git_commands;

class LogCommand extends GitCommandBase implements ShellCommand {
  LogCommand(GitnuOutput output, GitnuFileSystem fileSystem)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
    parser.addOption('num', abbr: 'n',
        help: html('<int> Number of log entries to show'));
    parser.addFlag('help');
    return parser;
  }

  void help() {
    String helpText = """usage: git log [--] ${html('[<branch-name>]')}
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
      String branch = null;
      if (commandLineOptions.rest.length > 0)
        branch = commandLineOptions.rest[0];
      // TODO(camfitz): Implement paging awaiting git library support.
      int num = null;
      if (commandLineOptions['num'] != null)
        num = int.parse(commandLineOptions['num']);
      return Log.log(store, num, branch).then((List<CommitObject> commits) {
        for (CommitObject commit in commits) {
          Map<String, String> commitMap = commit.toMap();
          _output.printHtml(
              '<span class="gold">commit ${commitMap['commit']}</span><br>');
          _output.printHtml(
              '''Author: ${commitMap['author_name']}
              &lt;${commitMap['author_email']}&gt;<br>''');
          _output.printHtml('Date: ${commitMap['date'].toString()}<br>');
          _output.printHtml(
              '<br><div class="indent-14">${commitMap['message']}</div><br>');
        }
      });
    });
  }
}
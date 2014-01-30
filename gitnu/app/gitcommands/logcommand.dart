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

    return _getRepo().then((store) {
      String branch = null;
      if (commandLineOptions.rest.length > 0)
        branch = commandLineOptions.rest[0];
      int num = null;
      if (commandLineOptions['num'] != null)
        num = int.parse(commandLineOptions['num']);
      GitnuPager pager = new GitnuPager(
          "Gitnu Log Viewer", new LogOutputGenerator(store, branch, num));
      return pager.run();
    });
  }
}

class LogOutputGenerator implements OutputGenerator {
  ObjectStore _store;
  Log _gitLog;
  int _count;
  int _max;

  LogOutputGenerator(this._store, String branch, this._max) {
    _gitLog = new Log(_store, branch: branch);
    _count = 0;
  }

  Future<String> getNext() {
    return _gitLog.getNextCommits().then((List<CommitObject> commits) {
      if (commits.length == 0 || (_max != null && _count >= _max))
        return null;
      StringBuffer b = new StringBuffer();
      for (CommitObject commit in commits) {
        b.write(formatCommit(commit.toMap()));
        _count++;
        if (_max != null && _count == _max)
          break;
      }
      return b.toString();
    });
  }

  StringBuffer formatCommit(Map<String, String> commit) {
    StringBuffer b = new StringBuffer();
    b.write('<span class="gold">commit ${commit['commit']}</span><br>');
    b.write('''Author: ${commit['author_name']}
               &lt;${commit['author_email']}&gt;<br>''');
    b.write('Date: ${commit['date'].toString()}<br>');
    b.write('<br><div class="indent-14">${commit['message']}</div><br>');
    return b;
  }
}
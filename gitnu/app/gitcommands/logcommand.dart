part of git_commands;

class LogCommand extends GitCommandBase implements ShellCommand {
  LogCommand(GitnuOutput output, GitnuFileSystem fileSystem)
      : super(output, fileSystem);

  ArgParser getArgParser() {
    ArgParser parser = new ArgParser();
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

    Future printCommits(String headSha, ObjectStore store) {
      List<String> headShas = [headSha];
      // TODO(camfitz): Implement paging awaiting git library support.
      // Implement default "all", optional switch for num.
      return store.getCommitGraph(headShas, 10).then((CommitGraph graph) {
        for (CommitObject commit in graph.commits) {
          // TODO(camfitz): Replace split and toString, build output using
          // object getters. Blocking - implementation of CommitObject getters.
          List<String> commitLines = commit.toString().split("\n");
          bool firstEmptyLine = true;
          StringBuffer output = new StringBuffer();
          for (String commitLine in commitLines) {
            if (commitLine.length > "commit".length &&
                commitLine.substring(0, "commit".length) == "commit") {
              output.write('<span class="gold">$commitLine</span><br>');
            } else if (commitLine.isEmpty) {
              if (firstEmptyLine)
                output.write('<br /><div class="indent-14">');
              firstEmptyLine = false;
            } else {
              output.write('${html(commitLine)}<br>');
            }
          }
          if (!firstEmptyLine)
            output.write('</div><br />');
          _output.printHtml(output.toString());
        }
      });
    }

    return _getRepo().then((ObjectStore store) {
      if (commandLineOptions.rest.isEmpty) {
        return store.getHeadSha().then(
            (String headSha) => printCommits(headSha, store));
      }
      return store.getAllHeads().then((List<String> branches) {
        if (!branches.contains(commandLineOptions.rest[0])) {
          _output.printLine(
              "log error: ${commandLineOptions.rest[0]} is not a branch.");
          return new Future.value();
        }
        return store.getHeadForRef(
            'refs/heads/${commandLineOptions.rest[0]}').then(
            (String headSha) => printCommits(headSha, store));
      });
    });
  }
}
part of git_commands;

class AddCommand extends GitCommandBase implements ShellCommand {
  AddCommand() : super(null, null);

  @override
  Future<List<String>> getAllCompletions(List<String> args) =>
      new Future.value([]);

  @override
  Future run(List<String> args) {
    // TODO(camfitz): Implement.
    throw new Exception("add not yet implemented.");
  }
}
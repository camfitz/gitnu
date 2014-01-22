part of git_commands;

class MergeCommand extends GitCommandBase implements ShellCommand {
  MergeCommand() : super(null, null);

  @override
  Future run(List<String> args) {
    // TODO(camfitz): Implement.
    throw new Exception("merge not yet implemented.");
  }
}

part of git_commands;

class HelpCommand extends GitCommandBase implements ShellCommand {
  HelpCommand(GitnuOutput output)
      : super(output, null);

  @override
  Future run(List<String> args) {
    String helpText =
        """usage: git &lt;command&gt; [&lt;args&gt;]<br><br>
           this app implements a subset of all git commands, as listed:
           <table class="help-list">
             <tr>
               <td>add</td>
               <td>[TBA] add file contents to the index</td>
             </tr>
             <tr>
               <td>branch</td>
               <td>list, create, or delete branches</td>
             </tr>
             <tr>
               <td>clone</td>
               <td>clone a repository into a new directory</td>
             </tr>
             <tr>
               <td>commit</td>
               <td>record changes to the repository</td>
             </tr>
             <tr>
               <td>checkout</td>
               <td>swap to a different branch</td>
             </tr>
             <tr>
               <td>help</td>
               <td>display help contents</td>
             </tr>
             <tr>
               <td>log</td>
               <td>displays recent commits on the current branch</td>
             </tr>
             <tr>
               <td>merge</td>
               <td>[TBA] combine two branches</td>
             </tr>
             <tr>
               <td>options</td>
               <td>retains name and email options in local storage</td>
             </tr>
             <tr>
               <td>pull</td>
               <td>fetch from and merge with another repository</td>
             </tr>
             <tr>
               <td>push</td>
               <td>Update remote refs along with associated objects</td>
             </tr>
             <tr>
               <td>status</td>
               <td>displays current branch and working data</td>
             </tr>
           </table>""";
    _output.printHtml(helpText);
    return new Future.value();
  }
}
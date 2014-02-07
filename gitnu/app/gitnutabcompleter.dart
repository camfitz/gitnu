library GitnuTabCompleter;

import 'dart:async';

import 'stringutils.dart';

/**
 * GitnuTabCompleter wraps the static tab completer function to allow for
 * testing.
 */
class GitnuTabCompleter {
  GitnuTabCompleter();

  /**
   * Takes a list of strings and returns a list with strings removed that
   * didn't begin with portion.
   */
  static List<String> filterList(List<String> options, String portion) {
    return options..removeWhere((String option) => !option.startsWith(portion));
  }

  /**
   * Handles tab completion by dispatching according to the function received.
   * TODO(camfitz): Merge implementation of the Git tabCompleter with this one
   * to unify the system.
   */
  static Future<Completion> tabCompleter(String cmdLine,
                           Map<String, Function> cmds,
                           Map<String, Function> tabCompletion) {
    List<String> args = StringUtils.parseCommandLine(cmdLine);
    // If there is an unfinished quotation set, args will be null.
    if (args == null)
      return new Future.value();

    // If there is text in the first argument, use it to filter possible
    // tab complete options.
    String filter = '';
    if (!args.isEmpty)
      filter = args[0];
    List<String> options =
        filterList(cmds.keys.toList(), filter)..sort();

    // Emulate the final space with an empty arg.
    if (cmdLine.endsWith(' '))
      args.add('');

    // If we received more than one argument, attempt to tab complete on
    // remaining arguments, else display the tab completion.
    if (args.length > 1) {
      // We can only tab complete on the second argument if we can recognise
      // a unique first argument and if a tab completion exists.
      if (options.length == 1 && tabCompletion[args[0]] != null) {
        return tabCompletion[args[0]](args).then((List<String> innerOptions) {
          return new Completion(cmdLine, args.last, innerOptions);
        });
      }
    } else {
      String lastArg = "";
      if (args.length != 0)
        lastArg = args.last;
      return new Future.value(new Completion(cmdLine, lastArg, options));
    }
  }
}


class Completion {
  String cmdLine;
  String last;
  List<String> options;

  Completion(this.cmdLine, this.last, this.options);
}